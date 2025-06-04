function [fh] = displayTFPeaks(varargin)
%DISPLAYTFPEAKS  Display TF peaks detected by computeTFPeaks() on a spectrogram
%
%   Usage:
%       [fh] = displayTFPeaks(stats_table, spect, stimes, sfreqs)
%
%   Inputs:
%       stats_table:        table - features of each TFpeak
%       spect:              2D double - spectrogram of data
%       stimes:             1D double - timestamp bin center values for dimension 2 of spect
%       sfreqs:             1D double - frequency bin center values for dimension 1 of spect
%
%   Optional inputs:
%       data_time_range:    [1xn] double - timeseries data in time_range
%       t_time_range:       [1xn] double - timestamps for data in time_range
%       artifacts:          1xT logical of times flagged as artifacts (logical OR of hf and bb artifacts)
%       stage_times:        [1x<number of stages>] vector - times of sleep stages in seconds
%       stage_vals:         [1x<number of stages>] - values of sleep stages
%
%   Output:
%       fh:                 figure handle
%
%**********************************************************************

%%
p = inputParser;

addRequired(p, 'stats_table', @(x) validateattributes(x, {'table'}, {'real','nonempty','2d'}));
addRequired(p, 'spect', @(x) validateattributes(x, {'numeric'}, {'real','2d'}));
addRequired(p, 'stimes', @(x) validateattributes(x, {'numeric'}, {'real','finite','nondecreasing','vector'}));
addRequired(p, 'sfreqs', @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector'}));

addOptional(p, 'data_time_range', [], @(x) validateattributes(x, {'numeric'}, {'real','2d'}));
addOptional(p, 't_time_range', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addOptional(p, 'artifacts', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));

addOptional(p, 'stage_times', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nondecreasing','2d'}));
addOptional(p, 'stage_vals', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nonnegative','2d'}));

parse(p,varargin{:});

%% Create figure
fh = figure('Color',[1 1 1],'units','inches','position',[5 5 8.5 6]);
orient portrait;

%Hypnogram/spectrogram/eeg axes
if ~isempty(stage_times) && ~isempty(stage_vals)
    hypn_spect_ax(1) = axes('Parent',fh,'Position',[0.10 0.80 0.80 0.15]);
end

hypn_spect_ax(2) = axes('Parent',fh,'Position',[0.10 0.30 0.80 0.50]);

if ~isempty(data_time_range) && ~isempty(t_time_range)
    hypn_spect_ax(3) = axes('Parent',fh,'Position',[0.10 0.10 0.80 0.20]);
end

%% Plot hypnogram
if isgraphics(hypn_spect_ax(1))
    axes(hypn_spect_ax(1));
    %Adds artifacts raster below hypnogram, as computed in the time-domain,
    %will not match up to the spectrogram due to windowing
    hypnoplot(stage_times/3600,stage_vals,'Artifacts',artifacts','ArtifactTimes',t_time_range/3600);
    th(1) = title('EEG Spectrogram and Detected TF-peaks');
    set(hypn_spect_ax(1), 'XTick', []);
end

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

if ~isgraphics(hypn_spect_ax(1))
    th(1) = title('EEG Spectrogram and Detected TF-peaks');
end

if isgraphics(hypn_spect_ax(3))
    set(hypn_spect_ax(2), 'XtickLabel', []);
end

% overlay TF-peak boundaries on the spectrogram
bd = stats_table.Boundaries;
hold on;
for ii = 1:length(bd)
    plot(bd{ii}(:, 1)/3600, bd{ii}(:, 2), 'w', 'LineWidth', 1)
end

%% Plot EEG trace
if isgraphics(hypn_spect_ax(3))
    axes(hypn_spect_ax(3))
    plot(t_time_range/3600, data_time_range,'linewidth',1)
    min_trace = prctile(data_time_range, 1);
    max_trace = prctile(data_time_range, 99);
    ylim([min_trace-(0.1*abs(min_trace)), max_trace+(0.1*abs(max_trace))])
    hypn_spect_ax(3).YTick = [round(min_trace, 2, 'significant') 0 round(max_trace, 2, 'significant')];
    hypn_spect_ax(3).YTickLabel = num2str(get(hypn_spect_ax(3),'ytick')','%.1f');
    ylabel('Voltage (\muV)');
end
xlabel('Time (hr)')

%% Additional axes adjustments
linkaxes(hypn_spect_ax, 'x');
xlim([min(stimes)/3600, max(stimes)/3600])
set(hypn_spect_ax, 'FontSize', 10)
if exist('th', 'var')
    set(th, 'FontSize', 15)
end
