function addDataFiles(app, filePaths)
    % addDataFiles  Programmatically append EDF files to the data list.
    %
    %   addDataFiles(app, filePaths)
    %
    %   Input:
    %     filePaths – char or cell array of char, full file path(s) to add

    if ~iscell(filePaths), filePaths = {filePaths}; end
    filePaths = setdiff(filePaths, app.DataList, 'stable');
    app.DataList = [app.DataList, filePaths];
    updateDataListBox(app);
end
