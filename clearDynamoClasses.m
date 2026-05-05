function names = clearDynamoClasses()
%CLEARDYNAMOCLASSES  Evict only DYNAM-O class definitions from MATLAB's cache.
%
%   names = clearDynamoClasses() drops every class declared inside this
%   repository (top-level classdefs, class folders @<Name>/, and any
%   classdef files under submodules like CSSuicontrols) from the MATLAB
%   class cache. Returns the names that were targeted.
%
%   This is the surgical alternative to `clear classes`. It leaves
%   third-party classes, base-workspace variables, breakpoints, and timers
%   from other tools untouched. It WILL still delete live instances of the
%   cleared classes (e.g., an open DYNAMOFileManager) — the cache and live
%   instances are coupled in MATLAB.
%
%   Uses `clear classdef <name>` on R2022b+ and falls back to `clear <name>`
%   on older releases.

    repo_root = fileparts(mfilename('fullpath'));
    names = {};

    % --- Class folders: any directory named @<ClassName> ---
    cf = dir(fullfile(repo_root, '**', '@*'));
    cf = cf([cf.isdir]);
    for k = 1:numel(cf)
        nm = cf(k).name;
        if numel(nm) > 1 && nm(1) == '@'
            names{end+1} = nm(2:end); %#ok<AGROW>
        end
    end

    % --- classdef files: scan the first non-comment line of every .m ---
    mfiles = dir(fullfile(repo_root, '**', '*.m'));
    for k = 1:numel(mfiles)
        folder = mfiles(k).folder;
        if contains(folder, [filesep '.git' filesep]) || endsWith(folder, [filesep '.git'])
            continue
        end
        nm = scanClassdefName(fullfile(folder, mfiles(k).name));
        if ~isempty(nm)
            names{end+1} = nm; %#ok<AGROW>
        end
    end

    names = unique(names);

    % --- Clear each, preferring targeted `clear classdef` ---
    for k = 1:numel(names)
        try
            evalin('base', sprintf('clear classdef %s', names{k}));
        catch
            try
                evalin('base', sprintf('clear %s', names{k}));
            catch
            end
        end
    end
end

function nm = scanClassdefName(path)
    nm = '';
    fid = fopen(path, 'r');
    if fid < 0; return; end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    for line_idx = 1:200  % bail after enough lines to clear preamble comments
        line = fgetl(fid);
        if ~ischar(line); return; end
        t = strtrim(line);
        if isempty(t) || t(1) == '%'; continue; end
        tok = regexp(t, '^classdef(?:\s*\([^)]*\))?\s+(\w+)', 'tokens', 'once');
        if ~isempty(tok)
            nm = tok{1};
        end
        return  % first non-comment, non-blank line decides (classdef or function)
    end
end
