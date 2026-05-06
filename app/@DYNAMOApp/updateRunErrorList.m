function updateRunErrorList(app)
    % updateRunErrorList  Populate run_error_list with any blocking validation issues.
    %   Also sets IsError on related CSSui components to highlight problems visually.
    %
    %   Checks the following conditions and appends a descriptive message
    %   to app.run_error_list for each failure:
    %     - DataList is empty
    %     - StagingList is empty
    %     - No output directory specified
    %     - Data and staging file counts do not match
    %     - Stages column not specified
    %     - Times column not specified
    %     - Header rows not specified
    %     - No channels selected
    %     - Any listed file does not exist on disk

    app.run_error_list = {};  % Clear before re-validating

    % Clear all component error states before re-evaluating
    app.DataListBox.IsError           = false;
    app.StagingListBox.IsError        = false;
    app.OutputDirEditField.IsError    = false;
    app.StagesColumnEditField.IsError = false;
    app.TimesColumnEditField.IsError  = false;
    app.HeaderRowsEditField.IsError   = false;
    app.ViewChannelsButton.IsError    = false;
    app.ArtifactEditField.IsError     = false;
    app.WakeEditField.IsError         = false;
    app.REMEditField.IsError          = false;
    app.N1EditField.IsError           = false;
    app.N2EditField.IsError           = false;
    app.N3EditField.IsError           = false;

    if isempty(app.DataList)
        app.run_error_list(end+1) = {'- Data list empty. Need edf files to run.'};
        app.DataListBox.IsError = true;
    end

    if isempty(app.OutputDirEditField.Value)
        app.run_error_list(end+1) = {'- No output directory given. Need somewhere to save files.'};
        app.OutputDirEditField.IsError = true;
    end

    if ~isempty(app.StagingList) && length(app.DataList) ~= length(app.StagingList)
        app.run_error_list(end+1) = {strcat('- Number of data files (', ...
            num2str(length(app.DataList)), ...
            ') does not match staging files (', ...
            num2str(length(app.StagingList)), ').')};
        app.DataListBox.IsError    = true;
        app.StagingListBox.IsError = true;
    end

    if isempty(app.StagesColumnEditField.Value)
        app.run_error_list(end+1) = {'- No staging column given in the staging file.'};
        app.StagesColumnEditField.IsError = true;
    end

    if isempty(app.TimesColumnEditField.Value)
        app.run_error_list(end+1) = {'- No times column given in the staging file.'};
        app.TimesColumnEditField.IsError = true;
    end

    if isempty(app.HeaderRowsEditField.Value)
        app.run_error_list(end+1) = {'- No header rows given in the staging file.'};
        app.HeaderRowsEditField.IsError = true;
    end

    % Channel field is read-only; the composer is the only
    % writer. So the failure mode is "user never opened the
    % composer", which we surface by reddening the launcher
    % button rather than the (greyed-out) text field.
    if isempty(app.ChannelList)
        app.run_error_list(end+1) = {'- No channels selected.'};
        app.ViewChannelsButton.IsError = true;
    end

    % Check that required stage label fields are not empty
    stage_label_fields = {'Artifact','Wake','REM','N1','N2','N3'};
    for ii = 1:numel(stage_label_fields)
        name = stage_label_fields{ii};
        c = app.([name 'EditField']);
        if isempty(strtrim(c.Value))
            app.run_error_list(end+1) = {['- ' name ' stage label is empty.']};
            c.IsError = true;
        end
    end

    % Check that every file in both lists actually exists on disk
    allFiles = [app.DataList(:); app.StagingList(:)];
    missing  = allFiles(~isfile(allFiles));

    if ~isempty(missing)
        app.run_error_list{end+1} = sprintf('Missing files:\n%s', strjoin(missing, '\n'));
        app.DataListBox.IsError    = true;
        app.StagingListBox.IsError = true;
    end
end
