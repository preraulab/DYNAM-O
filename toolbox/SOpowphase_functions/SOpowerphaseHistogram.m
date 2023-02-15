function [SOpow_mat, SOphase_mat, SOpow_bins, SOphase_bins, freq_bins, SOpow_TIB, SOphase_TIB, peak_SOpower, peak_SOphase, peak_selection_inds, SOpower, SOpower_times, SOphase, SOphase_times, SOdata] = SOpowerphaseHistogram(EEG,Fs,varargin)
% SOPOWERPHASEHISTOGRAM computes slow-oscillation power and phase histogram matrices
% Usage:
%   [SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin, peak_SOpower_norm, peak_selection_inds] = ...
%                                 SOpowerphaseHistogram(EEG, Fs, TFpeak_times, TFpeak_freqs, <options>)
%
%  Inputs:
%   REQUIRED:
%       EEG: 1xN double - timeseries EEG data --required
%       Fs: numerical - sampling frequency of EEG (Hz) --required
%       TFpeak_freqs: Px1 - frequency each TF peak occurs (Hz) --required
%       TFpeak_times: Px1 - times each TF peak occurs (s) --required
%
%   OPTIONAL:
%       TFpeak_stages: Px1 - sleep stage each TF peak occurs 5=W,4=R,3=N1,2=N2,1=N3
%       stage_vals:  1xS double - numeric stage values 5=W,4=R,3=N1,2=N2,1=N3
%       stage_times: 1xS double - stage times
%       freq_range: 1x2 double - min and max frequencies of TF peak to include in the histograms
%                   (Hz). Default = [0,40]
%       freq_binsizestep: 1x2 double - [size, step] frequency bin size and bin step for frequency
%                         axis of SO power/phase histograms (Hz). Default = [1, 0.2]
%       SOpower_range: 1x2 double - min and max SO power values to consider in SO power analysis.
%                      Default calculated using min and max of SO power
%       SOpower_binsizestep: 1x2 double - [size, step] SO power bin size and step for SO power axis
%                            of histogram. Units are radians. Default
%                            size is (SOpower_range(2)-SOpower_range(1))/5, default step is
%                            (SOpower_range(2)-SOpower_range(1))/100
%       SOphase_range: 1x2 double - min and max SO phase values (radians) to consider in SO phase analysis.
%                                   Default is [-pi, pi]
%       SOphase_binsizestep: 1x2 double - [size, step] SO phase bin size and step for SO phase axis
%                            of histogram. Units are radians. Default size is 2*pi/5, default step is 2*pi/100
%       SO_freqrange: 1x2 double - min and max frequencies (Hz) considered to be "slow oscillation".
%                     Default = [0.3, 1.5]
%       SOPH_stages: stages in which to restrict the SOPHs. Default: 1:3 (NREM only)
%                    W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
%       compute_rate: logical - histogram output in terms of TFpeaks/min instead of count.
%                               Default = true.
%       SOpower_outlier_threshold: double - cutoff threshold in standard deviation for excluding outlier SOpower values.
%                                  Default = 3.
%       SOpower_norm_method: char - normalization method for SOpower. Options:'pNshiftS', 'percent', 'proportion', 'none'. Default: 'p2shift1234'
%                         For shift, it follows the format pNshiftS where N is the percentile and S is the list of stages (5=W,4=R,3=N1,2=N2,1=N3).
%                         (e.g. p2shift1234 = use the 2nd percentile of stages N3, N2, N1, and REM,
%                               p5shift123 = use the 5th percentile of stages N3, N2 and N1)
%       SOpower_retain_Fs: logical - whether to upsample calculated SOpower to the sampling rate of EEG. Default = true
%       SOpower_min_time_in_bin: numerical - time (minutes) required in each SO power bin to include
%                                          in SOpower analysis. Otherwise all values in that SO power bin will
%                                          be NaN. Default = 1.
%       SOphase_filter: 1xF double - custom filter that will be used to estimate SOphase
%       SOphase_norm_dim: integer - which dimension of the SOphase histogram to normalize to add to 1. Default = 1
%       EEG_times: 1xN double - times for each EEG sample. Default = (0:length(EEG)-1)/Fs
%       time_range: 1x2 double - min and max times for which to include TFpeaks. Also used to normalize
%                   SOpower. Default = [EEG_times(1), EEG_times(end)]
%       isexcluded: 1xN logical - marks each timestep of EEG as artifact or non-artifact. Default = all false.
%
%       plot_on: logical - SO power histogram plots. Default = false
%       verbose: logical - Verbose output. Default = true
%
%  Outputs:
%       SOpow_mat:    2D double - SO power histogram data
%       SOphase_mat:  2D double - SO phase histogram data
%       SOpow_bins:   1D double - SO power bin center values for dimension 1 of SOpow_mat
%       SOphase_bins: 1D double - SO phase bin center values for dimension 1 of SOphase_mat
%       freq_bins:    1D double - frequency bin center values for dimension 2
%                     of SOpow_mat and SOphase_mat
%       SOpow_TIB:    1xT double - time (minutes) in each SOpower bin for all stages 1-5 (0min if not in SOPH_stages)
%       SOphase_TIB:  1xT double - time (minutes) in each SOphase bin for all stages 1-5 (0min if not in SOPH_stages)
%       peak_SOpower: 1xP double - normalized slow oscillation power at each TFpeak
%       peak_SOphase: 1xP double - slow oscillation phase at each TFpeak
%       peak_selection_inds: 1xP logical - which TFpeaks are counted in the histogram
%       SOpower: 1xM double - timeseries SO power data
%       SOpower_times: 1xM double - timeseries SO power times
%       SOphase: 1xN double - timeseries SO phase data
%       SOphase_times: 1xN double - timeseries SO phase times
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

