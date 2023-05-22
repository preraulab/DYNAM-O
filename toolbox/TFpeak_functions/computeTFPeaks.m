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
%       downsample_spect(opt):     2x1 double indicating number of rows and columns to downsize spect to
%       features (opt):            [1xf] char or cell array of char -
%                                  features to be extracted from each peak region. Can be any subset of
%                                  {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height', 'HeightData', 
%                                   'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume'} or 'all'. Default = 'all'
%       artifacts (opt):           [1xn] logical - boolean indicating artifact time points. Default = [], run detect_artifacts()
%       artifact_filters (opt):    struct with 2 digitalFilter fields "hpFilt_high","hpFilt_broad" -
%                                  filters to be used for artifact detection
%       stages_include (opt):      [1xp] double - which stages to include in the SO-power and
%                                  SO-phase histograms. Default = [1,2,3,4]
%                                  W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
%       verbose (opt):             logical - display extra info. Default = true
%       quality_setting (opt):     charcater - Quality settings for the algorithm:
%                                       'precision': high res settings
%                                       'fast' (default): speed-up with minimal impact on results *suggested*
%                                       'draft': faster speed-up with increased high frequency TF-peaks, *not recommended for analyzing SOphase*
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

%% Parse inputs
p = inputParser;

addRequired(p, 'data', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'stage_vals', @(x) validateattributes(x, {'numeric', 'vector'}, {'real','nonempty'}));
addRequired(p, 'stage_times', @(x) validateattributes(x, {'numeric', 'vector'}, {'real','nonempty'}));
addOptional(p, 't_data', [], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'time_range', [], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'downsample_spect', [],  @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'features', 'all',  @(x) validateattributes(x,{'char', 'cell'},{}));
addOptional(p, 'artifacts', [], @(x) validateattributes(x,{'logical'},{'real','finite','nonnan'}));
addOptional(p, 'artifact_filters', [], @(x) validateattributes(x,{'struct'},{}));
addOptional(p, 'stages_include', [1,2,3,4], @(x) validateattributes(x,{'numeric', 'vector'}, {'real', 'nonempty'}))
addOptional(p, 'verbose', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
addOptional(p, 'quality_setting', 'fast', @(x) validateattributes(x,{'char','numeric'},{}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

if isempty(t_data) %#ok<*NODEF>
    t_data = (0:length(data)-1)/Fs;
end

if isempty(time_range)
    time_range = [min(t_data), max(t_data)];
end

if isempty(artifact_filters)
    artifact_filters.hpFilt_high = [];
    artifact_filters.hpFilt_broad = [];
end

%% Truncate data to time range
time_range_inds = t_data >= time_range(1) & t_data <= time_range(2);
data_trunc = data(time_range_inds);
t_data_trunc = t_data(time_range_inds);

%% Compute spectrogram
% For more information on the multitaper spectrogram parameters and
% implementation visit: https://github.com/preraulab/multitaper

time_window_params = [1,0.05]; % [time window, time step] in seconds
dsfreqs = 0.1; % For consistency with our results we expect a df of 0.1 Hz or less

if isnumeric(quality_setting) % If spect_settings is numeric use it, and don't downsample
    time_window_params = spect_settings(1:2);
    dsfreqs = spect_settings(3);
    downsample_spect = [];
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
            error('spect_settings must be ''precision'', ''fast'', ''draft'', or ''paper''')
    end
end

freq_range = [0,30]; % frequency range to compute spectrum over (Hz)
taper_params = [2,3]; % [time halfbandwidth product, number of tapers]
nfft = 2^(nextpow2(Fs/dsfreqs)); % zero pad data to this minimum value for fft
detrend = 'constant'; % do not detrend
weight = 'unity'; % each taper is weighted the same
ploton = false; % do not plot out
mts_verbose = false; % suppress verbose messages

%MTS frequency resolution
df = taper_params(1)/time_window_params(1)*2;

%Set min duration and bandwidth based on spectral parameters
dur_min = time_window_params(1)/2;
bw_min = df/2;

%Max duration and bandwidth are set to be large values
dur_max = 5; % second
bw_max = 15; % Hz

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
stimes = stimes + t_data_trunc(1); % adjust the time axis to t_data

%% Artifcact Detection
if isempty(artifacts)
    if verbose
        disp('Performing artifact rejection...');
    end
    artifacts = detect_artifacts(data_trunc, Fs, 'hpFilt_high', artifact_filters.hpFilt_high, 'hpFilt_broad', artifact_filters.hpFilt_broad);
else
    artifacts = artifacts(time_range_inds); % apply time_range selection
end
artifacts_stimes = logical(interp1(t_data_trunc, double(artifacts), stimes, 'nearest')); % get artifacts occurring at spectrogram times

%% Compute baseline spectrum used to flatten data spectrum
% Exclude segments with artifacts during baseline computation
spect_bl = spect;
spect_bl(:,artifacts_stimes) = NaN; % turn artifact times into NaNs for percentile computation
spect_bl(spect_bl==0) = NaN; % Turn 0s to NaNs for percentile computation

baseline_ptile = 2; % using 2nd percentile of spectrogram as baseline
baseline = prctile(spect_bl, baseline_ptile, 2); % get baseline

%% Compute time-frequency peaks
if verbose
    disp('Extracting TF-peaks from the spectrogram...');
    tfp = tic;
end

stats_table = runSegmentedData(spect, stimes, sfreqs, baseline, seg_time, downsample_spect, features, dur_min, bw_min, [], merge_thresh);

if verbose
    disp(['TF-peak extraction took ' datestr(seconds(toc(tfp)),'HH:MM:SS'), newline]);
end

%% Filter stats_table based on duration, bandwidth, frequency, and height
filter_idx = filterStatsTable(stats_table, [dur_min, dur_max], [bw_min, bw_max], [-inf inf], ht_db_min, verbose);
stats_table = stats_table(filter_idx, :);

if isempty(stats_table)
    error('No TFpeaks found');
end

%% Get peak stages
stats_table.PeakStage = interp1(stage_times, single(stage_vals), stats_table.PeakTime, 'previous');
stats_table.PeakStage(logical(interp1(t_data_trunc, double(artifacts), stats_table.PeakTime, 'nearest'))) = 6;
stats_table.Properties.VariableDescriptions{'PeakStage'} = 'Stage: 6 = Artifact, 5 = W, 4 = R, 3 = N1, 2 = N2, 1 = N3, 0 = Unknown';
stats_table.Properties.VariableUnits{'PeakStage'} = 'Stage #';

end