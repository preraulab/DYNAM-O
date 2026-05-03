function createAnalysisTab(app)
    %createAnalysisTab  Build the Analysis tab and its inner tab
    %   group hosting SO-Histograms (channel multi-select + plot panel).
    % ============================================================
    %   Analysis Tab: hosts SO-Histograms (and future tabs)
    % ============================================================
    analysisGrid             = uigridlayout(app.AnalysisTab);
    analysisGrid.ColumnWidth = {'1x'};
    analysisGrid.RowHeight   = {'1x'};
    analysisGrid.Padding     = [5 5 5 5];

    app.AnalysisTabGroup = uitabgroup(analysisGrid);
    app.AnalysisTabGroup.Layout.Row    = 1;
    app.AnalysisTabGroup.Layout.Column = 1;
    % Refresh the SO Histograms availability lazily — only when the
    % user actually selects that tab AND the underlying data is marked
    % dirty (results root reloaded, aggregation completed). This keeps
    % the multi-second uiaxes-creation cost off the hot path of every
    % tree load.
    app.AnalysisTabGroup.SelectionChangedFcn = ...
        @(src,evt) onAnalysisTabSelected(app, evt);

    app.SOHistogramsTab       = uitab(app.AnalysisTabGroup);
    app.SOHistogramsTab.Title = 'SO-Histograms';

    % Top: fixed-height channel selector | Bottom: dynamic plot grid
    app.SOHistogramsGrid             = uigridlayout(app.SOHistogramsTab);
    app.SOHistogramsGrid.ColumnWidth = {'1x'};
    app.SOHistogramsGrid.RowHeight   = {120, '1x'};
    app.SOHistogramsGrid.RowSpacing  = 5;
    app.SOHistogramsGrid.Padding     = [5 5 5 5];

    % --- Channel selector panel (top) ---
    app.SOHistogramsSelectorPanel             = uigridlayout(app.SOHistogramsGrid);
    app.SOHistogramsSelectorPanel.ColumnWidth = {'1x'};
    app.SOHistogramsSelectorPanel.RowHeight   = {18, '1x'};
    app.SOHistogramsSelectorPanel.RowSpacing  = 2;
    app.SOHistogramsSelectorPanel.Padding     = [0 0 0 0];
    app.SOHistogramsSelectorPanel.Layout.Row    = 1;
    app.SOHistogramsSelectorPanel.Layout.Column = 1;

    app.SOHistogramsChannelLabel = CSSuiLabel(app.SOHistogramsSelectorPanel, ...
        'Style', app.AppStyle, ...
        'FontSize','13px', ...
        'Text','Channels (multi-select):');
    app.SOHistogramsChannelLabel.Layout.Row    = 1;
    app.SOHistogramsChannelLabel.Layout.Column = 1;

    app.SOHistogramsChannelListBox = uilistbox(app.SOHistogramsSelectorPanel, ...
        'Multiselect',     'on', ...
        'Items',           {}, ...
        'ValueChangedFcn', @(src,evt) onSOHistogramsSelectionChanged(app));
    app.SOHistogramsChannelListBox.Layout.Row    = 2;
    app.SOHistogramsChannelListBox.Layout.Column = 1;

    % --- Plot panel (bottom) ---
    % uipanel (white) hosts a single placeholder uiaxes that
    % covers the area; redraw replaces the children, leaving the
    % panel itself stable across selection changes. When channels
    % are picked, figdesign(panel, N, 2) places real axes on top.
    app.SOHistogramsPlotPanel = uipanel(app.SOHistogramsGrid, ...
        'BackgroundColor','white', ...
        'BorderType','none');
    app.SOHistogramsPlotPanel.Layout.Row    = 2;
    app.SOHistogramsPlotPanel.Layout.Column = 1;

    app.SOHistogramsPlaceholderAxes = uiaxes(app.SOHistogramsPlotPanel, ...
        'Units','normalized', ...
        'Position',[0 0 1 1], ...
        'BackgroundColor','white');
    axis(app.SOHistogramsPlaceholderAxes,'off');
    text(app.SOHistogramsPlaceholderAxes, 0.5, 0.5, ...
        'Select one or more channels above', ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'Color',[0.5 0.5 0.5]);

end
