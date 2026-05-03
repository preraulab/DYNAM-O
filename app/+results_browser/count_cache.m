function [nDirs, nFiles] = count_cache(node)
%COUNT_CACHE  Total directories and files in a walk_to_cache struct.
    import results_browser.*
nDirs  = 1;
nFiles = numel(node.files);
for ii = 1:numel(node.dirs)
    [d, f]  = count_cache(node.dirs{ii});
    nDirs   = nDirs  + d;
    nFiles  = nFiles + f;
end
end

