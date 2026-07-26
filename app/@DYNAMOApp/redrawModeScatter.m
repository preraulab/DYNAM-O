function redrawModeScatter(app)
    % redrawModeScatter  Full-rebuild path: replace ModeScatterPlotPanel
    %   children with one (axPower, axPhase) pair per selected channel,
    %   laid out via buildPairGrid. Each axis is rendered by
    %   renderModeScatterAxis. Caches the axis pairs in
    %   app.ModeScatter_AxState_ so dropdown / colormap edits can
    %   update data in place via updateModeScatterData (no layout
    %   churn).
    panelH = app.ModeScatterPlotPanel;
    delete(panelH.Children);
    app.ModeScatter_AxState_ = struct('sel', {{}}, 'pairs', {{}});

    sel = app.SOHistogramsChannelListBox.Value;
    if ischar(sel) || isstring(sel), sel = cellstr(sel); end
    sel = sel(~startsWith(sel, '(no data) '));
    n = numel(sel);
    if n == 0
        phAx = uiaxes(panelH, ...
            'Units','normalized', 'Position',[0 0 1 1], ...
            'BackgroundColor','white');
        axis(phAx, 'off');
        text(phAx, 0.5, 0.5, ...
            'Select one or more channels on the left', ...
            'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
            'Color',[0.5 0.5 0.5]);
        app.ModeScatterPlaceholderAxes = phAx;
        return
    end

    pairs = app.buildPairGrid(panelH, sel);

    powerAxes = gobjects(0);
    phaseAxes = gobjects(0);
    for ii = 1:n
        ch   = sel{ii};
        axP  = pairs{ii}(1);
        axPh = pairs{ii}(2);
        if app.renderModeScatterAxis(axP,  ch, 'power')
            powerAxes(end+1) = axP; %#ok<AGROW>
        end
        if app.renderModeScatterAxis(axPh, ch, 'phase')
            phaseAxes(end+1) = axPh; %#ok<AGROW>
        end
    end

    applySharedLimits_(app, sel, powerAxes, phaseAxes);
    app.linkModeScatterAxes(powerAxes, phaseAxes);

    % Cache for in-place updates. updateModeScatterData revalidates
    % these handles before reusing.
    app.ModeScatter_AxState_ = struct('sel', {sel}, 'pairs', {pairs});
end


function applySharedLimits_(app, sel, powerAxes, phaseAxes)
    % Pre-compute shared X/Y limits per axis kind so all scatter axes
    % line up. Mirrors the SOPH display ranges (frequency 2-16 Hz,
    % SO-power matches SOpower_bins, SO-phase = [-pi, pi]).
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
end
