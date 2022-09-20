function [peak_props, SOpow_mat, SOphase_mat, SOpow_bins, SOphase_bins, freq_bins, spect, stimes, sfreqs, SOpower_norm, SOpow_times, boundaries] = ...
    run_watershed_SOpowphase(varargin)
% Run watershed algorithm to extract time-frequency peaks from spectrogram
% of data, then compute Slow-Oscillation power and phase histograms
%
%   Inputs:
%       data (req):             [1xn] double - timeseries data to be analyzed
%       Fs (req):               double - sampling frequency of data (Hz)
%       stage_times (req):      [1xm] double - timestamps of stage_vals
%       stage_vals (req):       [1xm] double - sleep stage values at eaach time in
%                               stage_times. Note the staging convention: 0=unidentified, 1=N3,
%                               2=N2, 3=N1, 4=REM, 5=WAKE
%       t (opt):                [1xn] double - timestamps for data. Default = (0:length(data)-1)/Fs;
%       time_range (opt):       [1x2] double - section of EEG to use in analysis
%                               (seconds). Default = [0, max(t)]
%       artifact_filters (opt): struct with 3 digitalFilter fields "hpFilt_high","hpFilt_broad","detrend_filt" -
%                               filters to be used for artifact detection
%       stages_include (opt):   [1xp] double - which stages to include in the SOpower and
%                               SOphase analyses. Default = [1,2,3,4]
%       lightsonoff_mins (opt): double - minutes before first non-wake
%                               stage and after last non-wake stage to include in watershed
%                               baseline removal. Default = 5
%
%   Outputs:
%       peak_props:   table - time, frequency, height, SOpower, and SOphase
%                     for each TFpeak
%       SOpow_mat:    2D double - SO power histogram data
%       SOphase_mat:  2D double - SO phase histogram data
%       SOpow_bins:   1D double - SO power bin center values for dimension 1 of SOpow_mat
%       SOphase_bins: 1D double - SO phase bin center values for dimension
%                     1 of SOphase_mat
%       freq_bins:    1D double - frequency bin center values for dimension 2
%                     of SOpow_mat and SOphase_mat
%       spect:        2D double - spectrogram of data
%       stimes:       1D double - timestamp bin center values for dimension 2 of
%                     spect
%       sfreqs:       1D double - frequency bin center values for dimension 1 of
%                     spect
%       SOpower_norm: 1D double - normalized SO-power used to compute histogram
%       SOpow_times:  1D double - SO-power times
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

%% Parse Inputs
p = inputParser;

