function runParamBasis(app)
    % runParamBasis  Resolve paramfit + emit requested formats.
    %
    %   Three-step pattern:
    %     1. Load: try in-memory → .h5 → legacy .mat → .csv (per axis).
    %     2. Reuse: if both axes loaded, skip the fit.
    %     3. Fit: call fitParamBasis when no on-disk artifact is available.
    %
    %   Outputs (gated by ParametricBasisDropDown + SaveParamImagesCheckBox):
    %     - .csv per axis (with `#`-preamble metadata)
    %     - .h5 per axis (struct with params, fitobj, gof, model_SOPH,
    %       wshed_img; fitobj is a real cfit when fit was just run, or a
    %       struct stand-in when reconstructed from CSV).
    %     - .png/.tiff parametric basis figure.

    % Channel/output dirs prepared once in runBatch; reuse cached paths
    chanDir        = fullfile(app.OutputDirEditField.Value, app.channel);
    paramDir       = fullfile(chanDir, 'param_basis');
    paramFigDir    = fullfile(chanDir, 'figures', 'param_basis');
    paramPowerBase = fullfile(paramDir, [app.input_fbase '_SOpower_paramfit_' app.channel]);
    paramPhaseBase = fullfile(paramDir, [app.input_fbase '_SOphase_paramfit_' app.channel]);

    % ---- Resolve requested formats ----
    overwrite    = app.OverwriteExistingFilesCheckBox.Value;
    basis_choice = app.ParametricBasisDropDown.Value;

    formats = {};
    if ~strcmp(basis_choice, '--')
        if any(strcmp(basis_choice, {'.csv','All'})), formats{end+1} = '.csv'; end
        if any(strcmp(basis_choice, {'.mat','All'})), formats{end+1} = '.mat'; end
    end
    fig_choice = app.ParametricFiguresDropDown.Value;

    % ---- Skip-when-cached gate ----
    pow_have   = present_(paramPowerBase, formats);
    phase_have = present_(paramPhaseBase, formats);
    pow_missing   = setdiff(formats, pow_have);
    phase_missing = setdiff(formats, phase_have);

    plot_figure = app.SaveParamImagesCheckBox.Value && ~strcmp(fig_choice,'--');
    figPath = '';
    fig_missing = false;
    if plot_figure
        figPath = fullfile(paramFigDir, ...
            [app.input_fbase '_param_basis_figure_' app.channel fig_choice]);
        fig_missing = ~isfile(figPath);
    end

    if ~overwrite && isempty(pow_missing) && isempty(phase_missing) && ...
            ~fig_missing && ~isempty(formats)
        app.TextArea.addnl('   Skipping parametric basis (outputs already exist).');
        return
    end

    % ---- Try to load existing paramfits ----
    % Overwrite means "ignore existing artifacts, re-fit" — skip the
    % loader entirely so the fit branch always runs.
    if overwrite
        loaded = struct('SOpower_paramfit', [], 'SOphase_paramfit', []);
    else
        loaded = app.loadParamfit(app.channel, app.input_fbase);
    end
    pow_loaded   = ~isempty(loaded.SOpower_paramfit);
    phase_loaded = ~isempty(loaded.SOphase_paramfit);

    % If both axes loaded AND the figure already exists (or wasn't asked
    % for), we can skip the fit entirely and just write missing formats.
    can_skip_fit = pow_loaded && phase_loaded && ...
                   (~app.SaveParamImagesCheckBox.Value || strcmp(fig_choice,'--') || ~fig_missing);

    if can_skip_fit
        if isempty(app.SOPHs), app.SOPHs = struct(); end
        app.SOPHs.SOpower_paramfit = loaded.SOpower_paramfit;
        app.SOPHs.SOphase_paramfit = loaded.SOphase_paramfit;
        % SOPHs binning/freq still needed by the writers — make sure
        % SOPHs is fully populated. loadOrReconstructSOPHs handles this.
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
        % ---- Ensure SOPHs are available for fitting ----
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

        % AutoCreate=false guard (see runBatch comment block).
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

        app.TextArea.addnl('   Running parametric basis...');
        if plot_figure
            app.TextArea.addnl('   Generating parametric basis figure...');
        end
        dynamo_pool_trace('runParamBasis: before fitParamBasis');
        app.fitParamBasis(plot_figure);
        dynamo_pool_trace('runParamBasis: after fitParamBasis');
        p_ = []; try, p_ = gcp('nocreate'); catch, end
        if ~isempty(p_)
            try, delete(p_); catch, end
        end

        % Save the parametric basis figure (overwrite-gated). Only
        % grab gcf when we asked fitParamBasis to render — otherwise
        % gcf would return a stale handle from a prior stage.
        if plot_figure && (overwrite || ~isfile(figPath))
            app.anything_run = 1;
            app.output_param_name = figPath;
            app.TextArea.addnl('   Saving parametric basis figure...');
            exportgraphics(gcf, figPath, 'Resolution', 300);
        end
        close all;
    end

    % ---- Save parametric fit data ----
    pow_have_data   = isfield(app.SOPHs,'SOpower_paramfit') && ~isempty(app.SOPHs.SOpower_paramfit);
    phase_have_data = isfield(app.SOPHs,'SOphase_paramfit') && ~isempty(app.SOPHs.SOphase_paramfit);

    if ~pow_have_data
        app.TextArea.addnl('   Skipping parametric power save (fit failed or absent).');
        if isempty(app.partial_failures), app.partial_failures = {}; end
        app.partial_failures{end+1} = 'parametric power fit';
    end
    if ~phase_have_data
        app.TextArea.addnl('   Skipping parametric phase save (fit failed or absent).');
        if isempty(app.partial_failures), app.partial_failures = {}; end
        app.partial_failures{end+1} = 'parametric phase fit';
    end

    write_pow   = formats; if ~overwrite, write_pow   = pow_missing;   end
    write_phase = formats; if ~overwrite, write_phase = phase_missing; end

    if pow_have_data && ~isempty(write_pow)
        app.writeParamfitFormats( ...
            app.SOPHs.SOpower_paramfit, paramPowerBase, 'power', ...
            app.SOPHs.freq_bins, app.SOPHs.SOpower_bins, app.input_fbase, ...
            write_pow, overwrite);
    end
    if phase_have_data && ~isempty(write_phase)
        app.writeParamfitFormats( ...
            app.SOPHs.SOphase_paramfit, paramPhaseBase, 'phase', ...
            app.SOPHs.freq_bins, app.SOPHs.SOphase_bins, app.input_fbase, ...
            write_phase, overwrite);
    end

    if ~pow_have_data && ~phase_have_data
        error('DYNAMOApp:runParamBasis:bothFitsFailed', ...
            'Both parametric power and phase fits failed or are absent.');
    end
end


function have = present_(base, formats)
    have = {};
    if any(strcmp(formats, '.csv')) && isfile([base '.csv']), have{end+1} = '.csv'; end
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
