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
%   This is what gets recorded in run-log JSONL entries and what a
%   compiled standalone reports.

    v = 'unknown';
    here = fileparts(mfilename('fullpath'));
    try
        [st, out] = system(sprintf( ...
            'git -C "%s" rev-parse --short HEAD 2>/dev/null', here));
        if st ~= 0; return; end
        sha = strtrim(out);
        if isempty(sha); return; end

        [stb, outb] = system(sprintf( ...
            'git -C "%s" rev-parse --abbrev-ref HEAD 2>/dev/null', here));
        if stb == 0
            branch = strtrim(outb);
        else
            branch = '';
        end
        if isempty(branch) || strcmp(branch, 'HEAD')
            branch = 'detached';
        end

        [std, outd] = system(sprintf( ...
            'git -C "%s" status --porcelain --untracked-files=no 2>/dev/null', here));
        dirty = (std == 0) && ~isempty(strtrim(outd));

        if dirty
            v = sprintf('%s@%s.dirty', branch, sha);
        else
            v = sprintf('%s@%s', branch, sha);
        end
    catch
    end
end
