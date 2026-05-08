function refreshEdfLabelCache(app, varargin)
    % refreshEdfLabelCache  Bring app.EdfLabelCache_ in sync with app.DataList.
    %
    %   refreshEdfLabelCache(app)
    %   refreshEdfLabelCache(app, 'ShowProgress', mode, ...)
    %
    %   Path-keyed cache of EDF header information so the channel
    %   composer, the run-time pre-flight check, and the progress-bar
    %   sizing all share one inventory of "what labels live in which
    %   files". For each path in app.DataList that is missing from the
    %   cache (or stale relative to disk mtime when CheckMtime is on),
    %   reads the EDF header via read_EDF and stores
    %   {labels, fs, mtime}. Prunes entries for paths no longer in
    %   DataList. Idempotent — call it liberally.
    %
    %   Name-Value options:
    %     'ShowProgress' (char) — visibility mode for the scan UI:
    %       'auto'        : uiprogressdlg on app.UIFigure when
    %                       nNewFiles >= ShowProgressThreshold,
    %                       silent otherwise. Default.
    %       'force'       : always show the uiprogressdlg, even for
    %                       a single file or a fully-warm cache (so the
    %                       user gets a "pre-flight running" beat
    %                       before the real run).
    %       'silent'      : never show. Test hook.
    %       'progressbar' : drive the main app.ProgressBar instead of
    %                       a uiprogressdlg. Used by the run-start
    %                       defensive scan since the user is already
    %                       looking at that bar.
    %
    %     'ShowProgressThreshold' (numeric, default 10) — the new-file
    %       count above which 'auto' mode shows progress. Below this,
    %       'auto' stays silent.
    %
    %     'ProgressMessage' (char, default 'Scanning EDF headers...') —
    %       the title of the progress UI.
    %
    %     'CheckMtime' (logical, default false) — when true, also
    %       re-scans cached entries whose on-disk mtime is newer than
    %       the cached one. Off by default because remote-storage
    %       stat() can be slow.
    %
    %   See also: simulateChannelResolution, createRunMontageWindow.
    %
    % =====================================================================
    %                   DYNAM-O Toolbox  |  Prerau Laboratory
    % =====================================================================

    p = inputParser;
    p.CaseSensitive = false;
    addParameter(p, 'ShowProgress', 'auto', @(x) ischar(x) || isstring(x));
    addParameter(p, 'ShowProgressThreshold', 10, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'ProgressMessage', 'Scanning EDF headers...', @(x) ischar(x) || isstring(x));
    addParameter(p, 'CheckMtime', false, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});
    showMode      = char(lower(string(p.Results.ShowProgress)));
    showThreshold = p.Results.ShowProgressThreshold;
    progressMsg   = char(p.Results.ProgressMessage);
    checkMtime    = p.Results.CheckMtime;

    if isempty(app.EdfLabelCache_) || ~isa(app.EdfLabelCache_, 'containers.Map')
        app.EdfLabelCache_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
    end

    paths = reshape(cellstr(app.DataList), 1, []);

    % --- Prune entries no longer in DataList ----------------------------
    pathSet = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    for k = 1:numel(paths), pathSet(paths{k}) = true; end
    cachedKeys = keys(app.EdfLabelCache_);
    nPruned = 0;
    for k = 1:numel(cachedKeys)
        if ~pathSet.isKey(cachedKeys{k})
            remove(app.EdfLabelCache_, cachedKeys{k});
            nPruned = nPruned + 1;
        end
    end

    % --- Decide which paths need (re)scanning ---------------------------
    toScan = false(1, numel(paths));
    for k = 1:numel(paths)
        p_ = paths{k};
        if ~app.EdfLabelCache_.isKey(p_)
            toScan(k) = true;
            continue
        end
        if checkMtime
            entry = app.EdfLabelCache_(p_);
            try
                d = dir(p_);
                if isempty(d) || datetime(d.datenum, 'ConvertFrom', 'datenum') > entry.mtime
                    toScan(k) = true;
                end
            catch
                % stat failed — leave entry alone, user gets the cached version
            end
        end
    end
    nNewFiles = sum(toScan);

    if nNewFiles == 0 && ~strcmp(showMode, 'force')
        % Cache fully warm. If files were pruned (deletion-only update),
        % the user still wants to see the new coverage numbers.
        if nPruned > 0
            try, app.reportChannelCoverage(); catch, end
        end
        return
    end

    % --- Set up progress UI ---------------------------------------------
    [progressKind, dlg] = openProgressUI(app, showMode, showThreshold, ...
        nNewFiles, progressMsg);
    cleanupProgress = onCleanup(@() closeProgressUI(progressKind, dlg, app)); %#ok<NASGU>

    if nNewFiles == 0
        % 'force' mode with a fully-warm cache: still log the heading so
        % the run log shows a "pre-flight" beat.
        try, app.TextArea.addnl(sprintf('%s (cache warm — 0 files to scan).', progressMsg)); catch, end
        return
    end

    try, app.TextArea.addnl(sprintf('%s (%d file(s))...', progressMsg, nNewFiles)); catch, end

    % --- Scan loop ------------------------------------------------------
    t0   = tic;
    done = 0;
    nScanIdx = find(toScan);
    for ii = 1:numel(nScanIdx)
        k = nScanIdx(ii);
        p_ = paths{k};

        if isCancelled(progressKind, dlg)
            try, app.TextArea.addnl(sprintf('Pre-flight cancelled after %d/%d file(s).', done, nNewFiles)); catch, end
            return
        end

        [~, base, ext] = fileparts(p_);
        progressLabel = sprintf('(%d/%d) %s%s', ii, nNewFiles, base, ext);
        updateProgressUI(progressKind, dlg, app, ii, nNewFiles, progressLabel);

        try
            [~, signalHeader] = read_EDF(p_);
            labels = cell(1, numel(signalHeader));
            fs     = nan(1, numel(signalHeader));
            for jj = 1:numel(signalHeader)
                labels{jj} = strtrim(signalHeader(jj).signal_labels);
                fs(jj)     = signalHeader(jj).sampling_frequency;
            end
            entry = struct('labels', {labels}, 'fs', fs, 'mtime', datetime('now'));
            app.EdfLabelCache_(p_) = entry;
            done = done + 1;
        catch ME
            warning('refreshEdfLabelCache:readFailed', ...
                'Failed to read EDF header: %s — %s', p_, ME.message);
        end
    end

    elapsed = toc(t0);
    try, app.TextArea.addnl(sprintf('Pre-flight complete: cached %d/%d file(s) in %.1fs.', ...
            done, nNewFiles, elapsed)); catch, end

    % Show channel coverage across the (possibly updated) file list. Same
    % report fires on add/remove via the mutation hooks at all DataList
    % write sites, so the user always sees the current numbers.
    try, app.reportChannelCoverage(); catch, end