addRequired(p, 'data', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'stage_times', @(x) validateattributes(x, {'numeric', 'vector'}, {'real','nonempty'}));
addRequired(p, 'stage_vals', @(x) validateattributes(x, {'numeric', 'vector'}, {'real','nonempty'}));
addOptional(p, 't', [], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'time_range', [], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'downsample_spect', [],  @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'artifact_filters', [], @(x) validateattributes(x,{'isstruct'},{}));
addOptional(p, 'stages_include', [1,2,3,4], @(x) validateattributes(x,{'numeric', 'vector'}, {'real', 'nonempty'}))
addOptional(p, 'lightsonoff_mins', 5, @(x) validateattributes(x,{'numeric'},{'real','nonempty', 'nonnan'}));
addOptional(p, 'verbose', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
addOptional(p, 'spect_settings', 'fast', @(x) validateattributes(x,{'char','numeric'},{}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results);
field_names = fieldnames(p.Results);

eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);


if isempty(t)
    t = (0:length(data)-1)/Fs;
end

if isempty(time_range)
    time_range = [0, max(t)];
end

if isempty(artifact_filters)
    artifact_filters.hpFilt_high = [];
    artifact_filters.hpFilt_broad = [];
    artifact_filters.detrend_filt = [];
end


ttotal = tic;

%% Compute spectrogram
% For more information on the multitaper spectrogram parameters and
% implementation visit: https://github.com/preraulab/multitaper

time_window_params = [1,0.05]; % [time window, time step] in seconds
dsfreqs = 0.1; % For consistency with our results we expect a df of 0.1 Hz or less



if isnumeric(spect_settings)
    time_window_params = spect_settings(1:2);
    dsfreqs = spect_settings(3);
else
    switch lower(spect_settings)
        case {'paper'} %Matches SLEEP paper settings exactly
               downsample_spect = [];
                seg_time = 60;
        case {'precision'} %Matches SLEEP paper settings but smaller segments for speed
               downsample_spect = [];
                seg_time = 30;
        case 'fast' %~3x speed improvement with little accuracy reduction
              downsample_spect = [2 2];
              seg_time = 30;
        case 'draft' %10x speed improvement with but phase shift
            downsample_spect = [5 1];
            seg_time = 30;
        otherwise
            error('spect_settings must be ''precision'', ''fast'', ''draft'', or ''paper''')
    end
end

freq_range = [0,30]; % frequency range to compute spectrum over (Hz)
taper_params = [2,3]; % [time halfbandwidth product, number of tapers]
nfft = 2^(nextpow2(Fs/dsfreqs)); % zero pad data to this minimum value for fft
detrend = 'off'; % do not detrend
weight = 'unity'; % each taper is weighted the same
ploton = false; % do not plot out
mts_verbose = false;

%MST frequency resolution
df = taper_params(1)/time_window_params(1)*2;

%Set min bandwidth and duration based on spectral parameters
bw_min = df/2;
dur_min = time_window_params(1)/2;

if verbose
    disp('Computing TF-peak spectrogram...')

    if exist(['multitaper_spectrogram_coder_mex.' mexext],'file')
        [spect,stimes,sfreqs] = multitaper_spectrogram_mex(data, Fs, freq_range, taper_params, time_window_params, nfft, detrend, weight, ploton, mts_verbose);
    else
        [spect,stimes,sfreqs] = multitaper_spectrogram(data, Fs, freq_range, taper_params, time_window_params, NFFT, detrend, weight, ploton, mts_verbose);
        warning(sprintf('Unable to use mex version of multitaper_spectrogram. Using compiled multitaper spectrogram function will greatly increase the speed of this computaton. \n\nFind mex code at:\n    https://github.com/preraulab/multitaper_toolbox'));
    end
end

%% Compute baseline spectrum used to flatten data spectrum
if verbose
    disp('Performing artifact rejection...')
end

artifacts = detect_artifacts(data, Fs, [],[],[],[],[],[],[],[],[], ... % detect artifacts in EEG
    artifact_filters.hpFilt_high, artifact_filters.hpFilt_broad, artifact_filters.detrend_filt);
artifacts_stimes = logical(interp1(t, double(artifacts), stimes, 'nearest')); % get artifacts occuring at spectrogram times

% Get lights off and lights on times
lightsoff_time = max( min(t(~ismember(stage_vals,[5,0])))-lightsonoff_mins*60, 0); % 5 min before first non-wake stage
lightson_time = min( max(t(~ismember(stage_vals,[5,0])))+lightsonoff_mins*60, max(stage_times)); % 5 min after last non-wake stage

% Get invalid times for baseline computation
invalid_times = (stimes > lightson_time & stimes < lightsoff_time) & artifacts_stimes;

spect_bl = spect;
spect_bl(:,invalid_times) = NaN; % turn artifact times into NaNs for percentile computation
spect_bl(spect_bl==0) = NaN; % Turn 0s to NaNs for percentile computation

baseline_ptile = 2; % using 2nd percentile of spectrogram as baseline
baseline = prctile(spect_bl, baseline_ptile, 2);  % Get baseline

%% Pick a segment of the spectrogram to extract peaks from
% Use only a the specified segment of the spectrogram
[~,start] = min(abs(time_range(1) - stimes));
[~,last] = min(abs(time_range(2) - stimes));
spect_in = spect(:, start:last);
stimes_in = stimes(start:last);

%% Compute time-frequency peaks
if verbose
    disp('Extracting TF-peaks from the spectrogram...')
    tfp = tic;
end

[matr_names, matr_fields, peaks_matr,~,~, pixel_values,~,boundaries] = extract_TFpeaks(spect_in, stimes_in, sfreqs, baseline, seg_time, downsample_spect, dur_min, bw_min);

if verbose
    disp(['TF-peak extraction took ' datestr(seconds(toc(tfp)),'HH:MM:SS')]);
    disp(' ');
end


%% Filter out noise peaks
if verbose
    disp('Removing noise peaks...')
end

[feature_matrix, feature_names, xywcntrd, peak_mask] = filterpeaks_watershed(peaks_matr, matr_fields, matr_names, pixel_values);

boundaries = boundaries(peak_mask,:);

%% Compute SO power and SO phase
% Exclude WAKE stages from analyses
if length(stage_times) ~= length(t)
    stages_t = interp1(stage_times, single(stage_vals), t, 'previous');
elseif all(stage_times ~= t)
    stages_t = interp1(stage_times, single(stage_vals), t, 'previous');
else
    stages_t = stage_vals;
end

stage_exclude = ~ismember(stages_t, stages_include);

%% Extract time-frequency peak times, frequencies, and heights
peak_times = xywcntrd(:,1);
peak_freqs = xywcntrd(:,2);
peak_height = feature_matrix(:,strcmp(feature_names, 'Height'));
peak_bw = feature_matrix(:,strcmp(feature_names, 'Bandwidth'));
peak_dur = feature_matrix(:,strcmp(feature_names, 'Duration'));


%% Compute SO power
if verbose
    disp('Computing SO-power histogram...')
end

% use ('plot_flag', true) to plot directly from this function call
[SOpow_mat, freq_bins, SOpow_bins, ~, ~, peak_SOpow, peak_inds, SOpower_norm, ~, SOpow_times] = SOpower_histogram(data, Fs, peak_freqs, peak_times, 'stage_exclude', stage_exclude, 'artifacts', artifacts);

%% Compute SO phase
if verbose
    disp('Computing SO-phase histogram...')
end

% use ('plot_flag', true) to plot directly from this function call
[SOphase_mat, ~, SOphase_bins, ~, ~, peak_SOphase, ~] = SOphase_histogram(data, Fs, peak_freqs, peak_times, 'stage_exclude', stage_exclude, 'artifacts', artifacts);

% To use a custom precomputed SO phase filter, use the SOphase_filter argument
% custom_SOphase_filter = designfilt('bandpassfir', 'StopbandFrequency1', 0.1, 'PassbandFrequency1', 0.4, ...
%                        'PassbandFrequency2', 1.75, 'StopbandFrequency2', 2.05, 'StopbandAttenuation1', 60, ...
%                        'PassbandRipple', 1, 'StopbandAttenuation2', 60, 'SampleRate', 256);
% [SOphase_mat, ~, SOphase_cbins, TIB_phase, PIB_phase] = SOphase_histogram(data, Fs, peak_freqs, peak_times, 'stage_exclude', stage_exclude, 'artifacts', artifacts, ...
%                                                                           'SOphase_flter', custom_SOphase_filter);

%% Make output peak properties table
if verbose
    disp('Creating output tables...')
end

peak_props = table(peak_times(peak_inds), peak_freqs(peak_inds), peak_height(peak_inds), ...
    peak_SOpow(peak_inds), peak_SOphase(peak_inds), peak_bw(peak_inds), peak_dur(peak_inds), 'VariableNames', {'peak_times', 'peak_freqs', 'peak_height', ...
    'peak_SOpow', 'peak_SOphase', 'peak_bw', 'peak_dur'});

boundaries = boundaries(peak_inds,:);


if verbose
    disp(' ');
    disp(['Total time: ' datestr(seconds(toc(ttotal)),'HH:MM:SS')]);
end
end

