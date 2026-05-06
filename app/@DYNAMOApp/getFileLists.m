function [dataFiles, stagingFiles] = getFileLists(app)
    % getFileLists  Return current data and staging file lists.
    %
    %   [dataFiles, stagingFiles] = getFileLists(app)
    %
    %   Outputs:
    %     dataFiles    – cell array of EDF file paths
    %     stagingFiles – cell array of staging file paths

    dataFiles    = app.DataList;
    stagingFiles = app.StagingList;
end
