function go = preflightSummaryDialog(app, perFileResolved, resolves, dataList, primarySpecIdxList, channelListSafe)
    % preflightSummaryDialog  Show a Continue/Cancel summary of the
    % pre-flight resolution results. Returns true if the user wants
    % to proceed with the run, false if they cancelled.
    %
    %   Only called when at least one (file, outname) pair is
    %   predicted to fail — a fully-clean configuration skips the
    %   dialog entirely. Categorizes files into:
    %     - all resolve     (no list shown)
    %     - partial resolve (with the missing outnames per file)
    %     - none resolve    (whole subjects predicted to skip)
    %
    %   See also: simulateChannelResolution, runBatch.
    %
    % =====================================================================
    %                   DYNAM-O Toolbox  |  Prerau Laboratory
    % =====================================================================

    nFiles          = numel(dataList);
    nUniqueOutnames = numel(primarySpecIdxList);

    filesAll     = sum(perFileResolved == nUniqueOutnames);
    filesPartial = sum(perFileResolved > 0 & perFileResolved < nUniqueOutnames);
    filesNone    = sum(perFileResolved == 0);

    % Build per-file lines for the partial / none categories.
    partialLines = {};
    noneLines    = {};
    for jj = 1:nFiles
        [~, base, ext] = fileparts(dataList{jj});
        fname = [base, ext];
        if perFileResolved(jj) == nUniqueOutnames
            continue
        end
        missing = {};
        for kk = 1:nUniqueOutnames
            if ~resolves(jj, kk)
                missing{end+1} = channelListSafe{primarySpecIdxList(kk)}; %#ok<AGROW>
            end
        end
        line = sprintf('%s   [missing: %s]', fname, strjoin(missing, ', '));
        if perFileResolved(jj) == 0
            noneLines{end+1} = line; %#ok<AGROW>
        else
            partialLines{end+1} = line; %#ok<AGROW>
        end
    end

    % Window
    win = uifigure('Name', 'Pre-flight summary', ...
        'Position', [200 200 820 480], ...
        'WindowStyle', 'modal');
    try, app.trackChildWindow(win); catch, end

    g = uigridlayout(win, [5 1]);
    g.RowHeight   = {30, 30, '1x', '1x', 50};
    g.ColumnWidth = {'1x'};

    hdr = uilabel(g, 'Text', sprintf( ...
        'Pre-flight scan: %d file(s) × %d outname(s) planned.', ...
        nFiles, nUniqueOutnames), ...
        'FontWeight', 'bold', 'FontSize', 14);
    hdr.Layout.Row = 1;

    summary = uilabel(g, 'Text', sprintf( ...
        '   • %d file(s) produce all %d outname(s)\n   • %d file(s) produce a subset (see below)\n   • %d file(s) produce nothing (will be skipped)', ...
        filesAll, nUniqueOutnames, filesPartial, filesNone));
    summary.Layout.Row = 2;

    partialPanel = uigridlayout(g, [2 1]);
    partialPanel.Layout.Row = 3;
    partialPanel.RowHeight   = {22, '1x'};
    partialPanel.ColumnWidth = {'1x'};
    plbl = uilabel(partialPanel, 'Text', sprintf('Partial resolve (%d):', filesPartial), 'FontWeight','bold');
    plbl.Layout.Row = 1;
    plb = uilistbox(partialPanel, 'Items', defaultIfEmpty(partialLines));
    plb.Layout.Row = 2;

    nonePanel = uigridlayout(g, [2 1]);
    nonePanel.Layout.Row = 4;
    nonePanel.RowHeight   = {22, '1x'};
    nonePanel.ColumnWidth = {'1x'};
    nlbl = uilabel(nonePanel, 'Text', sprintf('No resolution (%d) — will skip without reading EDF:', filesNone), 'FontWeight','bold');
    nlbl.Layout.Row = 1;
    nlb = uilistbox(nonePanel, 'Items', defaultIfEmpty(noneLines));
    nlb.Layout.Row = 2;

    btnRow = uigridlayout(g, [1 3]);
    btnRow.Layout.Row = 5;
    btnRow.ColumnWidth = {'1x', 120, 120};
    btnRow.Padding = [10 5 10 5];
    spacer = uilabel(btnRow, 'Text', ''); spacer.Layout.Column = 1; %#ok<NASGU>

    decision = struct('go', false, 'done', false);
    cancelBtn = uibutton(btnRow, 'Text', 'Cancel', ...
        'ButtonPushedFcn', @(~,~) onClick(false));
    cancelBtn.Layout.Column = 2;
    okBtn = uibutton(btnRow, 'Text', 'Continue Run', ...
        'BackgroundColor', [0.10 0.55 0.20], 'FontColor', 'w', ...
        'ButtonPushedFcn', @(~,~) onClick(true));
    okBtn.Layout.Column = 3;

    win.CloseRequestFcn = @(~,~) onClick(false);

    uiwait(win);
    go = decision.go;

    function onClick(g_)
        decision.go   = g_;
        decision.done = true;
        if isvalid(win), delete(win); end
    end
end

function items = defaultIfEmpty(items)
    if isempty(items)
        items = {'(none)'};
    end
end
