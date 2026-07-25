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
%       hist_peakidx        [Px1] logical - which TFpeaks are counted in the feature histograms.
%                           This population sets the scatter-plot dot-size scale; all non-artifact
%                           TFpeaks with valid SO phase are displayed.
%       SOPH_stages:        [1xS] numeric - sleep-stage values the SO-power/phase histograms include
%                           (0:Undef 1:N3 2:N2 3:N1 4:REM 5:Wake 6:Art). Periods whose stage is not
%                           in this set or whose interpolated SOpower_norm is NaN are shaded gray behind
%                           the TF-peak scatter. Default = [1 2 3]
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
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
%   GITHUB     https://github.com
%
%   ATTRIBUTION
%   If you use this toolbox, please cite:
%
%   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
%%
p = inputParser;

% hypnogram needs these variables
addParameter(p, 'stage_times', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nondecreasing','2d'}));
addParameter(p, 'stage_vals', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nonnegative','2d'}));
% Accept logical OR numeric mask (numeric gets coerced to logical
% after parse). Earlier versions only accepted logical, but some
% callers persist artifacts via .mat round-trips or struct copies
% that promote them to double; rejecting those here aborts the
% summary figure for an entire subject over a harmless type drift.
addParameter(p, 'artifacts', logical([]), @(x) validateattributes(x,{'logical','numeric'},{'real','finite','2d'}));
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
addParameter(p, 'SOPH_stages', [1, 2, 3], @(x) validateattributes(x, {'numeric'}, {'real','finite','vector'}));

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

% Coerce numeric artifact masks to logical (validator accepts both).
if ~islogical(artifacts)
    artifacts = logical(artifacts);
end

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
% Create invisible; final visibility is restored at end of function
% based on the root DefaultFigureVisible. This prevents flicker/pop-up
% during rendering in batch runs (exportgraphics doesn't need visibility).
fh = figure('Color',[1 1 1],'units','inches','Visible','off');
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
    hypnoplot(hypn_spect_ax(1), stage_times/3600, stage_vals, 'Artifacts', artifacts, 'ArtifactTimes', t_time_range/3600, 'TimesUnit', 'hours');

    if isgraphics(hypn_spect_ax(2))
        th(1) = title(hypn_spect_ax(1), 'EEG Spectrogram');
    else
        th(1) = title(hypn_spect_ax(1), 'Sleep Hypnogram');
    end

    th(1) = title(hypn_spect_ax(1), 'EEG Spectrogram');
    set(hypn_spect_ax(1), 'XTick', []);
end

%% Plot spectrogram
if isgraphics(hypn_spect_ax(2))
    [spect_disp, stimes_disp, sfreqs_disp] = multitaper_spectrogram_dynamo(data, Fs, mtm_freq_range, [15 29], [30 15], [],'linear',[],false,false);

    stimes_inds = stimes_disp >= time_range(1) & stimes_disp <= time_range(2);
    imagesc(hypn_spect_ax(2), stimes_disp(stimes_inds)/3600, sfreqs_disp, pow2db(spect_disp(:, stimes_inds)));
    axis(hypn_spect_ax(2),'xy')
    colormap(hypn_spect_ax(2), rainbow4);
    climscale(hypn_spect_ax(2));

    c = colorbar_noresize(hypn_spect_ax(2)); % set colobar
    c.Label.String = 'PSD (dB)'; % colobar label
    c.Label.Rotation = -90; % rotate colorbar label
    c.Label.VerticalAlignment = "bottom";

    ylabel(hypn_spect_ax(2),'Frequency (Hz)');

    if ~isgraphics(hypn_spect_ax(3))
        xlabel(hypn_spect_ax(2),'Time (hr)')
    else
        set(hypn_spect_ax(2), 'XtickLabel', []);
    end

    if ~isgraphics(hypn_spect_ax(1))
        th(1) = title(hypn_spect_ax(2),'EEG Spectrogram');
    end
end

%% Plot SO-Power trace
if isgraphics(hypn_spect_ax(3))
    plot(hypn_spect_ax(3), SOpower_times/3600, SOpower_norm, 'linewidth', 2)
    min_SOP = min(SOpower_norm);
    max_SOP = max(SOpower_norm);
    ylim(hypn_spect_ax(3), [min_SOP-(0.1*abs(min_SOP)), max_SOP+(0.1*abs(max_SOP))])
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
    ylabel(hypn_spect_ax(3), ylab);

    if ~isgraphics(ax(1))
        xlabel(hypn_spect_ax(3), 'Time (hr)')
    end

    if ~isgraphics(hypn_spect_ax(2))
        th(2) = title(hypn_spect_ax(3), 'Slow Oscillation Power');
    end
end

%% Plot time-frequency peak scatterplot
if isgraphics(ax(1))
    hold(ax(1), 'on')
    shade_patches = gobjects(0);

    % Reconstruct the time intervals used by the SOPH histograms. Evaluate
    % the same linearly interpolated SOpower and previous-stage predicates
    % used for peak_selection_inds in SOpowerHistogram. SOpower_norm already
    % carries artifact exclusions as NaNs.
    if ~isempty(SOpower_norm) && ~isempty(SOpower_times) && numel(SOpower_times) > 1
        SOpower_times_plot = SOpower_times(:);
        SOpower_norm_plot = SOpower_norm(:);
        SOpower_times_step = SOpower_times_plot(2) - SOpower_times_plot(1);
        SOpower_interp_start = SOpower_times_plot(1) - SOpower_times_step;
        SOpower_interp_end = SOpower_times_plot(end) + SOpower_times_step;

        interval_edges = unique([time_range(:); SOpower_interp_start; ...
            SOpower_times_plot; SOpower_interp_end; stage_times(:)]);
        interval_edges = interval_edges(interval_edges >= time_range(1) & interval_edges <= time_range(2));
        interval_midpoints = (interval_edges(1:end-1) + interval_edges(2:end)) / 2;

        SOpower_at_interval = interp1( ...
            [SOpower_interp_start; SOpower_times_plot; SOpower_interp_end], ...
            [SOpower_norm_plot(1); SOpower_norm_plot; SOpower_norm_plot(end)], ...
            interval_midpoints);
        interval_excluded = isnan(SOpower_at_interval);
        if ~isempty(stage_times) && ~isempty(stage_vals)
            stages_at_interval = interp1(stage_times, stage_vals, interval_midpoints, 'previous');
            stages_at_interval(isnan(stages_at_interval)) = 0;
            interval_excluded = interval_excluded | ~ismember(stages_at_interval, SOPH_stages);
        end

        excluded_edges = diff([false; interval_excluded; false]);
        excluded_runs = [find(excluded_edges == 1), find(excluded_edges == -1) - 1];

        shade_color = [0.9, 0.9, 0.9];
        shade_alpha = 0.75;
        for k = 1:size(excluded_runs, 1)
            t0 = interval_edges(excluded_runs(k, 1)) / 3600;
            t1 = interval_edges(excluded_runs(k, 2) + 1) / 3600;
            if t1 > t0
                shade_patches(end+1) = patch(ax(1), [t0 t1 t1 t0], ... %#ok<AGROW>
                    [freq_limits(1) freq_limits(1) freq_limits(2) freq_limits(2)], ...
                    shade_color, 'FaceAlpha', shade_alpha, 'EdgeColor', 'none', ...
                    'HandleVisibility', 'off');
            end
        end
    end

    % Use histogram-included peaks only to define the marker-size scale.
    stats_table_SOPH = stats_table(hist_peakidx, :);
    if isempty(stats_table_SOPH)
        peak_size = 0.5 * ones(height(stats_table), 1);
    else
        pmin = prctile(stats_table_SOPH.Volume, peak_size_prctiles(1));
        pmax = prctile(stats_table_SOPH.Volume, peak_size_prctiles(2));
        peak_size = min(stats_table.Volume, pmax) / pmin * 0.5;
    end

    % Artifact-excluded peaks have NaN SO phase. Plot every remaining peak
    % using the circular phase colormap.
    display_peakidx = ~isnan(stats_table.SOphase);
    scatter(ax(1), stats_table.PeakTime(display_peakidx)/3600, stats_table.PeakFrequency(display_peakidx), ...
        peak_size(display_peakidx), stats_table.SOphase(display_peakidx), 'filled', 'MarkerEdgeColor', 'none');
    if ~isempty(shade_patches)
        uistack(shade_patches, 'top');
    end

    %Make circular colormap
    colormap(ax(1),circshift(hsv(2^12),-650))

    c = colorbar_noresize(ax(1));
    c.Label.String = 'Phase (radians)';
    c.Label.Rotation = -90;
    c.Label.VerticalAlignment = "bottom";
    c.XTick = [-pi -pi/2 0 pi/2 pi];
    c.XTickLabel = {'-\pi', '-\pi/2', '0', '\pi/2', '\pi'};

    ylabel(ax(1), 'Frequency (Hz)');
    xlabel(ax(1), 'Time (hr)')
    th(3) = title(ax(1), 'Extracted Time-Frequency Peaks');
end

%% Plot SO-power histogram
if isgraphics(ax(2))
    imagesc(ax(2), SOpower_bins, freq_bins, SOpower_mat'); %#ok<*USENS>
    axis(ax(2),'xy');
    colormap(ax(2), gouldian);

    %Set colorscale
    if ~all(isnan(SOpower_mat),'all')
        tmp_freq_idx = freq_bins >= freq_limits(1) & freq_bins <= freq_limits(2);
        tmp_mat = SOpower_mat(:, tmp_freq_idx);
        c_ptiles = prctile(tmp_mat(:), SOPH_clim_prctiles);
        clim(ax(2),[c_ptiles(1) c_ptiles(2)]);

        c = colorbar_noresize(ax(2));
        c.Label.String = {'Density', '(peaks/min in bin)'};
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
    end

    ylim(ax(2), [min(freq_bins) max(freq_bins)]);
    ylabel(ax(2), 'Frequency (Hz)');

    switch SOpower_norm_method
        case 'percent'
            xlab = '% SO-Power';
        case 'proportion'
            xlab = 'SO-Power Proportion';
        otherwise
            xlab = 'SO-Power (dB)';
    end
    xlabel(ax(2), xlab);

    th(4) = title(ax(2), 'SO-Power Histogram');
end

%% Plot SO-phase histogram
if isgraphics(ax(3))
    imagesc(ax(3), SOphase_bins, freq_bins, SOphase_mat');
    axis(ax(3),'xy');
    colormap(ax(3), 'magma');

    %Scale color limits
    if ~all(isnan(SOphase_mat),'all')
        tmp_freq_idx = freq_bins >= freq_limits(1) & freq_bins <= freq_limits(2);
        tmp_mat = SOphase_mat(:, tmp_freq_idx);
        c_ptiles = prctile(tmp_mat(tmp_mat(:)~=0), SOPH_clim_prctiles);
        clim(ax(3),[c_ptiles(1) c_ptiles(2)]);

        c = colorbar_noresize(ax(3));
        c.Label.String = {'Proportion'};
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
    end

    ylim(ax(3), [min(freq_bins) max(freq_bins)]);

    if ~isgraphics(ax(2))
        ylabel(ax(3), 'Frequency (Hz)');
    end

    xlabel(ax(3), 'SO-Phase (rad)');
    xticks(ax(3), [-pi -pi/2 0 pi/2 pi])
    xticklabels(ax(3), {'-\pi', '-\pi/2', '0', '\pi/2', '\pi'});

    th(5) = title(ax(3), 'SO-Phase Histogram');
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
    xlimits = xlim(temp_axes(1));
    if all(isfinite(time_range))
        xlim(temp_axes(1), time_range/3600)
    elseif isfinite(time_range(1))
        xlim(temp_axes(1), [time_range(1), xlimits(2)])
    elseif isfinite(time_range(2))
        xlim(temp_axes(1), [xlimits(1), time_range(2)])
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

% Restore visibility for interactive callers (batch runs leave root
% DefaultFigureVisible='off', so the figure stays hidden there).
if strcmp(get(groot, 'DefaultFigureVisible'), 'on')
    set(fh, 'Visible', 'on');
end
