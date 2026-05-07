function node = walk_to_cache_progress(dirPath, logFn)
%WALK_TO_CACHE_PROGRESS  Walk the root with per-top-level-subdir timing
%lines and a "still scanning…" heartbeat that fires every few seconds
%showing the current relative path. Useful on slow/network drives where
%a single subdir can take much longer than the others.
    import results_browser.*
[~, baseName] = fileparts(dirPath);
if isempty(baseName), baseName = dirPath; end
node = struct('name', baseName, 'path', dirPath, 'isDir', true, ...
              'dirs', {{}}, 'files', struct('name',{},'path',{}));

if ~isempty(logFn)
    logFn('    Listing root folder…');
    drawnow;
end
tList = tic;
[dirNames, fileNames] = list_dir(dirPath);
listSec = toc(tList);
if ~isempty(logFn)
    logFn(sprintf('    Listed root in %.1fs (%d subdirs, %d files)', ...
        listSec, numel(dirNames), numel(fileNames)));
end
if isempty(dirNames) && isempty(fileNames), return, end

% Bubble 'aggregates' to the top — keeps it visible at the root level.
aggIdx = find(strcmp(dirNames, 'aggregates'), 1);
if ~isempty(aggIdx) && aggIdx > 1
    dirNames = dirNames([aggIdx, 1:aggIdx-1, aggIdx+1:end]);
end

state = struct('logFn',        logFn, ...
               'rootPath',     dirPath, ...
               'lastBeat',     tic, ...
               'beatEverySec', 2.0, ...
               'totalDirs',    0, ...
               'totalListSec', listSec);

nTop = numel(dirNames);
dirs = cell(1, nTop);
for ii = 1:nTop
    childPath = fullfile(dirPath, dirNames{ii});
    tChild    = tic;
    [dirs{ii}, state] = walk_to_cache_state(childPath, state);
    if ~isempty(logFn)
        [d, f] = count_cache(dirs{ii});
        logFn(sprintf('    [%5.1fs] %s  (%d folders, %d files)', ...
            toc(tChild), dirNames{ii}, d, f));
        drawnow limitrate;
    end
end
node.dirs  = dirs;
node.files = make_file_struct(dirPath, fileNames);

if ~isempty(logFn) && state.totalListSec > 0.5
    logFn(sprintf('    Total dir() time: %.1fs across %d folders', ...
        state.totalListSec, state.totalDirs + 1));
end
end

