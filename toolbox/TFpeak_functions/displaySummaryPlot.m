function [fh] = displaySummaryPlot(varargin)
%DISPLAYSUMMARYPLOT  Display main outputs of the runDYNAMO() wrapper function
%
%   Usage:
%       [fh] = displaySummaryPlot('stats_table', stats_table)
%
%   Optional inputs:
%    >> HYPNOGRAM
%       stage_times:        [1x<number of stages>] vector - times of sleep stages in seconds
%       stage_vals:         [1x<number of stages>] - values of sleep stages
%       artifacts:          [1xT] logical of times flagged as artifacts (logical OR of hf and bb artifacts)
%       t_time_range:       [1xn] double - timestamps for data in time_range
%
%    >> SPECTROGRAM
%       data:               [1xT] double - timeseries data to be analyzed
%       Fs:                 double - sampling frequency of data (Hz)
%       time_range:         [1x2] double - section of EEG to display (seconds).
%       mtm_freq_range:     [1x2] double - multitaper method frequency range to compute spectrogram over (Hz). [lower, higher].
%                           Default = [2, 25]
%       freq_limits:        [1x2] double - frequency limits to display spectrograms and SO feature histograms (Hz). [lower, higher].
%                           Default = mtm_freq_range
%
%    >> SO-POWER TRACE
%       SOpower_norm:       [1xM] double - spectral power of slow oscillation computed with multitaper spectral estimation.
%                           At a coarser resolution than the original data timeseries since windowing is used. Should be calculated
%                           using computeSOpower(), with typical window parameters used at [5, .5].
%       SOpower_times:      [1xM] double - times for each SOpower data sample. Also output by computeSOpower().
%       SOpower_norm_method:char - normalization method used for SOpower_norm. Options:'pNshiftS', 'percent', 'proportion', 'none'.
%                           Note that the provided normalization option should match with what was used to compute SOpower_norm.
%                           Default = 'p2shift1234'
%
%    >> TIME-FREQUENCY PEAK SCATTERPLOT
%       stats_table:        table - features of each TFpeak
%       hist_peakidx        [1xP] logical - which TFpeaks are counted in the feature histograms
%       peak_size_prctiles: [1x2] double - percentiles used to scale the dot size of TF-peaks in the scatter plot.
%                           Default = [5, 95]
%
%    >> SOPH SETTINGS FOR BOTH SO-POWER AND SO-PHASE HISTOGRAMS
%       freq_bins:          [1xF] double - frequency bin center values for dimension 2 of SOpower_mat and SOphase_mat
%       SOPH_clim_prctiles: [1x2] double - percentiles used to scale the heatmap color on SO feature histograms
%                           Default = [5, 98]
%
%    >> SO-POWER HISTOGRAM
%       SOpower_mat:        [BxF] double - SO power histogram data
%       SOpower_bins:       [1xB] double - SO power bin center values for dimension 1 of SOpower_mat
%
%    >> SO-PHASE HISTOGRAM
%       SOphase_mat:        [DxF] double - SO phase histogram data
%       SOphase_bins:       [1xD] double - SO phase bin center values for dimension 1 of SOphase_mat
%
%   Output:
%       fh:                 figure handle
%
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

%%
p = inputParser;

% hypnogram needs these variables
addParameter(p, 'stage_times', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nondecreasing','2d'}));
addParameter(p, 'stage_vals', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nonnegative','2d'}));
addParameter(p, 'artifacts', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));
addParameter(p, 't_time_range', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));

% spectrogram needs these variables
addParameter(p, 'data', [], @(x) validateattributes(x, {'numeric'}, {'real','2d'}));
addParameter(p, 'Fs', [], @(x) isa(x,'numeric') && (isempty(x) || isscalar(x)));
addParameter(p, 'time_range', [-inf inf], @(x) isa(x,'numeric') && length(x) <= 2);
addParameter(p, 'mtm_freq_range', [2, 25], @(x) validateattributes(x,{'numeric'},{'real','finite','vector','numel',2}));
addParameter(p, 'freq_limits', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));

