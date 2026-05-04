function node = scanDirIntoCache(app, dirPath, displayName, depth)
    %SCANDIRTOCACHE  Recursively walk a JSONL-uncataloged root
    %   folder (aggregates/, logs/, settings/) into a
    %   walk_to_cache-shaped node. Caps protect against
    %   accidentally diving into a deep or huge tree on slow
    %   network shares — when a cap trips, the offending subdir
    %   becomes an empty placeholder the user can still open in
    %   the OS.
    %
    %   Caps:
    %     MaxDepth   = 4  (root → channel → axis → bin/file)
    %     MaxEntries = 500 entries per folder
    MaxDepth   = 4;
    MaxEntries = 500;

    node = struct('name', displayName, 'path', dirPath, ...
                  'isDir', true, ...
                  'dirs', {{}}, ...
                  'files', struct('name',{},'path',{}));
    try
        entries = dir(dirPath);
    catch
        return
    end
    if isempty(entries), return, end
    if numel(entries) > MaxEntries
        app.logResultsBrowser(sprintf( ...
            '  (skipping %s - %d entries exceeds cap of %d; %s)', ...
            displayName, numel(entries), MaxEntries, ...
            'shown as a folder placeholder'));
        return
    end
    isDirFlag = [entries.isdir];
    allNames  = {entries.name};
    keepDir   = isDirFlag & ~ismember(allNames, {'.','..'}) ...
                          & ~startsWith(allNames, '.');
    keepFile  = ~isDirFlag & ~startsWith(allNames, '.');

    subDirNames = sort(allNames(keepDir));
    subDirs = cell(1, numel(subDirNames));
    for ii = 1:numel(subDirNames)
        subPath = fullfile(dirPath, subDirNames{ii});
        if depth + 1 >= MaxDepth
            subDirs{ii} = struct( ...
                'name', subDirNames{ii}, 'path', subPath, ...
                'isDir', true, ...
                'dirs', {{}}, ...
                'files', struct('name',{},'path',{}));
        else
            subDirs{ii} = app.scanDirIntoCache( ...
                subPath, subDirNames{ii}, depth + 1);
        end
    end
    node.dirs = subDirs;

    fileNames = sort(allNames(keepFile));
    if ~isempty(fileNames)
        filePaths = cellfun( ...
            @(n) fullfile(dirPath, n), fileNames, ...
            'UniformOutput', false);
        node.files = struct('name', fileNames, 'path', filePaths);
    end
end
