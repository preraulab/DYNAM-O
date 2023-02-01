function [SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin, peak_SOpower, peak_selection_inds, SOpower, SOpower_times] = SOpowerHistogram(v1,v2,varargin)
% SOPOWERHISTOGRAM computes slow-oscillation power histogram matrix
% Usage:
%   [SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin, peak_SOpower_norm, peak_selection_inds] = ...
%                                 SOpowerHistogram(EEG, Fs, TFpeak_times, TFpeak_freqs, <options>)
%
%  Inputs:
%   REQUIRED:
%       EEG: 1xN double - timeseries EEG data --required
%       Fs: numerical - sampling frequency of EEG (Hz) --required
%                   OR
%       SOpower: 1xM double - timeseries SO power data --required
%       SOpower_times: 1xM double - timeseries SO power times --required
%
%       TFpeak_freqs: Px1 - frequency each TF peak occurs (Hz) --required
%       TFpeak_times: Px1 - times each TF peak occurs (s) --required
%
%   OPTIONAL:
%       TFpeak_stages: Px1 - sleep stage each TF peak occurs 5=W,4=R,3=N1,2=N2,1=N3
%       stage_vals:  1xS double - numeric stage values 5=W,4=R,3=N1,2=N2,1=N3
%       stage_times: 1xS double - stage times
%       freq_range: 1x2 double - min and max frequencies of TF peak to include in the histogram
%                   (Hz). Default = [0,40]
%       freq_binsizestep: 1x2 double - [size, step] frequency bin size and bin step for frequency
%                         axis of SO power histograms (Hz). Default = [1, 0.2]
%       SO_range: 1x2 double - min and max SO power values to consider in SO power analysis.
%                 Default calculated using min and max of SO power
%       SO_binsizestep: 1x2 double - [size, step] SO power bin size and step for SO power axis
%                            of histogram. Units are radians. Default
%                            size is (SO_range(2)-SOrange(1))/5, default step is
%                            (SO_range(2)-SOrange(1))/100
%       SO_freqrange: 1x2 double - min and max frequencies (Hz) considered to be "slow oscillation".
%                     Default = [0.3, 1.5]
%       SOPH_stages: stages in which to restrict the SOPH. Default: 1:3 (NREM only)
%                    W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
%       norm_dim: double - histogram dimension to normalize, not related to norm_method (default: 0 = no normalization)
%       compute_rate: logical - histogram output in terms of TFpeaks/min instead of count. 
%                               Default = true.
%       SOpower_outlier_threshold: double - cutoff threshold in standard deviation for excluding outlier SOpower values. 
%                                  Default = 3. 
%       norm_method: char - normalization method for SOpower. Options:'pNshiftS', 'percent', 'proportion', 'none'. Default: 'p2shift1234'
%                         For shift, it follows the format pNshiftS where N is the percentile and S is the list of stages (5=W,4=R,3=N1,2=N2,1=N3).
%                         (e.g. p2shift1234 = use the 2nd percentile of stages N3, N2, N1, and REM,
%                               p5shift123 = use the 5th percentile of stages N3, N2 and N1)
%       retain_Fs: logical - whether to upsample calculated SOpower to the sampling rate of EEG. Default = true
%       min_time_in_bin: numerical - time (minutes) required in each SO power bin to include
%                                  in SOpower analysis. Otherwise all values in that SO power bin will
%                                  be NaN. Default = 1.
%       EEG_times: 1xN double - times for each EEG sample. Default = (0:length(EEG)-1)/Fs
%       time_range: 1x2 double - min and max times for which to include TFpeaks. Also used to normalize
%                   SOpower. Default = [EEG_times(1), EEG_times(end)]
%       isexcluded: 1xN logical - marks each timestep of EEG as artifact or non-artifact. Default = all false.
%
%       plot_on: logical - SO power histogram plots. Default = false
%       verbose: logical - Verbose output. Default = true
%
%  Outputs:
%       SO_mat: SO power histogram (SOpower x frequency)
%       freq_cbins: 1xF double - centers of the frequency bins
%       SO_cbins: 1xPO double - centers of the power SO bins
%       time_in_bin: 1xTx5 double - minutes spent in each power bin for each stage
%       prop_in_bin: 1xT double - proportion of total time (all stages) in each bin spent in
%                          the selected stages
%       peak_SOpower: 1xP double - normalized slow oscillation power at each TFpeak
%       peak_selection_inds: 1xP logical - which TFpeaks are counted in the histogram
%       SOpower: 1xM double - timeseries SO power data
%       SOpower_times: 1xM double - timeseries SO power times
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

%%
%Check for first two inputs being EEG/FS or SOpower/SOpower_times
assert(nargin >= 2, 'First inputs must either be EEG/Fs or SOpower/SOpower_times')
if isscalar(v2)
    EEG = v1;
    Fs = v2;
    SOpower = [];
    SOpower_times = [];
    assert(isvector(EEG) & length(EEG)>1,'EEG must be a vector')
    assert(Fs>0,'Must have positive Fs');
else
    EEG = [];
    Fs = [];
    SOpower = v1;
    SOpower_times = v2;
