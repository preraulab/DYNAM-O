function [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, tfp_timings] = computeTFPeaks(data, Fs, stage_times, stage_vals, varargin)
%COMPUTETFPEAKS  Run watershed algorithm to extract time-frequency peaks from a spectrogram
%
%   Usage:
%       [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, tfp_timings] = ...
%               computeTFPeaks(data, Fs, stage_times, stage_vals, <options>)
%
%   Required Inputs:
%       data:                      [1xN] double - timeseries data to be analyzed -- required
%       Fs:                        double - sampling frequency of data (Hz) -- required
%       stage_times:               [1xM] double or single - timestamps of stage_vals -- required
%       stage_vals:                [1xM] double or single - sleep stage values at each time in
%                                  stage_times. Staging convention: 0=unidentified, 1=N3,
%                                  2=N2, 3=N1, 4=REM, 5=WAKE -- required
%
%   Optional Inputs:
%       t_data (opt):              [1xn] double - timestamps for data. Default = (0:length(data)-1)/Fs
%       time_range (opt):          [1x2] double - section of EEG to use in analysis (seconds).
%                                  Default = [min(t_data), max(t_data)]
%       features (opt):            [1xf] char or cell array of char -
%                                  features to be extracted from each peak region. Can be any subset of
%                                  {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height', 'HeightData',
%                                   'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume'} or 'all'. Default = 'all'
%       display_peaks (opt):       logical - whether to display all detected TF-peaks overlaid on spectrogram in a new figure
%       artifacts (opt):           [nx1] logical - boolean indicating artifact time points. Default = logical([]), run detect_artifacts()
%       artifact_filters (opt):    struct with 2 digitalFilter fields "hpFilt_high","hpFilt_broad" -
%                                  filters to be used for artifact detection. Default = []
%       verbose (opt):             logical - whether to print out messages when performing each computation step. Default = true
%
%       BASELINE_OPTS STRUCTURE PARAMETERS - see baseline_opts()
%       baseline_stages (opt):     [1xp] double - stages to include in spectrogram baseline computation. Default = [1,2,3,4,5]
%       baseline_exclude (opt):    [1xn] logical - boolean indicating time points to exclude in baseline computation. Default = logical([])
%       baseline_ptile (opt):      scalar - percentile of power spectral density at every frequency used for baseline subtraction
%                                  Default = 2
%       baseline_trim (opt):       2D array representing start and stop times for baseline trimming OR integer representing
%                                  buffer time (min) around the first and last sleep period. Default = [-inf, inf]
%
%       DETECTION_OPTS STRUCTURE PARAMETERS - see detection_opts()
%       double_watershed (opt):    logical - whether to run two rounds of watershed to achieve better
%                                  frequency resolution in addition to good temporal resolution. Default = true
%       mtm_dsfreqs (opt):         scalar - frequency bin resolution between two consecutive frequency samples,
%                                  which is used to determine nfft in spectrogram computation. Default = 0.1
%       mtm_freq_range (opt):      [1x2] double - multitaper method frequency range to compute spectrogram over (Hz). [lower, higher].
%                                  Default = [0, 30]
%       mtm_taper_params (opt):    [1x2] double - multitaper method parameter. [time half-bandwidth product, number of tapers].
%                                  Default = [2, 3]
%       mtm_window_length_1 (opt): scalar - window length for multitaper spectrogram computation used for the first round of watershed
%                                  Default = 1 (second)
%       mtm_window_length_2 (opt): scalar - window length for multitaper spectrogram computation used for the second round of watershed
%                                  Default = 2 (seconds)
%       mtm_window_stepsize (opt): scalar - step size between windows for multitaper spectrogram computations, used for both rounds
%                                  Default = 0.05 (seconds)
%       downsample_spect (opt):    2D array representing the number of decimation steps during downsampling spectrogram
%                                  for watershed and merging to extract peaks. First index decimates time (columns of spect).
%                                  Second index decimates frequency (rows of spect). Default = [], to be set by quality_setting
%       seg_time (opt):            scalar - length in seconds of each segment of spectrogram on which peaks are extracted.
%                                  Default = [], to be set by quality_setting
%       merge_thresh (opt):        scalar - threshold weight value for when to stop merge rule.
%                                  Default = [], to be set by quality_setting
%       quality_setting (opt):     character - Quality settings for the algorithm. Default = 'default'
%                                       'stokes_2023': matches Stokes et al. 2023 SLEEP paper settings exactly
%                                           downsample_spect = [];
%                                           seg_time = 60; (seconds)
%                                           merge_thresh = 8; (merge weight unit)
%                                       'precision': high resolution settings
%                                           downsample_spect = [];
%                                           seg_time = 30; (seconds)
%                                           merge_thresh = 8; (merge weight unit)
%                                       'default': speed-up with minimal impact on results *suggested*
%                                           downsample_spect = [2, 2]; (steps, steps)
%                                           seg_time = 30; (seconds)
%                                           merge_thresh = 11; (merge weight unit)
%                                  N.B.: using quality_setting will overwrite the downsample_spect, seg_time, and merge_thresh inputs
%       max_merges (opt):          integer - maximum number of merges to perform. Default = inf
%       trim_vol (opt):            scalar - fraction of maximum in trimmed volume (from 0 to 1), i.e. 1 means no trim. Default = 0.8
%       dur_max (opt):             scalar - maximum duration allowed for a peak. Default = 5 (seconds)
%       bw_max (opt):              scalar - maximum bandwidth allowed for a peak. Default = 15 (Hz)
%       refinement (opt):          logical - perform 1Hz refinement on the PeakFrequency feature in stats_table. Default = true
%       show_pbar (opt):           logical - whether to display progress bar during runSegmentedData(). Default = true
%       debug_mode (opt):          logical - whether to run runSegmentedData() in serial for-loop instead of parfor. Default = false
%
%   Outputs:
%       stats_table:        table - features of each TFpeak
%       spect:              2D double - spectrogram of data
%       stimes:             1D double - timestamp bin center values for dimension 2 of spect
%       sfreqs:             1D double - frequency bin center values for dimension 1 of spect
%       data_time_range:    [1xn] double - timeseries data in time_range
%       t_time_range:       [1xn] double - timestamps for data in time_range
%       artifacts:          1xT logical of times flagged as artifacts (logical OR of hf and bb artifacts)
%       tfp_timings:        struct - per-stage wallclock seconds with fields
%                           spect_pass1, artifact, baseline_pass1, extract_pass1,
%                           spect_pass2, baseline_pass2, extract_pass2, refine.
%                           Second-pass fields are 0 when double_watershed is false.
%                           Merged into runDYNAMO's master timings summary.
%
%   See Also: runWatershed, mergeWshedSegment, trimWshedRegions, extractTFPeaks, refinePeakFrequency
%
%
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
%   GITHUB     https://github.com
%
%   ATTRIBUTION
%   If you use this toolbox, please cite:
%
%   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
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

    % Check that no parameter NAME is passed both as an explicit name-value
    % pair and inside a struct. Only inspect odd-indexed string entries
    % (the names in name-value pairs) after the 4 required positional args.
    positional_count = 4; % data, Fs, stage_times, stage_vals
    name_indices = (positional_count+1):2:length(varargin);
    name_indices = name_indices(name_indices <= length(varargin));
    param_names = varargin(name_indices);
    param_names = param_names(cellfun(@(x) ischar(x) || isstring(x), param_names));
    assert(length(param_names) == length(unique(param_names)), ...
        'Cannot include struct and duplicate parameters.')
