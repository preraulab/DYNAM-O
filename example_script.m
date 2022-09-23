%Example Script to Run TF-peak Extraction and Create SO-power/phase Histograms
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
%
%**********************************************************************

%%%% Example script showing how to compute time-frequency peaks and SO-power/phase histograms

%% PATH SETTINGS
% Add necessary functions to path
addpath(genpath('./toolbox'))

%% DATA SETTINGS
%Location of example data
data_fname = 'example_data/example_data.mat';

%Select 'segment' or 'night' for example data range
data_range = 'segment'; %Only works for example data provide

%% ALGORITHM SETTINGS
%Quality settings for the algorithm:
%   'precision': high res settings
%   'fast': speed-up with minimal impact on results *suggested*
%   'draft': faster speed-up with increased high frequency TF-peaks, *not recommended for analyzing SOphase*
quality_setting = 'fast';

%Normalization setting for computing SO-power histogram:
%   'p5shift': Aligns at the 5th percentile, important for comparing across subjects
%   'percent': Scales between 1st and 99th ptile. Use percent only if subjects all reach stage 3
%   'proportion': ratio of SO-power to total power
%   'none': No normalization. Raw dB power
SOpower_norm_method = 'p5shift';

%Save figure image
save_output_image = false;
output_fname = [];

%Save peak property data
%   0: Does not save anything
%   1: Saves a subset of properties for each TFpeak 
%   2: Saves all properties for all peaks (including rejected noise peaks) 
save_peak_properties = 0;

%% PREPARE DATA
%Check for parallel toolbox
v = ver;
haspar = any(strcmp({v.Name}, 'Parallel Computing Toolbox'));
if haspar
    gcp;
end

%% LOAD DATA
%Load example EEG data
load(data_fname, 'data', 'stage_vals', 'stage_times', 'Fs');

%STAGE NOTATION (in order of sleep depth)
% W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0

% Add necessary functions to path
addpath(genpath('./toolbox'))

switch data_range
    case 'segment'
        % Choose an example segment from the data
        time_range = [8420 13446];
        disp('Running example segment')
    case 'night'
        wake_buffer = 5*60; %5 minute buffer before/after first/last wake
        start_time = stage_times(find(stage_vals < 5 & stage_vals > 0, 1, 'first')) - wake_buffer;
        end_time = stage_times(find(stage_vals < 5 & stage_vals > 0, 1, 'last')+1) + wake_buffer;

        time_range = [start_time end_time];
        disp('Running full night')
end

%% RUN WATERSHED AND COMPUTE SO-POWER/PHASE HISTOGRAMS
[peak_props, SOpow_mat, SOphase_mat, SOpow_bins, SOphase_bins, freq_bins, spect, stimes, sfreqs, SOpower_norm, SOpow_times, boundaries] = ...
    run_watershed_SOpowphase(data, Fs, stage_times, stage_vals, 'time_range', time_range, 'quality_setting', quality_setting, 'SOpower_norm_method', SOpower_norm_method, 'save_pref', save_peak_properties);

%% COMPUTE SPECTROGRAM FOR DISPLAY
[spect_disp, stimes_disp, sfreqs_disp] = multitaper_spectrogram_mex(data, Fs, [4,25], [15 29], [30 15], [],'linear',[],false,false);

% PLOT RESULTS FIGURE
% Create figure
fh = figure('Color',[1 1 1],'units','inches','position',[0 0 8.5 11]);
orient portrait;

%Hypnogram/spectrogram/SO-power axes
hypn_spect_ax(1) = axes('Parent',fh,'Position',[0.06 0.913 0.83 0.056]);
hypn_spect_ax(2) = axes('Parent',fh,'Position',[0.06 0.756 0.83 0.157]);
hypn_spect_ax(3) = axes('Parent',fh,'Position',[0.06 0.7   0.83 0.056]);

%Scatter plot axes
ax(1) = axes('Parent',fh,'Position',[0.06 0.45 0.83 0.2]);

%SO-power/phase axes
ax(2) = axes('Parent',fh,'Position',[0.06  0.07 0.335 0.3]);
ax(3) = axes('Parent',fh,'Position',[0.555 0.07 0.335 0.3]);

