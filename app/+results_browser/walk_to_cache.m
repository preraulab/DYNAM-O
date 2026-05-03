function node = walk_to_cache(dirPath)
%WALK_TO_CACHE  Plain recursive walk with no progress reporting.
    import results_browser.*
state = struct('logFn', [], 'rootPath', dirPath, ...
               'lastBeat', tic, 'beatEverySec', inf, ...
               'totalDirs', 0, 'totalListSec', 0);
[node, ~] = walk_to_cache_state(dirPath, state);
end

