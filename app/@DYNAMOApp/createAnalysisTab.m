function createAnalysisTab(app)
    %createAnalysisTab  Build the Aggregate Data tab. Channel
    %   multi-select listbox sits at the top; below it is an inner
    %   tab group with two views:
    %     1. Mean SOPH    — per-channel mean power/phase histograms,
    %                       shown as power+phase pairs per channel
    %     2. Mode Scatter — paramfit mode scatter, also as
    %                       power+phase pairs per channel. Power and
    %                       phase have non-overlapping numeric columns
    %                       (e.g. PrefPhaseModel / SOphaseMean), so
    %                       each axis kind gets its own X/Y/Size/Color
    %                       dropdown group, both visible at once.
    %
    %   The Mode Scatter inner tab and the outer Aggregate Data tab
    %   are attached/detached at runtime by
    %   updateAggregateDataTabVisibility based on what aggregate data
    %   is present under the current results root.

    % --- Top-level wrapper: metadata bar (row 1) + content (row 2) ---
    %     Wrapping the existing 3-column SOHistogramsGrid in a parent
    %     keeps the metadata picker out of the splittable region so
    %     resizing the channel column doesn't squish the path field.
    analysisTabGrid               = uigridlayout(app.AnalysisTab);
    analysisTabGrid.ColumnWidth   = {'1x'};
    analysisTabGrid.RowHeight     = {32, '1x'};
    analysisTabGrid.RowSpacing    = 4;
    analysisTabGrid.Padding       = [0 0 0 0];

    % Metadata bar (mirrored to MetadataFileEditField in Batch Setup).
    metaBar               = uigridlayout(analysisTabGrid);
    metaBar.ColumnWidth   = {110, '1x', 96, 96};
    metaBar.RowHeight     = {'1x'};
    metaBar.ColumnSpacing = 6;
    metaBar.Padding       = [5 0 5 0];
    metaBar.Layout.Row    = 1;
    metaBar.Layout.Column = 1;

    metaLbl = CSSuiLabel(metaBar, 'Style', app.AppStyle, ...
        'FontSize','12.5px','FontWeight','700','Text','Metadata:');
    metaLbl.Layout.Row = 1; metaLbl.Layout.Column = 1;

    app.MetadataFileFieldAggregate = CSSuiEditField(metaBar, ...
        'Style', app.AppStyle, ...
        'Value', char(app.MetadataFile_), ...
        'ValueChangedFcn', @(s,e) app.setMetadataFile(e.Value));
    app.MetadataFileFieldAggregate.Layout.Row    = 1;
    app.MetadataFileFieldAggregate.Layout.Column = 2;

    app.MetadataBrowseButtonAggregate = CSSuiButton(metaBar, ...
        'Style', app.AppStyle, ...
        'Text', 'Browse...', ...
        'ButtonPushedFcn', @(s,e) app.pickMetadataFileViaDialog());
    app.MetadataBrowseButtonAggregate.Layout.Row    = 1;
    app.MetadataBrowseButtonAggregate.Layout.Column = 3;

    app.MetadataClearButtonAggregate = CSSuiButton(metaBar, ...
        'Style', app.AppStyle, ...
        'Text', 'Clear', ...
        'ButtonPushedFcn', @(s,e) app.setMetadataFile(''));
    app.MetadataClearButtonAggregate.Layout.Row    = 1;
    app.MetadataClearButtonAggregate.Layout.Column = 4;

    % --- Outer 3-column layout: selector on left | draggable splitter |
    %     inner tabgroup on right. SplitterWidth_ caches the col-2 size
    %     so the drag handler can recompute new col-1 width without
    %     re-reading the layout. The splitter is a thin uipanel whose
    %     ButtonDownFcn arms figure-level WindowButtonMotion / Up
    %     handlers for the duration of the drag.
    app.SOHistogramsGrid               = uigridlayout(analysisTabGrid);
    app.SOHistogramsGrid.ColumnWidth   = {180, 6, '1x'};
    app.SOHistogramsGrid.RowHeight     = {'1x'};
    app.SOHistogramsGrid.ColumnSpacing = 0;
    app.SOHistogramsGrid.Padding       = [5 5 5 5];
    app.SOHistogramsGrid.Layout.Row    = 2;
    app.SOHistogramsGrid.Layout.Column = 1;

    % --- Channel selector + Group-by panel (left) ---
    %     Rows 1-2: Channel listbox header + multiselect listbox (1x)
    %     Rows 3-4: Group-by label + dropdown
    %     Rows 5-6: Group-filter label + multiselect listbox (90px)
    app.SOHistogramsSelectorPanel             = uigridlayout(app.SOHistogramsGrid);
    app.SOHistogramsSelectorPanel.ColumnWidth = {'1x'};
    app.SOHistogramsSelectorPanel.RowHeight   = {18, '1x', 14, 28, 14, 90};
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

    % --- Group-by (row 3-4) ---
    gbLbl = CSSuiLabel(app.SOHistogramsSelectorPanel, ...
        'Style', app.AppStyle, ...
        'FontSize','12px', 'Text','Group by:');
    gbLbl.Layout.Row = 3; gbLbl.Layout.Column = 1;
    app.ModeScatterGroupByDropDown = CSSuiDropdown( ...
        app.SOHistogramsSelectorPanel, ...
        'Style', app.AppStyle, ...
        'Items', {'(none)'}, ...
        'Value', '(none)', ...
        'ValueChangedFcn', @(s,e) onGroupByChanged_(app));
    app.ModeScatterGroupByDropDown.Layout.Row    = 4;
    app.ModeScatterGroupByDropDown.Layout.Column = 1;

    % --- Group filter (row 5-6) ---
    gfLbl = CSSuiLabel(app.SOHistogramsSelectorPanel, ...
        'Style', app.AppStyle, ...
        'FontSize','12px', 'Text','Group filter:');
    gfLbl.Layout.Row = 5; gfLbl.Layout.Column = 1;
    app.ModeScatterGroupFilterListBox = CSSuiListBox( ...
        app.SOHistogramsSelectorPanel, ...
        'Style', app.AppStyle, ...
        'Multiselect', true, ...
        'Items', {}, ...
        'ValueChangedFcn', @(s,e) onGroupFilterChanged_(app));
    app.ModeScatterGroupFilterListBox.Layout.Row    = 6;
    app.ModeScatterGroupFilterListBox.Layout.Column = 1;

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
    %   cols 2-6 = X / Y / Z / Size / Color dropdowns
    %             Z defaults to '(none)' = 2-D scatter; setting Z to any
    %             numeric column flips that axis to scatter3.
    %   col 7   = Colormap (free-text CSSuiEditField, e.g. 'hsv', 'jet')
    %   headers in row 1, controls on row 2 (Power) and row 3 (Phase).
    app.ModeScatterDropdownGrid               = uigridlayout(modeGrid);
    app.ModeScatterDropdownGrid.ColumnWidth   = {78,'1x','1x','1x','1x','1x','1x'};
    app.ModeScatterDropdownGrid.RowHeight     = {18, 36, 36};
    app.ModeScatterDropdownGrid.RowSpacing    = 4;
    app.ModeScatterDropdownGrid.ColumnSpacing = 8;
    app.ModeScatterDropdownGrid.Padding       = [0 0 0 0];
    app.ModeScatterDropdownGrid.Layout.Row    = 1;
    app.ModeScatterDropdownGrid.Layout.Column = 1;

    headers = {'X','Y','Z','Size','Color','Colormap'};
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
     app.ModeScatterPowerZDropDown, ...
     app.ModeScatterPowerSizeDropDown, ...
     app.ModeScatterPowerColorDropDown] = ...
        local_addDropdownRow(app, app.ModeScatterDropdownGrid, 2, cbPow);
    [app.ModeScatterPhaseXDropDown, ...
     app.ModeScatterPhaseYDropDown, ...
     app.ModeScatterPhaseZDropDown, ...
     app.ModeScatterPhaseSizeDropDown, ...
     app.ModeScatterPhaseColorDropDown] = ...
        local_addDropdownRow(app, app.ModeScatterDropdownGrid, 3, cbPha);

    % Per-axis colormap free-text fields (col 7, rows 2 and 3). Triggers
    % the same redraw path as the dropdowns so changes apply
    % immediately. Empty / unrecognized names fall back to parula.
    app.ModeScatterColormapPowerField = CSSuiEditField(app.ModeScatterDropdownGrid, ...
        'Style', app.AppStyle, ...
        'Value', app.ModeScatterColormapPower_, ...
        'ValueChangedFcn', @(s,e) onModeScatterColormapChanged_(app, 'power', e.Value));
    app.ModeScatterColormapPowerField.Layout.Row    = 2;
    app.ModeScatterColormapPowerField.Layout.Column = 7;

    app.ModeScatterColormapPhaseField = CSSuiEditField(app.ModeScatterDropdownGrid, ...
        'Style', app.AppStyle, ...
        'Value', app.ModeScatterColormapPhase_, ...
        'ValueChangedFcn', @(s,e) onModeScatterColormapChanged_(app, 'phase', e.Value));
    app.ModeScatterColormapPhaseField.Layout.Row    = 3;
    app.ModeScatterColormapPhaseField.Layout.Column = 7;

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

    % --- Group Stats tab: two-group permutation tests via multicomp_test ---
    %     Hidden until metadata is loaded AND a Group-by column is picked
    %     AND exactly two values are selected in the Group-filter listbox.
    %     Two views stacked vertically:
    %       - Top: per-paramfit-column gpermtest table (FDR_1D corrected)
    %       - Bottom: per-pixel SOPH gpermtest map (FDR_2D corrected)
    app.GroupStatsTab       = uitab(app.AggregateViewsTabGroup);
    app.GroupStatsTab.Title = 'Group Stats';

    statsGrid               = uigridlayout(app.GroupStatsTab);
    statsGrid.ColumnWidth   = {'1x'};
    statsGrid.RowHeight     = {28, 90, 36, '1x'};
    statsGrid.RowSpacing    = 6;
    statsGrid.Padding       = [6 6 6 6];

    app.GroupStatsHintLabel = CSSuiLabel(statsGrid, ...
        'Style', app.AppStyle, ...
        'FontSize','12.5px', ...
        'Text', '');
    app.GroupStatsHintLabel.Layout.Row    = 1;
    app.GroupStatsHintLabel.Layout.Column = 1;

    % Run-stats button + summary line
    statsCtrlGrid               = uigridlayout(statsGrid);
    statsCtrlGrid.ColumnWidth   = {180, 180, '1x'};
    statsCtrlGrid.RowHeight     = {'1x'};
    statsCtrlGrid.ColumnSpacing = 8;
    statsCtrlGrid.Padding       = [0 0 0 0];
    statsCtrlGrid.Layout.Row    = 3;
    statsCtrlGrid.Layout.Column = 1;
    runScatterBtn = CSSuiButton(statsCtrlGrid, 'Style', app.AppStyle, ...
        'Text', 'Run scatter stats', ...
        'ButtonPushedFcn', @(s,e) app.runGroupStatsScatter());
    runScatterBtn.Layout.Row = 1; runScatterBtn.Layout.Column = 1;
    runSOPHBtn = CSSuiButton(statsCtrlGrid, 'Style', app.AppStyle, ...
        'Text', 'Run SOPH stats', ...
        'ButtonPushedFcn', @(s,e) app.runGroupStatsSOPH());
    runSOPHBtn.Layout.Row = 1; runSOPHBtn.Layout.Column = 2;

    app.GroupStatsScatterTable = uitable(statsGrid, ...
        'ColumnName', {'Column','Axis','tStat','p','p_adj','sig'}, ...
        'RowName', {});
    app.GroupStatsScatterTable.Layout.Row    = 2;
    app.GroupStatsScatterTable.Layout.Column = 1;

    app.GroupStatsSOPHPanel = uipanel(statsGrid, ...
        'BackgroundColor','white', ...
        'BorderType','none');
    app.GroupStatsSOPHPanel.Layout.Row    = 4;
    app.GroupStatsSOPHPanel.Layout.Column = 1;

    % Refresh hint visibility on tab show. Wired via the tabgroup
    % SelectionChangedFcn so we don't waste cycles when the user is on
    % a different inner tab.
    app.AggregateViewsTabGroup.SelectionChangedFcn = ...
        @(s,e) onAggregateViewsTabChanged_(app, e);
