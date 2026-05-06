function updateReferenceInput(app)
    % updateReferenceInput  Parse the reference edit field into
    % a cell array of 'NAME = expr' strings. Same paren/$-aware
    % comma split as updateChannelInput, so 'R1 = mean(A1, A2)'
    % stays one entry. The composer is the primary writer; this
    % parses any subsequent in-place edits the user makes after
    % the field is enabled.
    app.ReferenceList = app.splitTopLevelCommas(app.ReferenceEditField.Value);
end
