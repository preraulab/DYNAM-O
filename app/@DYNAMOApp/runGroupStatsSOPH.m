function runGroupStatsSOPH(app)
    % runGroupStatsSOPH  Per-pixel two-sample comparison of SOPHs split
    %   by the active Group-by levels. Uses FDR_2D from
    %   toolbox/helper_functions/statistical_tests/ (already on the
    %   path via init_DYNAMO).
    %
    %   Renders a (channels × axisKinds, 3) grid of axes:
    %       column 1 = mean SOPH for group A
    %       column 2 = mean SOPH for group B
    %       column 3 = signed mean difference (A − B) with the FDR-
    %                  significant pixels outlined.
    %
    %   Pages are matched to subject IDs using `agg.subjectIDs` from
    %   the .mat aggregate; the .tiff aggregate has subject IDs only
    %   in a sibling _subjectIDs.txt sidecar so we'd be reading them
    %   twice — for the stats path we only consume the .mat aggregate
    %   to keep the code straightforward.
    [ok, msg, info] = app.groupStatsState();
    if ~ok
        try, uialert(app.UIFigure, msg, 'Group Stats — not ready'); catch, end
        try, delete(app.GroupStatsSOPHPanel.Children); catch, end
        return
    end

    % Build the work list: one row per (channel, axisKind) that has
    % data for both levels.
    work = struct('channel', {}, 'axisKind', {}, ...
                  'A', {}, 'B', {}, 'freq_bins', {}, 'so_bins', {});
    for ci = 1:numel(info.channels)
        ch = info.channels{ci};
        for kk = 1:2
            axisKind = 'power'; if kk == 2, axisKind = 'phase'; end
            [stack, ids, fb, sb] = loadSOPHStackForStats_(app, ch, axisKind);
            if isempty(stack), continue, end
            G = app.getActiveSubjectGroups(ids);
            if ~G.ready, continue, end
            mA = G.masksByLevel(char(string(info.levels{1})));
            mB = G.masksByLevel(char(string(info.levels{2})));
            if nnz(mA) < 2 || nnz(mB) < 2, continue, end
            work(end+1).channel  = ch;          %#ok<AGROW>
            work(end).axisKind   = axisKind;
            work(end).A          = stack(:, :, mA);
            work(end).B          = stack(:, :, mB);
            work(end).freq_bins  = fb;
            work(end).so_bins    = sb;
        end
    end

    delete(app.GroupStatsSOPHPanel.Children);
    if isempty(work)
        ax = uiaxes(app.GroupStatsSOPHPanel, 'Units','normalized', ...
            'Position',[0 0 1 1], 'BackgroundColor','white');
        axis(ax, 'off');
        text(ax, 0.5, 0.5, ...
            'No (channel, axis) pair has \geq 2 subjects per group.', ...
            'HorizontalAlignment','center', 'Color',[0.5 0.5 0.5]);
        return
    end

    nRows = numel(work);
    grid               = uigridlayout(app.GroupStatsSOPHPanel);
    grid.RowHeight     = repmat({'1x'}, 1, nRows);
    grid.ColumnWidth   = {'1x','1x','1x'};
    grid.RowSpacing    = 4;
    grid.ColumnSpacing = 4;
    grid.Padding       = [4 4 4 4];

    for rr = 1:numel(work)
        w = work(rr);
        % Per-pixel FDR via FDR_2D (BH at q=0.1, nonparam ranksum).
        try
            [sigbins, ~, ~] = FDR_2D(w.A, w.B, 0.1, ...
                'dependent', false, true, false);
        catch ME
            try, app.appendResultsBrowserLog(sprintf( ...
                    'Group SOPH stats (%s|%s): FDR_2D failed — %s', ...
                    w.channel, w.axisKind, ME.message)); catch, end
            sigbins = false(size(w.A, 1), size(w.A, 2));
        end
        meanA = mean(w.A, 3, 'omitnan');
        meanB = mean(w.B, 3, 'omitnan');
        diffM = meanA - meanB;

        axA = uiaxes(grid); axA.Layout.Row = rr; axA.Layout.Column = 1;
        axB = uiaxes(grid); axB.Layout.Row = rr; axB.Layout.Column = 2;
        axD = uiaxes(grid); axD.Layout.Row = rr; axD.Layout.Column = 3;

        labelA = sprintf('%s | %s | %s', w.channel, w.axisKind, info.levels{1});
        labelB = sprintf('%s | %s | %s', w.channel, w.axisKind, info.levels{2});
        labelD = sprintf('%s − %s (sig FDR<.1)', info.levels{1}, info.levels{2});

        plotPanel_(axA, meanA, w.freq_bins, w.so_bins, w.axisKind, labelA, false);
        plotPanel_(axB, meanB, w.freq_bins, w.so_bins, w.axisKind, labelB, false);
        plotPanel_(axD, diffM, w.freq_bins, w.so_bins, w.axisKind, labelD, true);
        % Overlay significance contour on the diff axis.
        if any(sigbins(:))
            hold(axD, 'on');
            xs = w.so_bins;   if isempty(xs), xs = 1:size(diffM, 1); end
            ys = w.freq_bins; if isempty(ys), ys = 1:size(diffM, 2); end
            contour(axD, xs, ys, double(sigbins.'), [0.5 0.5], ...
                'LineColor','k', 'LineWidth', 1.0);
            hold(axD, 'off');
        end
    end
end


function [stack, ids, freq_bins, so_bins] = loadSOPHStackForStats_(app, channel, axisKind)
    stack = []; ids = {}; freq_bins = []; so_bins = [];
    aggDir = fullfile(app.ResultsBrowserOutputDirField.Value, 'aggregates', channel);
    cand   = fullfile(aggDir, [channel '_aggregate_SOPHs_' axisKind '.mat']);
    if ~isfile(cand), return, end
    try
        S = load(cand);
    catch
        return
    end
    if isfield(S, 'aggregate'), agg = S.aggregate; else, agg = S; end
    fld = ['SO' axisKind '_mat'];
    if ~isfield(agg, fld) || isempty(agg.(fld)), return, end
    stack = agg.(fld);
    if isfield(agg, 'subjectIDs'), ids = agg.subjectIDs; end
    if isfield(agg, 'freq_bins'), freq_bins = agg.freq_bins(:); end
    if isfield(agg, ['SO' axisKind '_bins']), so_bins = agg.(['SO' axisKind '_bins'])(:); end
end


function plotPanel_(ax, M, freq_bins, so_bins, axisKind, ttl, isDiff)
    if isempty(so_bins),   so_bins   = (1:size(M, 1)).'; end
    if isempty(freq_bins), freq_bins = (1:size(M, 2)).'; end
    imagesc(ax, so_bins, freq_bins, M.');
    axis(ax, 'xy');
    if isDiff
        cmax = max(abs(M(:)), [], 'omitnan');
        if isfinite(cmax) && cmax > 0
            clim(ax, [-cmax, cmax]);
        end
        try, colormap(ax, redblue_(256)); catch, colormap(ax, parula); end
    else
        try, colormap(ax, parula); catch, end
        finiteVals = M(isfinite(M));
        if ~isempty(finiteVals)
            cp = prctile(finiteVals, [5 98]);
            if cp(2) > cp(1), clim(ax, cp); end
        end
    end
    colorbar(ax);
    if strcmp(axisKind, 'phase')
        xlim(ax, [-pi pi]);
        xticks(ax, [-pi -pi/2 0 pi/2 pi]);
        xticklabels(ax, {'-\pi','-\pi/2','0','\pi/2','\pi'});
        xlabel(ax, 'SO-Phase (rad)');
    else
        xlabel(ax, 'SO-Power (dB)');
    end
    ylabel(ax, 'Frequency (Hz)');
    title(ax, ttl, 'Interpreter','none', 'FontSize', 9);
end


function cmap = redblue_(n)
    % Diverging red-blue map centered at zero; midpoint white.
    if mod(n, 2) == 1, n = n + 1; end
    half = n / 2;
    blue = [linspace(0,1,half).', linspace(0,1,half).', ones(half,1)];
    red  = [ones(half,1), linspace(1,0,half).', linspace(1,0,half).'];
    cmap = [blue; red];
end