end


function onGroupByChanged_(app)
    % Group-by column changed → repopulate the filter listbox with the
    % new column's levels, then redraw both Mean SOPH and Mode Scatter.
    try, app.refreshGroupByControls(); catch, end
    try, app.redrawSOHistograms();     catch, end
    try, app.updateModeScatterData();  catch, end
    try, app.refreshGroupStatsHint();  catch, end
end


function onAggregateViewsTabChanged_(app, ~)
    try, app.refreshGroupStatsHint(); catch, end
end


function onGroupFilterChanged_(app)
    % Group-filter selection changed → no need to re-populate items;
    % just push the new filter through both renders.
    try, app.redrawSOHistograms();    catch, end
    try, app.updateModeScatterData(); catch, end
    try, app.refreshGroupStatsHint(); catch, end
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


function [xDD, yDD, zDD, sDD, cDD] = local_addDropdownRow(app, parent, gridRow, cb)
    % local_addDropdownRow  Place X/Y/Z/Size/Color dropdowns into one
    %   row of the Mode Scatter dropdown grid (cols 2..6). All five
    %   share the same ValueChangedFcn so the renderer redraws the
    %   axis they belong to. Z defaults to '(none)' which keeps the
    %   plot 2-D; setting it to a numeric column flips that axis to
    %   scatter3.
    xDD = CSSuiDropdown(parent, 'Style', app.AppStyle, ...
        'Items', {'(none)'}, 'ValueChangedFcn', cb);
    xDD.Layout.Row = gridRow; xDD.Layout.Column = 2;
    yDD = CSSuiDropdown(parent, 'Style', app.AppStyle, ...
        'Items', {'(none)'}, 'ValueChangedFcn', cb);
    yDD.Layout.Row = gridRow; yDD.Layout.Column = 3;
    zDD = CSSuiDropdown(parent, 'Style', app.AppStyle, ...
        'Items', {'(none)'}, 'ValueChangedFcn', cb);
    zDD.Layout.Row = gridRow; zDD.Layout.Column = 4;
    sDD = CSSuiDropdown(parent, 'Style', app.AppStyle, ...
        'Items', {'(none)'}, 'ValueChangedFcn', cb);
    sDD.Layout.Row = gridRow; sDD.Layout.Column = 5;
    cDD = CSSuiDropdown(parent, 'Style', app.AppStyle, ...
        'Items', {'(none)'}, 'ValueChangedFcn', cb);
    cDD.Layout.Row = gridRow; cDD.Layout.Column = 6;
end
