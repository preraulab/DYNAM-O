function node = dynamo_walk_results(rootDir)
%DYNAMO_WALK_RESULTS  Recursive walk of a DYNAM-O results tree.
%
%   node = dynamo_walk_results(rootDir) walks rootDir and returns a
%   nested struct describing every directory and file under it. The
%   shape matches what the GUI's progress walker produces, so the same
%   downstream consumer (dynamo_seed_index_from_cache) accepts either:
%
%       node.name   char  — leaf directory name
%       node.path   char  — absolute path
%       node.isDir  logical — true (always, this returns dirs only)
%       node.dirs   cell of node structs (sorted by name)
%       node.files  struct array with fields {name, path}
%
%   This is the headless / CLI counterpart to walk_to_cache_progress.
%   It performs no UI updates, no heartbeat, no per-subdir timing — use
%   it from scripts and from dynamo_seed_index. The GUI keeps its
%   progress-reporting variant under app/+results_browser/ so a slow
%   network drive shows status while the user waits.
%
%   Filters out dotfiles and the `_runs/` infrastructure directory so
%   the walker shape matches what the GUI tree displays.
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

    arguments
        rootDir (1,:) char
    end

    [~, baseName] = fileparts(rootDir);
    if isempty(baseName), baseName = rootDir; end
    node = struct('name', baseName, 'path', rootDir, 'isDir', true, ...
                  'dirs', {{}}, 'files', struct('name',{},'path',{}));

    [dirNames, fileNames] = local_list_dir(rootDir);
    if isempty(dirNames) && isempty(fileNames), return, end

    dirs = cell(1, numel(dirNames));
    for ii = 1:numel(dirNames)
        dirs{ii} = dynamo_walk_results(fullfile(rootDir, dirNames{ii}));
    end
    node.dirs  = dirs;
    node.files = local_make_file_struct(rootDir, fileNames);
end


function [dirNames, fileNames] = local_list_dir(dirPath)
    entries = dir(dirPath);
    if isempty(entries), dirNames = {}; fileNames = {}; return, end
    names = {entries.name};
    keep  = ~startsWith(names, '.') & ~strcmp(names, '_runs');
    if ~any(keep), dirNames = {}; fileNames = {}; return, end
    isDir = [entries.isdir];
    isDir = isDir(keep);
    names = names(keep);
    dirNames  = sort(names(isDir));
    fileNames = sort(names(~isDir));
end


function fs = local_make_file_struct(dirPath, fileNames)
    n = numel(fileNames);
    if n == 0, fs = struct('name',{},'path',{}); return, end
    paths = cell(1, n);
    sep = filesep;
    for ii = 1:n
        paths{ii} = [dirPath sep fileNames{ii}];
    end
    fs = struct('name', fileNames, 'path', paths);
end
