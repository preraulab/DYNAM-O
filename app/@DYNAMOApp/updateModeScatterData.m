function updateModeScatterData(app)
    % updateModeScatterData  In-place refresh path for the Mode Scatter
    %   panel: reuse the (axPower, axPhase) pairs cached by the most
    %   recent redrawModeScatter and re-render scatter contents on
    %   them via renderModeScatterAxis. Avoids the layout churn of
    %   delete+rebuild when only a dropdown or colormap edit changed.
    %
    %   Falls back to redrawModeScatter on cache miss or when any
    %   cached axes handle has been deleted (e.g. user switched
    %   tabs and the panel was rebuilt by some other path).

    state = app.ModeScatter_AxState_;
    if isempty(state) || ~isstruct(state) || ~isfield(state,'pairs') ...
            || isempty(state.pairs)
        app.redrawModeScatter();
        return
    end
    sel   = state.sel;
    pairs = state.pairs;

    % Channel selection must still match what we cached. If the user
    % added/removed a channel, the pair count is wrong → full rebuild.
    cur = app.SOHistogramsChannelListBox.Value;
    if ischar(cur) || isstring(cur), cur = cellstr(cur); end
    cur = cur(~startsWith(cur, '(no data) '));
    if ~isequal(sel, cur)
        app.redrawModeScatter();
        return
    end

    % Validate every cached axes handle. Any stale one → full rebuild.
    for ii = 1:numel(pairs)
        h = pairs{ii};
        if numel(h) ~= 2 || ~all(isgraphics(h))
            app.redrawModeScatter();
            return
        end
    end

    powerAxes = gobjects(0);
    phaseAxes = gobjects(0);
    for ii = 1:numel(sel)
        axP  = pairs{ii}(1);
        axPh = pairs{ii}(2);
        if app.renderModeScatterAxis(axP,  sel{ii}, 'power')
            powerAxes(end+1) = axP; %#ok<AGROW>
        end
        if app.renderModeScatterAxis(axPh, sel{ii}, 'phase')
            phaseAxes(end+1) = axPh; %#ok<AGROW>
        end
    end

    [xLimP,  yLimP]  = app.computeScatterLims(sel, 'power');
    [xLimPh, yLimPh] = app.computeScatterLims(sel, 'phase');
    for ax = powerAxes(:).'
        if ~isempty(xLimP), xlim(ax, xLimP); end
        if ~isempty(yLimP), ylim(ax, yLimP); end
    end
    for ax = phaseAxes(:).'
        if ~isempty(xLimPh)
            xlim(ax, xLimPh);
            if isequal(xLimPh, [-pi pi])
                xticks(ax, [-pi -pi/2 0 pi/2 pi]);
                xticklabels(ax, {'-\pi','-\pi/2','0','\pi/2','\pi'});
            end
        end
        if ~isempty(yLimPh), ylim(ax, yLimPh); end
    end

    % Re-establish the linkprop bindings. We're reusing the same axes
    % handles so the previous link object is still valid in principle,
    % but each render flips axes between 2-D and 3-D and replaces the
    % scatter object — re-linking is cheap and ensures view/camera
    % syncing covers any axis that just transitioned to scatter3.
    app.linkModeScatterAxes(powerAxes, phaseAxes);
end
