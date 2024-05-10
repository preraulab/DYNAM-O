function [stats_table, spect, stimes, sfreqs, data_trunc, t_data_trunc, artifacts] = computeTFPeaks(varargin)
% COMPUTETFPKEAKS: Run watershed algorithm to extract time-frequency peaks
%                  from spectrogram of data
%
%   Usage:
%       [stats_table, spect, stimes, sfreqs, data, t_data, artifacts] = ...
%               computeTFPeaks(data, Fs, stage_times, stage_vals, <options>)
%
%   Inputs:
%       data (req):                [1xn] double - timeseries data to be analyzed
%       Fs (req):                  double - sampling frequency of data (Hz)
%       stage_vals (req):          [1xm] double - sleep stage values at eaach time in
%                                  stage_times. Note the staging convention: 0=unidentified, 1=N3,
%                                  2=N2, 3=N1, 4=REM, 5=WAKE
%       stage_times (req):         [1xm] double - timestamps of stage_vals
%       t_data (opt):              [1xn] double - timestamps for data. Default = (0:length(data)-1)/Fs;
%       time_range (opt):          [1x2] double - section of EEG to use in analysis
%                                  (seconds). Default = [min(t_data), max(t_data)]
%       features (opt):            [1xf] char or cell array of char -
%                                  features to be extracted from each peak region. Can be any subset of
%                                  {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height', 'HeightData',
%                                   'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume'} or 'all'. Default = 'all'
%       artifacts (opt):           [nx1] logical - boolean indicating artifact time points. Default = [], run detect_artifacts()
%       baseline_exclude (opt):    [1xn] logical - boolean indicating time points to exclude in baseline computation 
%       baseline_stages (opt):     [1xp] double - stages to include in spectrogram baseline computation
%       baseline_trim (opt):       2D array representing start and stop
%                                  times for baseline trimming OR integer representing buffer time (min)
%                                  around the first and last sleep period.
%                                  Default = [-inf,inf]
%       artifact_filters (opt):    struct with 2 digitalFilter fields "hpFilt_high","hpFilt_broad" -
%                                  filters to be used for artifact detection
%       stages_include (not used): [1xp] double - which stages to include in the SO-power and
%                                  SO-phase histograms. Default = [1,2,3,4]
%                                  W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
%       double_watershed (opt):    logical - whether to run two rounds of watershed to achieve better
%                                       frequency resolution in addition to good temporal resolution. Default = true
%       verbose (opt):             logical - display extra info. Default = true
%       quality_setting (opt):     charcater - Quality settings for the algorithm:
%                                       'precision': high res settings
%                                       'fast' (default): speed-up with minimal impact on results *suggested*
%                                       'draft': faster speed-up with increased high frequency TF-peaks, *not recommended for analyzing SOphase*
%       refinement (opt):          logical - perform 1Hz refinement on the spindle table from double watershed. Default = true
%
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
% If a struct is input with the SOPH settings/params, detect and
% reformat it to work with the input parser below.
struct_ind = cellfun(@isstruct,varargin); % Get index of the struct

if any(struct_ind)

    locs = find(struct_ind==1);
    if length(locs)>1
        opt_struct = cell2struct([struct2cell(varargin{locs(1)});struct2cell(varargin{locs(2)})],[fieldnames(varargin{locs(1)});fieldnames(varargin{locs(2)})]);
    else
        opt_struct = varargin{struct_ind}; % Store the struct
    end
    varargin = varargin(~struct_ind); % Remove struct from the varargins

    argcell = namedargs2cell(opt_struct); % Convert the struct to cell array
    varargin = cat(2,varargin,argcell); % Add the new cell array with the params to the end of the varargins

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

addRequired(p, 'data', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'stage_vals', @(x) validateattributes(x, {'numeric', 'vector'}, {'real','nonempty'}));
addRequired(p, 'stage_times', @(x) validateattributes(x, {'numeric', 'vector'}, {'real','nonempty'}));

