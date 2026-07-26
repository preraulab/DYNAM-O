function linkModeScatterAxes(app, powerAxes, phaseAxes)
    % linkModeScatterAxes  Tie together the X/Y/Z limits and the
    %   camera view across same-kind axes (so panning, zooming, and
    %   3-D rotation on one channel mirror to all the others). Power
    %   and phase are linked separately — they have different units
    %   on every axis so cross-kind linking would be wrong.
    %
    %   The returned linkprop objects MUST be retained — the link
    %   exists only while the handle is alive — so we stash them on
    %   app.ModeScatter_Links_. Each call replaces the previous
    %   stash; the old objects fall out of scope and the old links
    %   die naturally with them.
    props = {'XLim','YLim','ZLim', ...
             'View','CameraPosition','CameraTarget', ...
             'CameraUpVector','CameraViewAngle'};

    s = struct('power', [], 'phase', []);
    if numel(powerAxes) > 1
        s.power = linkprop(powerAxes, props);
    end
    if numel(phaseAxes) > 1
        s.phase = linkprop(phaseAxes, props);
    end
    app.ModeScatter_Links_ = s;
end
