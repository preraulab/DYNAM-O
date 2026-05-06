function updateDataListBox(app)
    % updateDataListBox  Refresh the DataListBox items and update the file-count label.
    %
    % Both DataListBox AND StagingListBox have their IsError
    % cleared because the "files mismatch" validation reddens
    % both boxes simultaneously — fixing it from either side
    % should clear both, otherwise the un-edited box keeps a
    % stale red highlight until the next failed validation.

    app.DataListBox.IsError    = false;
    app.StagingListBox.IsError = false;
    app.DataListBox.Items = app.DataList;
    if length(app.DataList) == 1 %#ok<*ISCL>
        app.DataLabel.Text = 'DATA (1 File)';
    else
        app.DataLabel.Text = sprintf('DATA (%d Files)', length(app.DataList));
    end
end
