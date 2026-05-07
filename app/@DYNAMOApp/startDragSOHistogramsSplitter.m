function startDragSOHistogramsSplitter(app)
    % startDragSOHistogramsSplitter  ButtonDownFcn target for
    %   the thin uipanel between the channel listbox and the
    %   inner tab group. Stashes the figure's existing
    %   WindowButtonMotion / Up callbacks, installs our own
    %   for the duration of the drag, and restores them on
    %   mouse-up so other figure-level handlers aren't
    %   clobbered.
    if isempty(app.SOHistogramsGrid) || isempty(app.SOHistogramsSplitter)
        return
    end
    app.SOHistogramsSplitter_Drag_ = struct( ...
        'motion', app.UIFigure.WindowButtonMotionFcn, ...
        'up',     app.UIFigure.WindowButtonUpFcn);
    app.UIFigure.WindowButtonMotionFcn = @(s,e) app.dragSOHistogramsSplitter();
    app.UIFigure.WindowButtonUpFcn     = @(s,e) app.endDragSOHistogramsSplitter();
end
