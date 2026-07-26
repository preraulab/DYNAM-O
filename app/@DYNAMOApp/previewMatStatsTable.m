function previewMatStatsTable(app, p)
    % previewMatStatsTable  Render a TFpeaks stats_table .mat as
    % a sortable uitable filling the preview pane.
    S = load(p);
    ut = uitable(app.ResultsBrowserPreviewBody);
    ut.Units = 'normalized'; ut.Position = [0 0 1 1];
    ut.Data = S.stats_table; ut.ColumnSortable = true;
end
