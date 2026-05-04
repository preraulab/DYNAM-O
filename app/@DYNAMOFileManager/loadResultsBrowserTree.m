function loadResultsBrowserTree(app)
    % loadResultsBrowserTree  Walk the chosen results root once,
    % build a JSON-friendly node tree, and hand it to the
    % CSSuiTree. All filtering thereafter is client-side (JS
    % toggles display:none on <li> nodes — no disk I/O, no
    % MATLAB rebuilds).
    import results_browser.*
    % Note: the entry-level drawnow that used to live here was a
    % first-call hot spot (~4-5s on a freshly-constructed
    % uifigure because it forced full layout before any work).
    % The status-pane logs and overlay flips below already pump
    % the event loop, so the eager flush isn't needed.
    root = strtrim(char(app.ResultsBrowserOutputDirField.Value));

    if isempty(root)
        app.ResultsBrowserCache_  = [];
        app.ResultsBrowserTree.Data = ...
            {struct('text','No results directory selected.', ...
                    'data','', 'isLeaf', true, 'children', {{}})};
        return
    end
    if ~isfolder(root)
        app.ResultsBrowserCache_  = [];
        app.ResultsBrowserTree.Data = ...
            {struct('text', sprintf('Directory not found: %s', root), ...
                    'data','', 'isLeaf', true, 'children', {{}})};
        return
    end
    if ~is_dynamo_results_dir(root)
        % Before reporting failure, see if the user pointed at a
        % parent that *contains* a DYNAM-O_results subfolder
        % (common when they pick the project root rather than
        % the results folder itself). Check the immediate child
        % first, then a single shallow scan for any descendant
        % named DYNAM-O_results — keeps the auto-correct cheap
        % on slow shares.
        cand = local_findResultsDir(root);
        if ~isempty(cand) && is_dynamo_results_dir(cand)
            app.logResultsBrowser(sprintf( ...
                'Auto-corrected to DYNAM-O_results subfolder: %s', cand));
            app.ResultsBrowserOutputDirField.Value = cand;
            root = cand;
        else
            app.ResultsBrowserCache_  = [];
            app.ResultsBrowserTree.Data = ...
                {struct('text','Invalid DYNAM-O_results folder — see preview pane.', ...
                        'data','', 'isLeaf', true, 'children', {{}})};
            app.renderResultsBrowserPreviewError(root);
            app.logResultsBrowser(sprintf('Load aborted: not a DYNAM-O_results folder: %s', root));
            return
        end
    end

    app.logResultsBrowser(sprintf('Loading %s', root));

    % Fast path: read the JSONL run index FIRST. If non-empty, the
    % tree is built directly from the index — every (subject,
    % channel) entry carries the list of output files it produced,
    % so we have an exhaustive catalog without any recursive walk.
    % The few non-cataloged folders (settings/, figures/, logs/,
    % aggregates/) get a shallow per-folder dir() to populate them.
    % On SMB this turns a 30-45 minute walk into a sub-second load.
    idx = app.readRunIndexFile(root);
    haveIndex = ~isempty(idx) && ~isempty(idx.entries);

    app.ResultsBrowserTree.Data = ...
        {struct('text','Loading directory tree…', ...
                'data','', 'isLeaf', true, 'children', {{}})};
    % Show the dancing-bars animation over the tree area while
    % the load runs. The placeholder text node still renders
    % beneath the overlay; the overlay sits on top because it
    % shares the same grid cell.
    app.ResultsTreeLoadingOverlay.HTMLSource = ...
        app.buildLoadingAnimationHtml('Loading…');
    app.ResultsTreeLoadingOverlay.Visible = 'on';
    drawnow;

    if haveIndex
        tBuild = tic;
        app.ResultsBrowserCache_ = app.buildCacheFromIndex(root, idx);
        [nDirs, nFiles] = count_cache(app.ResultsBrowserCache_);
        app.logResultsBrowser(sprintf( ...
            '  Built tree from index: %d folder(s), %d file(s) in %.2fs', ...
            nDirs, nFiles, toc(tBuild)));
        app.ResultsBrowserTree.Data = cache_to_tree_node(app.ResultsBrowserCache_);
    else
        % No index — fall back to the recursive walk + offer to
        % seed an index afterwards. Slow on SMB, but only on the
        % first load of a freshly-populated results folder.
        app.logResultsBrowser('  Scanning directory tree…');
        tStart = tic;
        app.ResultsBrowserCache_ = walk_to_cache_progress(root, ...
            @(msg) app.logResultsBrowser(msg));
        [nDirs, nFiles] = count_cache(app.ResultsBrowserCache_);
        app.logResultsBrowser(sprintf( ...
            '  Scanned %d folder(s), %d file(s) in %.2f s', ...
            nDirs, nFiles, toc(tStart)));

        app.logResultsBrowser('  Building tree…');
        drawnow;
        tBuild = tic;
        app.ResultsBrowserTree.Data = cache_to_tree_node(app.ResultsBrowserCache_);
        app.logResultsBrowser(sprintf('  Tree built in %.2f s', toc(tBuild)));
    end

    % Hide the loading overlay so the populated tree is visible.
    app.ResultsTreeLoadingOverlay.Visible = 'off';
    app.renderResultsBrowserPreviewPlaceholder();
    % Reveal the Aggregate Data tab when this root already has
    % an aggregates/ folder, otherwise keep it hidden. Refresh
    % is left lazy here (forceRefresh=false): refreshing the
    % SO-Histograms uiaxes is ~3-4s on first call, so we let
    % the tab group's SelectionChangedFcn pick it up only if
    % the user actually clicks the tab.
    app.updateAggregateDataTabVisibility(false);
    app.logResultsBrowser('Done.');

    % If no index existed at load time, offer to seed one from the
    % in-memory cache the walk just produced — no second disk pass.
    if ~haveIndex
        app.promptToSeedRunIndex(root);
    end

    % Offer to aggregate per-subject outputs into per-channel
    % stacks. Skip the prompt if the user already has an
    % aggregates/ tree under root (re-running aggregate is a
    % deliberate right-click action via the tree menu).
    if ~isfolder(fullfile(root, 'aggregates'))
        sel = uiconfirm(app.UIFigure, ...
            'Aggregate per-subject outputs into per-channel stacks now?', ...
            'Aggregate results', ...
            'Options', {'Aggregate', 'Skip'}, ...
            'DefaultOption', 1, ...
            'CancelOption', 2, ...
            'Icon', 'question');
        if strcmp(sel, 'Aggregate')
            app.aggregateResultsRoot();
        end
    end

    function r = local_findResultsDir(parent)
        % Look for a DYNAM-O_results subfolder under parent.
        % Tries the obvious immediate-child name first, then
        % falls back to a single shallow dir() scan for any
        % match (case-sensitive on POSIX, case-insensitive on
        % Windows — dir()'s native behavior). Returns '' if
        % nothing matches; the caller treats that as "no
        % auto-correct possible".
        r = '';
        direct = fullfile(parent, 'DYNAM-O_results');
        if isfolder(direct), r = direct; return, end
        d = dir(parent);
        d = d([d.isdir]);
        names = {d.name};
        hit = find(strcmpi(names, 'DYNAM-O_results'), 1);
        if ~isempty(hit)
            r = fullfile(parent, names{hit});
        end
    end
end
