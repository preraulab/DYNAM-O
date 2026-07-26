function pickResultsBrowserDirViaDialog(app)
    % pickResultsBrowserDirViaDialog  Folder picker for the Results Browser tab.
    % Auto-loads the tree once a folder is chosen.
    startDir = char(app.ResultsBrowserOutputDirField.Value);
    if isempty(startDir) || ~isfolder(startDir), startDir = pwd; end
    folder = uigetdir(startDir, 'Select results directory');
    if folder ~= 0
        app.ResultsBrowserOutputDirField.Value = folder;
        app.loadResultsBrowserTree();
    end
end
