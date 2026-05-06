function refreshSOHistogramsAvailability(app)
    % refreshSOHistogramsAvailability  Walk <root>/aggregates/<channel>/SOPHs_*/
    % to determine which channels have aggregate power & phase data.
    % Updates the listbox: every real channel under root is shown, but
    % channels lacking aggregate data are visually marked and
    % filtered out of the selection.
    root = strtrim(char(app.ResultsBrowserOutputDirField.Value));
    chInfo = struct('name',{},'hasPower',{},'hasPhase',{}, ...
                    'powerPath',{},'phasePath',{});
    if ~isempty(root) && isfolder(root)
        entries = dir(root);
        for ii = 1:numel(entries)
            if ~entries(ii).isdir, continue, end
            if startsWith(entries(ii).name, '.'), continue, end
            if ismember(entries(ii).name, {'settings','logs','aggregates'})
                continue
            end
            chDir = fullfile(root, entries(ii).name);
            if ~(isfolder(fullfile(chDir,'param_basis')) || ...
                 isfolder(fullfile(chDir,'SOPHs')))
                continue
            end
            [pPath, hasPow]   = app.findSOHistAggregate(root, entries(ii).name, 'power');
            [phPath, hasPhase] = app.findSOHistAggregate(root, entries(ii).name, 'phase');
            chInfo(end+1) = struct( ...
                'name',      entries(ii).name, ...
                'hasPower',  hasPow, ...
                'hasPhase',  hasPhase, ...
                'powerPath', pPath, ...
                'phasePath', phPath); %#ok<AGROW>
        end
    end
    app.SOHist_ChannelInfo_ = chInfo;

    % Display strings: '(no data) <name>' for channels without aggregates.
    items = cell(1, numel(chInfo));
    for ii = 1:numel(chInfo)
        if chInfo(ii).hasPower || chInfo(ii).hasPhase
            items{ii} = chInfo(ii).name;
        else
            items{ii} = ['(no data) ' chInfo(ii).name];
        end
    end

    availableNames = {chInfo([chInfo.hasPower] | [chInfo.hasPhase]).name};
    currentVal = app.SOHistogramsChannelListBox.Value;
    if ~iscell(currentVal), currentVal = {currentVal}; end
    currentVal = currentVal(~cellfun(@isempty, currentVal));
    if isempty(currentVal)
        newSelection = availableNames;
    else
        newSelection = intersect(currentVal, availableNames, 'stable');
        if isempty(newSelection)
            newSelection = availableNames;
        end
    end

    % Clear Value before changing Items: CSSuiListBox builds
    % an event struct that pairs PreviousValue with Value as
    % cell arrays, and crashes ("Array dimensions of input N
    % must match...") when their lengths differ across an
    % Items change. Forcing the previous Value to {} before
    % the new Items lands keeps both sides consistent.
    app.SOHist_SuppressFcn_ = true;
    app.SOHistogramsChannelListBox.Value = {};
    app.SOHistogramsChannelListBox.Items = items;
    if ~isempty(items)
        app.SOHistogramsChannelListBox.Value = newSelection;
    end
    app.SOHist_SuppressFcn_ = false;

    app.redrawSOHistograms();
end
