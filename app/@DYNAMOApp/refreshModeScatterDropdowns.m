function refreshModeScatterDropdowns(app, axisKind)
    % refreshModeScatterDropdowns  Walk the currently-selected
    %   channels' paramfit aggregates for `axisKind` only and
    %   build the union of available column names for that
    %   axis's four dropdowns:
    %     - X / Y / Size  → numeric columns only
    %     - Color         → numeric + 'ID'
    %   Each dropdown gets a leading '(none)' option. Current
    %   selections are preserved when still valid; on the very
    %   first populated refresh we apply axis-specific defaults
    %     Power: X=SOpowerMean, Y=FreqMean, Size=Amplitude, Color=PrefPhaseCirc
    %     Phase: X=SOphaseMean, Y=FreqMean, Size=Amplitude, Color=PrefPhaseCirc
    %   The "first populated refresh" is tracked per-dropdown
    %   in UserData so user picks of '(none)' aren't clobbered
    %   on subsequent refreshes.
    [xDD, yDD, sDD, cDD] = app.modeScatterDropdowns(axisKind);

    sel = app.SOHistogramsChannelListBox.Value;
    if ischar(sel) || isstring(sel), sel = cellstr(sel); end
    sel = sel(~startsWith(sel, '(no data) '));

    numericCols = {};
    allCols     = {};
    for ii = 1:numel(sel)
        T = app.loadParamfitAggregateForChannel(sel{ii}, axisKind);
        if isempty(T) || ~istable(T), continue, end
        vn = T.Properties.VariableNames;
        for kk = 1:numel(vn)
            col = vn{kk};
            if ~ismember(col, allCols), allCols{end+1} = col; end %#ok<AGROW>
            v = T.(col);
            if isnumeric(v) && ~ismember(col, numericCols)
                numericCols{end+1} = col; %#ok<AGROW>
            end
        end
    end

    xyItems    = [{'(none)'}, sort(numericCols)];
    sizeItems  = [{'(none)'}, sort(numericCols)];
    colorItems = [{'(none)'}, sort(allCols)];

    xDD.Items = xyItems;
    yDD.Items = xyItems;
    sDD.Items = sizeItems;
    cDD.Items = colorItems;

    switch axisKind
        case 'power'
            xPref = 'SOpowerMean';
            cPref = 'PrefPhaseCirc';
        case 'phase'
            xPref = 'SOphaseMean';
            cPref = 'SOphaseMean';
        otherwise
            xPref = 'Amplitude';
            cPref = 'ID';
    end

    if ~isstruct(app.ModeScatter_DropdownsInited_)
        app.ModeScatter_DropdownsInited_ = struct('power', false, 'phase', false);
    end
    inited = app.ModeScatter_DropdownsInited_.(axisKind);

    pickDefault(xDD, xPref,        inited);
    pickDefault(yDD, 'FreqMean',   inited);
    pickDefault(sDD, 'Amplitude',  inited);
    pickDefault(cDD, cPref,        inited);

    app.ModeScatter_DropdownsInited_.(axisKind) = true;

    function pickDefault(dd, preferred, alreadyInited)
        cur = dd.Value;
        if ~ismember(cur, dd.Items)
            if ismember(preferred, dd.Items)
                dd.Value = preferred;
            else
                dd.Value = dd.Items{1};
            end
        elseif ~alreadyInited && ismember(preferred, dd.Items)
            dd.Value = preferred;
        end
    end
end
