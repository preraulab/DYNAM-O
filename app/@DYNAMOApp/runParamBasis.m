function runParamBasis(app)
    % runParamBasis  Fit the parametric basis model and save results/figures.
    %
    %   Loads SOPHs if needed, calls fitParamBasis, and saves:
    %     - Parametric fit figure (if SaveParamImagesCheckBox is checked)
    %     - SOpower/SOphase parametric fit data (.csv, .mat, or both)
    %       according to ParametricBasisDropDown selection.

    % Channel/output dirs prepared once in runBatch; reuse cached paths
    chanDir        = fullfile(app.OutputDirEditField.Value, app.channel);
    paramDir       = fullfile(chanDir, 'param_basis');
    paramFigDir    = fullfile(chanDir, 'figures', 'param_basis');
    sophMat        = fullfile(chanDir, 'SOPHs', [app.input_fbase '_SOPHs_' app.channel '.mat']);
    paramPowerBase = fullfile(paramDir, [app.input_fbase '_SOpower_paramfit_' app.channel]);
    paramPhaseBase = fullfile(paramDir, [app.input_fbase '_SOphase_paramfit_' app.channel]);

    % ---- Skip-when-cached gate ----
    % Build the list of files this stage would emit under the
    % current dropdown choices. If overwrite is off AND every
    % one already exists, the (expensive) fitParamBasis call
    % is pure waste — bail out early.
    overwrite = app.OverwriteExistingFilesCheckBox.Value;
    expected  = {};
    basis_choice = app.ParametricBasisDropDown.Value;
    if ~strcmp(basis_choice, '--')
        if any(strcmp(basis_choice, {'.csv','All'}))
            expected{end+1} = [paramPowerBase '.csv']; %#ok<AGROW>
            expected{end+1} = [paramPhaseBase '.csv']; %#ok<AGROW>
        end
        if any(strcmp(basis_choice, {'.mat','All'}))
            expected{end+1} = [paramPowerBase '.mat']; %#ok<AGROW>
            expected{end+1} = [paramPhaseBase '.mat']; %#ok<AGROW>
        end
    end
    fig_choice = app.ParametricFiguresDropDown.Value;
    if app.SaveParamImagesCheckBox.Value && ~strcmp(fig_choice,'--')
        expected{end+1} = fullfile(paramFigDir, ...
            [app.input_fbase '_param_basis_figure_' app.channel fig_choice]); %#ok<AGROW>
    end
    if ~overwrite && ~isempty(expected) && all(cellfun(@isfile, expected))
        app.TextArea.addnl('   Skipping parametric basis (outputs already exist).');
        return
    end

    % ---- Ensure SOPHs are available ----
    if isempty(app.SOPHs)
        if isfile(sophMat)
            app.SOPHs = load(sophMat).SOPHs;
        else
            app.anything_run = 1;
            app.TextArea.addnl('   Running DYNAMO (computing SOPHs)...');
            runStatsTable(app);
        end
    end

    % Fit parametric basis model.
    %
    % Layered AutoCreate=false guard. runBatch already sets this at
    % batch scope, but we also set it here so the protection holds when:
    %   - a custom driver calls runParamBasis directly (no runBatch),
    %   - a callback inside the batch loop temporarily flips it back,
    %   - the user's MATLAB session has a startup script that resets it
    %     between batch iterations.
    % The guard is scoped to this function via onCleanup; the matlab
    % backend's explicit parpool() in setup_parallel_pool is unaffected.
    pool_guard_orig_ = []; %#ok<NASGU>
    if exist('parallel.Settings', 'class') == 8 || ...
            (exist('ver','builtin')~=0 && any(strcmp({ver().Name}, 'Parallel Computing Toolbox')))
        try
            ps_ = parallel.Settings;
            pool_guard_orig_ = ps_.Pool.AutoCreate.ActiveValue;
            ps_.Pool.AutoCreate.TemporaryValue = false;
            pool_guard_cleanup_ = onCleanup( ...
                @() restore_pool_autocreate_(pool_guard_orig_)); %#ok<NASGU>
        catch
            % no-op — best-effort guard.
        end
    end

    app.TextArea.addnl('   Running parametric basis...');
    app.TextArea.addnl('   Generating parametric basis figure...');
    dynamo_pool_trace('runParamBasis: before fitParamBasis');
    app.fitParamBasis();
    dynamo_pool_trace('runParamBasis: after fitParamBasis');
    % If a pool was nevertheless spawned during fitParamBasis (some
    % MATLAB toolbox internals ignore AutoCreate), kill it now so the
    % next channel doesn't inherit an idle pool.
    p_ = []; try, p_ = gcp('nocreate'); catch, end
    if ~isempty(p_)
        try, delete(p_); catch, end
    end
    fh = gcf;

    % Optionally save the parametric basis figure (overwrite-gated)
    if app.SaveParamImagesCheckBox.Value && ~strcmp(fig_choice,'--')
        figPath = fullfile(paramFigDir, ...
            [app.input_fbase '_param_basis_figure_' app.channel fig_choice]);
        if overwrite || ~isfile(figPath)
            app.anything_run = 1;
            app.output_param_name = figPath;
            app.TextArea.addnl('   Saving parametric basis figure...');
            exportgraphics(fh, figPath, 'Resolution', 300);
        end
    end
    close all;

    % Save parametric fit data — fitParamBasis leaves *_paramfit
    % empty when its sub-fit failed; skip those saves so a failed
    % phase fit doesn't prevent saving the (good) power fit.
    % Per-file overwrite gating ensures we don't re-write existing
    % outputs unless the user asked for it.
    pow_have   = ~isempty(app.SOPHs.SOpower_paramfit);
    phase_have = ~isempty(app.SOPHs.SOphase_paramfit);
    if ~pow_have
        app.TextArea.addnl('   Skipping parametric power save (fit failed).');
        app.partial_failures{end+1} = 'parametric power fit';
    end
    if ~phase_have
        app.TextArea.addnl('   Skipping parametric phase save (fit failed).');
        app.partial_failures{end+1} = 'parametric phase fit';
    end
    if ~strcmp(basis_choice,'--')
        save_csv = any(strcmp(basis_choice, {'.csv','All'}));
        save_mat = any(strcmp(basis_choice, {'.mat','All'}));
        if pow_have
            if save_csv, write_paramfit_csv([paramPowerBase '.csv'], app.SOPHs.SOpower_paramfit, 'power', app.SOPHs.SOpower_bins); end
            if save_mat, write_paramfit_mat([paramPowerBase '.mat'], app.SOPHs.SOpower_paramfit, 'SOpower_paramfit');             end
        end
        if phase_have
            if save_csv, write_paramfit_csv([paramPhaseBase '.csv'], app.SOPHs.SOphase_paramfit, 'phase', app.SOPHs.SOphase_bins); end
            if save_mat, write_paramfit_mat([paramPhaseBase '.mat'], app.SOPHs.SOphase_paramfit, 'SOphase_paramfit');             end
        end
    end

    function write_paramfit_csv(p, fitData, axis_kind, bins)
        if ~overwrite && isfile(p), return, end
        app.TextArea.addnl(sprintf('   Saving parametric %s as .csv...', axis_kind));
        if strcmp(axis_kind,'power')
            app.output_paramfit_power_name = p;
        else
            app.output_paramfit_phase_name = p;
        end
        app.writeParamfitCsv(p, fitData, axis_kind, app.SOPHs.freq_bins, bins);
    end

    function write_paramfit_mat(p, fitData, varName)
        if ~overwrite && isfile(p), return, end
        app.TextArea.addnl(sprintf('   Saving %s as .mat...', varName));
        if contains(varName,'power')
            app.output_paramfit_power_name = p;
        else
            app.output_paramfit_phase_name = p;
        end
        S.(varName) = fitData; %#ok<STRNU>
        save(p, '-struct', 'S');
    end

    % If both fits failed, surface that to the per-stage try/catch in
    % runBatch so the subject is logged as "partially run".
    if ~pow_have && ~phase_have
        error('DYNAMOApp:runParamBasis:bothFitsFailed', ...
            'Both parametric power and phase fits failed.');
    end
end % runParamBasis

function restore_pool_autocreate_(orig)
    if isempty(orig), return, end
    try
        parallel.Settings.Pool.AutoCreate.TemporaryValue = orig;
        clearTemporaryValue(parallel.Settings.Pool.AutoCreate);
    catch
    end
end
