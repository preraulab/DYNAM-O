function runApp()
%RUNAPP  Launch the DYNAM-O GUI (DYNAMOFileManager).
%
%   Sets up the headless path (toolbox), then adds the GUI tree
%   (app/ — class folder, +results_browser/ package, components/) and
%   launches the file-manager window. This is the canonical entrypoint
%   for the desktop application and the natural mcc -m compile target.

    DYNAMO_addpath();
    repo_root = fileparts(mfilename('fullpath'));
    app_dir = fullfile(repo_root, 'app');
    if isfolder(app_dir)
        addpath(genpath(app_dir));
    end
    DYNAMOFileManager();
end
