function createDYNAMOSettingsTab(app)
    % createDYNAMOSettingsTab  Embed the DYNAMOOptions sub-app into the settings tab.
    %
    %   Calls DYNAMOOptionsApp to populate DYNAMOSettingsGrid with the
    %   DYNAM-O parameter controls. The 'false' arguments suppress
    %   standalone figure creation.

    app.DYNAMOOptionsApp(false, app.UIFigure, app.DYNAMOSettingsGrid, false);
end
