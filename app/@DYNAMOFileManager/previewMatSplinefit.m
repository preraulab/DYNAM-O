function previewMatSplinefit(app, p, names)
    % previewMatSplinefit  Render a per-subject splinefit .mat:
    % a tab group with the fitted SOPH model image and a text
    % dump of the spline coefficients/knots. `names` is the list
    % of top-level variables in the file (from whos).
    varName = '';
    for n = names
        if endsWith(n{1}, '_splinefit'), varName = n{1}; break, end
    end
    S = load(p, varName);
    SF = S.(varName);

    tg = uitabgroup(app.ResultsBrowserPreviewBody, ...
        'Units','normalized','Position',[0 0 1 1]);

    if isfield(SF, 'splinefit') && ~isempty(SF.splinefit)
        tS = uitab(tg, 'Title','splinefit');
        axS = uiaxes(tS, 'Units','normalized','Position',[0 0 1 1], ...
            'BackgroundColor','white');
        % Same canonical SOPH rendering as the parametric preview —
        % gives the spline fit real frequency / SO-axis values
        % instead of bin indices.
        if startsWith(varName, 'SOpower'), axis_kind = 'power';
        else,                              axis_kind = 'phase';
        end
        [freq_bins, so_bins] = app.binsForParamfit(SF, p, axis_kind);
        app.styleSOPHAxes(axS, SF.splinefit, freq_bins, so_bins, axis_kind);
        title(axS, 'Spline-fitted SOPH');
    end

    tI = uitab(tg, 'Title','knots / coefs');
    ta = app.createFillTextArea(tI);
    lines = {};
    for fld = {'knots_x','knots_y','coefs','spline_obj'}
        if isfield(SF, fld{1})
            lines = [lines; {sprintf('--- %s ---', fld{1})}; ...
                splitlines(string(evalc('disp(SF.(fld{1}))')))]; %#ok<AGROW>
        end
    end
    ta.Value = cellstr(lines);
end
