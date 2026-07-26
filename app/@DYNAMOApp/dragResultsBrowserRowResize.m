function dragResultsBrowserRowResize(app)
    % dragResultsBrowserRowResize  Mouse-motion handler while dragging the
    % horizontal splitter between the tree (rows 1-5) and the
    % status pane (row 7). Live-updates ResultsLeftGrid.RowHeight
    % with clamped heights for both panes.
    if ~app.ResultsRowSplitterDrag_.active, return, end
    fig    = app.UIFigure;
    pos    = fig.CurrentPoint;
    % Figure y grows upward; dragging the splitter UP shrinks the
    % tree (above) and grows the status (below). The startY is
    % captured at click; positive dy (cursor above start) means
    % the splitter has moved up, so tree height should decrease.
    dy     = pos(2) - app.ResultsRowSplitterDrag_.startY;
    startH = app.ResultsRowSplitterDrag_.startH1;
    total  = app.ResultsRowSplitterDrag_.totalH;
    minH   = 80;
    newH1  = min(max(startH - dy, minH), total - minH);
    newH2  = max(total - newH1, minH);
    rh = app.ResultsLeftGrid.RowHeight;
    rh{5} = newH1;
    rh{7} = newH2;
    app.ResultsLeftGrid.RowHeight = rh;
end
