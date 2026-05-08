function runSplineBasis(app)
    % runSplineBasis  Resolve splinefit + emit requested formats.
    %
    %   Three-step pattern:
    %     1. Load: try in-memory → .h5 → legacy .mat → .tiff (per axis).
    %     2. Reuse: if both axes loaded, skip the fit.
    %     3. Fit: call fitSplineBasis when no on-disk artifact is available.

    % Channel/output dirs prepared once in runBatch; reuse cached paths
    chanDir         = fullfile(app.OutputDirEditField.Value, app.channel);
    splineDir       = fullfile(chanDir, 'spline_basis');
    splineFigDir    = fullfile(chanDir, 'figures', 'spline_basis');
    splinePowerBase = fullfile(splineDir, [app.input_fbase '_SOpower_splinefit_' app.channel]);
    splinePhaseBase = fullfile(splineDir, [app.input_fbase '_SOphase_splinefit_' app.channel]);

    overwrite    = app.OverwriteExistingFilesCheckBox.Value;
    basis_choice = app.SplineBasisDropDown.Value;

    formats = {};
    if ~strcmp(basis_choice, '--')
        if any(strcmp(basis_choice, {'.tiff','All'})), formats{end+1} = '.tiff'; end
        if any(strcmp(basis_choice, {'.mat','All'})), formats{end+1} = '.mat';  end
    end
    fig_choice = app.SplineFiguresDropDown.Value;

    pow_have   = present_(splinePowerBase, formats);
    phase_have = present_(splinePhaseBase, formats);
    pow_missing   = setdiff(formats, pow_have);
    phase_missing = setdiff(formats, phase_have);

    figPath = '';
    fig_missing = false;
    if app.SaveSplineImagesCheckBox.Value && ~strcmp(fig_choice,'--')
        figPath = fullfile(splineFigDir, ...
            [app.input_fbase '_spline_basis_figure_' app.channel fig_choice]);
        fig_missing = ~isfile(figPath);
    end

    if ~overwrite && isempty(pow_missing) && isempty(phase_missing) && ...
            ~fig_missing && ~isempty(formats)
        app.TextArea.addnl('   Skipping spline basis (outputs already exist).');
        return
    end

    % ---- Try to load existing splinefits ----
    % Overwrite means "ignore existing artifacts, re-fit" — skip the
    % loader entirely so the fit branch always runs.
    if overwrite
        loaded = struct('SOpower_splinefit', [], 'SOphase_splinefit', []);
    else
        loaded = app.loadSplinefit(app.channel, app.input_fbase);
    end
    pow_loaded   = ~isempty(loaded.SOpower_splinefit);
    phase_loaded = ~isempty(loaded.SOphase_splinefit);

    can_skip_fit = pow_loaded && phase_loaded && ...
                   (~app.SaveSplineImagesCheckBox.Value || strcmp(fig_choice,'--') || ~fig_missing);

    if can_skip_fit
        if isempty(app.SOPHs), app.SOPHs = struct(); end
        app.SOPHs.SOpower_splinefit = loaded.SOpower_splinefit;
        app.SOPHs.SOphase_splinefit = loaded.SOphase_splinefit;
        if ~isfield(app.SOPHs,'freq_bins')
            S = app.loadOrReconstructSOPHs(app.channel, app.input_fbase);
            f = fieldnames(S);
            for ii = 1:numel(f)
                if ~isfield(app.SOPHs, f{ii})
                    app.SOPHs.(f{ii}) = S.(f{ii});
                end
            end
        end
    else
        if isempty(app.SOPHs)
            SOPHs_resolved = app.loadOrReconstructSOPHs(app.channel, app.input_fbase);
            if isfield(SOPHs_resolved, 'SOpower_mat') || ...
                    isfield(SOPHs_resolved, 'SOphase_mat')
                app.SOPHs = SOPHs_resolved;
            else
                app.anything_run = 1;
                app.TextArea.addnl('   Running DYNAMO (computing SOPHs)...');
                runStatsTable(app);
            end
        end

        % AutoCreate=false guard
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

        app.TextArea.addnl('   Running spline basis...');
        app.TextArea.addnl('   Generating spline basis figure...');
        app.fitSplineBasis();
        p_ = []; try, p_ = gcp('nocreate'); catch, end
        if ~isempty(p_)
            try, delete(p_); catch, end
        end
        fh = gcf;

        if ~isempty(figPath) && (overwrite || ~isfile(figPath))
            app.anything_run = 1;
            app.TextArea.addnl('   Saving spline figure...');
            app.output_spline_name = figPath;
            exportgraphics(fh, figPath, 'Resolution', 300);
        end
        close all;
    end

    % ---- Save splinefit data ----
    pow_have_data   = isfield(app.SOPHs,'SOpower_splinefit') && ~isempty(app.SOPHs.SOpower_splinefit);
    phase_have_data = isfield(app.SOPHs,'SOphase_splinefit') && ~isempty(app.SOPHs.SOphase_splinefit);

    if ~pow_have_data
        app.TextArea.addnl('   Skipping spline power save (fit failed or absent).');
        if isempty(app.partial_failures), app.partial_failures = {}; end
        app.partial_failures{end+1} = 'spline power fit';
    end
    if ~phase_have_data
        app.TextArea.addnl('   Skipping spline phase save (fit failed or absent).');
        if isempty(app.partial_failures), app.partial_failures = {}; end
        app.partial_failures{end+1} = 'spline phase fit';
    end

    write_pow   = formats; if ~overwrite, write_pow   = pow_missing;   end
    write_phase = formats; if ~overwrite, write_phase = phase_missing; end

    if pow_have_data && ~isempty(write_pow)
        app.writeSplinefitFormats( ...
            app.SOPHs.SOpower_splinefit, splinePowerBase, 'power', ...
            app.SOPHs.freq_bins, app.SOPHs.SOpower_bins, 'SOpower_bins', ...
            app.input_fbase, write_pow, overwrite);
    end
    if phase_have_data && ~isempty(write_phase)
        app.writeSplinefitFormats( ...
            app.SOPHs.SOphase_splinefit, splinePhaseBase, 'phase', ...
            app.SOPHs.freq_bins, app.SOPHs.SOphase_bins, 'SOphase_bins', ...
            app.input_fbase, write_phase, overwrite);
    end

    if ~pow_have_data && ~phase_have_data
        error('DYNAMOApp:runSplineBasis:bothFitsFailed', ...
            'Both spline power and phase fits failed or are absent.');
    end
end


function have = present_(base, formats)
    have = {};
    if any(strcmp(formats, '.tiff')) && isfile([base '.tiff']), have{end+1} = '.tiff'; end
    if any(strcmp(formats, '.mat')) && (isfile([base '.mat']) || isfile([base '.h5']))
        have{end+1} = '.mat';
    end
end


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
