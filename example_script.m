%%% Example script showing how to compute time-frequency peaks and slow oscillation power and phase 

%% Clear workspace and close plots
clear; close all;

%% Load example EEG data
load('example_data/example_data.mat', 'EEG', 'stages', 'Fs', 't');


%% Compute spectrogram 
% For more information on the multitaper spectrogram parameters and
% implementation visit: https://github.com/preraulab/multitaper

freq_range = [4,35]; % frequency range to compute spectrum over (Hz)
taper_params = [2,3]; % [time halfbandwidth product, number of tapers]
time_window_params = [1,0.05]; % [time window, time step] in seconds
nfft = 2^10; % zero pad data to this minimum value for fft
detrend = 'off'; % do not detrend 
weight = 'unity'; % each taper is weighted the same
ploton = false; % do not plot out

[spect,stimes,sfreqs] = multitaper_spectrogram_mex(EEG, Fs, freq_range, taper_params, time_window_params, nfft, detrend, weight, ploton);

%% Compute baseline spectrum used to flatten EEG data spectrum
artifacts = detect_artifacts(EEG, Fs); % detect artifacts in EEG
artifacts_stimes = logical(interp1(t, double(artifacts), stimes, 'nearest')); % get artifacts occuring during stimes

spect_bl = spect; % copy spectogram
spect_bl(:,artifacts_stimes) = NaN; % turn artifact times into NaNs for percentile computation
spect_bl(spect_bl==0) = NaN; % Turn 0s to NaNs for percentile computation

baseline_ptile = 2; % using 2nd percentile of spectrogram as baseline
baseline = prctile(spect_bl, baseline_ptile, 2); % Get baseline

%% Pick a segment of the spectrogram to extract peaks from 
% Use only a segment of the spectrogram (4000-12000 seconds) for example to save computing time
[~,start] = min(abs(4000 - stimes)); 
[~,last] = min(abs(12000 - stimes)); 
spect_in = spect(:, start:last);
stimes_in = stimes(start:last);

%% Compute time-frequency peaks
%%% TODO - make input parser for extract_TFpeaks
[matr_names, matr_fields, peaks_matr,~,~, pixel_values] = extract_TFpeaks(spect_in, stimes_in, sfreqs, baseline);

%% Filter out noise peaks
[feature_matrix, feature_names, xywcntrd, combined_mask] = filterpeaks_watershed(peaks_matr, matr_fields, matr_names, pixel_values);

%% Extract time-frequency peak times and frequencies
peak_times = xywcntrd(:,1);
peak_freqs = xywcntrd(:,2);

%% Compute SO power and SO phase
% Exclude WAKE stages from analyses
stage_exclude = ismember(stages, 5);

% Compute SO power
% use ('plot_flag', true) to plot directly from this function call
[SOpow_mat, freq_cbins, SOpow_cbins, ~, ~, peak_SOpow, peak_inds] = SOpower_histogram(EEG, Fs, peak_freqs, peak_times, 'stage_exclude', stage_exclude, 'artifacts', artifacts); 

% Compute SO phase
% use ('plot_flag', true) to plot directly from this function call
[SOphase_mat, ~, SOphase_cbins, ~, ~, peak_SOphase, ~] = SOphase_histogram(EEG, Fs, peak_freqs, peak_times, 'stage_exclude', stage_exclude, 'artifacts', artifacts);

% To use a custom precomputed SO phase filter, use the SOphase_filter argument
% custom_SOphase_filter = designfilt('bandpassfir', 'StopbandFrequency1', 0.1, 'PassbandFrequency1', 0.4, ...
%                        'PassbandFrequency2', 1.75, 'StopbandFrequency2', 2.05, 'StopbandAttenuation1', 60, ...
%                        'PassbandRipple', 1, 'StopbandAttenuation2', 60, 'SampleRate', Fs);
% [SOphase_mat, ~, SOphase_cbins, TIB_phase, PIB_phase] = SOphase_histogram(EEG, Fs, peak_freqs, peak_times, 'stage_exclude', stage_exclude, 'artifacts', artifacts, ...
%                                                                           'SOphase_flter', custom_SOphase_filter);

                                                                      
%% Plot
% Create empty figure 
figure; 
ax = figdesign(11,2,'type','usletter','orient','portrait','merge',{[1:4], [5:10], [11:16], [17,19,21], [18,20,22]}, 'margins',[.1 .05 .08 .11 .12, 0.06]);

% Link axes of appropriate plots 
linkaxes([ax(1), ax(2), ax(3)], 'x');
linkaxes([ax(4), ax(5)], 'y');

% Plot hypnogram
axes(ax(1))
hypnoplot(stimes, interp1(t,stages,stimes,'nearest'));

% Plot spectrogram
axes(ax(2))
imagesc(stimes, sfreqs, nanpow2db(spect));
axis xy; % flip axes
colormap(ax(2), 'jet'); 
spect_clims = climscale; % change color scale for better visualization
c = colorbar_noresize;
ylabel(c, 'Power (dB)');
ylabel('Frequency (Hz)');
xlabel('')

% Plot time-frequency peak scatterplot
axes(ax(3))
peak_volumes = feature_matrix(:,strcmp(feature_names, 'Volume')); % get volume of each peak
scatter(peak_times(peak_inds), peak_freqs(peak_inds), peak_volumes(peak_inds)/50, peak_SOphase(peak_inds), 'filled'); % scatter plot all peaks 
c = colorbar_noresize;
ylabel(c,'Phase (radians)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% Plot SO power histogram
axes(ax(4))
imagesc(SOpow_cbins, freq_cbins, SOpow_mat');
axis xy;
colormap(ax(4), 'parula');
pow_clims = climscale([],[],false);
c = colorbar_noresize;
ylabel(c,'Rate (peaks/min)');
xlabel('SO Power (Normalized)');
ylabel('Frequency (Hz)');

% Plot SO phase histogram
axes(ax(5))
imagesc(SOphase_cbins, freq_cbins, SOphase_mat');
axis xy;
colormap(ax(5), 'plasma');
climscale;
c = colorbar_noresize;
ylabel(c,'Normalized Rate');
xlabel('SO Phase (radians)');
yticklabels('');




