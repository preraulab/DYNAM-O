function DYNAMO_addpath()
%DYNAMO_ADDPATH  Headless path setup for the DYNAM-O science toolbox.
%
%   Adds toolbox/ (and the repo root, so DYNAMO.m / runDYNAMO.m resolve)
%   to the MATLAB path. Does NOT add app/ or app/components/ — those
%   carry the GUI and its CSSuicontrols submodule, which a headless run
%   does not need on path.
%
%   For a GUI launch, use runApp() instead.

    repo_root = fileparts(mfilename('fullpath'));
    if isempty(which('computeTFPeaks'))
        addpath(genpath(fullfile(repo_root, 'toolbox')));
    end
    addpath(repo_root);
end
