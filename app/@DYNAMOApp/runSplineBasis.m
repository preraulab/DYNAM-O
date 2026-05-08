function runSplineBasis(app)
    % runSplineBasis  Fit the spline basis model and save results/figures.
    %
    %   Loads SOPHs if needed, calls fitSplineBasis, and saves:
    %     - Spline basis figure (if SaveSplineImagesCheckBox is checked)
    %     - SOpower/SOphase spline fit data (.tiff, .mat, or both)
    %       according to SplineBasisDropDown selection.

    % Channel/output dirs prepared once in runBatch; reuse cached paths
    chanDir         = fullfile(app.OutputDirEditField.Value, app.channel);
    splineDir       = fullfile(chanDir, 'spline_basis');
    splineFigDir    = fullfile(chanDir, 'figures', 'spline_basis');
    sophMat         = fullfile(chanDir, 'SOPHs', [app.input_fbase '_SOPHs_' app.channel '.mat']);
    splinePowerBase = fullfile(splineDir, [app.input_fbase '_SOpower_splinefit_' app.channel]);
    splinePhaseBase = fullfile(splineDir, [app.input_fbase '_SOphase_splinefit_' app.channel]);

    % ---- Skip-when-cached gate ----
    % Build the list of files this stage would emit under the
    % current dropdown choices. If overwrite is off AND every
    % one already exists, the (expensive) fitSplineBasis call
    % is pure waste — bail out early.
    overwrite = app.OverwriteExistingFilesCheckBox.Value;
    expected  = {};
    basis_choice = app.SplineBasisDropDown.Value;
    if ~strcmp(basis_choice, '--')
        if any(strcmp(basis_choice, {'.tiff','All'}))
            expected{end+1} = [splinePowerBase '.tiff']; %#ok<AGROW>
            expected{end+1} = [splinePhaseBase '.tiff']; %#ok<AGROW>
        end
        if any(strcmp(basis_choice, {'.mat','All'}))
            expected{end+1} = [splinePowerBase '.mat']; %#ok<AGROW>
            expected{end+1} = [splinePhaseBase '.mat']; %#ok<AGROW>
        end
    end
    fig_choice = app.SplineFiguresDropDown.Value;
    if app.SaveSplineImagesCheckBox.Value && ~strcmp(fig_choice,'--')
        expected{end+1} = fullfile(splineFigDir, ...
            [app.input_fbase '_spline_basis_figure_' app.channel fig_choice]); %#ok<AGROW>
    end
    if ~overwrite && ~isempty(expected) && all(cellfun(@isfile, expected))
        app.TextArea.addnl('   Skipping spline basis (outputs already exist).');
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

    % Fit spline basis model. Layered AutoCreate=false guard mirrors
    % runParamBasis — see the comment block there for why this is
    % needed even though runBatch already sets it at batch scope.
    pool_guard_orig_ = [];
    pool_guard_mode_ = 'none';
    if exist('parallel.Settings', 'class') == 8 || ...
            (exist('ver','builtin')~=0 && any(strcmp({ver().Name}, 'Parallel Computing Toolbox')))
        try
            ps_ = parallel.Settings;
            raw_ = ps_.Pool.AutoCreate;
            if isa(raw_, 'matlab.settings.Setting')
                pool_guard_orig_ = raw_.ActiveValue;
                ps_.Pool.AutoCreate.TemporaryValue = false;
                pool_guard_mode_ = 'temporary';
            else
                pool_guard_orig_ = logical(raw_);
                ps_.Pool.AutoCreate = false;
                pool_guard_mode_ = 'direct';
            end
            pool_guard_cleanup_ = onCleanup( ...
                @() restore_pool_autocreate_(pool_guard_orig_, pool_guard_mode_)); %#ok<NASGU>
        catch
        end
    end

    app.TextArea.addnl(   'Running spline basis...');
    app.TextArea.addnl('   Generating spline basis figure...');
    app.fitSplineBasis();
    p_ = []; try, p_ = gcp('nocreate'); catch, end
    if ~isempty(p_)
        try, delete(p_); catch, end
    end
    fh = gcf;

    % Optionally save the spline basis figure (overwrite-gated)
    if app.SaveSplineImagesCheckBox.Value && ~strcmp(fig_choice,'--')
        figPath = fullfile(splineFigDir, ...
            [app.input_fbase '_spline_basis_figure_' app.channel fig_choice]);
        if overwrite || ~isfile(figPath)
            app.anything_run = 1;
            app.TextArea.addnl('   Saving spline figure...');
            app.output_spline_name = figPath;
            exportgraphics(fh, figPath, 'Resolution', 300);
        end
    end
    close all;

    % Save spline fit data — empty *_splinefit means that sub-fit
    % failed; skip those without erroring the surviving one.
    % Per-file overwrite gating below (write_splinefit_*).
    pow_have   = ~isempty(app.SOPHs.SOpower_splinefit);
    phase_have = ~isempty(app.SOPHs.SOphase_splinefit);
    if ~pow_have
        app.TextArea.addnl('   Skipping spline power save (fit failed).');
        app.partial_failures{end+1} = 'spline power fit';
    end
    if ~phase_have
        app.TextArea.addnl('   Skipping spline phase save (fit failed).');
        app.partial_failures{end+1} = 'spline phase fit';
    end
    if ~strcmp(basis_choice,'--')
        save_tiff = any(strcmp(basis_choice, {'.tiff','All'}));
        save_mat  = any(strcmp(basis_choice, {'.mat','All'}));

        % .tiff is multi-page: page 1 = coefs (the parameter
        % matrix that IS the model); page 2 = the rendered
        % splinefit on the fit-domain grid for direct preview.
        % knots_x/y + FIT-DOMAIN bins (filtered, not full SOPH
        % bins) go in page-1 ImageDescription so feeding them
        % + coefs + knots into spap2/fnval reproduces page 2.
        if pow_have
            [powMeta, powPages] = build_splinefit_payload( ...
                app.SOPHs.SOpower_splinefit, app.SOPHs.SOpower_bins, app.SOPHs.freq_bins, 'SOpower_bins');
            if save_tiff, write_splinefit_tiff([splinePowerBase '.tiff'], powPages, powMeta, 'power'); end
            if save_mat,  write_splinefit_mat([splinePowerBase '.mat'],  app.SOPHs.SOpower_splinefit, 'SOpower_splinefit'); end
        end
        if phase_have
            [phaMeta, phaPages] = build_splinefit_payload( ...
                app.SOPHs.SOphase_splinefit, app.SOPHs.SOphase_bins, app.SOPHs.freq_bins, 'SOphase_bins');
            if save_tiff, write_splinefit_tiff([splinePhaseBase '.tiff'], phaPages, phaMeta, 'phase'); end
            if save_mat,  write_splinefit_mat([splinePhaseBase '.mat'],  app.SOPHs.SOphase_splinefit, 'SOphase_splinefit'); end
        end
    end

    if ~pow_have && ~phase_have
        error('DYNAMOApp:runSplineBasis:bothFitsFailed', ...
            'Both spline power and phase fits failed.');
    end

    function [meta, pages] = build_splinefit_payload(SF, defaultSObins, defaultFreqBins, soBinsField)
        if isfield(SF,'fit_SOfeature_bins') && ~isempty(SF.fit_SOfeature_bins)
            fitSO = SF.fit_SOfeature_bins;
        else
            fitSO = defaultSObins;     % pre-refactor structs
        end
        if isfield(SF,'fit_freq_bins') && ~isempty(SF.fit_freq_bins)
            fitFB = SF.fit_freq_bins;
        else
            fitFB = defaultFreqBins;
        end
        metaStruct = struct( ...
            'knots_x',     SF.knots_x(:).', ...
            'knots_y',     SF.knots_y(:).', ...
            'freq_bins',   fitFB(:).', ...
            (soBinsField), fitSO(:).', ...
            'page1',       'coefs', ...
            'page2',       'splinefit');
        meta  = jsonencode(metaStruct);
        pages = {SF.coefs, SF.splinefit};
    end

    function write_splinefit_tiff(p, pages, meta, axisLabel)
        if ~overwrite && isfile(p), return, end
        app.TextArea.addnl(sprintf('   Saving spline %s as .tiff (coefs + splinefit)...', axisLabel));
        if strcmp(axisLabel,'power')
            app.output_splinefit_power_name = p;
        else
            app.output_splinefit_phase_name = p;
        end
        app.writeTiff(p, pages, meta);
    end

    function write_splinefit_mat(p, fitData, varName)
        if ~overwrite && isfile(p), return, end
        app.TextArea.addnl(sprintf('   Saving %s as .mat...', varName));
        if contains(varName,'power')
            app.output_splinefit_power_name = p;
        else
            app.output_splinefit_phase_name = p;
        end
        S.(varName) = fitData; %#ok<STRNU>
        save(p, '-struct', 'S', '-v7.3');
    end
end % runSplineBasis

function restore_pool_autocreate_(orig, mode)
    if isempty(orig) || strcmp(mode, 'none'), return, end
    try
        switch mode
            case 'temporary'
                clearTemporaryValue(parallel.Settings.Pool.AutoCreate);
            case 'direct'
                parallel.Settings.Pool.AutoCreate = orig;
        end
    catch
    end
end
