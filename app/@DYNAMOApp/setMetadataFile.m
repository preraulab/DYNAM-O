function setMetadataFile(app, path)
    % setMetadataFile  Single source of truth for the metadata path.
    %   Validates the supplied path, normalises it to absolute, busts
    %   every cache that depends on metadata, syncs both UI fields,
    %   and triggers a full redraw of the Aggregate Data tab.
    %
    %   path : '' or absent → clear the metadata.
    %          missing file → kept on the path field (so the user sees
    %                         what's wrong) but loaded as empty.
    %          valid file   → cached and joined.
    if nargin < 2 || isempty(path)
        path = '';
    end
    path = char(path);

    % Resolve to absolute when the file actually exists.
    if ~isempty(path) && isfile(path)
        d = dir(path);
        path = fullfile(d(1).folder, d(1).name);
    end

    app.MetadataFile_  = path;
    app.MetadataTable_ = [];   % bust the lazy-load cache

    % Mode Scatter joined-table cache: the next renderModeScatterAxis
    % call will re-load + re-join fresh.
    if isa(app.ModeScatter_TableCache_, 'containers.Map') ...
            && app.ModeScatter_TableCache_.Count > 0
        app.ModeScatter_TableCache_ = containers.Map( ...
            'KeyType','char','ValueType','any');
    end

    % Sync both UI fields — guarded for the constructor path where the
    % Aggregate Data tab may not be built yet.
    syncField_(app.MetadataFileEditField,      path);
    syncField_(app.MetadataFileFieldAggregate, path);

    % Repopulate Group-by dropdown items now that we know the metadata
    % schema. Triggers a full Mode Scatter rebuild + Mean SOPH redraw
    % via refreshGroupByControls (which itself calls those redraws
    % when applicable).
    try, app.refreshGroupByControls(); catch, end

    try, app.refreshSOHistogramsAvailability(); catch, end
    try, app.redrawModeScatter();              catch, end
end


function syncField_(ctrl, value)
    if isempty(ctrl), return, end
    try
        if ~isvalid(ctrl), return, end
    catch
        return
    end
    try
        ctrl.Value = value;
    catch
    end
end
