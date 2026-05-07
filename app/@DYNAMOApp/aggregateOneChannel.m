function aggregateOneChannel(app, channelDir, aggregatesRoot, categories, files)
    % aggregateOneChannel  Build aggregates inside
    % <aggregatesRoot>/<channelName>/ from per-subject inputs in
    % channelDir. `categories` is an optional cell-array subset of
    % {'paramPower','paramPhase','sophsPower','sophsPhase'}; the
    % default writes all four. `files` is an optional cell array
    % of absolute paths from the JSONL index — when provided, the
    % aggregator skips dir() entirely and pulls per-category lists
    % from this in-memory list instead.

    if nargin < 4 || isempty(categories)
        categories = {'paramPower','paramPhase','sophsPower','sophsPhase'};
    end
    if nargin < 5
        files = {};
    end
    wants = @(c) any(strcmp(categories, c));

    [~, channelName] = fileparts(channelDir);
    if isempty(files)
        app.appendResultsBrowserLog(sprintf('[%s] scanning (dir mode)...', channelName));
    else
        app.appendResultsBrowserLog(sprintf( ...
            '[%s] aggregating %d cataloged file(s) from index...', ...
            channelName, numel(files)));
    end

    % Per-stage progress callback. Logs a header line on the first
    % tick of each (cat, stage) and refreshes the preview-pane
    % progress bar at most every ~5% to keep HTML re-render cost
    % from dominating wall-clock. State lives in a containers.Map
    % so the closure can mutate it across calls (Map is a handle).
    stageState = containers.Map('KeyType','char','ValueType','any');
    stageState('lastKey') = '';
    stageState('lastPct') = -1;
    progressCb = @(catName, stage, ii, total) ...
        app.tickAggregateProgress(stageState, channelName, ...
                            catName, stage, ii, total);

    try
        R = aggregate_DYNAMO_outputs(channelDir, ...
            'Files', files, 'ProgressFcn', progressCb);
    catch ME
        app.appendResultsBrowserLog(sprintf('[%s] failed: %s', channelName, ME.message));
        return
    end

    for ii = 1:size(R.skipped, 1)
        app.appendResultsBrowserLog(sprintf('  dedupe-skip: %s — %s', R.skipped{ii,1}, R.skipped{ii,2}));
    end
    if isfield(R, 'warnings')
        for ii = 1:numel(R.warnings)
            app.appendResultsBrowserLog(sprintf('  warning: %s', R.warnings{ii}));
        end
    end

    aggRoot = fullfile(aggregatesRoot, channelName);

    if wants('paramPower')
        app.writeParamfitAggregate(R.paramPower, ...
            fullfile(aggRoot, 'param_basis_power'), ...
            channelName, 'SOpower_paramfit', 'paramPower');
    end
    if wants('paramPhase')
        app.writeParamfitAggregate(R.paramPhase, ...
            fullfile(aggRoot, 'param_basis_phase'), ...
            channelName, 'SOphase_paramfit', 'paramPhase');
    end
    if wants('sophsPower')
        app.writeSOPHsAggregate(R.sophsPower, ...
            fullfile(aggRoot, 'SOPHs_power'), ...
            channelName, 'power', 'SOPHs power');
    end
    if wants('sophsPhase')
        app.writeSOPHsAggregate(R.sophsPhase, ...
            fullfile(aggRoot, 'SOPHs_phase'), ...
            channelName, 'phase', 'SOPHs phase');
    end
end
