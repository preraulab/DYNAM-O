function onResultsBrowserMenuAction(app, evt)
    % onResultsBrowserMenuAction  Dispatch a CSSuiTree right-
    % click action. evt.Action is the action id from the menu
    % definition in node_menu_items; evt.NodeData is the path.
    if ~isfield(evt,'Action') || isempty(evt.Action), return, end
    p = '';
    if isfield(evt,'NodeData') && ~isempty(evt.NodeData)
        p = char(evt.NodeData);
    end
    switch evt.Action
        case 'open'
            if isempty(p), return, end
            app.openPathInOS(p);
        case 'aggregate-all'
            app.aggregateResultsRoot();
        case 'regenerate-run-index'
            if isempty(p), return, end
            app.regenerateRunIndex(p);
        case 'aggregate-channel'
            app.aggregateChannelByMenu(p, ...
                {'paramPower','paramPhase','sophsPower','sophsPhase'});
        case 'aggregate-paramfit'
            chDir = app.resolveChannelDir(p);
            app.aggregateChannelByMenu(chDir, ...
                {'paramPower','paramPhase'});
        case 'aggregate-sophs'
            chDir = app.resolveChannelDir(p);
            app.aggregateChannelByMenu(chDir, ...
                {'sophsPower','sophsPhase'});
    end
end
