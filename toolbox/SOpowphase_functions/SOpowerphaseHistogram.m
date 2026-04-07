function [SOpower_mat, SOphase_mat, SOpower_bins, SOphase_bins, freq_bins, num_peaks_at_freq, SOpower_TIB, SOphase_TIB, peak_SOpower, peak_SOphase, peak_selection_inds, ...
    SOpower, SOpower_times, SOphase, SOphase_times, SOdata] = SOpowerphaseHistogram(varargin)
%SOPOWERPHASEHISTOGRAM  Compute slow-oscillation power and phase histogram matrices
%
%   Usage:
%       [SOpower_mat, SOphase_mat, SOpower_bins, SOphase_bins, freq_bins, num_peaks_at_freq, SOpower_TIB, SOphase_TIB, peak_SOpower, peak_SOphase, peak_selection_inds] = ...
%                                 SOpowerphaseHistogram(data, Fs, TFpeak_freqs, TFpeak_times, <options>)
%
%   Required Inputs:
%       data:           [Nx1] double - timeseries EEG data -- required
%       Fs:             double - sampling frequency of data (Hz) -- required
%       TFpeak_freqs:   [Px1] double - frequency each TF peak occurs (Hz) -- required
%       TFpeak_times:   [Px1] double - times each TF peak occurs (s) -- required
%
%   Optional Inputs:
%       TFpeak_stages: Px1 - sleep stage each TF peak occurs 5=W,4=R,3=N1,2=N2,1=N3
%       stage_times: 1xS double or single - stage times
%       stage_vals: 1xS double or single - numeric stage values 5=W,4=R,3=N1,2=N2,1=N3
%       EEG_times: 1xN double - times for each EEG data sample. Default = (0:length(data)-1)/Fs
%       time_range: 1x2 double - min and max times for which to include TFpeaks. Also used to normalize
%                   SOpower. Default = [EEG_times(1), EEG_times(end)]
%       isexcluded: 1xN logical - marks each time point of data to be excluded or not, e.g., due to artifacts. Default = all false.
%
%       SOpower: 1xM double - spectral power of slow oscillation computed
%                with multitaper spectral estimation. At a coarser
%                resolution than the original data timeseries since
%                windowing is used. Should be calculated using
%                computeSOpower(), with typical window parameters used at
%                [5, .5]. Default = [].
%       SOpower_times: 1xM double - times for each SOpower data sample.
%                      Also output by computeSOpower(). Default = [].
%       SOphase: 1xN double - unwrapped phase of slow oscillation. Should
%                be calculated using computeSOphase(). Default = [].
%       SOphase_times: 1xN double - times for each SOphase data sample.
%                      Also output by computeSOphase(). Default = [].
%
%    HISTOGRAM OPTIONAL:
%       see SOpowerphasehist_opts() for optional parameters
%
%   Outputs:
%       SOpower_mat:            2D double - SO power histogram data
%       SOphase_mat:            2D double - SO phase histogram data
%       SOpower_bins:           1D double - SO power bin center values for dimension 1 of SOpower_mat
%       SOphase_bins:           1D double - SO phase bin center values for dimension 1 of SOphase_mat
%       freq_bins:              1D double - frequency bin center values for dimension 2 of SOpower_mat and SOphase_mat
%       num_peaks_at_freq:      1D double - number of TFpeaks in each frequency bin
%       SOpow_TIB:              1xT double - time (minutes) in each SOpower bin for all stages 1-5 (0min if not in SOPH_stages)
%       SOphase_TIB:            1xT double - time (minutes) in each SOphase bin for all stages 1-5 (0min if not in SOPH_stages)
%       peak_SOpower:           1xP double - normalized slow oscillation power at each TFpeak
%       peak_SOphase:           1xP double - slow oscillation phase at each TFpeak
%       peak_selection_inds:    1xP logical - which TFpeaks are counted in the histogram
%       SOpower:                1xM double - SO power timeseries data
%       SOpower_times:          1xM double - SO power timeseries times
%       SOphase:                1xN double - SO phase timeseries data
%       SOphase_times:          1xN double - SO phase timeseries times
%       SOdata:                 1xN double - SO filtered timeseries data
%
%
%   Citation:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification", Sleep, 2022; zsac223.
%       https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

%%
% If a struct is input with settings/params, detect and reformat it to work with the input parser below.
struct_ind = cellfun(@isstruct,varargin); % Get index of the struct

