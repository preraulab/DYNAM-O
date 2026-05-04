function regenerateRunIndex(app, root)
    %REGENERATERUNINDEX  Build a backfill JSONL from the cached tree.
    try
        app.logResultsBrowser('Generating run index from current tree...');
        drawnow;
        t0 = tic;
        outPath = dynamo_seed_index_from_cache(root, app.ResultsBrowserCache_);
        app.logResultsBrowser(sprintf( ...
            '  Wrote %s in %.2f s', outPath, toc(t0)));
        idx = dynamo_index_runs(root);
        app.logResultsBrowser(sprintf( ...
            '  Index now: %d entries across %d subjects, %d channels', ...
            numel(idx.entries), numel(idx.subjects), numel(idx.channels)));
    catch ME
        app.logResultsBrowser(['Run-index generation failed: ', ME.message]);
    end
end