end

%% Parse inputs
p = inputParser;

% Required parameters
addRequired(p, 'data', @(x) validateattributes(x, {'numeric'}, {'real','vector'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','scalar'}));
addRequired(p, 'stage_times', @(x) validateattributes(x, {'double','single'}, {'real','finite','nondecreasing','vector'}));
addRequired(p, 'stage_vals', @(x) validateattributes(x, {'double','single'}, {'real','finite','nonnegative','vector'}));

% Optional parameters with default values
addOptional(p, 't_data', [], @(x) validateattributes(x,{'numeric'},{'real','finite','2d'}));
addOptional(p, 'time_range', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addOptional(p, 'features', 'all',  @(x) validateattributes(x,{'char','cell'},{'nonempty'}));
addOptional(p, 'display_peaks', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));

addOptional(p, 'artifacts', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));
addOptional(p, 'artifact_filters', [], @(x) validateattributes(x,{'double','struct'},{'nonnan'}));

addOptional(p, 'verbose', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'scalar'}));

%Baseline struct parameters
baseline_options = baseline_opts(); % get the default parameters
addOptional(p, 'baseline_stages', baseline_options.baseline_stages, @(x) validateattributes(x,{'numeric'},{'real','vector'}));
addOptional(p, 'baseline_exclude', baseline_options.baseline_exclude, @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));
addOptional(p, 'baseline_ptile', baseline_options.baseline_ptile, @(x) validateattributes(x,{'numeric'},{'real','scalar'}));
addOptional(p, 'baseline_trim', baseline_options.baseline_trim, @(x) isa(x,'numeric') && length(x) <= 2);

