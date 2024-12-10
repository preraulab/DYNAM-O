function [SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin, peak_SOphase, peak_selection_inds, SOphase, SOphase_times] = SOphaseHistogram(v1,v2,varargin)
% SOPHASEHISTOGRAM computes slow-oscillation phase histogram matrix
% Usage:
%   [SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin, peak_SOphase, peak_selection_inds] = ...
%                                 SOphaseHistogram(EEG, Fs, TFpeak_freqs, TFpeak_times, <options>)
%
%  Inputs:
%   REQUIRED:
%       EEG: 1xN double - timeseries EEG data --required
%       Fs: numerical - sampling frequency of EEG (Hz) --required
%                   OR
%       SOphase: 1xN double - timeseries SO phase data --required
%       SOphase_times: 1xN double - timeseries SO phase times --required
%
%       TFpeak_freqs: Px1 - frequency each TF peak occurs (Hz) --required
%       TFpeak_times: Px1 - times each TF peak occurs (s) --required
%
%   OPTIONAL:
%       TFpeak_stages: Px1 - sleep stage each TF peak occurs 5=W,4=R,3=N1,2=N2,1=N3
%       stage_times: 1xS double - stage times
%       stage_vals:  1xS double - numeric stage values 5=W,4=R,3=N1,2=N2,1=N3
%       freq_range: 1x2 double - min and max frequencies of TF peak to include in the histogram
%                   (Hz). Default = [0,40]
%       freq_binsizestep: 1x2 double - [size, step] frequency bin size and bin step for frequency
%                         axis of SO phase histograms (Hz). Default = [1, 0.2]
%       SO_range: 1x2 double - min and max SO phase values (radians) to consider in SO phase analysis.
%                              Default is [-pi, pi]
%       SO_binsizestep: 1x2 double - [size, step] SO phase bin size and step for SO phase axis
%                       of histogram. Units are radians. Default size is 2*pi/5, default step is 2*pi/100
%       SO_freqrange: 1x2 double - min and max frequencies (Hz) considered to be "slow oscillation".
%                     Default = [0.3, 1.5]
%       SOPH_stages: stages in which to restrict the SOPH. Default: 1:3 (NREM only)
%                    W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
%       norm_dim: double - histogram dimension to normalize (default: 1 = normalize across each frequency)
%       compute_rate: logical - histogram output in terms of TFpeaks/min instead of count.
%                               Default = true.
%       min_time_in_bin: numerical - time (minutes) required in each SO phase bin to include
%                                  in SOphase analysis. Otherwise all values in that SO phase bin will
%                                  be NaN. Default = 0.
%       SOphase_filter: 1xF double - custom filter that will be used to estimate SOphase
%       EEG_times: 1xN double - times for each EEG sample. Default = (0:length(EEG)-1)/Fs
%       time_range: 1x2 double - min and max times for which to include TFpeaks.
%                                Default = [EEG_times(1), EEG_times(end)]
%       isexcluded: 1xN logical - marks each timestep of EEG as artifact or non-artifact. Default = all false.
%
%       plot_on: logical - SO phase histogram plots. Default = false
%       verbose: logical - Verbose output. Default = true
%
%  Outputs:
%       SO_mat: SO phase histogram (SOphase x frequency)
%       freq_cbins: 1xF double - centers of the frequency bins
%       SO_cbins: 1xPH - centers of the SO phase bins
%       time_in_bin: 1xTx5 - minutes spent in each phase bin for each stage
%       prop_in_bin: 1xT - proportion of total time (all stages) in each bin spent in
%                          the selected stages
%       peak_SOphase: 1xP double - slow oscillation phase at each TFpeak
%       peak_selection_inds: 1xP logical - which TFpeaks are counted in the histogram
%       SOphase: 1xN double - timeseries SO phase data
%       SOphase_times: 1xN double - timeseries SO phase times
%
%   Copyright 2024 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

