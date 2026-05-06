function startResultsBrowserColumnResize(app)
    % Mouse-down on the splitter — capture figure-level motion/up
    % callbacks and set a hand cursor while the drag is active.
    fig = app.UIFigure;
    pos = fig.CurrentPoint;        % [x y] in pixels, fig-relative
    % Resolve current column 1 width into an absolute pixel value.
    leftPos = getpixelposition(app.ResultsLeftGrid, true);
    rightPos = getpixelposition(app.ResultsBrowserPreviewGrid, true);
    startW1   = leftPos(3);
    totalW    = startW1 + rightPos(3);

    app.ResultsSplitterDrag_.active      = true;
    app.ResultsSplitterDrag_.startX      = pos(1);
    app.ResultsSplitterDrag_.startW1     = startW1;
    app.ResultsSplitterDrag_.totalW      = totalW;
    app.ResultsSplitterDrag_.origMotion  = fig.WindowButtonMotionFcn;
    app.ResultsSplitterDrag_.origUp      = fig.WindowButtonUpFcn;
    app.ResultsSplitterDrag_.origPointer = fig.Pointer;

    fig.Pointer              = 'left';
    fig.WindowButtonMotionFcn = @(~,~) app.dragResultsBrowserColumnResize();
    fig.WindowButtonUpFcn     = @(~,~) app.endResultsBrowserColumnResize();
end
