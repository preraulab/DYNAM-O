function T = loadParamfitAggregateForChannel(app, channelName, axisKind)
    % loadParamfitAggregateForChannel  Load the per-channel
    %   paramfit aggregate as a table.
    %
    %   Looks under <root>/aggregates/<channel>/param_basis/
    %   for <channel>_aggregate_SO<axis>_paramfit.{mat,csv}.
    %   Prefers .mat (carries the table verbatim, with original
    %   column types and ID strings) over .csv (which has been
    %   round-tripped through writetable / readtable and may
    %   coerce types). Falls back to .csv if .mat is absent so
    %   runs that wrote only one format are still usable.
    %
    %   axisKind: 'power' or 'phase'. Returns [] when neither
    %   file exists or neither contains a usable table. Cached
    %   by (channel|axis) so dropdown changes don't re-read
    %   the disk; updateAggregateDataTabVisibility clears the
    %   cache on forceRefresh.
    T = [];
    if ~isa(app.ModeScatter_TableCache_, 'containers.Map')
        app.ModeScatter_TableCache_ = containers.Map( ...
            'KeyType','char','ValueType','any');
    end
    key = [channelName '|' axisKind];
    if isKey(app.ModeScatter_TableCache_, key)
        T = app.ModeScatter_TableCache_(key);
        return
    end
    % Single source of truth for the on-disk path; returns
    % whichever of .mat/.csv is present (preferring .mat).
    p = char(app.paramfitAggregatePath(channelName, axisKind));
    if isempty(p)
        app.ModeScatter_TableCache_(key) = [];
        return
    end

    [~, ~, ext] = fileparts(p);
    try
        switch lower(ext)
            case '.mat'
                S = load(p);
                if isfield(S, 'aggregate') && isfield(S.aggregate, 'params') ...
                        && istable(S.aggregate.params)
                    T = S.aggregate.params;
                end
            case '.csv'
                T = readtable(p, 'VariableNamingRule', 'preserve');
        end
    catch
        T = [];
    end

    app.ModeScatter_TableCache_(key) = T;
end
