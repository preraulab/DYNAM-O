function [node, state] = walk_to_cache_state(dirPath, state)
%WALK_TO_CACHE_STATE  Recursive walk that threads a heartbeat/timing
%state struct so the UI can show what's happening on slow drives.
    import results_browser.*
[~, baseName] = fileparts(dirPath);
if isempty(baseName), baseName = dirPath; end
node = struct('name', baseName, 'path', dirPath, 'isDir', true, ...
              'dirs', {{}}, 'files', struct('name',{},'path',{}));

state.totalDirs = state.totalDirs + 1;
if ~isempty(state.logFn) && toc(state.lastBeat) > state.beatEverySec
    rel = strrep(dirPath, state.rootPath, '');
    if isempty(rel), rel = '.'; elseif rel(1) == filesep, rel(1) = []; end
    state.logFn(sprintf('      … listing %s', rel));
    state.lastBeat = tic;
    drawnow;
end

tList = tic;
[dirNames, fileNames] = list_dir(dirPath);
listSec = toc(tList);
state.totalListSec = state.totalListSec + listSec;
if listSec > 5 && ~isempty(state.logFn)
    rel = strrep(dirPath, state.rootPath, '');
    if isempty(rel), rel = '.'; elseif rel(1) == filesep, rel(1) = []; end
    state.logFn(sprintf('         (%.1fs to list %s)', listSec, rel));
    drawnow;
end
if isempty(dirNames) && isempty(fileNames), return, end

dirs = cell(1, numel(dirNames));
for ii = 1:numel(dirNames)
    [dirs{ii}, state] = walk_to_cache_state(fullfile(dirPath, dirNames{ii}), state);
end
node.dirs  = dirs;
node.files = make_file_struct(dirPath, fileNames);
end

