function aggregateResultsRoot(app)
    % aggregateResultsRoot  For each channel under the chosen results
    % root, stack per-subject paramfit tables and SOPHs histograms
    % into per-channel aggregates inside <root>/aggregates/<chan>/.
    %
    % Channels and per-channel file lists come from the JSONL run
    % index, so the aggregator skips dir() entirely. Falls back to
    % a one-shot dir() at root only if no index is present.

    drawnow;
    app.ResultsBrowserTextArea.Value = {''};   % clear previous
    app.AggregateOverwriteMode_ = '';          % reset standing answer
    root = strtrim(char(app.ResultsBrowserOutputDirField.Value));
    if isempty(root) || ~isfolder(root)
        app.appendResultsBrowserLog(sprintf('Aggregate: invalid root: %s', root));
        return
    end

    % Index-driven discovery: channels come from the index, file
    % lists come pre-grouped per (subject, channel). Synth fallback
    % in dynamo_index_runs ensures legacy entries (components-only,
    % no `files` field) still produce usable file paths.
    idx = [];
    try
        runsDir = fullfile(root, '_runs');
        if isfolder(runsDir) && ~isempty(dir(fullfile(runsDir,'*.jsonl')))
            idx = dynamo_index_runs(root);
        end
    catch ME
        app.appendResultsBrowserLog(['Aggregate: index read failed: ', ME.message]);
    end

    if ~isempty(idx) && ~isempty(idx.entries)
        filesByChannel = app.groupIndexFilesByChannel(root, idx);
        channels = sort(filesByChannel.keys);
        app.appendResultsBrowserLog(sprintf( ...
            'Aggregate: %d channel(s) from index; no directory scan needed', ...
            numel(channels)));
    else
        % No index — fall back to the single-level dir() at root
        % to find candidate channel folders.
        entries = dir(root);
        channels = {};
        for ii = 1:numel(entries)
            if ~entries(ii).isdir, continue, end
            if startsWith(entries(ii).name, '.'), continue, end
            if ismember(entries(ii).name, {'settings','logs','aggregates'}), continue, end
            ch = fullfile(root, entries(ii).name);
            if isfolder(fullfile(ch, 'param_basis')) || isfolder(fullfile(ch, 'SOPHs'))
                channels{end+1} = ch; %#ok<AGROW>
            end
        end
        if isempty(channels)
            app.appendResultsBrowserLog('Aggregate: no channel directories found under root.');
            return
        end
        app.appendResultsBrowserLog(sprintf( ...
            'Aggregate: %d channel(s) under %s (no index, scanning dirs)', ...
            numel(channels), root));
        filesByChannel = containers.Map();
    end

    aggregatesRoot = fullfile(root, 'aggregates');

    % --- Pre-flight format pick ----------------------------
    % Detect which of the four aggregable file types are actually
    % present in the discovered inventory and ask the user (via a
    % CSSuiListBox multiselect) which to roll up. Skipped types
    % don't pay the load/scan cost. Cancel here aborts the run.
    presentFmts  = app.detectAggregateFormats(root, channels, filesByChannel);
    selectedFmts = app.pickAggregateFormats(presentFmts);
    % pickAggregateFormats sentinel: [] (numeric) = user cancelled,
    % {} (empty cell) = nothing of any type was found in this run.
    if isnumeric(selectedFmts) && isempty(selectedFmts)
        app.appendResultsBrowserLog('Aggregate: cancelled at file-type picker.');
        app.renderResultsBrowserPreviewPlaceholder('idle');
        return
    end
    if iscell(selectedFmts) && isempty(selectedFmts)
        app.appendResultsBrowserLog('Aggregate: no aggregable files found under root.');
        app.renderResultsBrowserPreviewPlaceholder('idle');
        return
    end
    app.appendResultsBrowserLog(sprintf( ...
        '  picked file types: %s', strjoin(selectedFmts, ', ')));

    % --- Pre-flight overwrite check ------------------------
    % If the aggregates/ tree already has any files, ask once
    % up-front instead of forcing the user to dismiss a
    % per-(channel, category) prompt later. The standing answer
    % feeds confirmAggregateOverwrite via AggregateOverwriteMode_,
    % which short-circuits all subsequent per-file prompts.
    if isfolder(aggregatesRoot) && ~app.aggregatesRootIsEmpty(aggregatesRoot)
        msg = sprintf(['Existing aggregates were found under:' ...
            '\n\n%s\n\nOverwrite them?'], aggregatesRoot);
        try
            sel = uiconfirm(app.UIFigure, msg, 'Aggregate exists', ...
                'Options', {'Yes', 'No', 'All', 'Cancel'}, ...
                'DefaultOption', 'All', ...
                'CancelOption',  'Cancel', ...
                'Icon', 'question');
        catch
            sel = 'Cancel';
        end
        switch sel
            case 'Yes'
                % Overwrite, but keep per-file prompting so the
                % user can still skip individual conflicts.
                app.AggregateOverwriteMode_ = '';
                app.appendResultsBrowserLog('  user chose: Yes — overwrite (with per-file prompts)');
            case 'No'
                app.AggregateOverwriteMode_ = 'none';
                app.appendResultsBrowserLog('  user chose: No — keep all existing aggregates');
            case 'All'
                app.AggregateOverwriteMode_ = 'all';
                app.appendResultsBrowserLog('  user chose: All — overwrite everything without prompts');
            otherwise
                app.appendResultsBrowserLog('Aggregate: cancelled by user.');
                app.renderResultsBrowserPreviewPlaceholder('idle');
                return
        end
    end

    % Resolve channel display names (leaf folder name) once,
    % matching what aggregateOneChannel uses as its `chan` key
    % when calling the progress callback. These names are also
    % what createAggregateProgressGrid keys the bar map by.
    channelLeafNames = cell(1, numel(channels));
    for ci = 1:numel(channels)
        if iscell(channels), spec = channels{ci}; else, spec = channels(ci); end
        if isKey(filesByChannel, spec)
            channelLeafNames{ci} = spec;
        else
            [~, channelLeafNames{ci}] = fileparts(spec);
        end
    end

    % Pre-build one progress bar per channel, stacked vertically.
    % tickAggregateProgress swaps each bar's N / LabelPrefix as that
    % channel moves through its (cat, stage) sequence.
    app.createAggregateProgressGrid(channelLeafNames);

    for ci = 1:numel(channels)
        if ischar(channels) || iscell(channels)
            chSpec = channels{ci};
        else
            chSpec = channels(ci);
        end
        if isKey(filesByChannel, chSpec)
            chDir   = fullfile(root, chSpec);
            chFiles = filesByChannel(chSpec);
        else
            chDir   = chSpec;   % legacy path: full channel directory
            chFiles = {};
        end
        app.aggregateOneChannel(chDir, aggregatesRoot, [], chFiles, selectedFmts);
    end

    app.destroyAggregateProgressGrid();
    app.appendResultsBrowserLog('Aggregate: done.');
    app.renderResultsBrowserPreviewPlaceholder('idle');
    % Surgical refresh: re-scan only aggregates/ and splice the
    % new subtree into the existing cache. Avoids re-reading the
    % JSONL and re-building the whole tree, which was O(N) in
    % entries and slow on large trees (e.g. 730 subjects on SMB).
    app.refreshAggregatesNodeInCache(root);
    % Refresh the Aggregate Data tab now (and reveal it if it
    % was hidden) so the listbox reflects the new aggregate
    % files immediately.
    app.updateAggregateDataTabVisibility(true);
end
