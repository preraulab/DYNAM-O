function createAnalysisTab(app)
    %createAnalysisTab  Build the Aggregate Data tab. Channel
    %   multi-select listbox sits at the top; below it is an inner
    %   tab group with two views:
    %     1. Mean SOPH    — per-channel mean power/phase histograms,
    %                       shown as power+phase pairs per channel
    %     2. Mode Scatter — paramfit mode scatter, also as
    %                       power+phase pairs per channel. Power and
    %                       phase have non-overlapping numeric columns
    %                       (e.g. PrefPhaseArgmax / SOphaseMean), so
    %                       each axis kind gets its own X/Y/Size/Color
    %                       dropdown group, both visible at once.
    %
    %   The Mode Scatter inner tab and the outer Aggregate Data tab
    %   are attached/detached at runtime by
    %   updateAggregateDataTabVisibility based on what aggregate data
    %   is present under the current results root.

    % --- Outer 3-column layout: selector on left | draggable splitter |
    %     inner tabgroup on right. SplitterWidth_ caches the col-2 size
    %     so the drag handler can recompute new col-1 width without
    %     re-reading the layout. The splitter is a thin uipanel whose
    %     ButtonDownFcn arms figure-level WindowButtonMotion / Up
    %     handlers for the duration of the drag.
    app.SOHistogramsGrid               = uigridlayout(app.AnalysisTab);
    app.SOHistogramsGrid.ColumnWidth   = {180, 6, '1x'};
    app.SOHistogramsGrid.RowHeight     = {'1x'};
    app.SOHistogramsGrid.ColumnSpacing = 0;
    app.SOHistogramsGrid.Padding       = [5 5 5 5];

    % --- Channel selector panel (left) ---
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

    app.SOHistogramsChannelListBox = CSSuiListBox(app.SOHistogramsSelectorPanel, ...
        'Style',           app.AppStyle, ...
        'Multiselect',     true, ...
        'Items',           {}, ...
        'ValueChangedFcn', @(src,evt) onSOHistogramsSelectionChanged(app));
    app.SOHistogramsChannelListBox.Layout.Row    = 2;
    app.SOHistogramsChannelListBox.Layout.Column = 1;

    % --- Splitter (middle) ---
    app.SOHistogramsSplitter = uipanel(app.SOHistogramsGrid, ...
        'BackgroundColor', [0.78 0.78 0.78], ...
        'BorderType',      'none', ...
        'Tooltip',         'Drag to resize channel selector', ...
        'ButtonDownFcn',   @(s,e) app.startDragSOHistogramsSplitter());
    app.SOHistogramsSplitter.Layout.Row    = 1;
    app.SOHistogramsSplitter.Layout.Column = 2;

    % --- Inner tab group (right): Mean SOPH | Mode Scatter ---
    app.AggregateViewsTabGroup = uitabgroup(app.SOHistogramsGrid);
    app.AggregateViewsTabGroup.Layout.Row    = 1;
    app.AggregateViewsTabGroup.Layout.Column = 3;

    % --- Mean SOPH tab ---
    app.MeanSOPHTab       = uitab(app.AggregateViewsTabGroup);
    app.MeanSOPHTab.Title = 'Mean SOPH';

    meanSOPHGrid             = uigridlayout(app.MeanSOPHTab);
    meanSOPHGrid.ColumnWidth = {'1x'};
    meanSOPHGrid.RowHeight   = {'1x'};
    meanSOPHGrid.Padding     = [0 0 0 0];

    app.SOHistogramsPlotPanel = uipanel(meanSOPHGrid, ...
        'BackgroundColor','white', ...
        'BorderType','none');
    app.SOHistogramsPlotPanel.Layout.Row    = 1;
    app.SOHistogramsPlotPanel.Layout.Column = 1;

    app.SOHistogramsPlaceholderAxes = uiaxes(app.SOHistogramsPlotPanel, ...
        'Units','normalized', ...
        'Position',[0 0 1 1], ...
        'BackgroundColor','white');
    axis(app.SOHistogramsPlaceholderAxes,'off');
    text(app.SOHistogramsPlaceholderAxes, 0.5, 0.5, ...
        'Select one or more channels on the left', ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'Color',[0.5 0.5 0.5]);

    % --- Mode Scatter tab: dropdown row (Power | Phase) + plot panel ---
    app.ModeScatterTab       = uitab(app.AggregateViewsTabGroup);
    app.ModeScatterTab.Title = 'Mode Scatter';

    modeGrid             = uigridlayout(app.ModeScatterTab);
    modeGrid.ColumnWidth = {'1x'};
    modeGrid.RowHeight   = {110, '1x'};
    modeGrid.RowSpacing  = 5;
    modeGrid.Padding     = [5 5 5 5];

    % Dropdown row layout:
    %   col 1 = row labels ("Power" / "Phase")
    %   cols 2-5 = X / Y / Size / Color dropdowns
    %   col 6   = Colormap (free-text CSSuiEditField, e.g. 'hsv', 'jet')
    %   headers in row 1, controls on row 2 (Power) and row 3 (Phase).
    app.ModeScatterDropdownGrid               = uigridlayout(modeGrid);
    app.ModeScatterDropdownGrid.ColumnWidth   = {78,'1x','1x','1x','1x','1x'};
    app.ModeScatterDropdownGrid.RowHeight     = {18, 36, 36};
    app.ModeScatterDropdownGrid.RowSpacing    = 4;
    app.ModeScatterDropdownGrid.ColumnSpacing = 8;
    app.ModeScatterDropdownGrid.Padding       = [0 0 0 0];
    app.ModeScatterDropdownGrid.Layout.Row    = 1;
    app.ModeScatterDropdownGrid.Layout.Column = 1;

    headers = {'X','Y','Size','Color','Colormap'};
    for cc = 1:numel(headers)
        L = CSSuiLabel(app.ModeScatterDropdownGrid, ...
            'Style', app.AppStyle, 'FontSize','12px', 'Text', headers{cc});
        L.Layout.Row = 1; L.Layout.Column = cc + 1;
    end
    powerLabel = CSSuiLabel(app.ModeScatterDropdownGrid, ...
        'Style', app.AppStyle, 'FontSize','13px', 'Text','Power');
    powerLabel.Layout.Row = 2; powerLabel.Layout.Column = 1;
    phaseLabel = CSSuiLabel(app.ModeScatterDropdownGrid, ...
        'Style', app.AppStyle, 'FontSize','13px', 'Text','Phase');
    phaseLabel.Layout.Row = 3; phaseLabel.Layout.Column = 1;

    cbPow = @(s,e) onModeScatterDropDownChanged(app, 'power');
    cbPha = @(s,e) onModeScatterDropDownChanged(app, 'phase');
    [app.ModeScatterPowerXDropDown, ...
     app.ModeScatterPowerYDropDown, ...
     app.ModeScatterPowerSizeDropDown, ...
     app.ModeScatterPowerColorDropDown] = ...
        local_addDropdownRow(app, app.ModeScatterDropdownGrid, 2, cbPow);
    [app.ModeScatterPhaseXDropDown, ...
     app.ModeScatterPhaseYDropDown, ...
     app.ModeScatterPhaseSizeDropDown, ...
     app.ModeScatterPhaseColorDropDown] = ...
        local_addDropdownRow(app, app.ModeScatterDropdownGrid, 3, cbPha);

    % Per-axis colormap free-text fields (col 6, rows 2 and 3). Triggers
    % the same redraw path as the four dropdowns so changes apply
    % immediately. Empty / unrecognized names fall back to parula.
    app.ModeScatterColormapPowerField = CSSuiEditField(app.ModeScatterDropdownGrid, ...
        'Style', app.AppStyle, ...
        'Value', app.ModeScatterColormapPower_, ...
        'ValueChangedFcn', @(s,e) onModeScatterColormapChanged_(app, 'power', e.Value));
    app.ModeScatterColormapPowerField.Layout.Row    = 2;
    app.ModeScatterColormapPowerField.Layout.Column = 6;

    app.ModeScatterColormapPhaseField = CSSuiEditField(app.ModeScatterDropdownGrid, ...
        'Style', app.AppStyle, ...
        'Value', app.ModeScatterColormapPhase_, ...
        'ValueChangedFcn', @(s,e) onModeScatterColormapChanged_(app, 'phase', e.Value));
    app.ModeScatterColormapPhaseField.Layout.Row    = 3;
    app.ModeScatterColormapPhaseField.Layout.Column = 6;

    % Plot panel: stable uipanel; redrawModeScatter replaces children
    % with one (axPower, axPhase) pair per selected channel using
    % buildPairGrid's normalized-position layout.
    app.ModeScatterPlotPanel = uipanel(modeGrid, ...
        'BackgroundColor','white', ...
        'BorderType','none');
    app.ModeScatterPlotPanel.Layout.Row    = 2;
    app.ModeScatterPlotPanel.Layout.Column = 1;

    app.ModeScatterPlaceholderAxes = uiaxes(app.ModeScatterPlotPanel, ...
        'Units','normalized', ...
        'Position',[0 0 1 1], ...
        'BackgroundColor','white');
    axis(app.ModeScatterPlaceholderAxes,'off');
    text(app.ModeScatterPlaceholderAxes, 0.5, 0.5, ...
        'Select one or more channels on the left', ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'Color',[0.5 0.5 0.5]);

    % Initialize the cache once. Cleared in updateAggregateDataTabVisibility
    % whenever forceRefresh fires (post-aggregate, transitions, etc.).
    app.ModeScatter_TableCache_ = containers.Map( ...
        'KeyType','char','ValueType','any');
