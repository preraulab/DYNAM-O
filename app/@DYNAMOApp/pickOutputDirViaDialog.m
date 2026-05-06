function pickOutputDirViaDialog(app)
    % pickOutputDirViaDialog  Open a folder picker and set the output directory field.
    %
    %   After selection, delegates to onOutputDirChanged to validate/create
    %   the directory if it does not yet exist.

    folder = uigetdir;
    if folder ~= 0
        app.OutputDirEditField.IsError = false;
        app.OutputDirEditField.Value   = folder;
        onOutputDirChanged(app);
    end
end
