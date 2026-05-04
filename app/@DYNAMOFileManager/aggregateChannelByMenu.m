function aggregateChannelByMenu(app, channelDir, categories)
    % Run aggregation for a single channel from a right-click,
    % then refresh the tree so the new aggregates folder shows
    % up. Mirrors aggregateResultsRoot's surrounding scaffolding.
    if isempty(channelDir) || ~isfolder(channelDir)
        app.logResultsBrowser(sprintf('Aggregate: invalid channel dir: %s', channelDir));
        return
    end
    root = strtrim(char(app.ResultsBrowserOutputDirField.Value));
    aggregatesRoot = fullfile(root, 'aggregates');

    drawnow;
    app.AggregateOverwriteMode_ = '';   % reset standing answer
    % Right-click is a single-channel op — drop any per-channel
    % bar map left over from a top-level run so tickAggregateProgress
    % falls back to the single-bar path.
    app.destroyAggregateProgressGrid();
    app.aggregateOneChannel(channelDir, aggregatesRoot, categories);
    app.refreshAggregatesNodeInCache(root);
    app.updateAggregateDataTabVisibility(true);
end
