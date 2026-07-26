function G = getActiveSubjectGroups(app, subjectIDs)
    % getActiveSubjectGroups  Per-level subject masks driven by the
    %   metadata Group-by + Group-filter state. Used by the stats
    %   path (multicomp_test) where activeSubjectMask's union mask
    %   isn't enough — we need to know which subjects belong to
    %   which level so a two-group permtest can pull the right
    %   columns from the 3-D SOPH stack / per-mode paramfit table.
    %
    %   subjectIDs : cell / string array of subject ID strings (the
    %                aggregate-side IDs, not metadata-side).
    %
    %   Returns a struct:
    %     .column        char  - the Group-by column name, or '' if
    %                            no Group-by is active.
    %     .levels        cellstr  - currently-included level values
    %                              (i.e. the Group filter listbox
    %                              selection), in the order they
    %                              appeared in the metadata table.
    %     .masksByLevel  containers.Map (char -> logical column) -
    %                              one mask per level over the
    %                              supplied subjectIDs.
    %     .ready         logical - true when there's enough state to
    %                              do a meaningful split (>=2 levels
    %                              with at least one matching subject
    %                              each). False otherwise; callers
    %                              can use this to gate the stats UI.
    G = struct( ...
        'column',       '', ...
        'levels',       {{}}, ...
        'masksByLevel', containers.Map('KeyType','char','ValueType','any'), ...
        'ready',        false);

    if isstring(subjectIDs), subjectIDs = cellstr(subjectIDs); end
    if ischar(subjectIDs),   subjectIDs = {subjectIDs}; end
    n = numel(subjectIDs);
    if n == 0, return, end

    % Need a Group-by control + value.
    gbDD = [];
    try, gbDD = app.ModeScatterGroupByDropDown; catch, end
    if isempty(gbDD) || ~isvalid(gbDD), return, end
    groupCol = char(gbDD.Value);
    if isempty(groupCol) || strcmp(groupCol, '(none)'), return, end

    % Need metadata with that column.
    M = app.loadSubjectMetadata();
    if isempty(M) || ~istable(M) ...
            || ~ismember(groupCol, M.Properties.VariableNames)
        return
    end

    % Group-filter listbox value; missing / empty ⇒ no filtering, so
    % use every distinct level present in the metadata column.
    selVals = {};
    try, selVals = app.ModeScatterGroupFilterListBox.Value; catch, end
    if isstring(selVals), selVals = cellstr(selVals); end
    if ischar(selVals),   selVals = {selVals}; end
    if isempty(selVals)
        selVals = unique_levels_(M.(groupCol));
    end

    G.column = groupCol;
    G.levels = selVals(:).';

    % Map each subject ID → metadata-row → group level. Subjects
    % without a metadata row are excluded from every level.
    normIds   = app.normalizeSubjectId(subjectIDs);
    [tf, loc] = ismember(normIds, M.ID);
    perSubjLevel = strings(n, 1);
    if any(tf)
        gv = M.(groupCol)(loc(tf));
        perSubjLevel(tf) = string_col_(gv);
    end

    nReady = 0;
    for kk = 1:numel(G.levels)
        lv = G.levels{kk};
        m  = perSubjLevel == string(lv);
        G.masksByLevel(char(string(lv))) = m(:);
        if any(m), nReady = nReady + 1; end
    end
    G.ready = nReady >= 2;
end


function lv = unique_levels_(col)
    s = string_col_(col);
    [~, ia] = unique(s, 'stable');
    lv = cellstr(s(ia));
end


function s = string_col_(x)
    if isnumeric(x) || islogical(x)
        s = string(x(:));
    elseif iscategorical(x)
        s = string(x(:));
    elseif iscell(x)
        s = string(x(:));
    else
        s = string(x(:));
    end
end
