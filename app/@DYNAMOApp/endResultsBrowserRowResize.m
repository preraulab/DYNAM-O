function endResultsBrowserRowResize(app)
    % endResultsBrowserRowResize  Mouse-up handler that releases the row
    % splitter — restores the figure's prior motion / up
    % callbacks and pointer style.
    fig = app.UIFigure;
    fig.WindowButtonMotionFcn = app.ResultsRowSplitterDrag_.origMotion;
    fig.WindowButtonUpFcn     = app.ResultsRowSplitterDrag_.origUp;
    fig.Pointer               = app.ResultsRowSplitterDrag_.origPointer;
    app.ResultsRowSplitterDrag_.active = false;
end
