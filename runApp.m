function runApp()
%RUNAPP  Launch the DYNAM-O GUI (DYNAMOFileManager).
%
%   Sets up the headless path (toolbox), then adds the GUI tree
%   (app/ — class folder, +results_browser/ package, components/) and
%   launches the file-manager window. This is the canonical entrypoint
%   for the desktop application and the natural mcc -m compile target.
%
%   Evicts only DYNAM-O class definitions (via clearDynamoClasses) so a
%   stale class cached from a shadowing copy elsewhere on the path
%   — e.g. an old CSSuiTable from a sibling repo loaded earlier in the
%   session — cannot persist into the new GUI. Third-party classes,
%   base-workspace variables, and breakpoints from other tools are
%   left alone. Live DYNAM-O instances (an already-open file manager)
%   will be cleared along with the cache.

    clearDynamoClasses();
    DYNAMO_addpath();
    repo_root = fileparts(mfilename('fullpath'));
    app_dir = fullfile(repo_root, 'app');
    if isfolder(app_dir)
        addpath(genpath(app_dir));
    end
    DYNAMOFileManager();
end
