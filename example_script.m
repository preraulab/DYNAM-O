%%%% Example script showing how to compute time-frequency peaks and slow oscillation power and phase %%%%

%% Clear workspace and close plots
clear; close all; clc;

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
fh = figure('Color',[1 1 1],'units','inches','position',[0 0 8.5 11]);
orient portrait;

% Create main axes
ax(1) = axes('Parent',fh,'Position',[0.06 0.45 0.83 0.2]);
ax(2) = axes('Parent',fh,'Position',[0.06 0.07 0.335 0.3]);
ax(3) = axes('Parent',fh,'Position',[0.555 0.07 0.335 0.3]);

%Create hypnogram axes
hypn_spect_ax(1) = axes('Parent',fh,'Position',[0.06 0.686 0.83 0.227]);
hypn_spect_ax(2) = axes('Parent',fh,'Position',[0.06 0.913 0.83 0.056]);

% Link axes of appropriate plots
linkaxes([hypn_spect_ax(1), hypn_spect_ax(2), ax(1)], 'x');

% Set yaxis limits
ylimits = [4,25];

% Plot hypnogram
axes(hypn_spect_ax(2));
hypnoplot(t/3600,stages);
xlim(time_range/3600)
ylim(hypn_spect_ax(2),[.3 5.1])
t(1) = title('Hypnogram and Spectrogram');

% Plot spectrogram
axes(hypn_spect_ax(1))
[spect_disp, stimes_disp, sfreqs_disp] = multitaper_spectrogram_mex(EEG, Fs, [4,25],[15 29], [30 15],[],'linear',[],false);
imagesc(stimes_disp/3600, sfreqs_disp, pow2db(spect_disp));
axis xy
colormap(hypn_spect_ax(1), 'jet');
climscale;
c = colorbar_noresize; % set colobar
c.Label.String = 'Power (dB)'; % colobar label
c.Label.Rotation = -90; % rotate colorbar label
c.Label.VerticalAlignment = "bottom";
ylabel('Frequency (Hz)');
xlabel('')
ylim(ylimits);
set(hypn_spect_ax(1),'XTick',{})


% Plot time-frequency peak scatterplot
axes(ax(1))

%Compute peak dot size
pmax = prctile(peak_props.peak_height, 95); % get 95th ptile of heights
peak_props.peak_height(peak_props.peak_height>pmax) = pmax; % don't plot larger than 95th ptile or else dots could obscure other things on the plot
peak_size = peak_props.peak_height/10;

scatter(peak_props.peak_times/3600, peak_props.peak_freqs, peak_size, peak_props.peak_SOphase, 'filled'); % scatter plot all peaks

%Make circular colormap
colormap(ax(1),circshift(hsv(2^12),-400))
c = colorbar_noresize;
c.Label.String = 'Phase (radians)';
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";
set(c,'xtick',([-pi -pi/2 0 pi/2 pi]),'xticklabel',({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'}));    

ylabel('Frequency (Hz)');
ylim(ylimits);

xlabel('Time (hrs)')
t(2) = title('Extracted Time-Frequency Peaks');
xlim(time_range/3600)

% Plot SO-power histogram
axes(ax(2))
imagesc(SOpow_bins, freq_bins, SOpow_mat');
axis xy;
colormap(ax(2), 'parula');
climscale([],[],false);

c = colorbar_noresize;
c.Label.String = {'Density', '(peaks/min in bin)'};
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";

xlabel('%SO-Power');
ylabel('Frequency (Hz)');
ylim(ylimits);
t(3) = title('SO-Power Histogram');

% Plot SO-phase histogram
axes(ax(3))
imagesc(SOphase_bins, freq_bins, SOphase_mat');
axis xy;

colormap(ax(3), 'magma');
climscale;
c = colorbar_noresize;
c.Label.String = {'Proportion'};
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";

xlabel('SO-Phase (rad)');
xticks([-pi -pi/2 0 pi/2 pi])
xticklabels({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'});

ylim(ylimits);

t(4) = title('SO-Phase Histogram');

set([ax hypn_spect_ax],'fontsize',10)
set(t,'fontsize',15)






