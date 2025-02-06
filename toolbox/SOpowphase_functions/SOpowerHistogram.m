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
%       stage_times: 1xS double - stage times
%       stage_vals:  1xS double - numeric stage values 5=W,4=R,3=N1,2=N2,1=N3
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
%       min_time_in_bin: numerical - time (minutes) required in each SO power bin to include
%                                  in SOpower analysis. Otherwise all values in that SO power bin will
%                                  be NaN. Default = 10.
%       SOpower_outlier_threshold: double - cutoff threshold in standard deviation for excluding outlier SOpower values.
%                                  Default = 3.
%       norm_method: char - normalization method for SOpower. Options: 'pNshiftS', 'percent', 'proportion', 'none'. Default: 'p2shift1234'
%                         For shift, it follows the format pNshiftS where N is the percentile and S is the list of stages (5=W,4=R,3=N1,2=N2,1=N3).
%                         (e.g. p2shift1234 = use the 2nd percentile of stages N3, N2, N1, and REM,
%                               p5shift123 = use the 5th percentile of stages N3, N2 and N1)
%       retain_Fs: logical - whether to upsample calculated SOpower to the sampling rate of EEG. Default = true
%       EEG_times: 1xN double - times for each EEG sample. Default = (0:length(EEG)-1)/Fs
%       time_range: 1x2 double - min and max times for which to include TFpeaks. Also used to normalize
%                   SOpower. Default = [EEG_times(1), EEG_times(end)]
%       isexcluded: 1xN logical - marks each time point of data to be excluded or not, e.g., due to artifacts. Default = all false.
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
%Check for first two inputs being EEG/FS or SOpower/SOpower_times
assert(nargin >= 2, 'First inputs must either be EEG/Fs or SOpower/SOpower_times')
if isscalar(v2)
    EEG = v1;
    Fs = v2;
    SOpower = [];
    SOpower_times = [];
    assert(isvector(EEG) & length(EEG)>1, 'EEG must be a vector')
    assert(Fs>0, 'Must have positive Fs');
else
    EEG = [];
    Fs = [];
    SOpower = v1;
    SOpower_times = v2;
end

%% Parse input
p = inputParser;

