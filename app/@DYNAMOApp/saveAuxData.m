function saveAuxData(app)
    % saveAuxData  Resolve auxiliary_data + emit (.h5).
    %
    %   Three-step pattern:
    %     1. Load: try in-memory → .h5 → legacy .mat.
    %     2. Regenerate: when missing, build from in-memory SOPHs or
    %        call computeSOpower directly (cheaper than full runDYNAMO).
    %     3. Recompute: fall through to runStatsTable when neither path
    %        can produce SOpower_norm.
    %
    %   Output:
    %     <chan>/auxiliary_data/<fbase>_auxiliary_data_<chan>.h5
    %     (legacy .mat read-only).

    chanDir = fullfile(app.OutputDirEditField.Value, app.channel);
    auxDir  = fullfile(chanDir, 'auxiliary_data');
    auxBase = fullfile(auxDir,  [app.input_fbase '_auxiliary_data_' app.channel]);

    overwrite = app.OverwriteExistingFilesCheckBox.Value;

    % Resolve requested format from the dropdown ('.h5' default, '.mat'
    % fallback, '--' to disable).
    aux_choice = '.h5';
    try, aux_choice = app.AuxiliaryDataDropDown.Value; catch, end
    if strcmp(aux_choice, '--')
        return
    end
    requested = {aux_choice};

    % Skip when EITHER format already covers the binary slot — a user
    % flipping between .h5 and .mat shouldn't double up the artifact
    % unless they ask to overwrite.
    h5Path  = [auxBase '.h5'];
    matPath = [auxBase '.mat'];
    if ~overwrite && (isfile(h5Path) || isfile(matPath))
        app.TextArea.addnl('   Skipping auxiliary data (file already exists).');
        return
    end

    % --- Step 1: load whatever exists (no-op when overwrite forces recompute) ---
    if isempty(app.auxiliary_data)
        loaded = app.loadAuxData(app.channel, app.input_fbase);
        if ~isempty(loaded)
            app.auxiliary_data = loaded;
        end
    end

    % --- Step 2: regenerate from in-memory state ---
    if isempty(app.auxiliary_data) || ~isfield(app.auxiliary_data, 'SOpower_norm') || ...
            isempty(app.auxiliary_data.SOpower_norm)
        % Try the unified SOPHs loader first — it can populate
        % SOpower_norm from a SOPHs .h5/.mat or from TIFF + an existing
        % aux file. After that, regenAuxData fills in scalars.
        if isempty(app.SOPHs)
            SOPHs_resolved = app.loadOrReconstructSOPHs(app.channel, app.input_fbase);
            if ~isempty(fieldnames(SOPHs_resolved))
                app.SOPHs = SOPHs_resolved;
            end
        end
        regen = app.regenAuxData();
        if ~isempty(regen)
            app.auxiliary_data = regen;
        else
            % Last resort: full TF-peak compute path (loads EDF if needed).
            app.anything_run = 1;
            app.TextArea.addnl('   Computing SOPHs for auxiliary data...');
            runStatsTable(app);
            % runStatsTable populates app.SOPHs; build aux from it.
            regen = app.regenAuxData();
            if ~isempty(regen)
                app.auxiliary_data = regen;
            end
        end
    end

    if isempty(app.auxiliary_data)
        error('DYNAMOApp:saveAuxData:noData', ...
            'Unable to produce auxiliary_data for %s / %s.', ...
            app.input_fbase, app.channel);
    end

    % --- Step 3: write requested format(s) ---
    app.writeAuxFormats(app.auxiliary_data, auxBase, app.input_fbase, ...
        requested, overwrite);
end
