function selected = pickAggregateFormats(app, present)
    % pickAggregateFormats  Modal CSSuiListBox multiselect dialog asking
    % which of the present aggregable file types to roll up.
    %
    %   selected - cell of {'paramfit_csv','paramfit_mat','sophs_mat','sophs_tiff'}
    %              that the user picked, or [] if cancelled.
    %
    %   Behaviors:
    %     * Only file types flagged true in `present` are shown.
    %     * If exactly one is present, returns it without prompting.
    %     * If zero are present, returns {}.
    %     * Default: every present type is preselected.

    keys   = {'paramfit_csv',     'paramfit_mat',     'sophs_mat',          'sophs_tiff'};
    labels = {'Param fit (CSV)',  'Param fit (MAT)',  'SOPHs (MAT struct)', 'SOPHs (TIFF)'};
    avail = false(size(keys));
    for kk = 1:numel(keys)
        avail(kk) = isfield(present, keys{kk}) && present.(keys{kk});
    end

    availKeys   = keys(avail);
    availLabels = labels(avail);

    if isempty(availKeys)
        selected = {};
        return
    end
    if numel(availKeys) == 1
        selected = availKeys;
        return
    end

    % --- Build the modal dialog ---
    ss   = get(0, 'ScreenSize');
    pdW  = 460; pdH = 300; pad = 14;
    dlg  = uifigure('Name', 'Aggregate — pick file types', ...
        'Position', [(ss(3)-pdW)/2, (ss(4)-pdH)/2, pdW, pdH], ...
        'WindowStyle', 'modal');

    CSSuiLabel(dlg, 'Style', app.AppStyle, ...
        'Text', 'Select which file types to aggregate:', ...
        'Position', [pad, pdH-pad-22, pdW-2*pad, 22]);

    lbH    = 160;
    lbBox  = CSSuiListBox(dlg, 'Style', app.AppStyle, ...
        'Items',       availLabels, ...
        'Multiselect', true, ...
        'Position',    [pad, pdH-pad-22-lbH-6, pdW-2*pad, lbH]);
    lbBox.Value = availLabels;   % default: select all

    selected = [];   % closure target — [] sentinel = cancel
    CSSuiButton(dlg, 'Style', app.AppStyle, 'Text', 'OK', ...
        'Position', [pdW-2*100-pad-8, pad, 100, 36], ...
        'ButtonPushedFcn', @(s,e) onOk());
    CSSuiButton(dlg, 'Style', app.AppStyle, 'Text', 'Cancel', ...
        'Position', [pdW-100-pad, pad, 100, 36], ...
        'ButtonPushedFcn', @(s,e) onCancel());

    uiwait(dlg);

    function onOk()
        sel = lbBox.Value;
        if ischar(sel),    sel = {sel};       end
        if isstring(sel),  sel = cellstr(sel); end
        if isempty(sel)
            uialert(dlg, 'Pick at least one file type, or Cancel.', ...
                'Need at least one', 'Icon', 'error');
            return
        end
        % Map labels back to canonical keys.
        keep = false(size(availLabels));
        for jj = 1:numel(availLabels)
            keep(jj) = any(strcmp(sel, availLabels{jj}));
        end
        selected = availKeys(keep);
        delete(dlg);
    end

    function onCancel()
        selected = [];
        delete(dlg);
    end
end
