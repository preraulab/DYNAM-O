function previewMatAuxiliary(app, p)
    % Single-panel mirror of displaySummaryPlot's hypn_spect_ax(1)
    % and hypn_spect_ax(3): properties table on top, hypnogram
    % with artifacts in the middle, SOpower trace below.
    S  = load(p);
    AD = S.auxiliary_data;

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
        if isfield(AD,'artifacts') && ~isempty(AD.artifacts) && ...
                isfield(AD,'Fs') && AD.Fs > 0
            N    = numel(AD.artifacts);
            tArt = (0:N-1) / double(AD.Fs) / 3600;       % hours
            hypnoplot(axH, stage_t, double(AD.stage_vals(:)'), ...
                'Artifacts', logical(AD.artifacts), ...
                'ArtifactTimes', tArt, ...
                'TimesUnit', 'hours');
        else
            hypnoplot(axH, stage_t, double(AD.stage_vals(:)'), ...
                'TimesUnit', 'hours');
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
        N         = numel(AD.SOpower_norm);
        retainFs  = true;
        winParams = [5, 0.5];
        if isfield(AD, 'SOpower_retain_Fs'),     retainFs  = logical(AD.SOpower_retain_Fs); end
        if isfield(AD, 'SOpower_window_params'), winParams = AD.SOpower_window_params;      end
        tSec = app.synthesizeSOpowerTimes(N, AD.Fs, retainFs, winParams);
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
