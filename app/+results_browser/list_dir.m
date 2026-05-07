function [dirNames, fileNames] = list_dir(dirPath)
%LIST_DIR  One dir() call → sorted (dirs, files) name lists. Filters out
%   dotfiles and DYNAM-O infrastructure (_runs/) so the user-facing tree
%   shows only result content.
entries = dir(dirPath);
if isempty(entries)
    dirNames = {}; fileNames = {}; return
end
names    = {entries.name};
keep     = ~startsWith(names, '.') & ~strcmp(names, '_runs');
if ~any(keep)
    dirNames = {}; fileNames = {}; return
end
isDir    = [entries.isdir];
isDir    = isDir(keep);
names    = names(keep);
dirNames  = sort(names(isDir));
fileNames = sort(names(~isDir));
end

