function dragSOHistogramsSplitter(app)
    % dragSOHistogramsSplitter  Recompute column 1 width from
    %   cursor position (relative to the SOHistogramsGrid),
    %   clamped to a sane min/max so the listbox can never
    %   eat the plot area or vanish entirely. The grid keeps
    %   the splitter at its fixed 6 px and the right column
    %   at '1x'.
    try
        gridPos = getpixelposition(app.SOHistogramsGrid, true);
        cp = app.UIFigure.CurrentPoint;
        relX = cp(1) - gridPos(1);

        splitterW = 6;
        minW   = 100;
        maxW   = max(minW + 1, gridPos(3) - splitterW - 200);
        newW   = round(max(minW, min(maxW, relX)));

        app.SOHistogramsGrid.ColumnWidth = {newW, splitterW, '1x'};
    catch
        % If the layout is mid-rebuild (e.g. tab detach), bail
        % out quietly and let endDrag clean up.
    end
end