% SO-power trace needs these variables
addParameter(p, 'SOpower_norm', [], @(x) validateattributes(x, {'numeric'}, {'real','2d'}));
addParameter(p, 'SOpower_times', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addParameter(p, 'SOpower_norm_method', 'p2shift1234', @(x) validateattributes(x, {'char','string'}, {'nonempty','scalartext'}));

% TF-peak scatter plot needs these variables
addParameter(p, 'stats_table', [], @(x) validateattributes(x, {'double','table'}, {'real','2d'}));
addParameter(p, 'hist_peakidx', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));
addParameter(p, 'peak_size_prctiles', [5, 95], @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));

% Both SOPH need these variables
addParameter(p, 'freq_bins', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addParameter(p, 'SOPH_clim_prctiles', [5, 98], @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));

% SO-power histogram needs these variables
addParameter(p, 'SOpower_mat', [], @(x) validateattributes(x, {'numeric'}, {'real','2d'}));
addParameter(p, 'SOpower_bins', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));

% SO-phase histogram needs these variables
addParameter(p, 'SOphase_mat', [], @(x) validateattributes(x, {'numeric'}, {'real','2d'}));
addParameter(p, 'SOphase_bins', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<*NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

%% Handle default values
if isempty(t_time_range) && ~isempty(artifacts)
    if ~isempty(Fs)
        if ~isempty(data)
            assert(length(artifacts) == length(data), 'Missing t_time_range and different vector lengths for artifacts and data.')
        end
        t_time_range = (0:length(artifacts)-1)/Fs;
    end
    error('Variable artifacts inputted but no time vector provided or can be calculated. Please provide t_time_range.')
end

if all(~isfinite(time_range))
    if ~isempty(t_time_range)
        time_range = [min(t_time_range), max(t_time_range)];
    elseif ~isempty(data) && ~isempty(Fs)
        tmp_t = (0:length(data)-1)/Fs;
        time_range = [min(tmp_t), max(tmp_t)];
    elseif ~isempty(SOpower_times)
        time_range = [min(SOpower_times), max(SOpower_times)];
    elseif ~isempty(stats_table)
        time_range = [min(stats_table.PeakTime), max(stats_table.PeakTime)];
    end
end

if isempty(freq_limits) %#ok<*NODEF>
    freq_limits = mtm_freq_range;
end

if isempty(hist_peakidx)
    hist_peakidx = true(1, height(stats_table));
end

if ~isempty(SOpower_mat) || ~isempty(SOphase_mat)
    assert(~isempty(freq_bins), 'freq_bins must be provided to plot SO feature histograms.')
end

%% Create figure
fh = figure('Color',[1 1 1],'units','inches');
set(fh, 'position', [0 0 8.5 11])
orient portrait;

hypn_spect_ax = gobjects(1, 3);
ax = gobjects(1, 3);

%Hypnogram/spectrogram/SO-power axes
if ~isempty(stage_times) && ~isempty(stage_vals)
    hypn_spect_ax(1) = axes('Parent',fh,'Position',[0.07  0.893  0.82  0.076]);
end
if ~isempty(data) && ~isempty(Fs)
    hypn_spect_ax(2) = axes('Parent',fh,'Position',[0.07  0.726  0.82  0.167]);
end
if ~isempty(SOpower_norm) && ~isempty(SOpower_times)
    hypn_spect_ax(3) = axes('Parent',fh,'Position',[0.07  0.670  0.82  0.056]);
end

%Scatter plot axes
if ~isempty(stats_table)
    ax(1) = axes('Parent',fh,'Position',           [0.07  0.420  0.82  0.2]);
end

%SO-power/phase axes
if ~isempty(freq_bins) && ~isempty(SOpower_mat) && ~isempty(SOpower_bins)
    ax(2) = axes('Parent',fh,'Position',           [0.07  0.050  0.335 0.3]);
end
if ~isempty(freq_bins) && ~isempty(SOphase_mat) && ~isempty(SOphase_bins)
    ax(3) = axes('Parent',fh,'Position',           [0.555 0.050  0.335 0.3]);
end

%% Plot hypnogram
if isgraphics(hypn_spect_ax(1))
    axes(hypn_spect_ax(1));
    hypnoplot(stage_times/3600, stage_vals, 'Artifacts', artifacts, 'ArtifactTimes', t_time_range/3600, 'TimesUnit', 'hours');

    if isgraphics(hypn_spect_ax(2))
        th(1) = title('EEG Spectrogram');
    else
        th(1) = title('Sleep Hypnogram');
    end

    th(1) = title('EEG Spectrogram');
    set(hypn_spect_ax(1), 'XTick', []);
end

%% Plot spectrogram
if isgraphics(hypn_spect_ax(2))
    [spect_disp, stimes_disp, sfreqs_disp] = multitaper_spectrogram_mex(data, Fs, mtm_freq_range, [15 29], [30 15], [],'linear',[],false,false);

    axes(hypn_spect_ax(2))
    stimes_inds = stimes_disp >= time_range(1) & stimes_disp <= time_range(2);
    imagesc(stimes_disp(stimes_inds)/3600, sfreqs_disp, pow2db(spect_disp(:, stimes_inds)));
    axis xy
    colormap(hypn_spect_ax(2), rainbow4);
    climscale;

    c = colorbar_noresize; % set colobar
    c.Label.String = 'PSD (dB)'; % colobar label
    c.Label.Rotation = -90; % rotate colorbar label
    c.Label.VerticalAlignment = "bottom";

    ylabel('Frequency (Hz)');

    if ~isgraphics(hypn_spect_ax(3))
        xlabel('Time (hr)')
    end

    if ~isgraphics(hypn_spect_ax(1))
        th(1) = title('EEG Spectrogram');
    end

    if isgraphics(hypn_spect_ax(3))
        set(hypn_spect_ax(2), 'XtickLabel', []);
    end
end

%% Plot SO-Power trace
if isgraphics(hypn_spect_ax(3))
    axes(hypn_spect_ax(3))
    plot(SOpower_times/3600, SOpower_norm, 'linewidth', 2)
    min_SOP = min(SOpower_norm);
    max_SOP = max(SOpower_norm);
    ylim([min_SOP-(0.1*abs(min_SOP)), max_SOP+(0.1*abs(max_SOP))])
    set(hypn_spect_ax(3), 'YTick', [round(min_SOP, 2, 'significant') round((max_SOP+min_SOP)/2, 2, 'significant') round(max_SOP, 2, 'significant')]);
    set(hypn_spect_ax(3), 'YTickLabel', num2str(get(hypn_spect_ax(3),'ytick')','%.1f'));

    switch SOpower_norm_method
        case 'percent'
            ylab = '%SOP';
        case 'proportion'
            ylab = 'SO Prop.';
        otherwise
            ylab = 'SOP (dB)';
    end
    ylabel(ylab);

    if ~isgraphics(ax(1))
        xlabel('Time (hr)')
    end

    if ~isgraphics(hypn_spect_ax(2))
        th(2) = title('Slow Oscillation Power');
    end
end

%% Plot time-frequency peak scatterplot
if isgraphics(ax(1))
    % Plot only TF peaks that contribute to SO-power/phase histograms
    stats_table_SOPH = stats_table(hist_peakidx, :);

    axes(ax(1))
    %Compute peak dot size
    pmin = prctile(stats_table_SOPH.Volume, peak_size_prctiles(1)); % get 5th ptile of volumes
    peak_size = stats_table_SOPH.Volume / pmin * 0.5;  % 5th ptile fixed at size 0.5

    %Do not plot larger than 95th ptile or else dots could obscure other things on the plot
    pmax = prctile(stats_table_SOPH.Volume, peak_size_prctiles(2)); % get 95th ptile of volumes
    pmax_inds = stats_table_SOPH.Volume> pmax;
    peak_size(pmax_inds) = nan;

    scatter(stats_table_SOPH.PeakTime/3600, stats_table_SOPH.PeakFrequency, peak_size, stats_table_SOPH.SOphase, 'filled'); % scatter plot all peaks

    %Make circular colormap
    colormap(ax(1),circshift(hsv(2^12),-650))

    c = colorbar_noresize;
    c.Label.String = 'Phase (radians)';
    c.Label.Rotation = -90;
    c.Label.VerticalAlignment = "bottom";
    c.XTick = [-pi -pi/2 0 pi/2 pi];
    c.XTickLabel = {'-\pi', '-\pi/2', '0', '\pi/2', '\pi'};

    ylabel('Frequency (Hz)');
    xlabel('Time (hr)')
    th(3) = title('Extracted Time-Frequency Peaks');
end

%% Plot SO-power histogram
if isgraphics(ax(2))
    axes(ax(2))
    imagesc(SOpower_bins, freq_bins, SOpower_mat'); %#ok<*USENS>
    axis xy;
    colormap(ax(2), gouldian);

    %Set colorscale
    if ~all(isnan(SOpower_mat),'all')
        tmp_freq_idx = freq_bins >= freq_limits(1) & freq_bins <= freq_limits(2);
        tmp_mat = SOpower_mat(:, tmp_freq_idx);
        c_ptiles = prctile(tmp_mat(:), SOPH_clim_prctiles);
        clim(gca,[c_ptiles(1) c_ptiles(2)]);

        c = colorbar_noresize;
        c.Label.String = {'Density', '(peaks/min in bin)'};
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
    end

    ylim(freq_limits);
    ylabel('Frequency (Hz)');

    switch SOpower_norm_method
        case 'percent'
            xlab = '% SO-Power';
        case 'proportion'
            xlab = 'SO-Power Proportion';
        otherwise
            xlab = 'SO-Power (dB)';
    end
    xlabel(xlab);

    th(4) = title('SO-Power Histogram');
end

%% Plot SO-phase histogram
if isgraphics(ax(3))
    axes(ax(3))
    imagesc(SOphase_bins, freq_bins, SOphase_mat');
    axis xy;
    colormap(ax(3), 'magma');

    %Scale color limits
    if ~all(isnan(SOphase_mat),'all')
        tmp_freq_idx = freq_bins >= freq_limits(1) & freq_bins <= freq_limits(2);
        tmp_mat = SOphase_mat(:, tmp_freq_idx);
        c_ptiles = prctile(tmp_mat(tmp_mat(:)~=0), SOPH_clim_prctiles);
        clim([c_ptiles(1) c_ptiles(2)]);

        c = colorbar_noresize;
        c.Label.String = {'Proportion'};
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
    end

    ylim(freq_limits);

    if ~isgraphics(ax(2))
        ylabel('Frequency (Hz)');
    end

    xlabel('SO-Phase (rad)');
    xticks([-pi -pi/2 0 pi/2 pi])
    xticklabels({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'});

    th(5) = title('SO-Phase Histogram');
end

%% Additional axes adjustments
% Link spectrogram y-axis
if isgraphics(hypn_spect_ax(2)) && isgraphics(ax(1))
    hy = linkprop([hypn_spect_ax(2), ax(1)], 'YLim');
    setappdata(hypn_spect_ax(2), 'YLink', hy);
    ylim(hypn_spect_ax(2), freq_limits)
end

% Link x-axes of appropriate plots
temp_axes = [hypn_spect_ax, ax(1)];
temp_axes = temp_axes(isgraphics(temp_axes));
if ~isempty(temp_axes)
    linkaxes(temp_axes, 'x');
    axes(temp_axes(1))
    xlimits = xlim;
    if all(isfinite(time_range))
        xlim(time_range/3600)
    elseif isfinite(time_range(1))
        xlim([time_range(1), xlimits(2)])
    elseif isfinite(time_range(2))
        xlim([xlimits(1), time_range(2)])
    end
end

% Link SOPH y-axis
if isgraphics(ax(2)) && isgraphics(ax(3))
    linkaxes([ax(2), ax(3)], 'y')
end

%Set consistent fontsizes throughout the figure
temp_axes = [hypn_spect_ax, ax];
temp_axes = temp_axes(isgraphics(temp_axes));
set(temp_axes, 'FontSize', 10)
set(th(isgraphics(th)), 'Fontsize', 15)