%TF peak detection struct parameters
detection_options = detection_opts(); % get the default parameters
addOptional(p, 'double_watershed', detection_options.double_watershed, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'mtm_dsfreqs', detection_options.mtm_dsfreqs, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addOptional(p, 'mtm_freq_range', detection_options.mtm_freq_range, @(x) validateattributes(x,{'numeric'},{'real','finite','vector','numel',2}));
addOptional(p, 'mtm_taper_params', detection_options.mtm_taper_params, @(x) validateattributes(x,{'numeric'},{'real','finite','vector','numel',2}));
addOptional(p, 'mtm_window_length_1', detection_options.mtm_window_length_1, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addOptional(p, 'mtm_window_length_2', detection_options.mtm_window_length_2, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addOptional(p, 'mtm_window_stepsize', detection_options.mtm_window_stepsize, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addOptional(p, 'downsample_spect', detection_options.downsample_spect, @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addOptional(p, 'seg_time', detection_options.seg_time, @(x) isa(x,'numeric') && (isempty(x) || isscalar(x)));
addOptional(p, 'merge_thresh', detection_options.merge_thresh, @(x) isa(x,'numeric') && (isempty(x) || isscalar(x)));
addOptional(p, 'quality_setting', detection_options.quality_setting, @(x) (ischar(x) || isstring(x)) && (isempty(x) || any(validatestring(x, {'stokes_2023', 'precision', 'default'}))));
addOptional(p, 'max_merges', detection_options.max_merges, @(x) validateattributes(x,{'numeric'},{'real','positive','scalar'}));
addOptional(p, 'trim_vol', detection_options.trim_vol, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addOptional(p, 'dur_max', detection_options.dur_max, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addOptional(p, 'bw_max', detection_options.bw_max, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addOptional(p, 'refinement', detection_options.refinement, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'show_pbar', detection_options.show_pbar, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'debug_mode', detection_options.debug_mode, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'parallel_mode', detection_options.parallel_mode, @(x) (ischar(x) || isstring(x)) && any(strcmp(x, {'', 'Processes', 'Threads'})));
addOptional(p, 'use_trim_mex', detection_options.use_trim_mex, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));

parse(p, data, Fs, stage_times, stage_vals, varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

%Force data to be a column vector
if isrow(data)
    data = data(:);
end

if isempty(t_data) %#ok<*NODEF>
    t_data = (0:length(data)-1)/Fs;
end

%Set default time range
if isempty(time_range)
    time_range = [min(t_data), max(t_data)];
end
assert(min(t_data)<max(time_range) & max(t_data)>min(time_range),'Staging times does not overlap at all with data times. Please check the staging input file and/or the EDF header.');

assert(min(t_data)<max(time_range) & max(t_data)>min(time_range),'Staging times does not overlap at all with data times. Please check the staging input file and/or the EDF header.');

%Set default features
if any(strcmpi(features, 'all'))
    features = {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height',...
        'HeightData', 'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume'};
end

%Check if filters are passed in
if isempty(artifact_filters)
    artifact_filters.hpFilt_high = [];
    artifact_filters.hpFilt_broad = [];
end

% Set baseline_range based on baseline_trim input
if isscalar(baseline_trim)
    buffer = baseline_trim;
    nonwake_stage_inds = ismember(stage_vals, [1,2,3,4]);
    baseline_range(1) = max([ min(stage_times(nonwake_stage_inds))-buffer*60, 0 ]); % x minutes before first non-wake stage
    baseline_range(2) = min([ max(stage_times(nonwake_stage_inds))+buffer*60, max(stage_times) ]); % x minutes after last non-wake stage
else
    if isempty(baseline_trim) % Empty array
        baseline_range = baseline_options.baseline_trim;
    elseif numel(baseline_trim) == 2 % Nonempty 2D array of start, stop
        baseline_range = baseline_trim;
    else
        error('Invalid baseline_trim. Enter a start and stop time range or a buffer time.')
    end
end

% Set default baseline_exclude
if isempty(baseline_exclude)
    baseline_exclude = false(1, length(data));
end

%% Timing struct — captures per-stage durations so runDYNAMO can print a
% uniform summary. Populated throughout this function; all fields are in
% seconds. Fields added in the order stages execute; second-pass fields
% (spect_pass2, extract_pass2) are 0 when double_watershed is false.
tfp_timings = struct();
tfp_timings.spect_pass1    = 0;
tfp_timings.artifact       = 0;
tfp_timings.baseline_pass1 = 0;
tfp_timings.extract_pass1  = 0;
tfp_timings.spect_pass2    = 0;
tfp_timings.baseline_pass2 = 0;
tfp_timings.extract_pass2  = 0;
tfp_timings.refine         = 0;

%% Truncate data to time range
time_range_inds = t_data >= time_range(1) & t_data <= time_range(2);
data_time_range = data(time_range_inds);
t_time_range = t_data(time_range_inds);
baseline_exclude = baseline_exclude(time_range_inds);

%% Compute spectrogram
t_stage = tic;
[spect, stimes, sfreqs, dur_min, bw_min, ht_db_min] = computeSpectrogram(mtm_taper_params, [mtm_window_length_1, mtm_window_stepsize], data_time_range, Fs, mtm_dsfreqs, mtm_freq_range, verbose);
stimes = stimes + t_time_range(1); % adjust the time axis to t_data
tfp_timings.spect_pass1 = toc(t_stage);

%% Artifact Detection
t_stage = tic;
if isempty(artifacts)
    if verbose
        disp('Performing artifact rejection...');
    end
    artifacts = detect_artifacts(data_time_range, Fs, 'hpFilt_high', artifact_filters.hpFilt_high, 'hpFilt_broad', artifact_filters.hpFilt_broad);
else
    artifacts = artifacts(time_range_inds); % apply time_range selection
end
tfp_timings.artifact = toc(t_stage);

%% Compute baseline spectrum used to flatten data spectrum
% Exclude artifacts, baseline_exclude, and times corresponding to stages not in baseline_stages from baseline computation
t_stage = tic;
exclude_stages = ~ismember(stage_vals, baseline_stages); %stages to use passed in
exclude_stages_resamp = interp1(stage_times, single(exclude_stages), t_time_range, 'previous')~=0; % ~=0 excludes both 1 and NaN (when t_time_range exceeds the interp1 range)
baseline_exclude = artifacts(:) | exclude_stages_resamp(:) | baseline_exclude(:);

baseline = computeBaseline(spect, stimes, t_time_range, baseline_exclude, baseline_range, baseline_ptile);
tfp_timings.baseline_pass1 = toc(t_stage);

%% Compute time-frequency peaks
if verbose
    disp('Extracting TF peaks from the spectrogram...');
end
tfp = tic;

% Augment extracted features with necessary computation features that will be removed later if extra added
compute_features = unique([features, {'PeakFrequency', 'PeakTime', 'Duration', 'Bandwidth', 'Height'}]);
if display_peaks
    compute_features = unique([compute_features, {'Boundaries'}]);
end

if double_watershed
    [stats_table, regions, borders] = runSegmentedData(spect, stimes, sfreqs, baseline, seg_time, downsample_spect, compute_features, ...
        dur_min, bw_min, merge_thresh, max_merges, trim_vol, verbose-1 + double(debug_mode), show_pbar, debug_mode, use_trim_mex);
else
    stats_table = runSegmentedData(spect, stimes, sfreqs, baseline, seg_time, downsample_spect, compute_features, ...
        dur_min, bw_min, merge_thresh, max_merges, trim_vol, verbose-1 + double(debug_mode), show_pbar, debug_mode, use_trim_mex);
end

tfp_timings.extract_pass1 = toc(tfp);
if verbose
    disp(['TF peak extraction took ' datestr(seconds(tfp_timings.extract_pass1),'HH:MM:SS'), newline]); %#ok<*DATST>
end

%% Filter stats_table based on {Duration, Bandwidth, PeakFrequency, and Height}
filter_idx = filterStatsTable(stats_table, [dur_min, dur_max], [bw_min, bw_max], [-inf inf], ht_db_min, verbose);
stats_table = stats_table(filter_idx, :);

if isempty(stats_table)
    error('No TFpeaks found');
end

%% Do a second round of watershed with finer frequency resolution of spectrogram
if double_watershed

    % Save the stimes from the first round of watershed
    stimes_first = stimes;

    % Compute multitaper spectrogram using new parameters with smaller spectral resolution
    t_stage = tic;
    [spect, stimes, sfreqs, ~, bw_min, ht_db_min] = computeSpectrogram(mtm_taper_params, [mtm_window_length_2, mtm_window_stepsize], data_time_range, Fs, mtm_dsfreqs, mtm_freq_range, verbose);
    stimes = stimes + t_time_range(1); % adjust the time axis to t_data
    tfp_timings.spect_pass2 = toc(t_stage);

    % Recompute baseline using the same baseline_exclude computed above
    t_stage = tic;
    baseline = computeBaseline(spect, stimes, t_time_range, baseline_exclude, baseline_range, baseline_ptile);

    % Mask the spectrogram using extracted TFpeaks from the first round of watershed
    spect_masked = maskSpectrogram(spect, stimes_first, stimes, regions, borders);
    tfp_timings.baseline_pass2 = toc(t_stage);

    % Compute time-frequency peaks
    if verbose
        disp('[2nd] Extracting TF peaks from the spectrogram...');
    end
    tfp = tic;

    stats_table = runSegmentedData(spect_masked, stimes, sfreqs, baseline, seg_time, downsample_spect, compute_features, ...
        dur_min, bw_min, merge_thresh, max_merges, trim_vol, verbose-1 + double(debug_mode), show_pbar, debug_mode, use_trim_mex);

    tfp_timings.extract_pass2 = toc(tfp);
    if verbose
        disp(['[2nd] TF peak extraction took ' datestr(seconds(tfp_timings.extract_pass2),'HH:MM:SS'), newline]);
    end

    % Filter stats_table based on {Duration, Bandwidth, PeakFrequency, and Height}
    filter_idx = filterStatsTable(stats_table, [dur_min, dur_max], [bw_min, bw_max], [-inf inf], ht_db_min, verbose);
    stats_table = stats_table(filter_idx, :);

    if isempty(stats_table)
        error('No TFpeaks found');
    end
end

%% Refine TFpeak frequency estimation using Hann windows
if refinement
    if verbose
        disp('Refining peaks...');
    end
    rft = tic;

    stats_table = refinePeakFrequency(data_time_range, Fs, stats_table, 'freq_range', mtm_freq_range, 't', t_time_range);
    stats_table(isnan(stats_table.PeakFrequency),:) = [];

    tfp_timings.refine = toc(rft);
    if verbose
        disp(['TF peak refinement took ' datestr(seconds(tfp_timings.refine),'HH:MM:SS'), newline]);
    end
end

%% Remove all features not requested to be extracted (added through compute_features)
stats_table = removevars(stats_table, setdiff(stats_table.Properties.VariableNames, features));

%% Display detected TFpeaks on the most recent spectrogram used for TFpeak computation
if display_peaks
    displayTFPeaks(stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, stage_times, stage_vals);
end

end


%% Helper functions
function [spect, stimes, sfreqs, dur_min, bw_min, ht_db_min] = computeSpectrogram(taper_params, time_window_params, data_time_range, Fs, dsfreqs, freq_range, verbose)
% For more information on the multitaper spectrogram parameters and implementation visit:
% https://github.com/preraulab/multitaper_toolbox

% Fixed multitaper computation parameters
nfft = 2^(nextpow2(Fs/dsfreqs)); % zero pad data to this minimum value for fft
detrend_opt = 'constant'; % do not detrend
weight = 'unity'; % each taper is weighted the same
ploton = false; % do not plot out
mts_verbose = verbose; % inherit verbose setting from computeTFPeaks()

%MTS spectral resolution
df = taper_params(1)/time_window_params(1)*2;

%Set min duration and bandwidth based on spectral parameters
dur_min = time_window_params(1)/2;
bw_min = df/2;

%Set minimal peak height based on confidence interval lower bound of MTS
chi2_df = 2 * taper_params(2);
alpha = 0.95;
ht_db_min = -pow2db(chi2_df / chi2inv(alpha/2 + 0.5, chi2_df)) * 2;

if verbose
    disp('Computing TF peak spectrogram...');
end

if exist(['multitaper_spectrogram_coder_mex.' mexext],'file')
    [spect,stimes,sfreqs] = multitaper_spectrogram_mex(data_time_range, Fs, freq_range, taper_params, time_window_params, nfft, detrend_opt, weight, ploton, mts_verbose);
else
    [spect,stimes,sfreqs] = multitaper_spectrogram(data_time_range, Fs, freq_range, taper_params, time_window_params, nfft, detrend_opt, weight, ploton, mts_verbose);
    warning(sprintf('Unable to use mex version of multitaper_spectrogram. Using compiled multitaper spectrogram function will greatly increase the speed of this computaton. \n\nFind mex code at:\n    https://github.com/preraulab/multitaper_toolbox')); %#ok<SPWRN>
end
end


function baseline = computeBaseline(spect, stimes, t_time_range, baseline_exclude, baseline_range, baseline_ptile)
% Get excluded baseline times occurring at spectrogram times
baseline_exclude_stimes = logical(interp1(t_time_range, single(baseline_exclude), stimes, 'nearest')); % no need to use ~=0 since t_time_range matches stimes

% Applying time period trimming for baseline computation
baseline_range_inds = stimes >= baseline_range(1) & stimes <= baseline_range(2);

% Find valid time points to compute baseline
valid_baseline_inds = ~baseline_exclude_stimes & baseline_range_inds;
if ~any(valid_baseline_inds)
    error('No valid baseline time bins remain after applying artifacts, stage filtering, and baseline_range.');
end

% Copy only valid columns and NaN zeros for percentile computation
spect_bl = spect(:, valid_baseline_inds);
spect_bl(spect_bl==0) = NaN;

% Compute baseline
baseline = prctile(spect_bl, baseline_ptile, 2); % 2 here indicates along second dimension
end


function spect_masked = maskSpectrogram(spect, stimes_first, stimes, regions, borders)
% Remove the offset between start times of spects from the two rounds
dt = stimes(2)-stimes(1);
indshift = round((stimes(1)-stimes_first(1)) / dt) * size(spect, 1); % assuming same sfreqs across spects

% mask all pixels outside of peak regions as zero
region_inds = cat(1, regions{:}) - indshift;
region_inds = region_inds(region_inds>=1 & region_inds<=numel(spect)); % limit to valid indices
spect_masked = zeros(size(spect));
spect_masked(region_inds) = spect(region_inds);

% mask all border pixels as zero as well
border_inds = cat(1, borders{:}) - indshift;
border_inds = border_inds(border_inds>=1 & border_inds<=numel(spect)); % limit to valid indices
spect_masked(border_inds) = 0;
end


function [downsample_spect, seg_time, merge_thresh] = getPresets(quality_setting)
% Check quality settings
switch lower(quality_setting)
    case {'stokes_2023'} %Matches Stokes et al. 2023 SLEEP paper settings exactly
        downsample_spect = [];
        seg_time = 60;
        merge_thresh = 8;
    case {'precision'} %Retaining high spectrogram precision but use smaller segments for speed
        downsample_spect = [];
        seg_time = 30;
        merge_thresh = 8;
    case {'default'} %Further speed improvement with little accuracy reduction by decimating the spectrogram
        downsample_spect = [2, 2];
        seg_time = 30;
        merge_thresh = 11;
    otherwise
        error("quality_setting must be 'stokes_2023', 'precision', or 'default'")
end
end