if any(struct_ind)
    locs = find(struct_ind==1);
    struct_arguments = cellfun(@(x) struct2cell(x), varargin(locs), 'UniformOutput', false);
    struct_fieldnames = cellfun(@(x) fieldnames(x), varargin(locs), 'UniformOutput', false);
    opt_struct = cell2struct(vertcat(struct_arguments{:}), vertcat(struct_fieldnames{:}));
    varargin = varargin(~struct_ind); % Remove structs from the varargin

    argcell = namedargs2cell(opt_struct); % Convert the struct to cell array
    varargin = cat(2, varargin, argcell); % Add the new cell array with the params to the end of the varargin

    % Test to make sure that none of the additional parameters are already included
    str_cell = cellstr(varargin(cellfun(@(x)(ischar(x)|isstring(x)),varargin)));
    assert(length(str_cell) == length(unique(str_cell)), 'Cannot include struct and duplicate parameters.')
end

%% Parse inputs
p = inputParser;

addRequired(p, 'data', @(x) validateattributes(x, {'numeric'}, {'real','vector'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','scalar'}));

%TFpeak info
addRequired(p, 'TFpeak_freqs', @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector'}));
addRequired(p, 'TFpeak_times', @(x) validateattributes(x, {'numeric'}, {'real','finite','vector'}));
addOptional(p, 'TFpeak_stages', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','2d'}));

%Stage info
addOptional(p, 'stage_times', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nondecreasing','2d'}));
addOptional(p, 'stage_vals', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nonnegative','2d'}));

%EEG time settings
addOptional(p, 'EEG_times', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addOptional(p, 'time_range', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addOptional(p, 'isexcluded', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));

%Precomputed SOpower and SOphase vectors
addOptional(p, 'SOpower', [], @(x) validateattributes(x, {'numeric'}, {'real','2d'}));
addOptional(p, 'SOpower_times', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addOptional(p, 'SOphase', [], @(x) validateattributes(x, {'numeric'}, {'real','2d'}));
addOptional(p, 'SOphase_times', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));

%SOPH struct parameters
SOPH_options = SOpowerphasehist_opts(); % get the default parameters
%General settings
addOptional(p, 'freq_range', SOPH_options.freq_range, @(x) validateattributes(x,{'numeric'},{'real','finite','vector','numel',2}));
addOptional(p, 'freq_binsizestep', SOPH_options.freq_binsizestep, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'compute_rate', SOPH_options.compute_rate, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'SOPH_stages', SOPH_options.SOPH_stages, @(x) validateattributes(x,{'numeric'},{'real','nonempty','nonnegative','vector'})); % W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
%SOpower computation params
addOptional(p, 'SO_freqrange', SOPH_options.SO_freqrange, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector','numel',2}));
addOptional(p, 'SOpower_tapers', SOPH_options.SOpower_tapers, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'SOpower_window_params', SOPH_options.SOpower_window_params, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'SOpower_outlier_threshold', SOPH_options.SOpower_outlier_threshold, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addOptional(p, 'SOpower_norm_method', SOPH_options.SOpower_norm_method, @(x) validateattributes(x, {'char','string'}, {'nonempty','scalartext'}));
addOptional(p, 'SOpower_retain_Fs', SOPH_options.SOpower_retain_Fs, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
%SOpower Histogram specific settings
addOptional(p, 'SOpower_min_time_in_bin', SOPH_options.SOpower_min_time_in_bin, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));
%Ranges and bin step sizes determined dynamically with empty input [], set to fixed values when comparing between subjects
addOptional(p, 'SOpower_range', SOPH_options.SOpower_range, @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addOptional(p, 'SOpower_binsizestep', SOPH_options.SOpower_binsizestep, @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
%SOphase computation params
addOptional(p, 'SOphase_filter', SOPH_options.SOphase_filter);
%SOphase Histogram specific settings
addOptional(p, 'SOphase_min_peak_at_freq', SOPH_options.SOphase_min_peak_at_freq, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));
addOptional(p, 'SOphase_norm_dim', SOPH_options.SOphase_norm_dim, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));
addOptional(p, 'SOphase_range', SOPH_options.SOphase_range, @(x) validateattributes(x, {'numeric'}, {'real','finite','vector','numel',2}));
addOptional(p, 'SOphase_binsizestep', SOPH_options.SOphase_binsizestep, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));

%Display settings
addOptional(p, 'plot_on', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'verbose', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'scalar'}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

%% Compute SO-power and SO-phase
if ~isempty(SOpower) && ~isempty(SOpower_times) %#ok<*NODEF>
    % SOpower is computed outside of this wrapper function and passed in
    SOpower_norm_method = '';
else
    [SOpower, SOpower_times, ~, SOpower_norm_method] = computeSOpower(data, Fs,...
        'EEG_times', EEG_times, 'time_range', time_range, 'isexcluded', isexcluded,...
        'SO_freqrange', SO_freqrange, 'tapers', SOpower_tapers, 'window_params', SOpower_window_params,...
        'SOpower_outlier_threshold', SOpower_outlier_threshold, 'norm_method', SOpower_norm_method, 'retain_Fs', SOpower_retain_Fs);
end

if ~isempty(SOphase) && ~isempty(SOphase_times)
    % SOphase is computed outside of this wrapper function and passed in
    SOdata = [];
else
    [SOphase, SOphase_times, ~, SOdata] = computeSOphase(data, Fs,...
        'EEG_times', EEG_times, 'isexcluded', isexcluded, 'SO_freqrange', SO_freqrange, 'SOphase_filter', SOphase_filter);
end

% Note that once SOpower and SOphase have been computed, the isexcluded
% vector is no longer needed, since peaks that need to be excluded have NaN
% values in their respective properties.

%% Synchronize TF peaks between SOpower and SOphase for inclusion in the two histograms
% SOpower and SOphase interpolate the isexcluded vector to different
% resolutions, resulting in different numbers of TFpeak events with NaN
% properties. To ensure the same periods and the same TFpeak events are
% included in the histograms, mask SOphase with NaN values from SOpower.
SOpower_times_step = SOpower_times(2) - SOpower_times(1);
SOphase(isnan(interp1([SOpower_times(1)-SOpower_times_step, SOpower_times, SOpower_times(end)+SOpower_times_step], [SOpower(1), SOpower, SOpower(end)], SOphase_times))) = nan;

%% Compute SO-power histogram
if verbose
    disp('Computing SO-power histogram...');
end

[SOpower_mat, freq_bins, SOpower_bins, SOpower_TIB, ~, ~, peak_SOpower, hist_peakidx_SOpower, SOpower, SOpower_times] =...
    SOpowerHistogram(SOpower, SOpower_times, TFpeak_freqs, TFpeak_times,...
    'TFpeak_stages', TFpeak_stages, 'stage_times', stage_times, 'stage_vals', stage_vals,...
    'freq_range', freq_range, 'freq_binsizestep', freq_binsizestep, 'SO_range', SOpower_range, 'SO_binsizestep', SOpower_binsizestep,...
    'SO_freqrange', SO_freqrange, 'SOPH_stages', SOPH_stages, 'compute_rate', compute_rate,...
    'min_time_in_bin', SOpower_min_time_in_bin, 'norm_method', SOpower_norm_method,... # these two options are specific to SOpower histogram
    'plot_on', plot_on, 'verbose', verbose);

%% Compute SO-phase histogram
if verbose
    disp('Computing SO-phase histogram...');
end

[SOphase_mat, ~, SOphase_bins, SOphase_TIB, ~, num_peaks_at_freq, peak_SOphase, hist_peakidx_SOphase, SOphase, SOphase_times] =...
    SOphaseHistogram(SOphase, SOphase_times, TFpeak_freqs, TFpeak_times,...
    'TFpeak_stages', TFpeak_stages, 'stage_times', stage_times, 'stage_vals', stage_vals,...
    'freq_range', freq_range, 'freq_binsizestep', freq_binsizestep, 'SO_range', SOphase_range, 'SO_binsizestep', SOphase_binsizestep, ...
    'SO_freqrange', SO_freqrange, 'SOPH_stages', SOPH_stages, 'compute_rate', compute_rate,...
    'min_peak_at_freq', SOphase_min_peak_at_freq, 'norm_dim', SOphase_norm_dim,... # these two options are specific to SOphase histogram
    'plot_on', plot_on, 'verbose', verbose);

%% Verify that the same TF peaks are included in the two histograms
assert(all(hist_peakidx_SOpower == hist_peakidx_SOphase), 'SOpower and SOphase histograms included different TF peaks.')
peak_selection_inds = hist_peakidx_SOpower;

end
