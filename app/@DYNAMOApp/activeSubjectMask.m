function mask = activeSubjectMask(app, subjectIDs)
    % activeSubjectMask  Logical mask over a list of subject IDs honoring
    %   the current Group-by / Group-filter state. Returns all-true when
    %   no metadata is configured or no Group-by column is selected, so
    %   the caller can use it unconditionally.
    %
    %   subjectIDs : cell array (or string array) of subject ID strings.
    %                Pass-through to normalizeSubjectId so the lookup is
    %                lenient on .edf suffixes.
    if isstring(subjectIDs), subjectIDs = cellstr(subjectIDs); end
    if ischar(subjectIDs),   subjectIDs = {subjectIDs}; end
    n = numel(subjectIDs);
    mask = true(n, 1);
    if n == 0, return, end

    % No Group-by control built yet, or its current value is '(none)'.
    gbDD = [];
    try, gbDD = app.ModeScatterGroupByDropDown; catch, end
    if isempty(gbDD) || ~isvalid(gbDD), return, end
    groupCol = char(gbDD.Value);
    if isempty(groupCol) || strcmp(groupCol, '(none)'), return, end

    % Need a metadata table with the chosen column.
    M = app.loadSubjectMetadata();
    if isempty(M) || ~istable(M) ...
            || ~ismember(groupCol, M.Properties.VariableNames)
        return
    end

    % Group-filter listbox value; missing / empty = no filtering.
    keepVals = {};
    try, keepVals = app.ModeScatterGroupFilterListBox.Value; catch, end
    if isstring(keepVals), keepVals = cellstr(keepVals); end
    if ischar(keepVals),   keepVals = {keepVals}; end
    if isempty(keepVals), return, end

    % Map each subject ID to its group value, then test membership in
    % the selected set. Subjects with no metadata row are excluded
    % whenever a Group-by column is active — they have no group, so
    % they can't satisfy the filter. (When no Group-by is active we
    % returned all-true above.)
    normIds   = app.normalizeSubjectId(subjectIDs);
    [tf, loc] = ismember(normIds, M.ID);
    mask = false(n, 1);
    if any(tf)
        gv = M.(groupCol)(loc(tf));
        mask(tf) = ismember(string_(gv), string_(keepVals));
    end
end


function s = string_(x)
    % Coerce mixed numeric / cellstr / categorical group values to a
    % string column for ismember comparison.
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
