function dragResultsBrowserColumnResize(app)
    % dragResultsBrowserColumnResize  Mouse-motion handler while dragging the
    % vertical splitter between the tree column and the preview
    % column. Updates BrowserContentContainer.ColumnWidth in
    % real time, clamping each side to a minimum width.
    if ~app.ResultsSplitterDrag_.active, return, end
    fig    = app.UIFigure;
    pos    = fig.CurrentPoint;
    dx     = pos(1) - app.ResultsSplitterDrag_.startX;
    startW = app.ResultsSplitterDrag_.startW1;
    total  = app.ResultsSplitterDrag_.totalW;
    minW   = 120;        % don't let either side collapse below this
    newW1  = min(max(startW + dx, minW), total - minW);
    newW2  = max(total - newW1, minW);
    app.BrowserContentContainer.ColumnWidth = {newW1, 6, newW2};
end
