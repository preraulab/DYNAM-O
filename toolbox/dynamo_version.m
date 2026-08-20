function [v, legacy] = dynamo_version()
%DYNAMO_VERSION  DYNAM-O toolbox build identity for provenance stamping
%
%   Usage:
%       [v, legacy] = dynamo_version()
%
%   Inputs:
%       none
%
%   Outputs:
%       v      : char - toolbox build in the DYNAM-O provenance grammar
%                '<semver>+<sha12>[.dirty]' (DesktopApp OUTPUT_FORMAT.md
%                section 8.1), e.g. '1.0.0+ab12cd34ef56.dirty'. The semver
%                comes from DYNAMO_TOOLBOX_VERSION and the sha12 is the
%                current commit. Falls back to the literal 'unknown' when
%                git metadata is unavailable (compiled standalone, source
%                exported without .git).
%       legacy : char - display string '<branch>@<sha7>[.dirty]'
%                ('detached@...' on a detached HEAD), or 'unknown'. For
%                banners and console output only. Never write it into
%                artifacts: branch names do not belong in provenance
%                stamps.
%
%   Notes:
%       Two strategies, in order:
%         1. shell out to git (with -c safe.directory='*' to bypass
%            dubious-ownership refusals on shared filesystems);
%         2. parse .git/HEAD + .git/refs by hand. Works without git on
%            the PATH and regardless of directory ownership. Skips dirty
%            detection (no cheap way to compare the working tree to the
%            index without git).
%       Both outputs are derived from the same branch/sha/dirty triple,
%       so they always describe the same commit.
%
%   Example:
%       stamp.writer_version = dynamo_version();
%
%   See also: DYNAMO_TOOLBOX_VERSION, dynamo_kernel_version, dynamo_stamp
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

    v = 'unknown';
    legacy = 'unknown';
    here = fileparts(mfilename('fullpath'));

    % Strategy 1: git, with safe.directory override.
    try
        [ok, branch, sha, dirty] = readViaGit(here);
        if ok
            [v, legacy] = formatVersion(branch, sha, dirty);
            return
        end
    catch
    end

    % Strategy 2: parse .git/HEAD + refs by hand.
    try
        [ok, branch, sha] = readViaFiles(here);
        if ok
            [v, legacy] = formatVersion(branch, sha, false);
            return
        end
    catch
    end
end

% ------------------------------------------------------------------
function [ok, branch, sha, dirty] = readViaGit(here)
%READVIAGIT  Read branch/sha/dirty by shelling out to git
%
%   Inputs:
%       here : char - directory inside the repo to run git from -- required
%
%   Outputs:
%       ok     : logical - true when git produced a usable sha
%       branch : char - branch name, or 'detached'
%       sha    : char - 12-hex-digit abbreviated commit sha
%       dirty  : logical - true when tracked files have uncommitted changes
    ok = false; branch = ''; sha = ''; dirty = false;
    base = sprintf('git -C "%s" -c safe.directory=''*''', here);

    % 12 hex digits is the stamp grammar's sha width (sha12). --short=12
    % asks for exactly that many unless more are needed for uniqueness.
    [st, out] = system([base ' rev-parse --short=12 HEAD 2>/dev/null']);
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
%READVIAFILES  Read branch/sha by parsing .git metadata directly
%
%   Inputs:
%       here : char - directory to start the .git search from -- required
%
%   Outputs:
%       ok     : logical - true when a sha was resolved
%       branch : char - branch name, or 'detached'
%       sha    : char - commit sha truncated to 12 hex digits
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
                for kk = 1:numel(lines)
                    line = strtrim(lines{kk});
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
        % Detached HEAD: HEAD is a raw SHA.
        if numel(head) >= 7 && all(isstrprop(head, 'xdigit'))
            sha = head;
            branch = 'detached';
        end
    end

    if isempty(sha); return; end
    % File-based reads yield the full 40-char sha; truncate to the
    % stamp grammar's 12 hex digits.
    if numel(sha) > 12
        sha = sha(1:12);
    end
    ok = true;
end

% ------------------------------------------------------------------
function root = findGitRoot(start)
%FINDGITROOT  Walk up from start until a .git dir/file is found
%
%   Inputs:
%       start : char - directory to start the upward walk from -- required
%
%   Outputs:
%       root : char - repo root containing .git, or '' if none found
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
%READTEXTFILE  Slurp a small text file, returning '' on open failure
%
%   Inputs:
%       path : char - file to read -- required
%
%   Outputs:
%       txt : char - file contents (may be '')
    fid = fopen(path, 'r');
    if fid < 0
        txt = ''; return
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    txt = fread(fid, inf, 'uint8=>char')';
end

% ------------------------------------------------------------------
function [v, legacy] = formatVersion(branch, sha, dirty)
%FORMATVERSION  Compose the stamp-grammar and display version strings
%
%   Inputs:
%       branch : char - branch name (or 'detached') -- required
%       sha    : char - 12-hex-digit sha -- required
%       dirty  : logical - append '.dirty' when true -- required
%
%   Outputs:
%       v      : char - '<semver>+<sha12>[.dirty]' or 'unknown'
%       legacy : char - '<branch>@<sha7>[.dirty]' or 'unknown'
    if isempty(branch) || isempty(sha)
        v = 'unknown'; legacy = 'unknown'; return
    end
    suffix = '';
    if dirty
        suffix = '.dirty';
    end
    v = sprintf('%s+%s%s', DYNAMO_TOOLBOX_VERSION(), sha, suffix);
    % Legacy display form keeps the familiar 7-char abbreviation.
    legacy = sprintf('%s@%s%s', branch, sha(1:min(7, numel(sha))), suffix);
end
