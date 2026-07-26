function S = collectBatchSettings(app)
    % collectBatchSettings  Snapshot the GUI batch-level state into a struct.
    %
    %   S = collectBatchSettings(app)
    %
    %   Returns a struct that captures every user-configurable batch-run
    %   field shown in the DYNAM-O Batch Run tab — data/staging file lists,
    %   output dir, save toggles, format dropdowns, channel/reference,
    %   staging CSV config, stage label mappings, and runtime options.
    %   No UI side effects.
    %
    %   The struct round-trips through generate_run_log / load_run_log and
    %   applyBatchSettings, so it is the canonical "reloadable batch
    %   settings" payload.
    %
    %   Note on construction: struct(field, value, ...) collapses to a 0x0
    %   struct array when any value is empty (the MATLAB "empty value
    %   pitfall"). That silently dropped the whole sub-block from the
    %   serialised JSON whenever a user hadn't set a numeric/string field
    %   yet. We use direct field assignment everywhere here to avoid that.
    %
    %   See also: applyBatchSettings, generate_run_log, load_run_log.
    %
    % =====================================================================
    %                   DYNAM-O Toolbox  |  Prerau Laboratory
    % =====================================================================

    S = struct();

    % Force row cellstr so the JSON encoder writes a flat array.
    S.data_files    = reshape(cellstr(app.DataList),    1, []);
    S.staging_files = reshape(cellstr(app.StagingList), 1, []);
    S.output_dir    = char(app.OutputDirEditField.Value);
    S.metadata_file = char(app.MetadataFile_);

    S.save_toggles = struct();
    S.save_toggles.save_logs           = logical(app.SaveLogsSwitch.Value);
    S.save_toggles.save_spline_images  = logical(app.SaveSplineImagesCheckBox.Value);
    S.save_toggles.save_param_images   = logical(app.SaveParamImagesCheckBox.Value);
    S.save_toggles.save_data_summary   = logical(app.SaveDataSummaryCheckBox.Value);
    S.save_toggles.save_aux_data       = logical(app.SaveAuxDataCheckBox.Value);
    S.save_toggles.save_spline_basis   = logical(app.SaveSplineBasisCheckBox.Value);
    S.save_toggles.save_param_basis    = logical(app.SaveParamBasisCheckBox.Value);
    S.save_toggles.save_sophs          = logical(app.SaveSOPHsCheckBox.Value);
    S.save_toggles.save_peak_stats     = logical(app.SavePeakStatsCheckBox.Value);

    S.formats = struct();
    S.formats.spline_figures      = char(app.SplineFiguresDropDown.Value);
    S.formats.parametric_figures  = char(app.ParametricFiguresDropDown.Value);
    S.formats.data_summary        = char(app.DataSummaryDropDown.Value);
    S.formats.auxiliary_data      = char(app.AuxiliaryDataDropDown.Value);
    S.formats.spline_basis        = char(app.SplineBasisDropDown.Value);
    S.formats.parametric_basis    = char(app.ParametricBasisDropDown.Value);
    S.formats.so_power_histograms = char(app.SOPowerHistogramsDropDown.Value);
    S.formats.peak_stats_table    = char(app.PeakStatsTableDropDown.Value);

    S.runtime = struct();
    S.runtime.overwrite_existing = logical(app.OverwriteExistingFilesCheckBox.Value);
    S.runtime.run_in_reverse     = logical(app.RunInReverse.Value);

    S.channels = struct();
    S.channels.channel_spec   = char(app.ChannelEditField.Value);
    S.channels.reference_spec = char(app.ReferenceEditField.Value);

    % Direct assignment is critical here: any of the numeric fields can be
    % empty before the user touches them, and struct(...) with an empty
    % value collapses the whole sub-struct to 0x0 — the prior bug that
    % silently stripped staging_config from saved JSONs.
    S.staging_config = struct();
    S.staging_config.delimiter     = char(app.DelimeterOptionField.Value);
    S.staging_config.header_rows   = scalar_or_nan_(app.HeaderRowsEditField.Value);
    S.staging_config.times_column  = scalar_or_nan_(app.TimesColumnEditField.Value);
    S.staging_config.stages_column = scalar_or_nan_(app.StagesColumnEditField.Value);
    S.staging_config.resample_on   = logical(app.ResampleSwitch.Value);
    S.staging_config.resample_fs   = scalar_or_nan_(app.ResampleFsEditField.Value);

    S.stage_labels = struct();
    S.stage_labels.Wake     = char(app.WakeEditField.Value);
    S.stage_labels.REM      = char(app.REMEditField.Value);
    S.stage_labels.N1       = char(app.N1EditField.Value);
    S.stage_labels.N2       = char(app.N2EditField.Value);
    S.stage_labels.N3       = char(app.N3EditField.Value);
    S.stage_labels.Unknown  = char(app.UnknownEditField.Value);
    S.stage_labels.Artifact = char(app.ArtifactEditField.Value);
end


function v = scalar_or_nan_(x)
    % Numeric field passthrough that converts MATLAB-empty (`[]`, the
    % default of an unset CSSuiNumericField) to NaN. NaN survives JSON
    % round-trip via the encode_specials sentinel ("__nan__") so the
    % distinction "field never set" carries through to the load side,
    % where applyBatchSettings's setNumeric coerces NaN back to empty
    % via the no-op double() / clamp() chain in CSSuiNumericField.
    if isempty(x)
        v = NaN;
    else
        v = double(x);
    end
end
