function addStagingFiles(app, filePaths)
    % addStagingFiles  Programmatically append staging files to the staging list.
    %
    %   addStagingFiles(app, filePaths)
    %
    %   Input:
    %     filePaths – char or cell array of char, full file path(s) to add

    if ~iscell(filePaths), filePaths = {filePaths}; end
    filePaths = setdiff(filePaths, app.StagingList, 'stable');
    app.StagingList = [app.StagingList, filePaths];
    updateStagingListBox(app);
end
