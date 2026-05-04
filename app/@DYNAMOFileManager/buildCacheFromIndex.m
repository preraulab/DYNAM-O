function cache = buildCacheFromIndex(app, root, idx)
    %BUILDCACHEFROMINDEX  Synthesize a walk_to_cache-shaped struct
    %   from the JSONL index, with no recursive filesystem walk.
    %   Each entry's `files` list is binned by directory; folders
    %   the index doesn't know about (settings/, figures/, logs/,
    %   aggregates/) are filled in via shallow per-folder dir()
    %   calls so the user can still browse them. The returned
    %   cache has the same shape as walk_to_cache_progress so
    %   downstream tree rendering, preview, and aggregate code
    %   keeps working unchanged.
    %
    %   On a 730-subject SMB tree this drops load time from the
    %   30-45 minute recursive walk to ~5 seconds.

    [~, baseName] = fileparts(root);
    if isempty(baseName), baseName = root; end
    cache = struct('name', baseName, 'path', root, 'isDir', true, ...
                   'dirs', {{}}, 'files', struct('name',{},'path',{}));

    % --- Phase 1: bin every cataloged file path by its parent dir.
    % keyToDir maps "C3/SOPHs" → struct('files', {{paths...}}).
    % Channels that show up in any path become the top-level dirs.
    chanMap = containers.Map('KeyType','char','ValueType','any');
    for ii = 1:numel(idx.entries)
        e = idx.entries{ii};
        if ~isfield(e,'files') || isempty(e.files), continue, end
        for jj = 1:numel(e.files)
            relPath = char(e.files{jj});
            relPath = strrep(relPath, '\', '/');
            parts = strsplit(relPath, '/');
            if numel(parts) < 2, continue, end
            chanName = parts{1};
            catName  = parts{2};
            fname    = parts{end};
            if ~isKey(chanMap, chanName)
                chanMap(chanName) = containers.Map( ...
                    'KeyType','char','ValueType','any');
            end
            catMap = chanMap(chanName);
            if ~isKey(catMap, catName)
                catMap(catName) = {};
            end
            fpaths = catMap(catName);
            fullPath = fullfile(root, parts{:});
            fpaths{end+1} = struct('name', fname, 'path', fullPath); %#ok<AGROW>
            catMap(catName) = fpaths;
            chanMap(chanName) = catMap;
        end
    end

    % --- Phase 2: for each channel known from the index, build
    % the channel node. After populating its index-cataloged
    % category subdirs, do ONE shallow dir() to find any extra
    % subfolders the index doesn't track (figures/ etc.) and
    % include them as folder-only nodes the user can expand.
    chanNames = sort(chanMap.keys);
    chanDirs = cell(1, numel(chanNames));
    for ic = 1:numel(chanNames)
        chanName = chanNames{ic};
        chanPath = fullfile(root, chanName);
        catMap = chanMap(chanName);

        catNames = sort(catMap.keys);
        catDirs  = cell(1, numel(catNames));
        for is = 1:numel(catNames)
            catName = catNames{is};
            catPath = fullfile(chanPath, catName);
            fileStructs = catMap(catName);
            fileNames = cellfun(@(s) s.name, fileStructs, 'UniformOutput', false);
            filePaths = cellfun(@(s) s.path, fileStructs, 'UniformOutput', false);
            % Drop entries whose path does not exist on disk. The
            % synth in dynamo_files_for_components is conservative
            % (lists every companion the run COULD produce), but
            % users can choose .mat-only or .tiff-only at run
            % time, and legacy JSONLs may have stale entries from
            % an earlier synth bug. Filtering here keeps the tree
            % from showing leaves that resolve to "File not
            % found" when clicked.
            keep = cellfun(@(p) isfile(p), filePaths);
            fileNames = fileNames(keep);
            filePaths = filePaths(keep);
            % Sort files by name for stable display
            [fileNames, sortIdx] = sort(fileNames);
            filePaths = filePaths(sortIdx);
            catDirs{is} = struct( ...
                'name', catName, 'path', catPath, 'isDir', true, ...
                'dirs', {{}}, ...
                'files', struct('name', fileNames, 'path', filePaths));
        end

        % Detect non-cataloged subdirs (figures, etc.) at the
        % channel level and scan their contents so the user can
        % browse them. scanDirIntoCache caps depth (4) and entries
        % per folder (500), which keeps huge SMB trees from
        % re-introducing the latency the JSONL was designed to
        % avoid — but populates the realistic case (a handful of
        % per-subject PNGs) so the user can preview them.
        extraDirs = app.listShallowDirsExcept( ...
            chanPath, [{'.','..','_runs'}, catNames]);
        for ie = 1:numel(extraDirs)
            extraName = extraDirs{ie};
            catDirs{end+1} = app.scanDirIntoCache( ...
                fullfile(chanPath, extraName), extraName, 0); %#ok<AGROW>
        end

        chanDirs{ic} = struct( ...
            'name', chanName, 'path', chanPath, 'isDir', true, ...
            'dirs', {catDirs}, ...
            'files', struct('name',{},'path',{}));
    end

    % --- Phase 3: at the root, the index-known channels plus any
    % other root-level dirs (aggregates/, settings/, logs/) found
    % via a single shallow dir() at root.
    extraRootDirs = app.listShallowDirsExcept( ...
        root, [{'.','..','_runs'}, chanNames]);
    allRootDirs = [chanDirs, cell(1, numel(extraRootDirs))];
    for ie = 1:numel(extraRootDirs)
        extraName = extraRootDirs{ie};
        tScan = tic;
        allRootDirs{numel(chanDirs)+ie} = app.scanDirIntoCache( ...
            fullfile(root, extraName), extraName, 0);
        app.logResultsBrowser(sprintf( ...
            'Scanned %s/ (%.2fs)', extraName, toc(tScan)));
    end
    cache.dirs = allRootDirs;
end
