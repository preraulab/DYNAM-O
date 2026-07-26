function renderResultsBrowserPreviewError(app, root)
    % Full-text explanation for an invalid results folder, rendered
    % into the right-hand preview pane (the "big window") instead
    % of cluttering the tree.
    app.ResultsBrowserPreviewTitle.Text = 'INVALID RESULTS FOLDER';
    delete(app.ResultsBrowserPreviewBody.Children);

    ta = app.createFillTextArea(app.ResultsBrowserPreviewBody);
    ta.FontName        = 'Helvetica';
    ta.FontSize        = 13;
    ta.FontColor       = [0.30 0.34 0.40];
    ta.BackgroundColor = [1 1 1];

    lines = {
        'Not a DYNAM-O_results folder.'
        ''
        sprintf('Selected: %s', root)
        ''
        'A valid DYNAM-O_results folder is one produced by the DYNAMOApp'
        'batch run. Each save category is independently optional, so this'
        'folder is accepted if ANY of the following is present:'
        ''
        '  • settings/batch_settings_*.json             (always emitted by a run)'
        ''
        '  • a channel subdirectory containing any of:'
        '       param_basis/        — parametric power/phase fit tables'
        '       SOPHs/              — SO-Power and SO-Phase histograms'
        '       TFpeaks/            — time-frequency peak tables'
        '       spline_basis/       — spline-basis fit outputs'
        '       figures/            — saved figures'
        '       auxiliary_data/     — auxiliary outputs'
        ''
        '  • aggregates/<channel>/ containing any of:'
        '       param_basis_power/  param_basis_phase/'
        '       SOPHs_power/        SOPHs_phase/'
        '       spline_basis_power/ spline_basis_phase/'
        '       TFpeaks/  figures/  auxiliary_data/'
        ''
        'Pick the top-level results folder (the one that contains the channel'
        'subdirs and/or the settings/ folder), then press Enter.'
        };
    ta.Value = lines;
end
