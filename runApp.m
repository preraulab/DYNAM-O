function runApp()
%RUNAPP  Launch the DYNAM-O GUI (DYNAMOApp).
%
%   Sniffs whether init is actually needed: if DYNAMOApp, runDYNAMO,
%   and computeTFPeaks all resolve to files inside THIS repo, the
%   path is already in the right state and we skip init_DYNAMO
%   entirely (saves several seconds on second-and-later launches).
%   Otherwise calls init_DYNAMO('clear','gui') for a full setup —
%   the 'clear' flag guards against stale shadowing classes (e.g.
%   an old CSSuiTable from a sibling repo loaded earlier in the
%   session) that would otherwise persist into the new GUI.
%
%   To force a full re-init mid-session — e.g. after pulling new
%   class files — call init_DYNAMO('force') first.

    if needsInit()
        init_DYNAMO('clear', 'gui');
    end
    DYNAMOApp();
end

function tf = needsInit()
    repo_root = fileparts(mfilename('fullpath'));
    needed = {'DYNAMOApp', 'runDYNAMO', 'computeTFPeaks'};
    for k = 1:numel(needed)
        p = which(needed{k});
        if isempty(p) || ~startsWith(p, repo_root)
            tf = true; return
        end
    end
    tf = false;
end