%% Parse input

p = inputParser;

%TFpeak info
addRequired(p, 'TFpeak_freqs', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'TFpeak_times', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addOptional(p, 'TFpeak_stages', [], @(x) validateattributes(x, {'numeric', 'vector'}, {'real'}));

%Stage info
addOptional(p, 'stage_vals', [], @(x) validateattributes(x, {'double', 'single'}, {'real'}));
addOptional(p, 'stage_times', [], @(x) validateattributes(x, {'numeric', 'vector'}, {'real'}));

%SOPH settings
addOptional(p, 'freq_range', [0,40], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'freq_binsizestep', [1, 0.2], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'SOpower_range', [], @(x) validateattributes(x,{'numeric', 'vector'}, {'real', 'nonempty'}));
addOptional(p, 'SOpower_binsizestep', [], @(x) validateattributes(x,{'numeric', 'vector'}, {'real', 'nonempty'}));
addOptional(p, 'SOphase_range', [-pi,pi], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'SOphase_binsizestep', [(2*pi)/5, (2*pi)/100], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'SO_freqrange', [0.3, 1.5], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan'}));
addOptional(p, 'SOPH_stages', 1:3, @(x) validateattributes(x, {'numeric', 'vector'}, {'real'})); % W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
addOptional(p, 'compute_rate', true, @(x) validateattributes(x,{'logical'},{}));

%SOpower/phase specific settings
addOptional(p, 'SOpower_outlier_threshold', 3, @(x) validateattributes(x,{'numeric'},{'scalar'}));
addOptional(p, 'SOpower_norm_method', 'p2shift1234', @(x) validateattributes(x, {'char', 'numeric'},{}));
addOptional(p, 'SOpower_retain_Fs', true, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'SOpower_min_time_in_bin', 10, @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','nonnan','nonnegative','integer'}));
addOptional(p, 'SOphase_filter', []);
addOptional(p, 'SOphase_norm_dim', 1, @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','nonnan','nonnegative','integer'}));

%EEG time settings
addOptional(p, 'EEG_times', [], @(x) validateattributes(x, {'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'time_range', [], @(x) validateattributes(x, {'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'isexcluded', [], @(x) validateattributes(x, {'logical', 'vector'},{}));

%Display settings
addOptional(p, 'plot_on', false, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'verbose', true, @(x) validateattributes(x,{'logical'},{}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

if ~isempty(EEG)
    if isempty(EEG_times) %#ok<*NODEF>
        EEG_times = (0:length(EEG)-1)/Fs;
    else
        assert(length(EEG_times) == size(EEG,2), 'EEG_times must be the same length as EEG');
    end
    
    if isempty(time_range)
        time_range = [min(EEG_times), max(EEG_times)];
    else
        assert( (time_range(1) >= min(EEG_times)) & (time_range(2) <= max(EEG_times)), 'time_range cannot be outside of the time range described by "EEG_times"');
    end
    
    if isempty(isexcluded)
        isexcluded = false(size(EEG,2),1);
    else
        assert(length(isexcluded) == size(EEG,2),'isexcluded must be the same length as EEG');
    end
end

%% Compute SO-power and SO-phase
[SOpower, SOpower_times] = computeSOpower(EEG, Fs, 'stage_vals', stage_vals, 'stage_times', stage_times,...
    'SO_freqrange', SO_freqrange, 'SOpower_outlier_threshold', SOpower_outlier_threshold, 'norm_method', SOpower_norm_method,...
    'retain_Fs', SOpower_retain_Fs, 'EEG_times', EEG_times, 'time_range', time_range, 'isexcluded', isexcluded);
[SOphase, SOphase_times, ~, SOdata] = computeSOphase(EEG, Fs, 'stage_vals', stage_vals, 'stage_times', stage_times,...
    'SO_freqrange', SO_freqrange, 'SOphase_filter', SOphase_filter, 'EEG_times', EEG_times, 'isexcluded', isexcluded);

% % mask SOphase with SOpower nan values to use the same periods in the histograms
SOpower_times_step = SOpower_times(2) - SOpower_times(1);
SOphase(isnan(interp1([SOpower_times(1)-SOpower_times_step, SOpower_times, SOpower_times(end)+SOpower_times_step], [SOpower(1), SOpower, SOpower(end)], SOphase_times))) = nan;

% To use a custom precomputed SO phase filter, use the SOphase_filter argument
% custom_SOphase_filter = designfilt('bandpassfir', 'StopbandFrequency1', 0.1, 'PassbandFrequency1', 0.4, ...
%                        'PassbandFrequency2', 1.75, 'StopbandFrequency2', 2.05, 'StopbandAttenuation1', 60, ...
%                        'PassbandRipple', 1, 'StopbandAttenuation2', 60, 'SampleRate', 256);

%% Compute SO-power histogram
if verbose
    disp('Computing SO-power histogram...');
end

[SOpow_mat, freq_bins, SOpow_bins, SOpow_TIB, ~, peak_SOpower, hist_peakidx_SOpower, SOpower, SOpower_times] =...
    SOpowerHistogram(SOpower, SOpower_times, TFpeak_freqs, TFpeak_times,...
    'TFpeak_stages', TFpeak_stages, 'stage_vals', single(stage_vals), 'stage_times', stage_times,...
    'freq_range', freq_range, 'freq_binsizestep', freq_binsizestep, 'SO_range', SOpower_range, 'SO_binsizestep', SOpower_binsizestep,...
    'SO_freqrange', SO_freqrange, 'SOPH_stages', SOPH_stages, 'compute_rate', compute_rate,...
    'min_time_in_bin', SOpower_min_time_in_bin, 'plot_on', plot_on, 'verbose', verbose);

%% Compute SO-phase histogram
if verbose
    disp('Computing SO-phase histogram...');
end

[SOphase_mat, ~, SOphase_bins, SOphase_TIB, ~, peak_SOphase, hist_peakidx_SOphase, SOphase, SOphase_times] =...
    SOphaseHistogram(SOphase, SOphase_times, TFpeak_freqs, TFpeak_times,...
    'TFpeak_stages', TFpeak_stages, 'stage_vals', single(stage_vals), 'stage_times', stage_times,...
    'freq_range', freq_range, 'freq_binsizestep', freq_binsizestep, 'SO_range', SOphase_range, 'SO_binsizestep', SOphase_binsizestep, ...
    'SO_freqrange', SO_freqrange, 'SOPH_stages', SOPH_stages, 'norm_dim', SOphase_norm_dim, 'compute_rate', compute_rate,...
    'plot_on', plot_on, 'verbose', verbose);

%% Verify that the same TF peaks are included in the two histograms
assert(all(hist_peakidx_SOpower == hist_peakidx_SOphase), 'SOpower and SOphase histograms included different TF peaks.')
peak_selection_inds = hist_peakidx_SOpower;

end
