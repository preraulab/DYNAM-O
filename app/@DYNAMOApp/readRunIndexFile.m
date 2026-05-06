function idx = readRunIndexFile(app, root)
    %TRYREADRUNINDEXEARLY  Read <root>/_runs/*.jsonl and log a summary
    %   BEFORE the directory walk runs. Returns the index struct on
    %   success (empty struct array [] when no JSONL exists or read
    %   fails). The caller uses non-emptiness to decide whether to
    %   build the tree from the index or fall back to a recursive
    %   walk.
    idx = [];
    try
        runsDir = fullfile(root, '_runs');
        if ~isfolder(runsDir), return, end
        d = dir(fullfile(runsDir, '*.jsonl'));
        if isempty(d), return, end
        nFiles = numel(d);
        if nFiles == 1
            app.appendResultsBrowserLog(sprintf( ...
                'Reading run index from 1 file (%s)...', d(1).name));
        else
            app.appendResultsBrowserLog(sprintf( ...
                'Reading run index from %d files...', nFiles));
        end
        drawnow;
        t0 = tic;
        idx = dynamo_index_runs(root);
        app.appendResultsBrowserLog(sprintf( ...
            'Run index: %d entries across %d subjects, %d channels (%d run files, %.2fs)', ...
            numel(idx.entries), numel(idx.subjects), ...
            numel(idx.channels), numel(idx.runFiles), toc(t0)));
    catch ME
        app.appendResultsBrowserLog(['Run-index read failed: ', ME.message]);
        idx = [];
    end
end
