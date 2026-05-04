function createResultsBrowserPreviewProgress(app, prefix, total)
    % createResultsBrowserPreviewProgress  Replace the preview body
    %   with a fresh CSSuicontrols SmoothProgressBar configured for
    %   one aggregation stage (N = total files). Called at the
    %   start of every (category, stage) pair so each pass gets
    %   its own browser-side animation cycle (rAF timing, ETA,
    %   colormap-fill — all native to SmoothProgressBar).
    delete(app.ResultsBrowserPreviewBody.Children);
    app.PreviewProgressBar_  = [];
    if total <= 0, return, end

    % Two-row layout: a fixed-pixel row hosts the bar with the
    % same proportions as the batch run progress bar at the
    % bottom of the window (createBottomBar.m: BarHeight=0.35,
    % pill BorderRadius). The remaining row is empty so the bar
    % sits near the top of the preview pane and doesn't stretch
    % vertically across the entire preview area.
    g = uigridlayout(app.ResultsBrowserPreviewBody, [2 1]);
    g.Padding     = [24 24 24 24];
    g.RowHeight   = {80, '1x'};
    g.ColumnWidth = {'1x'};
    pb = SmoothProgressBar(g, total, ...
        'BarHeight',       0.35, ...
        'BarBorderRadius', '999px', ...
        'BorderRadius',    '999px', ...
        'TextPosition',    'above');
    pb.Layout.Row    = 1;
    pb.Layout.Column = 1;
    pb.LabelPrefix       = prefix;
    pb.ShowPercentage    = true;
    pb.ShowTimeRemaining = true;
    pb.start();
    app.PreviewProgressBar_  = pb;
end
