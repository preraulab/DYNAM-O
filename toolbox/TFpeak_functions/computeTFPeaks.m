function [stats_table, spect, stimes, sfreqs, data_trunc, t_data_trunc, artifacts] = computeTFPeaks(varargin)
%COMPUTETFPKEAKS: Run watershed algorithm to extract time-frequency peaks
%                 from spectrogram of data
%
%   Usage:
%       [stats_table, spect, stimes, sfreqs, data_trunc, t_data_trunc, artifacts] = ...
%               computeTFPeaks(data, Fs, stage_vals, stage_times, <options>)
%
%   Inputs:
%       data (req):                [1xn] double - timeseries data to be analyzed
%       Fs (req):                  double - sampling frequency of data (Hz)
%       stage_vals (req):          [1xm] double - sleep stage values at eaach time in
%                                  stage_times. Note the staging convention: 0=unidentified, 1=N3,
%                                  2=N2, 3=N1, 4=REM, 5=WAKE
%       stage_times (req):         [1xm] double - timestamps of stage_vals
%
%   Optional inputs:
%       t_data (opt):              [1xn] double - timestamps for data. Default = (0:length(data)-1)/Fs
%       time_range (opt):          [1x2] double - section of EEG to use in analysis
%                                  (seconds). Default = [min(t_data), max(t_data)]
%       features (opt):            [1xf] char or cell array of char -
%                                  features to be extracted from each peak region. Can be any subset of
%                                  {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height', 'HeightData',
%                                   'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume'} or 'all'. Default = 'all'
%       artifacts (opt):           [nx1] logical - boolean indicating artifact time points. Default = [], run detect_artifacts()
%       artifact_filters (opt):    struct with 2 digitalFilter fields "hpFilt_high","hpFilt_broad" -
%                                  filters to be used for artifact detection. Default = []
%
%       BASELINE_OPTS STRUCTURE PARAMETERS - see baseline_opts()
%       baseline_stages (opt):     [1xp] double - stages to include in spectrogram baseline computation. Default = [1,2,3,4,5]
%       baseline_exclude (opt):    [1xn] logical - boolean indicating time points to exclude in baseline computation. Default = []
%       baseline_ptile (opt):      scalar - percentile of power spectral density at every frequency used for baseline subtraction
%                                  Default = 2
%       baseline_trim (opt):       2D array representing start and stop times for baseline trimming OR integer representing
%                                  buffer time (min) around the first and last sleep period. Default = [-inf, inf]
%
%       DETECTION_OPTS STRUCTURE PARAMETERS - see detection_opts()
%       verbose (opt):             logical - whether to print out messages when performing each computation step. Default = true
%       double_watershed (opt):    logical - whether to run two rounds of watershed to achieve better
%                                  frequency resolution in addition to good temporal resolution. Default = true
%       dsfreqs (opt):             scalar - frequency bin resolution between two consecutive frequency samples,
%                                  which is used to determine nfft in spectrogram computation. Default = 0.1
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
%
%   Outputs:
%       stats_table:  table - time, frequency, height, SOpower, and SOphase
%                     for each TFpeak
%       spect:        2D double - spectrogram of data
%       stimes:       1D double - timestamp bin center values for dimension 2 of
%                     spect
%       sfreqs:       1D double - frequency bin center values for dimension 1 of
%                     spect
%       data_trunc:   [1xn] double - timeseries data in time_range
%       t_data_trunc: [1xn] double - timestamps for data in time_range
%       artifacts:    1xT logical of times flagged as artifacts (logical OR of hf and bb artifacts)
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
% If a struct is input with settings/params, detect and reformat it to work
% with the input parser below.
struct_ind = cellfun(@isstruct,varargin); % Get index of the struct

