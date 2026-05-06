function updateStagingListBox(app)
    % updateStagingListBox  Refresh the StagingListBox items and update the file-count label.
    % Clears IsError on both lists; see updateDataListBox.

    app.DataListBox.IsError    = false;
    app.StagingListBox.IsError = false;
    app.StagingListBox.Items = app.StagingList;
    if length(app.StagingList) == 1
        app.StagingLabel.Text = 'STAGING (1 File)';
    else
        app.StagingLabel.Text = sprintf('STAGING (%d Files)', length(app.StagingList));
    end
end
