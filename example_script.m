%%%% Example script showing how to compute time-frequency peaks and slow oscillation power and phase %%%%

%% Clear workspace and close plots
clear; close all;

%% Load example EEG data
load('example_data/example_data.mat', 'EEG', 'stages', 'Fs', 't');

%% Add necessary functions to path
addpath(genpath('./toolbox'))

%% Pick a segment of the spectrogram to extract peaks from 
% Use only a segment of the spectrogram (13000-21000 seconds) for example to save computing time
time_range = [13000, 21000];

%% Run watershed and SO power/phase analyses
[peak_props, SOpow_mat, SOphase_mat, SOpow_bins, SOphase_bins, freq_bins, ...
    spect, stimes, sfreqs] = run_watershed_SOpowphase(EEG, Fs, t, stages, 'time_range', time_range);

                                                                      
%% Plot

% Create figure
fh = figure('Color',[1 1 1]);

% Create axes
ax(4) = axes('Parent',fh,'Position',[0.555 0.0700000000000001 0.335 0.2]);
ax(3) = axes('Parent',fh,'Position',[0.06 0.0700000000000001 0.335 0.2]);
ax(2) = axes('Parent',fh,'Position',[0.06 0.35 0.83 0.2]);
hypn_spect_ax(1) = axes('Parent',fh,'Position',[0.06 0.63 0.83 0.2278]);
hypn_spect_ax(2) = axes('Parent',fh,'Position',[0.06 0.8578 0.83 0.1122]);

% Link axes of appropriate plots
linkaxes([hypn_spect_ax(1), hypn_spect_ax(2), ax(2)], 'x');

% Set yaxis limits
ylimits = [4,25];

% Plot hypnogram
axes(hypn_spect_ax(2));
hypnoplot(stimes, interp1(t,stages,stimes,'nearest'));
title('Hypnogram and Spectrogram')

% Plot spectrogram
axes(hypn_spect_ax(1))
[spect_disp, stimes_disp, sfreqs_disp] = multitaper_spectrogram(EEG, Fs, [4,25]);
colormap(hypn_spect_ax(1), 'jet');
c = colorbar_noresize; % set colobar
c.Label.String = 'Power (dB)'; % colobar label
c.Label.Rotation = -90; % rotate colorbar label
c.Label.VerticalAlignment = "bottom";
ylabel('Frequency (Hz)');
xlabel('')
ylim(ylimits);
xlim(time_range)
xticklabels({});
[~, sh] = scaleline(hypn_spect_ax(1), 3600,'1 Hour' );
sh.FontSize = 10;


% Plot time-frequency peak scatterplot
axes(ax(2))
pmax = prctile(peak_props.peak_height, 95); % get 95th ptile of heights
peak_props.peak_height(peak_props.peak_height>pmax) = pmax; % don't plot larger than 95th ptile or else dots could obscure other things on the plot
scatter(peak_props.peak_times, peak_props.peak_freqs, peak_props.peak_height./12, peak_props.peak_SOphase, 'filled'); % scatter plot all peaks
colormap(ax(2),circshift(hsv(2^12),-400))
c = colorbar_noresize;
c.Label.String = 'Phase (radians)';
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";
set(c,'xtick',([-pi -pi/2 0 pi/2 pi]),'xticklabel',({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'}));    
ylabel('Frequency (Hz)');
ylim(ylimits);
xticklabels({});
[~, sh] = scaleline(ax(2), 3600,'1 Hour' );
sh.FontSize = 10;
title('TFpeak Scatterplot');


% Plot SO power histogram
axes(ax(3))
imagesc(SOpow_bins, freq_bins, SOpow_mat');
axis xy;
colormap(ax(3), 'parula');
pow_clims = climscale([],[],false);
c = colorbar_noresize;
c.Label.String = {'Density', '(peaks/min in bin)'};
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";
xlabel('SO Power (Normalized)');
ylabel('Frequency (Hz)');
ylim(ylimits);
title('SO Power Histogram');

% Plot SO phase histogram
axes(ax(4))
imagesc(SOphase_bins, freq_bins, SOphase_mat');
axis xy;
colormap(ax(4), 'magma');
climscale;
c = colorbar_noresize;
c.Label.String = {'Proportion'};
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";
xlabel('SO Phase (radians)');
ylabel('Frequency (Hz)');
ylim(ylimits);
title('SO Phase Histogram');
xticks([-pi -pi/2 0 pi/2 pi])
xticklabels({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'});




