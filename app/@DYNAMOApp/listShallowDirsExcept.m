function names = listShallowDirsExcept(~, parentDir, excludeList)
    %SHALLOWDIRSEXCEPT  One dir() call returning sorted subdir names
    %   under parentDir, with names in excludeList filtered out.
    %   Used by buildCacheFromIndex to discover folders the JSONL
    %   doesn't catalog (figures/, settings/, etc.) without doing
    %   a full recursive walk.
    names = {};
    try
        entries = dir(parentDir);
    catch
        return
    end
    if isempty(entries), return, end
    isDir = [entries.isdir];
    allNames = {entries.name};
    keep = isDir & ~ismember(allNames, excludeList) ...
        & ~startsWith(allNames, '.');
    names = sort(allNames(keep));
end