%TFpeak info
addRequired(p, 'TFpeak_freqs', @(x) validateattributes(x, {'numeric'}, {'real','finite','nonempty','positive','vector'}));
addRequired(p, 'TFpeak_times', @(x) validateattributes(x, {'numeric'}, {'real','finite','vector'}));
addOptional(p, 'TFpeak_stages', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','2d'}));

%Stage info
addOptional(p, 'stage_times', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nondecreasing','2d'}));
addOptional(p, 'stage_vals', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nonnegative','2d'}));

%EEG time settings
addOptional(p, 'EEG_times', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addOptional(p, 'time_range', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addOptional(p, 'isexcluded', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));

%SOPH settings
SOPH_options = SOpowerphasehist_opts(); % get the default parameters
addOptional(p, 'freq_range', SOPH_options.freq_range, @(x) validateattributes(x,{'numeric'},{'real','finite','vector','numel',2}));
addOptional(p, 'freq_binsizestep', SOPH_options.freq_binsizestep, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'SO_range', SOPH_options.SOpower_range, @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addOptional(p, 'SO_binsizestep', SOPH_options.SOpower_binsizestep, @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addOptional(p, 'SO_freqrange', SOPH_options.SO_freqrange, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector','numel',2}));
addOptional(p, 'SOPH_stages', SOPH_options.SOPH_stages, @(x) validateattributes(x,{'numeric'},{'real','nonempty','nonnegative','vector'})); % W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
addOptional(p, 'norm_dim', 0, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));
addOptional(p, 'compute_rate', SOPH_options.compute_rate, @(x) validateattributes(x,{'logical'},{'scalar'}));
addOptional(p, 'min_time_in_bin', SOPH_options.SOpower_min_time_in_bin, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));

%SOpower specific settings
addOptional(p, 'SOpower_outlier_threshold', SOPH_options.SOpower_outlier_threshold, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addOptional(p, 'norm_method', '', @(x) validateattributes(x, {'char','string'}, {'scalartext'}));
addOptional(p, 'retain_Fs', SOPH_options.SOpower_retain_Fs, @(x) validateattributes(x,{'logical'},{'scalar'}));

%Display settings
addOptional(p, 'plot_on', false, @(x) validateattributes(x,{'logical'},{'scalar'}));
addOptional(p, 'verbose', true, @(x) validateattributes(x,{'logical'},{'scalar'}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

if ~isempty(EEG) %Handle EEG/Fs input
    %Force EEG to be a column vector
    if isrow(EEG)
        EEG = EEG(:);
    end

    if isempty(EEG_times) %#ok<*NODEF>
        EEG_times = (0:length(EEG)-1)/Fs;
    else
        %Force EEG_times to be a row vector
        if iscolumn(EEG_times)
            EEG_times = transpose(EEG_times);
        end
        assert(length(EEG_times) == length(EEG), 'EEG_times must be the same length as EEG');
    end

    if isempty(time_range)
        time_range = [min(EEG_times), max(EEG_times)];
    else
        assert( (time_range(1) >= min(EEG_times)) & (time_range(2) <= max(EEG_times)), 'time_range cannot be outside of the time range described by "EEG_times"');
    end

    if isempty(isexcluded)
        isexcluded = false(length(EEG), 1);
    else
        assert(length(isexcluded) == length(EEG),'isexcluded must be the same length as EEG');
    end

else %Handle SOpower/SOpower_times input
    SOpower_times_step = SOpower_times(2) - SOpower_times(1);
    if isempty(time_range)
        time_range = [min(SOpower_times)-SOpower_times_step, max(SOpower_times)+SOpower_times_step];
    else
        assert((time_range(1) >= min(SOpower_times)-SOpower_times_step) & (time_range(2) <= max(SOpower_times)+SOpower_times_step), 'time_range cannot be outside of the time range described by "SOpower_times"');
    end

    % Compute SOpower stage
    if ~isempty(stage_times) && ~isempty(stage_vals)
        SOpower_stages = interp1(stage_times, stage_vals, SOpower_times, 'previous');
    else
        SOpower_stages = true;
    end
end

%% Compute SO power
if ~isempty(SOpower) % SOpower is directly provided
    assert(~isempty(SOpower_times), 'SOpower input only but no SOpower_times received.')
    if isempty(norm_method)
        norm_method = 'direct SOpower input';
    end
    %Force SOpower to be a row vector for the interp1
    if iscolumn(SOpower)
        SOpower = transpose(SOpower);
    end
    %Force SOpower_times to be a row vector for the interp1
    if iscolumn(SOpower_times)
        SOpower_times = transpose(SOpower_times);
    end

else % Compute the normalized SOpower
    if isempty(norm_method)
        norm_method = SOPH_options.SOpower_norm_method;
    end
    [SOpower, SOpower_times, SOpower_stages, norm_method] = computeSOpower(EEG, Fs, 'stage_times', stage_times, 'stage_vals', stage_vals,...
        'EEG_times', EEG_times, 'time_range', time_range, 'isexcluded', isexcluded,...
        'SO_freqrange', SO_freqrange,...
        'SOpower_outlier_threshold', SOpower_outlier_threshold, 'norm_method', norm_method, 'retain_Fs', retain_Fs);
end

% Get SOpower_times step size
SOpower_times_step = SOpower_times(2) - SOpower_times(1);

% Interpolate SOpower to peak time points
peak_SOpower = interp1([SOpower_times(1)-SOpower_times_step, SOpower_times, SOpower_times(end)+SOpower_times_step],...
    [SOpower(1), SOpower, SOpower(end)], TFpeak_times); % peaks at isexcluded time points have NaN values here

%% Get valid peak indices
% Compute TF-peak stages if not included
if isempty(TFpeak_stages) && ~isempty(stage_times) && ~isempty(stage_vals)
    TFpeak_stages = interp1(stage_times, stage_vals, TFpeak_times, 'previous');
    TFpeak_stages(isnan(TFpeak_stages)) = 0; % a conservative choice to mark peaks outside scored stages as unknown
end

% Remove TF-peaks outside of stage to reduce computational load during loop
if ~isempty(TFpeak_stages)
    stage_inds_peaks = ismember(TFpeak_stages, SOPH_stages);
else
    stage_inds_peaks = true(size(TFpeak_times));
end
nanSOpower_inds_peaks = ~isnan(peak_SOpower); % isexcluded time points have NaN values here
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

SOpower_excluded_valid = ~isnan(SOpower); % isexcluded time points have NaN values here
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
    SO_binsizestep(1) = (SO_range(2) - SO_range(1)) / 10;
    SO_binsizestep(2) = (SO_range(2) - SO_range(1)) / 100;
end

[SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin] = TFPeakHistogram(SOpower,...
    SOpower_stages, SOpower_times_step, SOpower_valid, SOpower_valid_allstages,...
    TFpeak_freqs(peak_selection_inds), peak_SOpower(peak_selection_inds),...
    'norm_method', norm_method,... # specific to SOpower histogram
    'Cmetric_label', 'SO-Power', 'xlabel_text', 'SO Power (normalized)',...
    'C_range', SO_range, 'C_binsizestep', SO_binsizestep,...
    'freq_range', freq_range, 'freq_binsizestep', freq_binsizestep,...
    'norm_dim', norm_dim, 'compute_rate', compute_rate, 'min_time_in_bin', min_time_in_bin,...
    'plot_on', plot_on, 'verbose', verbose);

end
