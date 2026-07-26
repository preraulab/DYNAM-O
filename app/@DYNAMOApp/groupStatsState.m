function [ok, msg, info] = groupStatsState(app)
    % groupStatsState  Tell the caller whether the Group Stats path is
    %   ready to run (true/false), with a human-readable hint, plus a
    %   struct describing what's selected.
    %
    %   Pre-conditions for two-sample stats:
    %     1. Metadata file loaded (table non-empty).
    %     2. A non-(none) Group-by column.
    %     3. Exactly two values selected in the Group filter listbox.
    %     4. At least one channel selected in the channel listbox.
    %
    %   info struct (always populated, even on the not-ready path so
    %   callers can decide what to do):
    %     .channels  cellstr  - currently-selected channel leaf names
    %     .column    char      - Group-by column ('' if none)
    %     .levels    cellstr  - the two filter values selected (or {} )
    info = struct('channels', {{}}, 'column', '', 'levels', {{}});

    sel = {};
    try
        sel = app.SOHistogramsChannelListBox.Value;
        if ischar(sel) || isstring(sel), sel = cellstr(sel); end
        sel = sel(~startsWith(sel, '(no data) '));
    catch
    end
    info.channels = sel;

    M = app.loadSubjectMetadata();
    if isempty(M) || ~istable(M) || height(M) == 0
        ok  = false;
        msg = 'Load a metadata CSV first (Browse... in the toolbar).';
        return
    end

    col = '';
    try, col = char(app.ModeScatterGroupByDropDown.Value); catch, end
    if isempty(col) || strcmp(col, '(none)')
        ok  = false;
        msg = 'Pick a Group-by column on the left to enable comparisons.';
        return
    end
    info.column = col;

    levs = {};
    try, levs = app.ModeScatterGroupFilterListBox.Value; catch, end
    if isstring(levs), levs = cellstr(levs); end
    if ischar(levs),   levs = {levs}; end
    info.levels = levs;
    if numel(levs) ~= 2
        ok  = false;
        msg = sprintf( ...
            'Select exactly TWO values in the Group filter listbox (%d selected) — gpermtest is a two-sample test.', ...
            numel(levs));
        return
    end

    if isempty(sel)
        ok  = false;
        msg = 'Select at least one channel on the left.';
        return
    end

    ok  = true;
    msg = sprintf('Ready: %d channel(s), Group-by "%s" {%s vs %s}.', ...
        numel(sel), col, levs{1}, levs{2});
end
