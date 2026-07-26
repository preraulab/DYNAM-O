function startResultsBrowserRowResize(app)
    % Mouse-down on the horizontal splitter — capture motion/up
    % so the user can drag the tree/status height boundary.
    fig    = app.UIFigure;
    pos    = fig.CurrentPoint;
    % CSSuiTree is a wrapper class, not a graphics handle — use
    % its underlying uihtml component for getpixelposition.
    treeP  = getpixelposition(app.ResultsBrowserTree.HTMLComponent, true);
    statP  = getpixelposition(app.ResultsBrowserStatusGrid, true);
    startH = treeP(4);
    totalH = startH + statP(4);

    app.ResultsRowSplitterDrag_.active      = true;
    app.ResultsRowSplitterDrag_.startY      = pos(2);
    app.ResultsRowSplitterDrag_.startH1     = startH;
    app.ResultsRowSplitterDrag_.totalH      = totalH;
    app.ResultsRowSplitterDrag_.origMotion  = fig.WindowButtonMotionFcn;
    app.ResultsRowSplitterDrag_.origUp      = fig.WindowButtonUpFcn;
    app.ResultsRowSplitterDrag_.origPointer = fig.Pointer;

    fig.Pointer               = 'top';
    fig.WindowButtonMotionFcn = @(~,~) app.dragResultsBrowserRowResize();
    fig.WindowButtonUpFcn     = @(~,~) app.endResultsBrowserRowResize();
end