end

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
addOptional(p, 'SO_range', [], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'SO_binsizestep', [], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'SO_freqrange', [0.3, 1.5], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan'}));
addOptional(p, 'SOPH_stages', 1:3, @(x) validateattributes(x, {'numeric', 'vector'}, {'real'})); % W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
addOptional(p, 'norm_dim', 0, @(x) validateattributes(x,{'numeric'},{'scalar'}));
addOptional(p, 'compute_rate', true, @(x) validateattributes(x,{'logical'},{}));

%SOpower specific settings
addOptional(p, 'SOpower_outlier_threshold', 3, @(x) validateattributes(x,{'numeric'},{'scalar'}));
addOptional(p, 'norm_method', 'p2shift1234', @(x) validateattributes(x, {'char', 'numeric'},{}));
addOptional(p, 'retain_Fs', true, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'min_time_in_bin', 1, @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','nonnan','nonnegative','integer'}));

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
    
%Handle SOpower/SOpower_times input
else
    SOpower_times_step = SOpower_times(2) - SOpower_times(1);
    if isempty(time_range)
        time_range = [min(SOpower_times)-SOpower_times_step, max(SOpower_times)+SOpower_times_step];
    else
        assert( (time_range(1) >= min(SOpower_times)-SOpower_times_step) & (time_range(2) <= max(SOpower_times)+SOpower_times_step), 'time_range cannot be outside of the time range described by "SOpower_times"');
    end
    
    % Compute SOpower stage
    if ~isempty(stage_vals) && ~isempty(stage_times)
        SOpower_stages = interp1(stage_times, stage_vals, SOpower_times, 'previous');
    else
        SOpower_stages = true;
    end
end

%% Compute SO power
if ~isempty(SOpower) % SOpower is directly provided
    assert(~isempty(SOpower_times), 'SOpower input only but no SOpower_times received.')
    norm_method = 'direct SOpower input';
else % Compute the normalized SOpower
    [SOpower, SOpower_times, SOpower_stages, norm_method] = computeSOpower(EEG, Fs, 'stage_vals', stage_vals, 'stage_times', stage_times,...
        'SO_freqrange', SO_freqrange, 'SOpower_outlier_threshold', SOpower_outlier_threshold, 'norm_method', norm_method,...
        'retain_Fs', retain_Fs, 'EEG_times', EEG_times, 'time_range', time_range, 'isexcluded', isexcluded);
end

% Get SOpower_times step size
SOpower_times_step = SOpower_times(2) - SOpower_times(1);

% Interpolate SOpower to peak time points
peak_SOpower = interp1([SOpower_times(1)-SOpower_times_step, SOpower_times, SOpower_times(end)+SOpower_times_step],...
    [SOpower(1), SOpower, SOpower(end)], TFpeak_times);

%% Get valid peak indices
% Compute TF-peak stages if not included
if isempty(TFpeak_stages) && ~isempty(stage_vals) && ~isempty(stage_times)
    TFpeak_stages = interp1(stage_times, stage_vals, TFpeak_times, 'previous');
end

% Remove TF-peaks outside of stage to reduce computational load during loop
if ~isempty(TFpeak_stages)
    stage_inds_peaks = ismember(TFpeak_stages, SOPH_stages);
else
    stage_inds_peaks = true(size(TFpeak_times));
end
nanSOpower_inds_peaks = ~isnan(peak_SOpower);
timerange_inds_peaks = TFpeak_times>=time_range(1) & TFpeak_times<=time_range(2);
peak_selection_inds = stage_inds_peaks & nanSOpower_inds_peaks & timerange_inds_peaks;

clear stage_inds_peaks nanSOpower_inds_peaks timerange_inds_peaks

%% Get valid SOpower indices
% Exclude unwanted stages, isexcluded, and outside time range
if islogical(SOpower_stages) && SOpower_stages
    SOpower_stages_valid = true(size(SOpower_stages));
else
    SOpower_stages_valid = ismember(SOpower_stages, SOPH_stages);
end
SOpower_excluded_valid = ~isnan(SOpower);
SOpower_times_valid = SOpower_times>=time_range(1) & SOpower_times<=time_range(2);

SOpower_valid = SOpower_stages_valid & SOpower_excluded_valid & SOpower_times_valid;
SOpower_valid_allstages = SOpower_excluded_valid & SOpower_times_valid;

clear SOpower_stages_valid SOpower_excluded_valid SOpower_times_valid

%% Compute the SO power histogram
% Set default range to max and min of SOpower being used in SOPH
if isempty(SO_range)
    SO_range(1) = min(SOpower(SOpower_valid));
    SO_range(2) = max(SOpower(SOpower_valid));
end
if isempty(SO_binsizestep)
    SO_binsizestep(1) = (SO_range(2) - SO_range(1)) / 5;
    SO_binsizestep(2) = (SO_range(2) - SO_range(1)) / 100;
end

[SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin] = TFPeakHistogram(SOpower, SOpower_stages, SOpower_times_step, SOpower_valid,...
    SOpower_valid_allstages, TFpeak_freqs(peak_selection_inds), peak_SOpower(peak_selection_inds),...
    'norm_method', norm_method, 'min_time_in_bin', min_time_in_bin,... # specific to SOpower histogram
    'Cmetric_label', 'SO-Power', 'C_range', SO_range, 'C_binsizestep', SO_binsizestep, 'freq_range', freq_range, 'freq_binsizestep', freq_binsizestep,...
    'norm_dim', norm_dim, 'compute_rate', compute_rate, 'plot_on', plot_on, 'xlabel_text', 'SO Power (normalized)', 'verbose', verbose);

end
