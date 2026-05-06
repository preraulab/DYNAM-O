function names = init_DYNAMO(varargin)
%INIT_DYNAMO  Bring the DYNAM-O repo to a known-good initial state.
%
%   Single entrypoint for path setup and class-cache reset. Replaces the
%   former DYNAMO_addpath / clearDynamoClasses pair.
%
%   Usage:
%       init_DYNAMO()                  % headless addpath (toolbox + repo root)
%       init_DYNAMO('gui')             % also addpath app/ (GUI tree)
%       init_DYNAMO('clear')           % also evict DYNAM-O classdef cache
%       init_DYNAMO('clear','gui')     % both
%
%   Returns the list of class names that were evicted from the MATLAB
%   class cache (empty unless 'clear' was passed).
%
%   'clear' is the surgical alternative to `clear classes`: it drops
%   every class declared inside this repository (top-level classdefs,
%   class folders @<Name>/, and any classdef files under submodules
%   like CSSuicontrols), and leaves third-party classes, base-workspace
%   variables, breakpoints, and timers from other tools untouched. It
%   WILL still delete live instances of the cleared classes (e.g., an
%   open DYNAMOApp) — the cache and live instances are coupled
%   in MATLAB. Uses `clear classdef <name>` on R2022b+ and falls back
%   to `clear <name>` on older releases.
%
%   For a GUI launch, prefer runApp() (which calls init_DYNAMO('clear','gui')
%   and then opens the file manager).

    flags = lower(string(varargin));
    do_clear = any(flags == "clear");
    do_gui   = any(flags == "gui");

    repo_root = fileparts(mfilename('fullpath'));
    names = {};

    % --- Optional: evict cached DYNAM-O classes BEFORE addpath, so the
    %     fresh path immediately re-resolves classdefs from disk.
    if do_clear
        names = collectClassNames(repo_root);
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

    % --- Headless path: toolbox + repo root.
    if isempty(which('computeTFPeaks'))
        addpath(genpath(fullfile(repo_root, 'toolbox')));
    end
    addpath(repo_root);

    % --- Optional: GUI tree.
    if do_gui
        app_dir = fullfile(repo_root, 'app');
        if isfolder(app_dir)
            addpath(genpath(app_dir));
        end
    end
end

function names = collectClassNames(repo_root)
    names = {};

    % Class folders: any directory named @<ClassName>.
    cf = dir(fullfile(repo_root, '**', '@*'));
    cf = cf([cf.isdir]);
    for k = 1:numel(cf)
        nm = cf(k).name;
        if numel(nm) > 1 && nm(1) == '@'
            names{end+1} = nm(2:end); %#ok<AGROW>
        end
    end

    % classdef files: scan the first non-comment line of every .m file.
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
