function refreshGroupByControls(app)
    % refreshGroupByControls  Repopulate the Mode Scatter Group-by
    %   dropdown and Group-filter listbox based on the currently
    %   loaded metadata table. Preserves the current Group-by
    %   selection when its column is still present; otherwise
    %   falls back to '(none)'. Identical preservation rule for
    %   the listbox values.
    gbDD = []; gfLB = [];
    try, gbDD = app.ModeScatterGroupByDropDown;    catch, end
    try, gfLB = app.ModeScatterGroupFilterListBox; catch, end
    if isempty(gbDD) || ~isvalid(gbDD), return, end

    M = app.loadSubjectMetadata();
    if isempty(M) || ~istable(M)
        % No metadata → only '(none)' is meaningful.
        gbDD.Items = {'(none)'};
        gbDD.Value = '(none)';
        if ~isempty(gfLB) && isvalid(gfLB)
            gfLB.Items = {};
            gfLB.Value = {};
        end
        return
    end

    % Skip the mandatory ID column; offer everything else.
    cols = M.Properties.VariableNames;
    cols = cols(~strcmp(cols, 'ID'));
    items = [{'(none)'}, sort(cols)];

    prev = '(none)';
    try, prev = char(gbDD.Value); catch, end
    gbDD.Items = items;
    if any(strcmp(items, prev))
        gbDD.Value = prev;
    else
        gbDD.Value = '(none)';
    end

    % Group filter listbox: levels of the active Group-by column.
    if isempty(gfLB) || ~isvalid(gfLB), return, end
    cur = char(gbDD.Value);
    if strcmp(cur, '(none)')
        gfLB.Items = {};
        gfLB.Value = {};
        return
    end

    levels = uniqueLevels_(M.(cur));
    prevSel = {};
    try, prevSel = gfLB.Value; catch, end
    if ischar(prevSel),   prevSel = {prevSel};       end
    if isstring(prevSel), prevSel = cellstr(prevSel); end

    gfLB.Items = levels;
    keep = prevSel(ismember(prevSel, levels));
    if isempty(keep)
        gfLB.Value = levels;        % default = include every level
    else
        gfLB.Value = keep;
    end
end


function lv = uniqueLevels_(col)
    if iscategorical(col)
        s = string(col);
    elseif isnumeric(col) || islogical(col)
        s = string(col);
    elseif iscell(col)
        s = string(col);
    else
        s = string(col);
    end
    s(ismissing(s)) = "";
    [~, ia] = unique(s, 'stable');
    lv = cellstr(s(ia));
    lv = lv(~cellfun('isempty', lv));
end
