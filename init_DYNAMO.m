function names = init_DYNAMO(varargin)
%INIT_DYNAMO  Bring the DYNAM-O repo to a known-good initial state.
%
%   Single entrypoint for path setup and class-cache reset. Replaces the
%   former DYNAMO_addpath / clearDynamoClasses pair.
%
%   Usage:
%       init_DYNAMO()                  % addpath (toolbox + repo root)
%       init_DYNAMO('clear')           % also evict DYNAM-O classdef cache
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
%   class folders @<Name>/, and any classdef files under the helper
%   submodules), and leaves third-party classes, base-workspace
%   variables, breakpoints, and timers from other tools untouched. It
%   WILL still delete live instances of the cleared classes — the cache
%   and live instances are coupled in MATLAB. Uses `clear classdef
%   <name>` on R2022b+ and falls back to `clear <name>` on older
%   releases.

    persistent done_root classnames_cache bridge_checked

    flags    = lower(string(varargin));
    do_clear = any(flags == "clear");
    do_force = any(flags == "force");

    repo_root = fileparts(mfilename('fullpath'));
    names     = {};

    if do_force
        done_root        = '';
        classnames_cache = [];
        bridge_checked   = [];
    end

    already_for_this_repo = ~isempty(done_root) && strcmp(done_root, repo_root);

    % Fast path: same MATLAB session already initialized this repo and the
    % caller didn't ask for a class-cache wipe.
    if already_for_this_repo && ~do_clear
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


    % --- Warn once per session if the committed MEX binaries are stale
    %     against the Rust source beside them. The binaries are checked in,
    %     so a pull can leave them older than the code they were built from,
    %     and the mismatch is otherwise silent: they load fine and return
    %     plausible numbers computed by the old Rust. Fails open, since a
    %     missing DYNAM-O_rs checkout is normal for an end user.
    if isempty(bridge_checked) || do_force
        bridge_checked = true;
        bridge_check = fullfile(repo_root, 'rust_bridge', 'check_rust_bridge.m');
        if isfile(bridge_check)
            try
                addpath(fullfile(repo_root, 'rust_bridge'));
                check_rust_bridge();
            catch err
                warning('init_DYNAMO:bridgeCheckFailed', ...
                    'Could not verify rust_bridge freshness: %s', err.message);
            end
        end
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
