function [fh] = displayTFPeaks(stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, stage_times, stage_vals)
%DISPLAYTFPEAKS  Display TF peaks detected by computeTFPeaks() on a spectrogram
%
%   Usage:
%       [] = displayTFPeaks(stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, stage_times, stage_vals, ax)
%
%   Input:
%       stats_table:        table - features of each TFpeak
%       spect:              2D double - spectrogram of data
%       stimes:             1D double - timestamp bin center values for dimension 2 of
%                           spect
%       sfreqs:             1D double - frequency bin center values for dimension 1 of
%                           spect
%       data_time_range:    [1xn] double - timeseries data in time_range
%       t_time_range:       [1xn] double - timestamps for data in time_range
%       artifacts:          1xT logical of times flagged as artifacts (logical OR of hf and bb artifacts)
%       stage_times:        [1x<number of stages>] vector - times of sleep stages in seconds
%       stage_vals:         [1x<number of stages>] - values of sleep stages
%
%   Output:
%       fh:                 figure handle
%
%    Copyright 2025 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%
%% ********************************************************************

% Create figure
fh = figure('Color',[1 1 1],'units','inches','position',[5 5 8.5 6]);
orient portrait;

%Hypnogram/spectrogram/SO-power axes
hypn_spect_ax(1) = axes('Parent',fh,'Position',[0.10 0.80 0.80 0.15]);
hypn_spect_ax(2) = axes('Parent',fh,'Position',[0.10 0.30 0.80 0.50]);
hypn_spect_ax(3) = axes('Parent',fh,'Position',[0.10 0.10 0.80 0.20]);

%% Plot hypnogram
axes(hypn_spect_ax(1));
%Adds artifacts raster below hypnogram, as computed in the time-domain,
%will not match up to the spectrogram due to windowing
hypnoplot(stage_times/3600,stage_vals,'Artifacts',artifacts','ArtifactTimes',t_time_range/3600);
th = title('EEG Spectrogram and Detected TF-peaks');
set(hypn_spect_ax(1), 'XTick', []);

%% Plot spectrogram
axes(hypn_spect_ax(2))
imagesc(stimes/3600, sfreqs, pow2db(spect));
axis xy
colormap(hypn_spect_ax(2), rainbow4);
climscale;

c = colorbar_noresize; % set colobar
c.Label.String = 'PSD (dB)'; % colobar label
c.Label.Rotation = -90; % rotate colorbar label
c.Label.VerticalAlignment = "bottom";

ylabel('Frequency (Hz)');
set(hypn_spect_ax(2), 'XtickLabel', []);

% overlay TF-peak boundaries on the spectrogram
bd = stats_table.Boundaries;
hold on;
for ii = 1:length(bd)
    plot(bd{ii}(:,1)/3600, bd{ii}(:, 2), 'w', 'LineWidth', 1)
end

%% Plot EEG trace
axes(hypn_spect_ax(3))
plot(t_time_range/3600,data_time_range,'linewidth',1)
min_trace = prctile(data_time_range, 1);
max_trace = prctile(data_time_range, 99);
ylim([min_trace-(0.1*abs(min_trace)), max_trace+(0.1*abs(max_trace))])
hypn_spect_ax(3).YTick = [round(min_trace, 2, 'significant') 0 round(max_trace, 2, 'significant')];
hypn_spect_ax(3).YTickLabel = num2str(get(hypn_spect_ax(3),'ytick')','%.1f');
ylabel('Voltage (\muV)');
xlabel('Time (hr)')

%% Additional axes adjustments
linkaxes(hypn_spect_ax, 'x');
xlim([min(t_time_range)/3600, max(t_time_range)/3600])

set(hypn_spect_ax,'fontsize',10)
set(th,'fontsize',15)
