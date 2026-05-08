function applyBatchSettings(app, S)
    % applyBatchSettings  Push a saved batch_settings struct back into the GUI.
    %
    %   applyBatchSettings(app, S)
    %
    %   Reverse of collectBatchSettings: takes the struct emitted by
    %   collectBatchSettings (typically round-tripped through generate_run_log
    %   and load_run_log) and applies every field to the corresponding
    %   GUI control.
    %
    %   Path validation:
    %     - data_files / staging_files / output_dir are checked with isfile /
    %       isfolder. Missing entries are dropped from the list (file lists)
    %       or left blank (output_dir), and a uifigure listbox dialog
    %       summarises what was skipped at the end.
    %
    %   Tolerant of missing top-level fields: only fields present in S are
    %   applied, so partial / older payloads still work.
    %
    %   See also: collectBatchSettings, loadBatchSettingsFromFile.
    %
    % =====================================================================
    %                   DYNAM-O Toolbox  |  Prerau Laboratory
    % =====================================================================

    if nargin < 2 || ~isstruct(S), return; end

    missing_data    = {};
    missing_staging = {};
    missing_outdir  = '';

    % --- File lists ------------------------------------------------------
    if isfield(S, 'data_files')
        files = normalizeStrCell(S.data_files);
        validMask = false(size(files));
        for k = 1:numel(files)
            validMask(k) = ~isempty(files{k}) && isfile(files{k});
        end
        valid   = files(validMask);
        missing = files(~validMask);
        missing = missing(~cellfun('isempty', missing));
        app.DataList = reshape(cellstr(valid), 1, []);
        missing_data = reshape(cellstr(missing), 1, []);
        app.updateDataListBox();
    end

    if isfield(S, 'staging_files')
        files = normalizeStrCell(S.staging_files);
        validMask = false(size(files));
        for k = 1:numel(files)
            validMask(k) = ~isempty(files{k}) && isfile(files{k});
        end
        valid   = files(validMask);
        missing = files(~validMask);
        missing = missing(~cellfun('isempty', missing));
        app.StagingList = reshape(cellstr(valid), 1, []);
        missing_staging = reshape(cellstr(missing), 1, []);
        app.updateStagingListBox();
    end

    % --- Output directory -----------------------------------------------
    if isfield(S, 'output_dir')
        od = char(S.output_dir);
        if ~isempty(od) && isfolder(od)
            app.OutputDirEditField.Value = od;
            try, app.onOutputDirChanged(); catch, end
        elseif ~isempty(od)
            missing_outdir = od;
        end
    end

    % --- Save toggles ---------------------------------------------------
    if isfield(S, 'save_toggles') && isstruct(S.save_toggles)
        t = S.save_toggles;
        setLogical(t, 'save_logs',          app.SaveLogsSwitch);
        setLogical(t, 'save_spline_images', app.SaveSplineImagesCheckBox);
        setLogical(t, 'save_param_images',  app.SaveParamImagesCheckBox);
        setLogical(t, 'save_data_summary',  app.SaveDataSummaryCheckBox);
        setLogical(t, 'save_aux_data',      app.SaveAuxDataCheckBox);
        setLogical(t, 'save_spline_basis',  app.SaveSplineBasisCheckBox);
        setLogical(t, 'save_param_basis',   app.SaveParamBasisCheckBox);
        setLogical(t, 'save_sophs',         app.SaveSOPHsCheckBox);
        setLogical(t, 'save_peak_stats',    app.SavePeakStatsCheckBox);
    end

    % --- Format dropdowns -----------------------------------------------
    if isfield(S, 'formats') && isstruct(S.formats)
        f = S.formats;
        setDropdown(f, 'spline_figures',      app.SplineFiguresDropDown);
        setDropdown(f, 'parametric_figures',  app.ParametricFiguresDropDown);
        setDropdown(f, 'data_summary',        app.DataSummaryDropDown);
        setDropdown(f, 'auxiliary_data',      app.AuxiliaryDataDropDown);
        setDropdown(f, 'spline_basis',        app.SplineBasisDropDown);
        setDropdown(f, 'parametric_basis',    app.ParametricBasisDropDown);
        setDropdown(f, 'so_power_histograms', app.SOPowerHistogramsDropDown);
        setDropdown(f, 'peak_stats_table',    app.PeakStatsTableDropDown);
    end

    % --- Runtime --------------------------------------------------------
    if isfield(S, 'runtime') && isstruct(S.runtime)
        r = S.runtime;
        setLogical(r, 'overwrite_existing', app.OverwriteExistingFilesCheckBox);
        setLogical(r, 'run_in_reverse',     app.RunInReverse);
    end

    % --- Channels / Reference -------------------------------------------
    if isfield(S, 'channels') && isstruct(S.channels)
        c = S.channels;
        setText(c, 'channel_spec',   app.ChannelEditField);
        setText(c, 'reference_spec', app.ReferenceEditField);
        try, app.refreshChannelTooltips(); catch, end
        try, app.updateChannelInput();     catch, end
        try, app.updateReferenceInput();   catch, end
    end

    % --- Staging CSV config ---------------------------------------------
    if isfield(S, 'staging_config') && isstruct(S.staging_config)
        sc = S.staging_config;
        setDropdown(sc, 'delimiter',     app.DelimeterOptionField);
        setNumeric(sc,  'header_rows',   app.HeaderRowsEditField);
        setNumeric(sc,  'times_column',  app.TimesColumnEditField);
        setNumeric(sc,  'stages_column', app.StagesColumnEditField);
        setLogical(sc,  'resample_on',   app.ResampleSwitch);
        setNumeric(sc,  'resample_fs',   app.ResampleFsEditField);
        try, app.onResampleSwitchChanged(); catch, end
        try, app.updateDelimeterInput();    catch, end
    end

    % --- Stage label mappings -------------------------------------------
    if isfield(S, 'stage_labels') && isstruct(S.stage_labels)
        sl = S.stage_labels;
        setText(sl, 'Wake',     app.WakeEditField);
        setText(sl, 'REM',      app.REMEditField);
        setText(sl, 'N1',       app.N1EditField);
        setText(sl, 'N2',       app.N2EditField);
        setText(sl, 'N3',       app.N3EditField);
        setText(sl, 'Unknown',  app.UnknownEditField);
        setText(sl, 'Artifact', app.ArtifactEditField);
        try, app.updateStagesInput(); catch, end
    end

    try, app.refreshSOHistogramsAvailability(); catch, end

    % Re-run the full pre-flight validation now that everything is set.
    % Programmatic .Value writes don't fire ValueChangedFcn, so the
    % per-field clearIsError handlers wired in finalizeUI never run on
    % load — stale red-border IsError flags from before the load would
    % otherwise persist. updateRunErrorList re-validates from scratch
    % and rebuilds app.run_error_list, which is what the Run button
    % gates on.
    try, app.updateRunErrorList(); catch, end

    % --- Surface skipped paths ------------------------------------------
    if ~isempty(missing_data) || ~isempty(missing_staging) || ~isempty(missing_outdir)
        showMissingPathsDialog(app, missing_data, missing_staging, missing_outdir);
    end
