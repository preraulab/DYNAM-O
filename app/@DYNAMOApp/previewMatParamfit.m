function previewMatParamfit(app, p, names)
    % paramfit struct: params (table) + model_SOPH (2D) + wshed_img (RGB)
    varName = '';
    for n = names
        if endsWith(n{1}, '_paramfit'), varName = n{1}; break, end
    end
    if isempty(varName)
        app.renderResultsBrowserPreviewMessage('paramfit variable missing.');
        return
    end
    S = load(p, varName);
    PF = S.(varName);

    % Decide axis kind from the variable name for SOPH-style rendering.
    if startsWith(varName, 'SOpower'), axis_kind = 'power';
    else,                              axis_kind = 'phase';
    end

    tg = uitabgroup(app.ResultsBrowserPreviewBody, ...
        'Units','normalized','Position',[0 0 1 1]);

    % --- params table ---
    if isfield(PF, 'params') && istable(PF.params)
        tT = uitab(tg, 'Title', sprintf('params (%d×%d)', ...
            height(PF.params), width(PF.params)));
        ut = uitable(tT);
        ut.Units = 'normalized'; ut.Position = [0 0 1 1];
        ut.Data = PF.params; ut.ColumnSortable = true;
    end

    % --- model SOPH heatmap ---
    % Reuse the canonical SOPHs rendering (styleSOPHAxes) so the
    % parametric model gets the same transpose, colormap, freq
    % window, robust color limits, and binned axes as the per-
    % subject SOPHs view. Without this the imagesc came out with
    % integer bin indices instead of actual frequency / SO-axis
    % values, which made comparing the parametric model to the
    % data SOPH visually impossible.
    if isfield(PF, 'model_SOPH') && ~isempty(PF.model_SOPH)
        tM = uitab(tg, 'Title','model SOPH');
        axM = uiaxes(tM, 'Units','normalized','Position',[0 0 1 1], ...
            'BackgroundColor','white');
        [freq_bins, so_bins] = app.binsForParamfit(PF, p, axis_kind);
        % model_SOPH comes from meshgrid(so_bins, freq_bins), so it
        % is [Nfreq × Nso]. styleSOPHAxes expects [Nso × Nfreq] —
        % transpose to match.
        app.styleSOPHAxes(axM, PF.model_SOPH.', freq_bins, so_bins, axis_kind);
        title(axM, 'Parametric model SOPH');
    end

    % --- watershed RGB ---
    if isfield(PF, 'wshed_img') && ~isempty(PF.wshed_img)
        tW = uitab(tg, 'Title','watershed');
        axW = uiaxes(tW, 'Units','normalized','Position',[0 0 1 1], ...
            'BackgroundColor','white');
        imshow(PF.wshed_img, 'Parent', axW);
        title(axW, 'Watershed segmentation');
    end

    % --- gof / fitobj summary ---
    if isfield(PF, 'gof') || isfield(PF, 'fitobj')
        tG = uitab(tg, 'Title','fit info');
        ta = app.createFillTextArea(tG);
        lines = {};
        if isfield(PF, 'gof')
            lines = [lines; {'--- gof ---'}; ...
                splitlines(string(evalc('disp(PF.gof)')))];
        end
        if isfield(PF, 'fitobj')
            lines = [lines; {''; '--- fitobj ---'}; ...
                splitlines(string(evalc('disp(PF.fitobj)')))];
        end
        ta.Value = cellstr(lines);
    end
end
