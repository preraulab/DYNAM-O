function updateStagesInput(app)
    % updateStagesInput  Parse stage identifier edit fields into cell arrays.
    %
    %   Reads each stage label field (Artifact, Wake, REM, N1, N2, N3, Unknown),
    %   splits the comma-separated string, and stores the resulting cell arrays
    %   as app.*UserInput properties for use by load_data.

    app.ArtifactUserInput = textscan(app.ArtifactEditField.Value, '%s', 'Delimiter', ',');
    app.ArtifactUserInput = app.ArtifactUserInput{1,1};

    app.WakeUserInput = textscan(app.WakeEditField.Value, '%s', 'Delimiter', ',');
    app.WakeUserInput = app.WakeUserInput{1,1};

    app.REMUserInput = textscan(app.REMEditField.Value, '%s', 'Delimiter', ',');
    app.REMUserInput = app.REMUserInput{1,1};

    app.N1UserInput = textscan(app.N1EditField.Value, '%s', 'Delimiter', ',');
    app.N1UserInput = app.N1UserInput{1,1};

    app.N2UserInput = textscan(app.N2EditField.Value, '%s', 'Delimiter', ',');
    app.N2UserInput = app.N2UserInput{1,1};

    app.N3UserInput = textscan(app.N3EditField.Value, '%s', 'Delimiter', ',');
    app.N3UserInput = app.N3UserInput{1,1};

    app.UnknownUserInput = textscan(app.UnknownEditField.Value, '%s', 'Delimiter', ',');
    app.UnknownUserInput = app.UnknownUserInput{1,1};
end