%%
%Check for first two inputs being EEG/FS or SOphase/SOphase_times
assert(nargin >= 2, 'First inputs must either be EEG/Fs or SOphase/SOphase_times')
if isscalar(v2)
    EEG = v1;
    Fs = v2;
    SOphase = [];
    SOphase_times = [];
    assert(isvector(EEG) & length(EEG)>1,'EEG must be a vector')
    assert(Fs>0,'Must have positive Fs');
else
    EEG = [];
    Fs = [];
    SOphase = v1;
    SOphase_times = v2;
end

%% Parse input

p = inputParser;

%TFpeak info
addRequired(p, 'TFpeak_freqs', @(x) validateattributes(x, {'numeric'}, {'real','finite','nonempty','positive','vector'}));
addRequired(p, 'TFpeak_times', @(x) validateattributes(x, {'numeric'}, {'real','finite','nonempty','nonnan','vector'}));
addOptional(p, 'TFpeak_stages', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','2d'}));

%Stage info
addOptional(p, 'stage_times', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnan','2d'}));
addOptional(p, 'stage_vals', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','2d'}));

%EEG time settings
addOptional(p, 'EEG_times', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnan','2d'}));
addOptional(p, 'time_range', [], @(x) assert(isa(x, 'numeric') && (isempty(x) || length(x) == 2), 'Expected input to be an array with number of elements equal to 2.'));
addOptional(p, 'isexcluded', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','nonnan','2d'}));

%SOPH settings
SOPH_options = SOpowerphasehist_opts(); % get the default parameters
addOptional(p, 'freq_range', SOPH_options.freq_range, @(x) validateattributes(x,{'numeric'},{'real','finite','nonempty','nonnan','vector','numel',2}));
addOptional(p, 'freq_binsizestep', SOPH_options.freq_binsizestep, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnan','positive','vector','numel',2}));
addOptional(p, 'SO_range', SOPH_options.SOphase_range, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnan','vector','numel',2}));
addOptional(p, 'SO_binsizestep', SOPH_options.SOphase_binsizestep, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnan','positive','vector','numel',2}));
addOptional(p, 'SO_freqrange', SOPH_options.SO_freqrange, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnan','nonnegative','vector','numel',2}));
addOptional(p, 'SOPH_stages', SOPH_options.SOPH_stages, @(x) validateattributes(x,{'numeric'},{'real','nonempty','nonnegative','vector'})); % W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
addOptional(p, 'norm_dim', SOPH_options.SOphase_norm_dim, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnan','nonnegative','integer','scalar'}));
addOptional(p, 'compute_rate', SOPH_options.compute_rate, @(x) validateattributes(x,{'logical'},{'nonempty','nonnan','scalar'}));
addOptional(p, 'min_time_in_bin', 0, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnan','nonnegative','integer','scalar'}));

%SOphase specific settings
addOptional(p, 'SOphase_filter', SOPH_options.SOphase_filter);

%Display settings
addOptional(p, 'plot_on', false, @(x) validateattributes(x,{'logical'},{'nonempty','nonnan','scalar'}));
addOptional(p, 'verbose', true, @(x) validateattributes(x,{'logical'},{'nonempty','nonnan','scalar'}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

%Handle EEG/Fs input
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

    %Handle SOphase/SOphase_times input
else
    SOphase_times_step = SOphase_times(2) - SOphase_times(1);
    if isempty(time_range)
        time_range = [min(SOphase_times)-SOphase_times_step, max(SOphase_times)+SOphase_times_step];
    else
        assert( (time_range(1) >= min(SOphase_times)-SOphase_times_step) & (time_range(2) <= max(SOphase_times)+SOphase_times_step), 'time_range cannot be outside of the time range described by "SOphase_times"');
    end

    % Compute SOphase stage
    if  ~isempty(stage_times) && ~isempty(stage_vals)
        SOphase_stages = interp1(stage_times, stage_vals, SOphase_times, 'previous');
    else
        SOphase_stages = true;
    end
end

assert((SO_range(1) >= -pi) & (SO_range(2) <= pi), 'SO-phase range must be values between -pi and pi')
assert(SO_binsizestep(1) < 2*pi, 'SO-phase bin size must be less than 2*pi')

%% Compute SO phase
if ~isempty(SOphase) % SOphase is directly provided
    assert(~isempty(SOphase_times), 'SOphase input only but no SOphase_times received.')
else % Compute the SOphase
    [SOphase, SOphase_times, SOphase_stages] = computeSOphase(EEG, Fs, 'stage_times', stage_times, 'stage_vals', stage_vals,...
        'EEG_times', EEG_times, 'isexcluded', isexcluded, 'SO_freqrange', SO_freqrange, 'SOphase_filter', SOphase_filter);
end

% Get SOphase_times step size
SOphase_times_step = SOphase_times(2) - SOphase_times(1);

% Interpolate SOphase to peak time points
peak_SOphase = interp1([SOphase_times(1)-SOphase_times_step, SOphase_times, SOphase_times(end)+SOphase_times_step],...
    [SOphase(1), SOphase, SOphase(end)], TFpeak_times);

% Re-wrap phases to be between -pi and pi
peak_SOphase = wrapToPi(peak_SOphase);
SOphase = wrapToPi(SOphase);

%% Get valid peak indices
% Compute TF-peak stages if not included
if isempty(TFpeak_stages) && ~isempty(stage_times) && ~isempty(stage_vals)
    TFpeak_stages = interp1(stage_times, stage_vals, TFpeak_times, 'previous');
end

% Remove TF-peaks outside of stage to reduce computational load during loop
if ~isempty(TFpeak_stages)
    stage_inds_peaks = ismember(TFpeak_stages, SOPH_stages);
else
    stage_inds_peaks = true(size(TFpeak_times));
end

nanSOphase_inds_peaks = ~isnan(peak_SOphase);
timerange_inds_peaks = TFpeak_times>=time_range(1) & TFpeak_times<=time_range(2);
peak_selection_inds = stage_inds_peaks & nanSOphase_inds_peaks & timerange_inds_peaks;

clear stage_inds_peaks nanSOphase_inds_peaks timerange_inds_peaks

%% Get valid SOphase indices
% Exclude unwanted stages, isexcluded, and outside time range
if islogical(SOphase_stages) && SOphase_stages
    SOphase_stages_valid = true(size(SOphase_stages));
else
    SOphase_stages_valid = ismember(SOphase_stages, SOPH_stages);
end
SOphase_excluded_valid = ~isnan(SOphase);
SOphase_times_valid = SOphase_times>=time_range(1) & SOphase_times<=time_range(2);

SOphase_valid = SOphase_stages_valid & SOphase_excluded_valid & SOphase_times_valid;
SOphase_valid_allstages = SOphase_excluded_valid & SOphase_times_valid;

clear SOphase_stages_valid SOphase_excluded_valid SOphase_times_valid

%% Compute the SO phase histogram
[SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin] = TFPeakHistogram(SOphase,...
    SOphase_stages, SOphase_times_step, SOphase_valid, SOphase_valid_allstages,...
    TFpeak_freqs(peak_selection_inds), peak_SOphase(peak_selection_inds),...
    'circular_Cmetric', true, 'circular_bounds', SO_range,... # specific to SOphase histogram
    'Cmetric_label', 'SO-Phase', 'xlabel_text', 'SO Phase (radians)',...
    'C_range', SO_range, 'C_binsizestep', SO_binsizestep,...
    'freq_range', freq_range, 'freq_binsizestep', freq_binsizestep,...
    'norm_dim', norm_dim, 'compute_rate', compute_rate, 'min_time_in_bin', min_time_in_bin,...
    'plot_on', plot_on, 'verbose', verbose);

end
