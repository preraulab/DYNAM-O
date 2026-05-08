function ok = renderModeScatterAxis(app, ax, channelName, axisKind)
    % renderModeScatterAxis  Draw one (channel, axisKind) scatter into
    %   the supplied uiaxes. Reads the current X/Y/Size/Color
    %   dropdowns plus the per-axis colormap edit-field. Returns true
    %   when a real scatter was drawn (callers use this to decide
    %   whether to apply shared XY limits afterwards).
    %
    %   Idempotent: cla(ax,'reset') before each draw so the same
    %   axes can be reused for in-place updates without leaking
    %   prior children (text overlays, stale colorbars, etc.).
    cla(ax, 'reset');
    ok = false;

    [xDD, yDD, sDD, cDD, zDD] = app.modeScatterDropdowns(axisKind);
    xCol     = char(xDD.Value);
    yCol     = char(yDD.Value);
    sizeCol  = char(sDD.Value);
    colorCol = char(cDD.Value);
    zCol     = char(zDD.Value);
    use3D    = ~strcmp(zCol, '(none)');

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
    if use3D
        if ~ismember(zCol, vn) || ~isnumeric(T.(zCol))
            % Selected Z column either vanished from this aggregate or
            % is non-numeric — silently degrade to 2-D rather than
            % erroring; the user can re-pick from the dropdown.
            use3D = false;
        else
            z = T.(zCol);
        end
    end

    % Marker size: rescale to 16..144 pixels² when a numeric Size
    % column is picked; constant 36 otherwise.
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

    % Color resolution: numeric column → continuous (per-axis user
    % colormap, default 'hsv'); categorical / cellstr → group index
    % through the same colormap; '(none)' → uniform navy.
    switch axisKind
        case 'power', cmapName = app.ModeScatterColormapPower_;
        case 'phase', cmapName = app.ModeScatterColormapPhase_;
        otherwise,    cmapName = 'hsv';
    end
    isContinuous = false;
    if strcmp(colorCol, '(none)') || ~ismember(colorCol, vn)
        cv = repmat([0.20 0.40 0.80], numel(x), 1);
    else
        raw = T.(colorCol);
        if isnumeric(raw)
            cv = double(raw);
            isContinuous = true;
        else
            if iscell(raw) || isstring(raw)
                [g, ~] = findgroups(string(raw));
            elseif iscategorical(raw)
                [g, ~] = findgroups(raw);
            else
                g = ones(numel(x),1);
            end
            ng   = max(1, max(g));
            cmap = resolveModeScatterColormap(cmapName, max(2, ng));
            cv   = cmap(g, :);
        end
    end

    if use3D
        scatter3(ax, x, y, z, sz, cv, 'filled', ...
            'MarkerEdgeColor', [0 0 0], 'LineWidth', 0.25);
        view(ax, 3);   % default 3-D azimuth/elevation; linkprop ties siblings
        zlabel(ax, zCol, 'Interpreter','none');
    else
        scatter(ax, x, y, sz, cv, 'filled', ...
            'MarkerEdgeColor', [0 0 0], 'LineWidth', 0.25);
        % Returning to 2-D: undo any aspect-ratio / camera state that
        % may have stuck through the linkprop or from a prior 3-D
        % render. cla(ax,'reset') clears most of this, but the linked
        % camera View can re-propagate from a sibling axis the moment
        % we re-link, so be explicit.
        view(ax, 2);
        axis(ax, 'normal');     % PlotBoxAspectRatio / DataAspectRatio → auto
    end
    if isContinuous
        cmap = resolveModeScatterColormap(cmapName, 256);
        colormap(ax, cmap);
        cb = colorbar(ax);
        cb.Label.String       = colorCol;
        cb.Label.Interpreter  = 'none';
        % Phase columns are angles in [-pi, pi]: snap colorbar limits
        % so 0 lines up at the colormap midpoint and ticks are labeled
        % in fractions of pi for readability.
        if is_phase_column_(colorCol)
            clim(ax, [-pi pi]);
            cb.Ticks      = [-pi -pi/2 0 pi/2 pi];
            cb.TickLabels = {'-\pi','-\pi/2','0','\pi/2','\pi'};
        end
    end
    xlabel(ax, xCol, 'Interpreter','none');
    if strcmp(axisKind, 'power')
        ylabel(ax, yCol, 'Interpreter','none');
    end
    grid(ax, 'on');
    ok = true;
end


function tf = is_phase_column_(name)
    % Heuristic: column maps to a [-pi, pi] phase angle.
    nm = lower(name);
    tf = startsWith(nm, 'prefphase') || ...
         strcmp(nm, 'sophasemean') || strcmp(nm, 'sophase');
end


function cmap = resolveModeScatterColormap(name, n)
    % Look up a colormap by name (e.g. 'jet', 'hsv', 'parula',
    % 'gouldian', 'magma', 'viridis'). Falls back to parula on any
    % failure so a typo'd name never breaks the plot.
    cmap = [];
    nm   = strtrim(char(name));
    if ~isempty(nm)
        try
            tmp = feval(nm, n);
            if isnumeric(tmp) && size(tmp, 2) == 3 && size(tmp, 1) >= 2
                cmap = tmp;
            end
        catch
        end
    end
    if isempty(cmap), cmap = parula(n); end
end
