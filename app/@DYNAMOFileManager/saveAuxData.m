function saveAuxData(app)
    % saveAuxData  Collect and save auxiliary analysis data for the current subject/channel.
    %
    %   Packages artifacts, sampling rate, and SO-power normalisation method
    %   into a struct and saves it to:
    %     <OutputDir>/<channel>/auxiliary_data/<fbase>_auxiliary_data_<channel>.mat
    %
    %   TO-DO: Expand to include additional auxiliary fields.

    % Channel/output dirs prepared once in runBatch; reuse cached paths
    chanDir = fullfile(app.OutputDirEditField.Value, app.channel);
    auxDir  = fullfile(chanDir, 'auxiliary_data');

    % Skip the entire stage when the .mat already exists and
    % the user hasn't asked to overwrite — saveAuxData is the
    % single-output stage where this is cheap to short-circuit.
    outPath = fullfile(auxDir, [app.input_fbase '_auxiliary_data_' app.channel '.mat']);
    overwrite = app.OverwriteExistingFilesCheckBox.Value;
    if ~overwrite && isfile(outPath)
        app.TextArea.addnl('   Skipping auxiliary data (file already exists).');
        return
    end

    % Ensure SOPHs are available (needed for SOpower_norm field)
    if isempty(app.SOPHs)
        SOPHmat = fullfile(chanDir, 'SOPHs', [app.input_fbase '_SOPHs_' app.channel '.mat']);
        if isfile(SOPHmat)
            app.SOPHs = load(SOPHmat).SOPHs;
        else
            app.anything_run = 1;
            app.TextArea.addnl('   Computing SOPHs for auxiliary data...');
            runStatsTable(app);
        end
    end

    % Package auxiliary data fields
    % TO-DO: Add additional fields (e.g. normalised power, spindle indices)
    app.auxiliary_data.artifacts             = app.artifacts;
    app.auxiliary_data.Fs                    = app.Fs;
    app.auxiliary_data.SOpower_norm_method   = app.SOPH_options.SOpower_norm_method;
    app.auxiliary_data.SOpower_norm          = app.SOPHs.SOpower_norm;
    app.auxiliary_data.stage_times           = app.stage_times;
    app.auxiliary_data.stage_vals            = app.stage_vals;

    auxiliary_data = app.auxiliary_data; %#ok<ADPROP>

    app.TextArea.addnl(   'Saving auxiliary data...');

    app.output_aux_name = fullfile(auxDir, ...
        [app.input_fbase '_auxiliary_data_' app.channel '.mat']);
    save(app.output_aux_name,'auxiliary_data');
end
