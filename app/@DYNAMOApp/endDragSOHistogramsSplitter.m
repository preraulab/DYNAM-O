function endDragSOHistogramsSplitter(app)
    % endDragSOHistogramsSplitter  Restore the figure's
    %   WindowButton callbacks captured at drag start. After a
    %   resize the right-side panels need a redraw so axes
    %   inside them reflow to the new pixel size.
    if isstruct(app.SOHistogramsSplitter_Drag_)
        app.UIFigure.WindowButtonMotionFcn = app.SOHistogramsSplitter_Drag_.motion;
        app.UIFigure.WindowButtonUpFcn     = app.SOHistogramsSplitter_Drag_.up;
    else
        app.UIFigure.WindowButtonMotionFcn = '';
        app.UIFigure.WindowButtonUpFcn     = '';
    end
    app.SOHistogramsSplitter_Drag_ = [];
end
