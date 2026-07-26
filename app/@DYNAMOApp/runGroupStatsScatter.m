function runGroupStatsScatter(app)
    % runGroupStatsScatter  Two-sample group comparison on every numeric
    %   paramfit column of the active channels.
    %
    %   Per-subject reduction first (mean across that subject's mode
    %   rows for the column), then split by Group-by level, then
    %   FDR_1D across columns. This keeps observations independent —
    %   subjects, not mode rows, are the unit of inference.
    %
    %   Uses FDR_1D from toolbox/helper_functions/statistical_tests/
    %   (already on the path via init_DYNAMO). Default test is
    %   nonparametric unpaired (ranksum) with FDR-BH at q=0.1; method
    %   is 'dependent' (Benjamini–Yekutieli) since paramfit columns
    %   are not independent of each other.
    [ok, msg, info] = app.groupStatsState();
    if ~ok
        try, app.GroupStatsScatterTable.Data = {}; catch, end
        try, uialert(app.UIFigure, msg, 'Group Stats — not ready'); catch, end
        return
    end

    % Build per-column accumulators for both group levels across the
    % selected channels. groupVals is a containers.Map per level
    % (column-name → [per-(subject, channel) mean vector]).
    accumA = containers.Map('KeyType','char','ValueType','any');
    accumB = containers.Map('KeyType','char','ValueType','any');

    for axisIdx = 1:2
        axisKind = 'power'; if axisIdx == 2, axisKind = 'phase'; end
        for ci = 1:numel(info.channels)
            ch = info.channels{ci};
            T  = app.loadParamfitAggregateForChannel(ch, axisKind);
            if isempty(T) || ~istable(T) || height(T) == 0, continue, end
            if ~ismember(info.column, T.Properties.VariableNames), continue, end
            if ~ismember('ID', T.Properties.VariableNames), continue, end

            numericCols = numericColumnsExcept_(T, {'ID', info.column});
            if isempty(numericCols), continue, end

            grpVals = string(T.(info.column));
            byID    = findgroups(T.ID);
            uniqIds = unique(T.ID, 'stable');

            % Per-subject reduction: mean of each numeric column over
            % that subject's mode rows. groupLabel for the subject is
            % constant (a subject belongs to one level of Group-by).
            for sj = 1:numel(uniqIds)
                rowsHere = byID == sj;
                if ~any(rowsHere), continue, end
                lvl = char(grpVals(find(rowsHere, 1, 'first')));
                if strcmp(lvl, info.levels{1})
                    accumKey = accumA;
                elseif strcmp(lvl, info.levels{2})
                    accumKey = accumB;
                else
                    continue
                end
                for kk = 1:numel(numericCols)
                    col   = numericCols{kk};
                    vals  = double(T.(col));
                    here  = vals(rowsHere);
                    here  = here(isfinite(here));
                    if isempty(here), continue, end
                    sm    = mean(here);
                    aKey  = [axisKind '|' col];
                    if isKey(accumKey, aKey)
                        accumKey(aKey) = [accumKey(aKey), sm];
                    else
                        accumKey(aKey) = sm;
                    end
                end
            end
        end
    end

    % Each (axis|column) tuple is one row in the result. Run FDR
    % per-axis to keep the multi-comparison family meaningful (power
    % columns vs phase columns aren't testing the same hypotheses).
    rows = {};
    for axisIdx = 1:2
        axisKind = 'power'; if axisIdx == 2, axisKind = 'phase'; end
        prefix   = [axisKind '|'];
        ka = filter_keys_(accumA, prefix);
        kb = filter_keys_(accumB, prefix);
        cols = unique([ka, kb], 'stable');
        if isempty(cols), continue, end

        % Pad to (n_cols × max_subj) matrices.
        nA = max(cellfun(@(k) numel(accumA(k)), cols(ismember(cols, ka))));
        nB = max(cellfun(@(k) numel(accumB(k)), cols(ismember(cols, kb))));
        if isempty(nA) || isempty(nB) || nA == 0 || nB == 0, continue, end
        Amat = nan(numel(cols), nA);
        Bmat = nan(numel(cols), nB);
        for kk = 1:numel(cols)
            if isKey(accumA, cols{kk}), v = accumA(cols{kk}); Amat(kk, 1:numel(v)) = v; end
            if isKey(accumB, cols{kk}), v = accumB(cols{kk}); Bmat(kk, 1:numel(v)) = v; end
        end

        try
            [~, p_adj, p_values] = FDR_1D(Amat, Bmat, 0.1, ...
                'dependent', false, true, false);
        catch ME
            try, app.appendResultsBrowserLog(sprintf( ...
                    'Group stats (%s): FDR_1D failed — %s', axisKind, ME.message)); catch, end
            continue
        end

        diffStat = median(Amat, 2, 'omitnan') - median(Bmat, 2, 'omitnan');
        for kk = 1:numel(cols)
            colName = strrep(cols{kk}, prefix, '');
            rows = [rows; {colName, axisKind, diffStat(kk), ...
                          p_values(kk), p_adj(kk), p_adj(kk) <= 0.1}]; %#ok<AGROW>
        end
    end

    if isempty(rows)
        try, app.GroupStatsScatterTable.Data = {}; catch, end
        try, uialert(app.UIFigure, ...
            'No comparisons could be run — check that both groups have subjects in the active channels.', ...
            'Group Stats'); catch, end
        return
    end

    % Sort by p_adj ascending so significant rows surface to the top.
    p_adj_col = cell2mat(rows(:, 5));
    [~, ord]  = sort(p_adj_col);
    rows = rows(ord, :);
    app.GroupStatsScatterTable.Data = rows;
end


function cols = numericColumnsExcept_(T, exclude)
    vn = T.Properties.VariableNames;
    keep = false(1, numel(vn));
    for kk = 1:numel(vn)
        keep(kk) = isnumeric(T.(vn{kk})) && ~ismember(vn{kk}, exclude);
    end
    cols = vn(keep);
end


function k = filter_keys_(map, prefix)
    if map.Count == 0, k = {}; return, end
    all = map.keys;
    k   = all(startsWith(all, prefix));
end
