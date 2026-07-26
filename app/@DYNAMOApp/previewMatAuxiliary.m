function previewMatAuxiliary(app, p)
    % Single-panel mirror of displaySummaryPlot's hypn_spect_ax(1)
    % and hypn_spect_ax(3): properties table on top, hypnogram
    % with artifacts in the middle, SOpower trace below.
    S  = load(p);
    AD = normalizeAuxStruct(S.auxiliary_data);

    g = uigridlayout(app.ResultsBrowserPreviewBody);
    g.ColumnWidth = {'1x'};
    g.RowHeight   = {70, '1x', '1x'};
    g.RowSpacing  = 6;
    g.Padding     = [6 6 6 6];

    % --- Row 1: properties table ---
    propRows = {
        'Fs (Hz)',              num2str(AD.Fs)
        'SOpower norm method',  char(string(AD.SOpower_norm_method))
        };
    ut = uitable(g);
    ut.Layout.Row    = 1; ut.Layout.Column = 1;
    ut.Data          = propRows;
    ut.ColumnName    = {'Property','Value'};
    ut.ColumnWidth   = {180, 'auto'};
    ut.RowName       = [];

    % --- Row 2: hypnogram with artifacts overlay ---
    axH = uiaxes(g, 'BackgroundColor','white');
    axH.Layout.Row = 2; axH.Layout.Column = 1;
    try
        stage_t = double(AD.stage_times(:)') / 3600;     % hours
        hypnoplot(axH, stage_t, double(AD.stage_vals(:)'), 'TimesUnit', 'hours');
        % Artifact overlay drawn from [start_s,end_s] spans (normalizeAuxStruct
        % guarantees AD.artifact_spans, synthesizing it from a legacy
        % per-sample mask when needed). Shaded regions need no sample count.
        if isfield(AD,'artifact_spans') && ~isempty(AD.artifact_spans)
            draw_artifact_spans_(axH, AD.artifact_spans / 3600);   % seconds -> hours
        end
        title(axH, 'Sleep Hypnogram');
    catch ME
        cla(axH); axis(axH, 'off');
        text(axH, 0.5, 0.5, sprintf('hypnoplot failed: %s', ME.message), ...
            'HorizontalAlignment','center', 'Color', 'red', ...
            'Interpreter','none');
    end

    % --- Row 3: SOpower trace ---
    axP = uiaxes(g, 'BackgroundColor','white');
    axP.Layout.Row = 3; axP.Layout.Column = 1;
    if isfield(AD,'SOpower_norm') && ~isempty(AD.SOpower_norm) && ...
            isfield(AD,'Fs') && AD.Fs > 0
        N    = numel(AD.SOpower_norm);
        % Reconstruct the native timeline from t_start + i*step
        % (normalizeAuxStruct guarantees both, native or legacy EEG-rate).
        t0   = 0;          step = 1 / double(AD.Fs);
        if isfield(AD,'SOpower_t_start') && ~isempty(AD.SOpower_t_start)
            t0 = double(AD.SOpower_t_start);
        end
        if isfield(AD,'SOpower_step') && ~isempty(AD.SOpower_step)
            step = double(AD.SOpower_step);
        end
        tSec = t0 + (0:N-1) * step;
        tHr  = tSec / 3600;
        plot(axP, tHr, double(AD.SOpower_norm), 'LineWidth', 1.2);
        methodStr = char(string(AD.SOpower_norm_method));
        switch methodStr
            case 'percent',    ylab = 'Normalized SOP (%)';
            case 'proportion', ylab = 'Normalized SOP (proportion)';
            otherwise,         ylab = 'Normalized SOP (dB)';
        end
        ylabel(axP, ylab);
        xlabel(axP, 'Time (hr)');
        grid(axP, 'on');
        if ~isempty(tHr)
            xlim(axP, [tHr(1) tHr(end)]);
        end
        title(axP, sprintf('Normalized Slow Oscillation Power (%s)', methodStr));
        try, linkaxes([axH, axP], 'x'); catch, end
    else
        axis(axP, 'off');
        text(axP, 0.5, 0.5, '(no SOpower_norm data)', ...
            'HorizontalAlignment','center', 'Color',[0.45 0.5 0.55]);
    end
end


function draw_artifact_spans_(ax, spans_hr)
    % Shade each [start, end] artifact span (in hours) across the axis.
    if isempty(spans_hr), return, end
    try
        xr = xregion(ax, spans_hr(:,1), spans_hr(:,2));
        set(xr, 'FaceColor', [0.85 0.2 0.2], 'FaceAlpha', 0.18, 'EdgeColor', 'none');
    catch
        % Older MATLAB without xregion: fall back to translucent patches.
        yl = ylim(ax); held = ishold(ax); hold(ax, 'on');
        for r = 1:size(spans_hr, 1)
            x = [spans_hr(r,1) spans_hr(r,2) spans_hr(r,2) spans_hr(r,1)];
            y = [yl(1) yl(1) yl(2) yl(2)];
            patch(ax, x, y, [0.85 0.2 0.2], 'FaceAlpha', 0.18, 'EdgeColor', 'none');
        end
        if ~held, hold(ax, 'off'); end
    end
end