addOptional(p, 't_data', [], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'time_range', [], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'features', 'all',  @(x) validateattributes(x,{'char', 'cell'},{}));

addOptional(p, 'artifacts', [], @(x) validateattributes(x,{'logical'},{'real','finite','nonnan'}));
addOptional(p, 'artifact_filters', [], @(x) validateattributes(x,{'struct'},{}));

%Baseline struct
addOptional(p, 'baseline_stages',[1,2,3,4,5],@(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addOptional(p, 'baseline_exclude',[], @(x) validateattributes(x,{'logical'},{'real','finite','nonnan'}));
addOptional(p, 'baseline_ptile',2,@(x) validateattributes(x, {'numeric', 'scalar'}, {'real', 'nonempty'}));
addOptional(p, 'baseline_trim',[],@(x) validateattributes(x, {'numeric', 'vector'}, {'real'}));

%TF-peak struct
addOptional(p, 'double_watershed', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
addOptional(p, 'dsfreqs', 0.1, @(x) validateattributes(x,{'scalar','numeric'},{'real','nonempty', 'nonnan'}));
addOptional(p, 'downsample_spect', [2 2], @(x) validateattributes(x,{'vector','numeric'},{}));
addOptional(p, 'seg_time', 3, @(x) validateattributes(x,{'scalar','numeric'},{}));
addOptional(p, 'merge_thresh', 11, @(x) validateattributes(x,{'scalar','numeric'},{}));
addOptional(p, 'max_merges', inf, @(x) validateattributes(x,{'scalar','numeric'},{}));
addOptional(p, 'quality_setting', '', @(x) validateattributes(x,{'char','numeric'},{}));
addOptional(p, 'refinement', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
addOptional(p, 'verbose', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
addOptional(p, 'trim_vol', 0.8, @(x) validateattributes(x,{'scalar','numeric'},{}));
addOptional(p, 'dur_max', 5, @(x) validateattributes(x,{'scalar','numeric'},{}));
addOptional(p, 'bw_max', 15, @(x) validateattributes(x,{'scalar','numeric'},{}));

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
    % Empty array
    if isempty(baseline_trim)
        baseline_range = [-inf,inf];
        % % Nonempty 2D array of start, stop
    elseif numel(baseline_trim) ==2
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
if ~isempty(quality_setting)
    [seg_time, merge_thresh, downsample_spect] = get_presets(quality_setting);
end

%% Truncate data to time range
time_range_inds = t_data >= time_range(1) & t_data <= time_range(2);
data_trunc = data(time_range_inds);
t_data_trunc = t_data(time_range_inds);
baseline_exclude = baseline_exclude(time_range_inds);

%% Compute spectrogram
% For more information on the multitaper spectrogram parameters and
% implementation visit: https://github.com/preraulab/multitaper

[spect, stimes, sfreqs, dur_min, bw_min, ht_db_min] = compute_spectrogram([2,3], [1,0.05], data_trunc, Fs, dsfreqs, verbose);
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
% Exclude artifacts, baseline_exclude and times corresponding to stages not in baseline_stages from baseline
% computation

exclude_stages = single(~ismember(stage_vals,baseline_stages)); %stages to use passed in
exclude_stages_resamp = logical(interp1(stage_times, exclude_stages, t_data_trunc, 'previous'));
baseline_exclude = artifacts'|exclude_stages_resamp|baseline_exclude;
baseline_exclude_stimes = logical(interp1(t_data_trunc, double(baseline_exclude), stimes, 'nearest')); % get excluded baseline times occurring at spectrogram times
% Applying time period trimming for baseline computation
baseline_range_inds = stimes >= baseline_range(1) & stimes <= baseline_range(2);
% Exclude segments with artifact/not in baseline include or withing baseline range for baseline computation
spect_bl = spect;
spect_bl(spect_bl==0) = NaN; % Turn 0s to NaNs for percentile computation
%spect_bl(:,baseline_exclude_stimes|~baseline_range_inds) = NaN;
% Get baseline
valid_baseline_inds = ~baseline_exclude_stimes&baseline_range_inds;
baseline = prctile(spect_bl(:,valid_baseline_inds), baseline_ptile, 2);

%% Compute time-frequency peaks
if verbose
    disp('Extracting TF-peaks from the spectrogram...');
    tfp = tic;
end

% Augment extracted features with necessary computation features that will be removed later
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
    disp(['TF-peak extraction took ' datestr(seconds(toc(tfp)),'HH:MM:SS'), newline]);
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
    [spect, stimes, sfreqs, ~, bw_min, ht_db_min] = compute_spectrogram([2,3], [2,0.05], data_trunc, Fs, dsfreqs, verbose);
    stimes = stimes + t_data_trunc(1); % adjust the time axis to t_data

    % Update baseline exclusion
    baseline_exclude_stimes = logical(interp1(t_data_trunc, double(baseline_exclude), stimes, 'nearest')); 
    % Applying time period trimming for baseline computation
    baseline_range_inds = stimes >= baseline_range(1) & stimes <= baseline_range(2);
    % Re-compute baseline spectrum
    % Exclude segments with artifact/not in baseline include or withing baseline range for baseline computation
    spect_bl = spect;
    spect_bl(spect_bl==0) = NaN; % Turn 0s to NaNs for percentile computation
    % Get baseline
    valid_baseline_inds = ~baseline_exclude_stimes&baseline_range_inds;
    baseline = prctile(spect_bl(:,valid_baseline_inds), baseline_ptile, 2);

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

    % Augment extracted features with necessary computation features that will be removed later
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
    stats_table = refineTFpeaks(data_trunc,Fs,stats_table,'t',t_data_trunc,'baseline_opt',false,'refine_method','spline_interp', ...
        'remove_edge_peaks',true);
    stats_table(isnan(stats_table.PeakFrequency),:) = [];
    if verbose
        disp(['TF-peak refinement took ' datestr(seconds(toc(rft)),'HH:MM:SS'), newline]);
    end
end

end

% Helper function to compute spectrogram and return various parameters
function [spect, stimes, sfreqs, dur_min, bw_min, ht_db_min] = compute_spectrogram(taper_params, time_window_params, data_trunc, Fs, dsfreqs, verbose)

if isempty(taper_params)
    taper_params = [2,3]; % [time halfbandwidth product, number of tapers]
end
if isempty(time_window_params)
    time_window_params = [1,0.05]; % [time window, time step] in seconds
end

freq_range = [0,30]; % frequency range to compute spectrum over (Hz)
nfft = 2^(nextpow2(Fs/dsfreqs)); % zero pad data to this minimum value for fft
detrend = 'constant'; % do not detrend
weight = 'unity'; % each taper is weighted the same
ploton = false; % do not plot out
mts_verbose = verbose; % suppress verbose messages

%MTS frequency resolution
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

function [seg_time, merge_thresh, downsample_spect] = get_presets(quality_setting)
% Check quality settings
if ~isempty(quality_setting)
    if iscell(quality_setting) % If quality_setting is a cell, define it this way
        downsample_spect = quality_setting{1};
        seg_time = quality_setting{2};
        merge_thresh = quality_setting{3};
    else
        switch lower(quality_setting)
            case {'paper'} %Matches SLEEP paper settings exactly
                downsample_spect = [];
                seg_time = 60;
                merge_thresh = 8;
            case {'precision'} %Matches SLEEP paper settings but smaller segments for speed
                downsample_spect = [];
                seg_time = 30;
                merge_thresh = 8;
            case {'fast'} %~speed improvement with little accuracy reduction
                downsample_spect = [2 2];
                seg_time = 30;
                merge_thresh = 11;
            case {'draft'} %greater speed improvement but increased high frequency peaks
                downsample_spect = [5 1];
                seg_time = 30;
                merge_thresh = 13;
                warning('The "draft" setting is not suitable for analyzing SO-phase, use "precision" or "fast" instead.')
            otherwise
                error('quality_setting must be ''precision'', ''fast'', ''draft'', or ''paper''')
        end
    end
end
end