% Link axes of appropriate plots
linkaxes([hypn_spect_ax, ax(1)], 'x');
linkaxes([hypn_spect_ax(2), ax(1)], 'y');

% Set yaxis limits
ylimits = [4,25];

% Plot hypnogram
axes(hypn_spect_ax(1));
hypnoplot(stage_times/3600,stage_vals);
xlim(time_range/3600)
ylim(hypn_spect_ax(1),[.3 5.1])
th(1) = title('EEG Spectrogram');

% Plot spectrogram
axes(hypn_spect_ax(2))
imagesc(stimes_disp/3600, sfreqs_disp, pow2db(spect_disp));
axis xy
colormap(hypn_spect_ax(2), 'jet');
climscale;

c = colorbar_noresize; % set colobar
c.Label.String = 'Power (dB)'; % colobar label
c.Label.Rotation = -90; % rotate colorbar label
c.Label.VerticalAlignment = "bottom";

ylabel('Frequency (Hz)');
xlabel('')
ylim(ylimits);
set(hypn_spect_ax(1),'XTick',{})
xlim(time_range/3600)

% Plot SO-Power trace
axes(hypn_spect_ax(3))
plot(SOpow_times/3600,SOpower_norm,'linewidth',2)
xlim(time_range/3600)
max_SOP = max(SOpower_norm);
ylim([0 max_SOP+(0.1*max_SOP)])
set(hypn_spect_ax(3),'YTick',[0 round(max_SOP/2, 2, 'significant') round(max_SOP, 2, 'significant')]);
switch SOpower_norm_method
    case {'p5shift', 'none'}
        ylab = 'SOP(dB)';
    case 'percent'
        ylab = '%SOP';
    case 'proportion'
        ylab = 'SO Prop.';
end
ylabel(ylab);

% Plot time-frequency peak scatterplot
axes(ax(1))
%Compute peak dot size
pmax = prctile(peak_props.peak_height, 95); % get 95th ptile of heights
peak_height = peak_props.peak_height;
peak_height(peak_height>pmax) = pmax; % don't plot larger than 95th ptile or else dots could obscure other things on the plot
peak_size = peak_height/6;

scatter(peak_props.peak_times/3600, peak_props.peak_freqs, peak_size, peak_props.peak_SOphase, 'filled'); % scatter plot all peaks

%Make circular colormap
colormap(ax(1),circshift(hsv(2^12),-650))

c = colorbar_noresize;
c.Label.String = 'Phase (radians)';
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";
set(c,'xtick',([-pi -pi/2 0 pi/2 pi]),'xticklabel',({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'}));

ylabel('Frequency (Hz)');
ylim(ylimits);

xlabel('Time (hrs)')
th(2) = title('Extracted Time-Frequency Peaks');
xlim(time_range/3600)

% Plot SO-power histogram
axes(ax(2))
imagesc(SOpow_bins, freq_bins, SOpow_mat');
axis xy;
colormap(ax(2), 'parula');

%Keep color scales consistent across different settings
%Run the climscale for different data
if strcmpi(data_range,'night')
    caxis([0 8.5]);
elseif strcmpi(data_range,'segment')
    caxis([0 2.4]);
else
    climscale([],[],false);
end

c = colorbar_noresize;
c.Label.String = {'Density', '(peaks/min in bin)'};
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";

switch SOpower_norm_method
    case {'p5shift', 'none'}
        xlab = 'SO-Power (dB)';
    case 'percent'
        xlab = '% SO-Power';
    case 'proportion'
        xlab = 'SO-Power Proportion';
end

xlabel(xlab);
ylabel('Frequency (Hz)');
ylim(ylimits);
th(3) = title('SO-Power Histogram');

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

%Keep color scales consistent across different settings
%Run the climscale for different data
if strcmpi(data_range,'night')
    caxis([0.0085    0.0118]);
elseif strcmpi(data_range,'segment')
    caxis([0.0070    0.0144]);
else
    climscale([],[],false);
end

th(4) = title('SO-Phase Histogram');

set([ax hypn_spect_ax],'fontsize',10)
set(th,'fontsize',15)

%% PRINT OUTPUT
if save_output_image
    %Output filename
    if isempty(output_fname)
        output_fname = 'TFpeakDynamics.png'
    end
    print(fh,'-dpng','-r200',output_fname);
end

