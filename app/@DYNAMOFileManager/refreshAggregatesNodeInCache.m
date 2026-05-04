function refreshAggregatesNodeInCache(app, root)
    %REFRESHAGGREGATESNODEINCACHE  Re-scan <root>/aggregates/ and
    %   replace just that node in app.ResultsBrowserCache_, then
    %   push the updated cache to the tree. The rest of the
    %   cache (per-channel JSONL-driven entries) is untouched —
    %   no JSONL re-read, no walk of the full tree.
    import results_browser.*
    if isempty(app.ResultsBrowserCache_), return, end
    cache = app.ResultsBrowserCache_;

    aggPath = fullfile(root, 'aggregates');
    if ~isfolder(aggPath)
        app.logResultsBrowser('  (no aggregates/ folder to splice)');
        return
    end

    tScan = tic;
    newNode = app.scanDirIntoCache(aggPath, 'aggregates', 0);
    app.logResultsBrowser(sprintf( ...
        '  Re-scanned aggregates/ in %.2fs (%d folder(s), %d file(s))', ...
        toc(tScan), numel(newNode.dirs), numel(newNode.files)));

    replaced = false;
    for ii = 1:numel(cache.dirs)
        if strcmp(cache.dirs{ii}.name, 'aggregates')
            cache.dirs{ii} = newNode;
            replaced = true;
            break
        end
    end
    if ~replaced
        cache.dirs{end+1} = newNode;
    end
    app.ResultsBrowserCache_ = cache;

    tTree = tic;
    app.ResultsBrowserTree.Data = cache_to_tree_node(cache);
    app.logResultsBrowser(sprintf( ...
        '  Tree updated in %.2fs', toc(tTree)));
end