end


function onModeScatterColormapChanged_(app, kind, newValue)
    % onModeScatterColormapChanged_  Persist the new colormap name and
    % route through the in-place updater so layout doesn't churn.
    nm = strtrim(char(newValue));
    switch kind
        case 'power', app.ModeScatterColormapPower_ = nm;
        case 'phase', app.ModeScatterColormapPhase_ = nm;
    end
    app.updateModeScatterData();
end


function [xDD, yDD, sDD, cDD] = local_addDropdownRow(app, parent, gridRow, cb)
    % local_addDropdownRow  Place X/Y/Size/Color dropdowns into one
    %   row of the Mode Scatter dropdown grid (cols 2..5). All four
    %   share the same ValueChangedFcn so the renderer redraws the
    %   axis they belong to.
    xDD = CSSuiDropdown(parent, 'Style', app.AppStyle, ...
        'Items', {'(none)'}, 'ValueChangedFcn', cb);
    xDD.Layout.Row = gridRow; xDD.Layout.Column = 2;
    yDD = CSSuiDropdown(parent, 'Style', app.AppStyle, ...
        'Items', {'(none)'}, 'ValueChangedFcn', cb);
    yDD.Layout.Row = gridRow; yDD.Layout.Column = 3;
    sDD = CSSuiDropdown(parent, 'Style', app.AppStyle, ...
        'Items', {'(none)'}, 'ValueChangedFcn', cb);
    sDD.Layout.Row = gridRow; sDD.Layout.Column = 4;
    cDD = CSSuiDropdown(parent, 'Style', app.AppStyle, ...
        'Items', {'(none)'}, 'ValueChangedFcn', cb);
    cDD.Layout.Row = gridRow; cDD.Layout.Column = 5;
end