end


% =========================================================================
% Helpers
% =========================================================================

function setLogical(S, fname, ctrl)
    if isfield(S, fname)
        try
            ctrl.Value = logical(S.(fname));
        catch
        end
    end
end

function setNumeric(S, fname, ctrl)
    if isfield(S, fname)
        try
            ctrl.Value = double(S.(fname));
        catch
        end
    end
end

function setText(S, fname, ctrl)
    if isfield(S, fname)
        try
            ctrl.Value = char(string(S.(fname)));
        catch
        end
    end
end

function setDropdown(S, fname, ctrl)
    if ~isfield(S, fname), return; end
    val = char(string(S.(fname)));
    items = {};
    try, items = ctrl.Items; catch, end
    if isempty(items) || any(strcmp(items, val))
        try, ctrl.Value = val; catch, end
    end
end

function out = normalizeStrCell(v)
    % Accept char, string array, cellstr, or column of any of the above.
    % Return a row cell array of char.
    if isempty(v)
        out = {};
        return
    end
    if ischar(v)
        out = {v};
    elseif isstring(v)
        out = cellstr(v);
    elseif iscell(v)
        out = cellfun(@(x) char(string(x)), v, 'UniformOutput', false);
    else
        out = {char(string(v))};
    end
    out = reshape(out, 1, []);
end

function showMissingPathsDialog(app, missing_data, missing_staging, missing_outdir)
    win = uifigure('Name', 'Batch Settings: Missing Paths', 'Position', [200 200 760 420]);
    try, app.trackChildWindow(win); catch, end

    g = uigridlayout(win, [4 2]);
    g.RowHeight   = {30, '1x', '1x', 30};
    g.ColumnWidth = {'1x', '1x'};

    hdrTxt = 'Some paths in the loaded settings file are missing on this machine. They were skipped.';
    hdr = uilabel(g, 'Text', hdrTxt, 'FontWeight', 'bold');
    hdr.Layout.Row = 1; hdr.Layout.Column = [1 2];

    lblD = uilabel(g, 'Text', sprintf('Skipped data files (%d):', numel(missing_data)));
    lblD.Layout.Row = 2; lblD.Layout.Column = 1;
    lbD  = uilistbox(g, 'Items', defaultIfEmpty(missing_data));
    lbD.Layout.Row = 3; lbD.Layout.Column = 1;

    lblS = uilabel(g, 'Text', sprintf('Skipped staging files (%d):', numel(missing_staging)));
    lblS.Layout.Row = 2; lblS.Layout.Column = 2;
    lbS  = uilistbox(g, 'Items', defaultIfEmpty(missing_staging));
    lbS.Layout.Row = 3; lbS.Layout.Column = 2;

    if ~isempty(missing_outdir)
        footer = uilabel(g, 'Text', sprintf('Output directory not found (left blank): %s', missing_outdir), ...
            'FontAngle', 'italic');
    else
        footer = uilabel(g, 'Text', '');
    end
    footer.Layout.Row = 4; footer.Layout.Column = [1 2];
end

function items = defaultIfEmpty(items)
    if isempty(items)
        items = {'(none)'};
    end
end
