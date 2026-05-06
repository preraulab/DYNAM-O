function v = dynamo_version()
%DYNAMO_VERSION  Return the DYNAM-O build identifier.
%
%   Returns '<branch>@<short_sha>' for a source-tree build, with a
%   '.dirty' suffix when there are uncommitted changes. For example:
%       'file-manager-overhaul@25f7d8b'         - clean source-tree build
%       'file-manager-overhaul@25f7d8b.dirty'   - tree has uncommitted changes
%       'detached@25f7d8b'                      - detached HEAD (no branch)
%       'unknown'                               - compiled standalone / non-git
%
%   Two strategies, in order:
%     1. shell out to `git` (with -c safe.directory='*' to bypass
%        dubious-ownership refusals on shared filesystems);
%     2. fall back to parsing .git/HEAD + .git/refs/heads/<branch> by
%        hand. Doesn't require git on the PATH and doesn't care who
%        owns the directory. Skips dirty detection (no cheap way to
%        compare working tree to index without git).
%
%   This is what gets recorded in run-log JSONL entries and what a
%   compiled standalone reports.

    v = 'unknown';
    here = fileparts(mfilename('fullpath'));

    % Strategy 1: git, with safe.directory override.
    try
        [ok, branch, sha, dirty] = readViaGit(here);
        if ok
            v = formatVersion(branch, sha, dirty);
            return
        end
    catch
    end

    % Strategy 2: parse .git/HEAD + refs by hand.
    try
        [ok, branch, sha] = readViaFiles(here);
        if ok
            v = formatVersion(branch, sha, false);
            return
        end
    catch
    end
end

% ------------------------------------------------------------------
function [ok, branch, sha, dirty] = readViaGit(here)
    ok = false; branch = ''; sha = ''; dirty = false;
    base = sprintf('git -C "%s" -c safe.directory=''*''', here);

    [st, out] = system([base ' rev-parse --short HEAD 2>/dev/null']);
    if st ~= 0; return; end
    sha = strtrim(out);
    if isempty(sha); return; end

    [stb, outb] = system([base ' rev-parse --abbrev-ref HEAD 2>/dev/null']);
    if stb == 0
        branch = strtrim(outb);
    end
    if isempty(branch) || strcmp(branch, 'HEAD')
        branch = 'detached';
    end

    [std, outd] = system([base ' status --porcelain --untracked-files=no 2>/dev/null']);
    dirty = (std == 0) && ~isempty(strtrim(outd));
    ok = true;
end

% ------------------------------------------------------------------
function [ok, branch, sha] = readViaFiles(here)
    ok = false; branch = ''; sha = '';
    root = findGitRoot(here);
    if isempty(root); return; end

    headPath = fullfile(root, '.git', 'HEAD');
    if ~isfile(headPath)
        % .git might be a file (submodule / worktree). Read it to
        % find the real gitdir.
        gd = fullfile(root, '.git');
        if isfile(gd)
            txt = readTextFile(gd);
            tok = regexp(strtrim(txt), '^gitdir:\s*(.*)$', 'tokens', 'once');
            if isempty(tok); return; end
            gitdir = tok{1};
            if ~isfolder(gitdir)
                gitdir = fullfile(root, gitdir);
            end
            headPath = fullfile(gitdir, 'HEAD');
            if ~isfile(headPath); return; end
        else
            return
        end
    end
    head = strtrim(readTextFile(headPath));

    refTok = regexp(head, '^ref:\s*(.+)$', 'tokens', 'once');
    if ~isempty(refTok)
        ref = strtrim(refTok{1});
        branch = regexprep(ref, '^refs/heads/', '');
        % Resolve the branch ref to a SHA. Two locations to try:
        % .git/refs/heads/<branch> (loose) or .git/packed-refs (packed).
        refPath = fullfile(fileparts(headPath), ref);
        if isfile(refPath)
            sha = strtrim(readTextFile(refPath));
        else
            packed = fullfile(fileparts(headPath), 'packed-refs');
            if isfile(packed)
                lines = strsplit(readTextFile(packed), newline);
                for k = 1:numel(lines)
                    line = strtrim(lines{k});
                    if isempty(line) || startsWith(line, '#') || startsWith(line, '^'); continue, end
                    parts = strsplit(line);
                    if numel(parts) >= 2 && strcmp(parts{2}, ref)
                        sha = parts{1};
                        break
                    end
                end
            end
        end
    else
        % Detached HEAD — HEAD is a raw SHA.
        if numel(head) >= 7 && all(isstrprop(head, 'xdigit'))
            sha = head;
            branch = 'detached';
        end
    end

    if isempty(sha); return; end
    if numel(sha) > 7
        sha = sha(1:7);
    end
    ok = true;
end

% ------------------------------------------------------------------
function root = findGitRoot(start)
    p = start;
    while true
        if exist(fullfile(p, '.git'), 'dir') || exist(fullfile(p, '.git'), 'file')
            root = p; return
        end
        parent = fileparts(p);
        if isempty(parent) || strcmp(parent, p)
            root = ''; return
        end
        p = parent;
    end
end

% ------------------------------------------------------------------
function txt = readTextFile(path)
    fid = fopen(path, 'r');
    if fid < 0
        txt = ''; return
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    txt = fread(fid, inf, 'uint8=>char')';
end

% ------------------------------------------------------------------
function v = formatVersion(branch, sha, dirty)
    if isempty(branch) || isempty(sha)
        v = 'unknown'; return
    end
    if dirty
        v = sprintf('%s@%s.dirty', branch, sha);
    else
        v = sprintf('%s@%s', branch, sha);
    end
end
