function endResultsBrowserColumnResize(app)
    % endResultsBrowserColumnResize  Mouse-up handler that releases the column
    % splitter — restores the figure's original motion / up
    % callbacks and pointer style.
    fig = app.UIFigure;
    fig.WindowButtonMotionFcn = app.ResultsSplitterDrag_.origMotion;
    fig.WindowButtonUpFcn     = app.ResultsSplitterDrag_.origUp;
    fig.Pointer               = app.ResultsSplitterDrag_.origPointer;
    app.ResultsSplitterDrag_.active = false;
end
