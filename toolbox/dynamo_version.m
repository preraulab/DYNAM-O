function v = dynamo_version()
%DYNAMO_VERSION  Return the DYNAM-O release + build version string.
%
%   Format follows SemVer build metadata: '<release>+<sha>[.dirty]'.
%   For example:
%       '1.0.0'                 - compiled standalone (no git tree)
%       '1.0.0+25f7d8b'         - source-tree build at commit 25f7d8b
%       '1.0.0+25f7d8b.dirty'   - source tree with uncommitted changes
%
%   This is what gets recorded in run-log JSONL entries and what a
%   compiled standalone reports. Bump the release constant on release.

    release = '1.0.0';

    sha = '';
    dirty = false;
    here = fileparts(mfilename('fullpath'));
    try
        [st, out] = system(sprintf( ...
            'git -C "%s" rev-parse --short HEAD 2>/dev/null', here));
        if st == 0
            sha = strtrim(out);
            [st2, out2] = system(sprintf( ...
                'git -C "%s" status --porcelain --untracked-files=no 2>/dev/null', here));
            if st2 == 0 && ~isempty(strtrim(out2))
                dirty = true;
            end
        end
    catch
    end

    if isempty(sha)
        v = release;
    elseif dirty
        v = sprintf('%s+%s.dirty', release, sha);
    else
        v = sprintf('%s+%s', release, sha);
    end
end
