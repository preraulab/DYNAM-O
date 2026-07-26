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
%       init_DYNAMO('force')           % bypass session cache; redo everything
%
%   Returns the list of class names that were evicted from the MATLAB
%   class cache (empty unless 'clear' was passed and there was something
%   to evict).
%
%   Performance notes:
%     - Within a single MATLAB session this function is idempotent and
%       cheap on the second-and-later calls. It remembers (in a
%       persistent) the repo it has already initialized, so a redundant
%       call with the same flags returns in microseconds.
%     - The 'clear' scan (which opens every .m file in the repo to look
%       for `classdef`) only happens once per session. Subsequent
%       'clear' calls reuse the cached classname list.
%     - 'force' resets the session cache and re-walks everything. Use
%       after pulling new files or renaming classes mid-session.
%
%   'clear' is the surgical alternative to `clear classes`: it drops
%   every class declared inside this repository (top-level classdefs,
%   class folders @<Name>/, and any classdef files under submodules
%   like CSSuicontrols), and leaves third-party classes, base-workspace
%   variables, breakpoints, and timers from other tools untouched. It
%   WILL still delete live instances of the cleared classes (e.g., an
%   open DYNAMOApp) — the cache and live instances are coupled in
%   MATLAB. Uses `clear classdef <name>` on R2022b+ and falls back
%   to `clear <name>` on older releases.

    persistent done_root done_gui classnames_cache
    if isempty(done_gui), done_gui = false; end

    flags    = lower(string(varargin));
    do_clear = any(flags == "clear");
    do_gui   = any(flags == "gui");
    do_force = any(flags == "force");

    repo_root = fileparts(mfilename('fullpath'));
    names     = {};

    if do_force
        done_root        = '';
        done_gui         = false;
        classnames_cache = [];
    end

    already_for_this_repo = ~isempty(done_root) && strcmp(done_root, repo_root);

    % Fast path: same MATLAB session already initialized this repo, the
    % caller didn't ask for a class-cache wipe, and either no GUI was
    % requested or the GUI tree was already added in a prior call.
    if already_for_this_repo && ~do_clear && (~do_gui || done_gui)
        return
    end

    % --- Optional: clear cache. Reuse the cached classname list when
    %     available; the contents only change when the repo gains or
    %     loses classes, which doesn't happen inside a session.
    if do_clear
        if isempty(classnames_cache)
            classnames_cache = collectClassNames(repo_root);
        end
        names = classnames_cache;
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
    if do_gui && (~done_gui || do_clear || do_force)
        app_dir = fullfile(repo_root, 'app');
        if isfolder(app_dir)
            addpath(genpath(app_dir));
        end
        done_gui = true;
    end

    done_root = repo_root;
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
