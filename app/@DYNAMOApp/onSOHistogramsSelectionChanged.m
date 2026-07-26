function onSOHistogramsSelectionChanged(app)
    % onSOHistogramsSelectionChanged  ListBox change handler for
    % the SO-Histograms tab. Strips any "(no data) ..." entries
    % out of the user's selection before redrawing — those
    % entries are placeholders for channels with no aggregate
    % SOPHs file yet and aren't valid plot targets.
    if app.SOHist_SuppressFcn_, return, end
    sel = app.SOHistogramsChannelListBox.Value;
    if ischar(sel) || isstring(sel), sel = cellstr(sel); end
    keep = sel(~startsWith(sel, '(no data) '));
    if numel(keep) ~= numel(sel)
        app.SOHist_SuppressFcn_ = true;
        app.SOHistogramsChannelListBox.Value = keep;
        app.SOHist_SuppressFcn_ = false;
    end
    app.redrawSOHistograms();
    % If the Mode Scatter inner tab is currently attached,
    % refresh both dropdown sets (column union depends on
    % the selected channels) and redraw the paired scatters.
    if ~isempty(app.ModeScatterTab) && ~isempty(app.ModeScatterTab.Parent)
        app.refreshModeScatterDropdowns('power');
        app.refreshModeScatterDropdowns('phase');
        app.redrawModeScatter();
    end
end