end


% =========================================================================
% Progress-UI helpers — three back-ends share one interface so the scan
% loop above is unaware of which one is active.
% =========================================================================

function [kind, dlg] = openProgressUI(app, showMode, threshold, nNewFiles, msg)
    kind = 'none';
    dlg  = [];

    switch showMode
        case 'silent'
            return
        case 'auto'
            if nNewFiles < threshold
                return
            end
            kind = 'dlg';
        case 'force'
            kind = 'dlg';
        case 'progressbar'
            kind = 'pbar';
        otherwise
            warning('refreshEdfLabelCache:badShowProgress', ...
                'Unknown ShowProgress mode "%s"; falling back to silent.', showMode);
            return
    end

    switch kind
        case 'dlg'
            try
                dlg = uiprogressdlg(app.UIFigure, ...
                    'Title',       msg, ...
                    'Message',     'Initializing...', ...
                    'Indeterminate', 'off', ...
                    'Cancelable',  'on', ...
                    'Value',       0);
            catch
                kind = 'none';
                dlg  = [];
            end
        case 'pbar'
            try
                app.ProgressBar.reset();
                app.ProgressBar.LabelPrefix = msg;
                app.ProgressBar.N           = max(nNewFiles, 1);
                app.ProgressBar.start;
            catch
                kind = 'none';
            end
    end
end

function updateProgressUI(kind, dlg, app, ii, nNewFiles, label)
    switch kind
        case 'dlg'
            try
                dlg.Value   = ii / max(nNewFiles, 1);
                dlg.Message = label;
            catch
            end
        case 'pbar'
            try
                app.ProgressBar.LabelPrefix = label;
                app.ProgressBar.updateIteration(ii);
            catch
            end
    end
end

function closeProgressUI(kind, dlg, app)
    switch kind
        case 'dlg'
            try, if isvalid(dlg), close(dlg); end, catch, end
        case 'pbar'
            try, app.ProgressBar.reset(); catch, end
    end
end

function tf = isCancelled(kind, dlg)
    tf = false;
    if strcmp(kind, 'dlg') && ~isempty(dlg)
        try, tf = dlg.CancelRequested; catch, end
    end
end
