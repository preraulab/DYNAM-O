function finalizeUI(app)
    %finalizeUI  Final pass after every tab is built: creates the Help
    %   menu (last so it lands rightmost), reveals the figure, applies the
    %   font, and wires tooltips / clear-on-change handlers on the batch
    %   fields.
    % ---- Help Menu (created last so it appears rightmost) ----
    app.HelpMenu      = uimenu(app.UIFigure);
    app.HelpMenu.Text = 'Help';

    app.HelpMenuItem = uimenu(app.HelpMenu);
    app.HelpMenuItem.MenuSelectedFcn = @(~,~) showHelpButtonPushed(app);
    app.HelpMenuItem.Text = 'Help';

    app.AboutMenu = uimenu(app.HelpMenu);
    app.AboutMenu.MenuSelectedFcn = createCallbackFcn(app, @AboutMenuSelected, true);
    app.AboutMenu.Text = 'About DYNAM-O...';
    app.AboutMenu.Separator = 'on';

    % NOTE: figure stays Visible='off' here. The constructor flips it on
    % once at the very end (after applyQuickFill + drawnow) so the user
    % never sees the window mid-population.
    app.applyFont;   % propagate FontName to all controls

    % ============================================================
    %   TOOLTIPS
    % ============================================================

    % Channel + reference tooltips reflect current state and are
    % refreshed from updateChannelTooltips on every composer commit.
    app.updateChannelTooltips();
    app.DelimeterOptionField.HTMLComponent.Tooltip       = 'Select delimiter used in the staging file';

    % Apply tooltips to all stage label fields programmatically
    stage_label_list = {'Artifact','Wake','REM','N1','N2','N3','Unknown'};
    for ii = 1:length(stage_label_list)
        tt = ['Comma separated list of labels used to identify ''' stage_label_list{ii} ''' within the staging file'];
        app.([stage_label_list{ii} 'EditField']).HTMLComponent.Tooltip      = tt;
        app.([stage_label_list{ii} 'EditFieldLabel']).HTMLComponent.Tooltip = tt;
    end

    app.StagesColumnEditField.HTMLComponent.Tooltip      = 'Column of the staging CSV containing the stage labels';
    app.StagesColumnEditFieldLabel.HTMLComponent.Tooltip = 'Column of the staging CSV containing the stage labels';
    app.TimesColumnEditField.HTMLComponent.Tooltip       = 'Column of the staging CSV containing the time of each stage';
    app.TimesColumnEditFieldLabel.HTMLComponent.Tooltip  = 'Column of the staging CSV containing time of each stage';
    app.HeaderRowsEditField.HTMLComponent.Tooltip        = 'Number of header rows in the stage file';
    app.HeaderRowsEditFieldLabel.HTMLComponent.Tooltip   = 'Number of header rows in the stage file';
    app.ResampleSwitch.HTMLComponent.Tooltip             = 'Resample the EEG data to the specified frequency before processing';
    app.ResampleFsEditField.HTMLComponent.Tooltip        = 'Target sampling frequency in Hz for resampling';
    app.ResampleFsEditFieldLabel.HTMLComponent.Tooltip   = 'Target sampling frequency in Hz for resampling';

    % Wire ValueChangedFcn on all validated fields so errors clear
    % immediately when the user corrects the value.
    % ChannelEditField is intentionally absent: the composer is the
    % single writer for that field, and run-time validation surfaces
    % "no channels" by reddening the launcher button (ViewChannelsButton)
    % rather than the (read-only) channel field. Wiring this field's
    % ValueChangedFcn here would do nothing useful since the user
    % cannot type into it.
    clearFields = { ...
        app.OutputDirEditField, ...
        app.StagesColumnEditField, ...
        app.TimesColumnEditField, ...
        app.HeaderRowsEditField ...
    };
    for ii = 1:numel(clearFields)
        c = clearFields{ii};
        c.ValueChangedFcn = @(~,~) clearIsError(app, c);
    end

    stage_label_fields = {'Artifact','Wake','REM','N1','N2','N3'};
    for ii = 1:numel(stage_label_fields)
        c = app.([stage_label_fields{ii} 'EditField']);
        c.ValueChangedFcn = @(~,~) clearIsError(app, c);
    end
end
