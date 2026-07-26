function renderSplinefitTiffPreview(app, p, axis_kind)
    % Mirror of previewMatSplinefit but for the multi-page
    % splinefit TIFF (page 1 = coefs, page 2 = rendered fit).
    % Two tabs: rendered image + knots/coefs dump. Bins, knots,
    % and coefs are recovered from the page-1 ImageDescription
    % JSON (written by runSplineBasis) so this reconstructs the
    % .mat preview without needing the .mat alongside.
    info = imfinfo(p);
    meta = struct();
    if ~isempty(info) && isfield(info,'ImageDescription') && ...
            ~isempty(info(1).ImageDescription)
        try, meta = jsondecode(info(1).ImageDescription); catch, end
    end

    tg = uitabgroup(app.ResultsBrowserPreviewBody, ...
        'Units','normalized','Position',[0 0 1 1]);

    % --- Tab 1: rendered splinefit (page 2) ---
    tS = uitab(tg, 'Title','splinefit');
    gS = uigridlayout(tS);
    gS.ColumnWidth = {'1x'}; gS.RowHeight = {'1x'};
    gS.Padding = [12 12 12 12];
    axS = uiaxes(gS, 'BackgroundColor','white');
    axS.Layout.Row = 1; axS.Layout.Column = 1;
    try
        if numel(info) >= 2
            M = double(imread(p, 2));
        else
            M = double(imread(p, 1));
        end
        freq_bins = []; so_bins = [];
        binsField = ['SO' axis_kind '_bins'];
        if isfield(meta, 'freq_bins'),    freq_bins = meta.freq_bins(:); end
        if isfield(meta, binsField),      so_bins   = meta.(binsField)(:); end
        app.styleSOPHAxes(axS, M, freq_bins, so_bins, axis_kind);
        title(axS, 'Spline-fitted SOPH');
        app.attachPopOutToolbar(axS, ...
            @(a) app.styleSOPHAxes(a, M, freq_bins, so_bins, axis_kind), ...
            'Spline-fitted SOPH');
    catch ME
        axis(axS,'off');
        text(axS, 0.5, 0.5, sprintf('render failed: %s', ME.message), ...
            'HorizontalAlignment','center','Color','red');
    end

    % --- Tab 2: knots / coefs dump (knots from metadata, coefs
    %     from page 1 of the TIFF). Mirrors the .mat preview's
    %     text dump so the two views agree.
    tI = uitab(tg, 'Title','knots / coefs');
    ta = app.createFillTextArea(tI);
    lines = {};
    if isfield(meta, 'knots_x')
        lines = [lines; {'--- knots_x ---'}; ...
            splitlines(string(evalc('disp(meta.knots_x(:).'')')))];
    end
    if isfield(meta, 'knots_y')
        lines = [lines; {'--- knots_y ---'}; ...
            splitlines(string(evalc('disp(meta.knots_y(:).'')')))];
    end
    try
        coefs = double(imread(p, 1));
        lines = [lines; {sprintf('--- coefs (%d×%d) ---', ...
            size(coefs,1), size(coefs,2))}; ...
            splitlines(string(evalc('disp(coefs)')))];
    catch
        % Page 1 unreadable; skip the dump silently.
    end
    ta.Value = cellstr(lines);
end
