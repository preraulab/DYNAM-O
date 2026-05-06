function redrawModeScatter(app)
    % redrawModeScatter  Replace ModeScatterPlotPanel children
    %   with one (axPower, axPhase) pair per selected channel,
    %   laid out via buildPairGrid. Each half is rendered by
    %   the local renderScatter helper using its axis-specific
    %   X/Y/Size/Color dropdowns. Missing aggregates / missing
    %   columns fall through to per-cell text overlays so the
    %   other half still draws.
    panelH = app.ModeScatterPlotPanel;
    delete(panelH.Children);

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

    % Pre-compute shared X/Y limits per axis kind so all
    % scatter axes line up with each other and with the SOPH
    % display ranges (frequency 2-16 Hz, SO-power matches
    % SOpower_bins range, SO-phase = [-pi, pi]).
    [xLimP, yLimP] = app.computeScatterLims(sel, 'power');
    [xLimPh, yLimPh] = app.computeScatterLims(sel, 'phase');

    powerAxes = gobjects(0);
    phaseAxes = gobjects(0);
    for ii = 1:n
        ch   = sel{ii};
        axP  = pairs{ii}(1);
        axPh = pairs{ii}(2);
        if renderScatter(axP,  ch, 'power')
            powerAxes(end+1) = axP; %#ok<AGROW>
        end
        if renderScatter(axPh, ch, 'phase')
            phaseAxes(end+1) = axPh; %#ok<AGROW>
        end
    end

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

    function ok = renderScatter(ax, channelName, axisKind)
        ok = false;
        [xDD, yDD, sDD, cDD] = app.modeScatterDropdowns(axisKind);
        xCol     = char(xDD.Value);
        yCol     = char(yDD.Value);
        sizeCol  = char(sDD.Value);
        colorCol = char(cDD.Value);

        T = app.loadParamfitAggregateForChannel(channelName, axisKind);
        if isempty(T) || ~istable(T)
            axis(ax, 'off');
            text(ax, 0.5, 0.5, ['(no SO' axisKind ' aggregate)'], ...
                'HorizontalAlignment','center');
            return
        end
        vn = T.Properties.VariableNames;
        if ~ismember(xCol, vn) || ~ismember(yCol, vn) ...
                || strcmp(xCol,'(none)') || strcmp(yCol,'(none)')
            axis(ax, 'off');
            text(ax, 0.5, 0.5, '(X/Y column not in this aggregate)', ...
                'HorizontalAlignment','center');
            return
        end
        x = T.(xCol);
        y = T.(yCol);
        if ~isnumeric(x) || ~isnumeric(y)
            axis(ax, 'off');
            text(ax, 0.5, 0.5, '(X/Y must be numeric)', ...
                'HorizontalAlignment','center');
            return
        end

        % Marker size: rescale to 16..144 pixels² when a
        % numeric Size column is picked; constant 36 otherwise.
        if ~strcmp(sizeCol, '(none)') && ismember(sizeCol, vn) ...
                && isnumeric(T.(sizeCol))
            sv = double(T.(sizeCol));
            sv(~isfinite(sv)) = NaN;
            if all(isnan(sv)) || min(sv) == max(sv)
                sz = 36;
            else
                sz = rescale(sv, 16, 144);
                sz(isnan(sz)) = 36;
            end
        else
            sz = 36;
        end

        % Color: numeric → continuous (default colormap);
        % categorical (e.g. 'ID') → group index → hsv;
        % '(none)' → uniform navy.
        if strcmp(colorCol, '(none)') || ~ismember(colorCol, vn)
            cv = repmat([0.20 0.40 0.80], numel(x), 1);
        else
            raw = T.(colorCol);
            if isnumeric(raw)
                cv = double(raw);
            else
                if iscell(raw) || isstring(raw)
                    [g, ~] = findgroups(string(raw));
                elseif iscategorical(raw)
                    [g, ~] = findgroups(raw);
                else
                    g = ones(numel(x),1);
                end
                ng = max(1, max(g));
                cmap = hsv(max(2, ng));
                cv = cmap(g, :);
            end
        end

        scatter(ax, x, y, sz, cv, 'filled', ...
            'MarkerEdgeColor', [0 0 0], 'LineWidth', 0.25);
        xlabel(ax, xCol, 'Interpreter','none');
        if strcmp(axisKind, 'power')
            ylabel(ax, yCol, 'Interpreter','none');
        end
        grid(ax, 'on');
        ok = true;
    end
end