if any(struct_ind)

    locs = find(struct_ind==1);
    if length(locs)>1
        opt_struct = cell2struct([struct2cell(varargin{locs(1)});struct2cell(varargin{locs(2)})],[fieldnames(varargin{locs(1)});fieldnames(varargin{locs(2)})]);
    else
        opt_struct = varargin{struct_ind}; % Store the struct
    end
    varargin = varargin(~struct_ind); % Remove struct from the varargin

    argcell = namedargs2cell(opt_struct); % Convert the struct to cell array
    varargin = cat(2,varargin,argcell); % Add the new cell array with the params to the end of the varargin

    % Test to make sure that none of the additional parameters are already
    % being included in the struct (if input)
    str_cell = cellstr(varargin(cellfun(@(x)(ischar(x)|isstring(x)),varargin)));
    if length(str_cell)~=length(unique(str_cell))
        error('Cannot include struct and duplicate parameters.');
    end

end

%% Parse inputs
p = inputParser;
p.KeepUnmatched=true;

addRequired(p, 'data', @(x) validateattributes(x, {'numeric'}, {'real','nonempty','row'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric'}, {'real','finite','nonempty','nonnan','positive','scalar'}));
addRequired(p, 'stage_vals', @(x) validateattributes(x, {'numeric'}, {'real','nonempty','row'}));
addRequired(p, 'stage_times', @(x) validateattributes(x, {'numeric'}, {'real','nonempty','row'}));

addOptional(p, 't_data', [], @(x) validateattributes(x,{'numeric'},{'real','finite','nonnan','2d'}));
addOptional(p, 'time_range', [], @(x) assert(isa(x, 'numeric') && (isempty(x) || length(x) == 2), 'Expected input to be an array with number of elements equal to 2.'));
addOptional(p, 'features', 'all',  @(x) validateattributes(x,{'char','cell'},{'nonempty'}));

addOptional(p, 'artifacts', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','nonnan','2d'}));
addOptional(p, 'artifact_filters', [], @(x) validateattributes(x,{'double','struct'},{'nonnan'}));

%Baseline struct parameters
baseline_options = baseline_opts(); % get the default parameters
addOptional(p, 'baseline_stages', baseline_options.baseline_stages, @(x) validateattributes(x,{'numeric'},{'real','nonempty','vector'}));
addOptional(p, 'baseline_exclude', baseline_options.baseline_exclude, @(x) validateattributes(x,{'logical'},{'real','finite','nonnan','2d'}));
addOptional(p, 'baseline_ptile', baseline_options.baseline_ptile, @(x) validateattributes(x,{'numeric'},{'real','nonempty','scalar'}));
addOptional(p, 'baseline_trim', baseline_options.baseline_trim, @(x) validateattributes(x,{'numeric'},{'real','vector','numel',2}));

%TF-peak detection struct parameters
detection_options = detection_opts(); % get the default parameters
addOptional(p, 'verbose', detection_options.verbose, @(x) validateattributes(x,{'logical'},{'nonempty','nonnan','scalar'}));
addOptional(p, 'double_watershed', detection_options.double_watershed, @(x) validateattributes(x,{'logical'},{'nonempty','nonnan','scalar'}));
addOptional(p, 'dsfreqs', detection_options.dsfreqs, @(x) validateattributes(x,{'numeric'},{'real','finite','nonempty','nonnan','scalar'}));
addOptional(p, 'mtm_taper_params', detection_options.mtm_taper_params, @(x) validateattributes(x,{'numeric'},{'real','finite','nonempty','nonnan','vector','numel',2}));
addOptional(p, 'mtm_window_length_1', detection_options.mtm_window_length_1, @(x) validateattributes(x,{'numeric'},{'real','finite','nonempty','nonnan','scalar'}));
addOptional(p, 'mtm_window_length_2', detection_options.mtm_window_length_2, @(x) validateattributes(x,{'numeric'},{'real','finite','nonempty','nonnan','scalar'}));
addOptional(p, 'mtm_window_stepsize', detection_options.mtm_window_stepsize, @(x) validateattributes(x,{'numeric'},{'real','finite','nonempty','nonnan','scalar'}));
addOptional(p, 'downsample_spect', detection_options.downsample_spect, @(x) assert(isa(x, 'numeric') && (isempty(x) || length(x) == 2), 'Expected input to be an array with number of elements equal to 2.'));
addOptional(p, 'seg_time', detection_options.seg_time, @(x) assert(isa(x, 'numeric') && (isempty(x) || isscalar(x)), 'Expected input to be a scalar.'));
addOptional(p, 'merge_thresh', detection_options.merge_thresh, @(x) assert(isa(x, 'numeric') && (isempty(x) || isscalar(x)), 'Expected input to be a scalar.'));
addOptional(p, 'quality_setting', detection_options.quality_setting, @(x) any(validatestring(x, {'stokes_2023', 'precision', 'default'})));
addOptional(p, 'max_merges', detection_options.max_merges, @(x) validateattributes(x,{'numeric'},{'real','finite','nonempty','nonnan','scalar'}));
addOptional(p, 'trim_vol', detection_options.trim_vol, @(x) validateattributes(x,{'numeric'},{'real','finite','nonempty','nonnan','scalar'}));
addOptional(p, 'dur_max', detection_options.dur_max, @(x) validateattributes(x,{'numeric'},{'real','finite','nonempty','nonnan','scalar'}));
addOptional(p, 'bw_max', detection_options.bw_max, @(x) validateattributes(x,{'numeric'},{'real','finite','nonempty','nonnan','scalar'}));
addOptional(p, 'refinement', detection_options.refinement, @(x) validateattributes(x,{'logical'},{'nonempty','nonnan','scalar'}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

if isempty(t_data) %#ok<*NODEF>
    t_data = (0:length(data)-1)/Fs;
end

%Set default time range
if isempty(time_range)
    time_range = [min(t_data), max(t_data)];
end

%Set default features
if any(strcmpi(features, 'all'))
    features = {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height',...
        'HeightData', 'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume', 'PeakStage'};
end

%Check if filters are passed in
if isempty(artifact_filters)
    artifact_filters.hpFilt_high = [];
    artifact_filters.hpFilt_broad = [];
end

% Set baseline_range based on baseline_trim input
% int
if isscalar(baseline_trim)
    buffer = baseline_trim;
    nonwake_stage_inds = ismember(stage_vals, [1,2,3,4]);
    baseline_range(1) = max([ min(stage_times(nonwake_stage_inds))-buffer*60, 0 ]); % x minutes before first non-wake stage
    baseline_range(2) = min([ max(stage_times(nonwake_stage_inds))+buffer*60, max(stage_times) ]); % x minutes after last non-wake stage
else
    if isempty(baseline_trim) % Empty array
        baseline_range = [-inf,inf];
    elseif numel(baseline_trim) ==2 % Nonempty 2D array of start, stop
        baseline_range = baseline_trim;
    else
        error('Invalid baseline range. Enter a start time or range.')
    end
end
% Set default baseline_exclude
if isempty(baseline_exclude)
    baseline_exclude = zeros(1, length(data));
end

%% Get presets if needed
if ~isempty(downsample_spect) || ~isempty(seg_time) || ~isempty(merge_thresh)
    assert(~isempty(downsample_spect) && ~isempty(seg_time) && ~isempty(merge_thresh), 'Must specify all three quality parameters together.')
    assert(isempty(quality_setting), 'Cannot specify quality parameters and quality_setting at the same time.')
else
    assert(~isempty(quality_setting), 'Must set quality_setting when not directly providing quality parameters.')
    [downsample_spect, seg_time, merge_thresh] = get_presets(quality_setting);
end

%% Truncate data to time range
time_range_inds = t_data >= time_range(1) & t_data <= time_range(2);
data_trunc = data(time_range_inds);
t_data_trunc = t_data(time_range_inds);
baseline_exclude = baseline_exclude(time_range_inds);

%% Compute spectrogram
% For more information on the multitaper spectrogram parameters and
% implementation visit: https://github.com/preraulab/multitaper
[spect, stimes, sfreqs, dur_min, bw_min, ht_db_min] = compute_spectrogram(mtm_taper_params, [mtm_window_length_1, mtm_window_stepsize], data_trunc, Fs, dsfreqs, verbose);
stimes = stimes + t_data_trunc(1); % adjust the time axis to t_data

%% Artifact Detection
if isempty(artifacts)
    if verbose
        disp('Performing artifact rejection...');
    end
    artifacts = detect_artifacts(data_trunc, Fs, 'hpFilt_high', artifact_filters.hpFilt_high, 'hpFilt_broad', artifact_filters.hpFilt_broad);
else
    artifacts = artifacts(time_range_inds); % apply time_range selection
end

%% Compute baseline spectrum used to flatten data spectrum
% Exclude artifacts, baseline_exclude, and times corresponding to stages not in baseline_stages from baseline computation
exclude_stages = single(~ismember(stage_vals,baseline_stages)); %stages to use passed in
exclude_stages_resamp = interp1(stage_times, exclude_stages, t_data_trunc, 'previous', 'extrap')==1; % ==1 instead of logical handles NaN
baseline_exclude = artifacts' | exclude_stages_resamp | baseline_exclude;
baseline_exclude_stimes = interp1(t_data_trunc, double(baseline_exclude), stimes, 'nearest', 'extrap')==1; % get excluded baseline times occurring at spectrogram times
% Applying time period trimming for baseline computation
baseline_range_inds = stimes >= baseline_range(1) & stimes <= baseline_range(2);
% Exclude segments with artifact/not in baseline include or not within baseline_range for baseline computation
spect_bl = spect;
spect_bl(spect_bl==0) = NaN; % Turn 0s to NaNs for percentile computation
% Get baseline
valid_baseline_inds = ~baseline_exclude_stimes & baseline_range_inds;
baseline = prctile(spect_bl(:, valid_baseline_inds), baseline_ptile, 2); % 2 here indicates along second dimension

%% Compute time-frequency peaks
if verbose
    disp('Extracting TF-peaks from the spectrogram...');
    tfp = tic;
end

% Augment extracted features with necessary computation features that will be removed later if extra added
compute_features = unique([features, {'Duration', 'Bandwidth', 'PeakFrequency', 'Height'}]);
if any(strcmpi(features, 'PeakStage'))
    compute_features = unique([compute_features, 'PeakTime']);
end

if double_watershed
    [stats_table, regions, borders] = runSegmentedData(spect, stimes, sfreqs, baseline, seg_time, downsample_spect, compute_features, ...
        dur_min, bw_min, merge_thresh, max_merges, trim_vol);
else
    stats_table = runSegmentedData(spect, stimes, sfreqs, baseline, seg_time, downsample_spect, compute_features, ...
        dur_min, bw_min, merge_thresh, max_merges, trim_vol);
end

if verbose
    disp(['TF-peak extraction took ' datestr(seconds(toc(tfp)),'HH:MM:SS'), newline]); %#ok<*DATST>
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
    [spect, stimes, sfreqs, ~, bw_min, ht_db_min] = compute_spectrogram(mtm_taper_params, [mtm_window_length_2, mtm_window_stepsize], data_trunc, Fs, dsfreqs, verbose);
    stimes = stimes + t_data_trunc(1); % adjust the time axis to t_data

    % Update baseline exclusion - this block is identical to the first round
    baseline_exclude_stimes = interp1(t_data_trunc, double(baseline_exclude), stimes, 'nearest', 'extrap')==1;
    % Applying time period trimming for baseline computation
    baseline_range_inds = stimes >= baseline_range(1) & stimes <= baseline_range(2);
    % Re-compute baseline spectrum
    % Exclude artifacts, baseline_exclude, and times corresponding to stages not in baseline_stages from baseline computation
    spect_bl = spect;
    spect_bl(spect_bl==0) = NaN; % Turn 0s to NaNs for percentile computation
    % Get baseline
    valid_baseline_inds = ~baseline_exclude_stimes & baseline_range_inds;
    baseline = prctile(spect_bl(:, valid_baseline_inds), baseline_ptile, 2); % 2 here indicates along second dimension

    % Mask the spectrogram using extracted TFpeaks from the first round of watershed
    % Remove the offset between start times of spects from the two rounds
    dt = stimes(2)-stimes(1);
    assert(dt == (stimes_first(2)-stimes_first(1)), 'The two rounds of watershed used different stepsizes. Cannot use linear indices.')
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

    % Compute time-frequency peaks
    if verbose
        disp('[2nd] Extracting TF-peaks from the spectrogram...');
        tfp = tic;
    end

    % Augment extracted features with necessary computation features that will be removed later if extra added
    compute_features = unique([features, {'Duration', 'Bandwidth', 'PeakFrequency', 'Height'}]);
    if any(strcmpi(features, 'PeakStage'))
        compute_features = unique([compute_features, 'PeakTime']);
    end

    stats_table = runSegmentedData(spect_masked, stimes, sfreqs, baseline, seg_time, downsample_spect, compute_features, ...
        dur_min, bw_min, merge_thresh, max_merges, trim_vol);

    if verbose
        disp(['[2nd] TF-peak extraction took ' datestr(seconds(toc(tfp)),'HH:MM:SS'), newline]);
    end

    % Filter stats_table based on {Duration, Bandwidth, PeakFrequency, and Height}
    filter_idx = filterStatsTable(stats_table, [dur_min, dur_max], [bw_min, bw_max], [-inf inf], ht_db_min, verbose);
    stats_table = stats_table(filter_idx, :);

    if isempty(stats_table)
        error('No TFpeaks found');
    end
end

%% Update feature columns of stats_table
% Get peak stages
if any(strcmpi(features, 'PeakStage'))
    stats_table.PeakStage = interp1(stage_times, single(stage_vals), stats_table.PeakTime, 'previous');
    stats_table.PeakStage(logical(interp1(t_data_trunc, double(artifacts), stats_table.PeakTime, 'nearest'))) = 6;
    stats_table.Properties.VariableDescriptions{'PeakStage'} = 'Stage: 6 = Artifact, 5 = W, 4 = R, 3 = N1, 2 = N2, 1 = N3, 0 = Unknown';
    stats_table.Properties.VariableUnits{'PeakStage'} = 'Stage #';
end

% Remove all features not requested to be extracted (added by compute_features)
stats_table = removevars(stats_table, setdiff(stats_table.Properties.VariableNames, features));

if refinement
    if verbose
        disp('Refining peaks...');
    end
    rft = tic;
    stats_table = refineTFpeaks(data_trunc, Fs, stats_table, 't', t_data_trunc);
    stats_table(isnan(stats_table.PeakFrequency),:) = [];
    if verbose
        disp(['TF-peak refinement took ' datestr(seconds(toc(rft)),'HH:MM:SS'), newline]);
    end
end

end


%% Helper functions to compute spectrogram and return various parameters
function [spect, stimes, sfreqs, dur_min, bw_min, ht_db_min] = compute_spectrogram(taper_params, time_window_params, data_trunc, Fs, dsfreqs, verbose)
% Fixed multitaper computation parameters
freq_range = [0,30]; % frequency range to compute spectrum over (Hz)
nfft = 2^(nextpow2(Fs/dsfreqs)); % zero pad data to this minimum value for fft
detrend = 'constant'; % do not detrend
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
    disp('Computing TF-peak spectrogram...');
end

if exist(['multitaper_spectrogram_coder_mex.' mexext],'file')
    [spect,stimes,sfreqs] = multitaper_spectrogram_mex(data_trunc, Fs, freq_range, taper_params, time_window_params, nfft, detrend, weight, ploton, mts_verbose);
else
    [spect,stimes,sfreqs] = multitaper_spectrogram(data_trunc, Fs, freq_range, taper_params, time_window_params, nfft, detrend, weight, ploton, mts_verbose);
    warning(sprintf('Unable to use mex version of multitaper_spectrogram. Using compiled multitaper spectrogram function will greatly increase the speed of this computaton. \n\nFind mex code at:\n    https://github.com/preraulab/multitaper_toolbox')); %#ok<SPWRN>
end
end


function [downsample_spect, seg_time, merge_thresh] = get_presets(quality_setting)
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
