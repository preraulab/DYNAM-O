function runStatsTable(app)
    % runStatsTable  Run DYNAMO and save TF-peak stats and SO-Power Histograms.
    %
    %   Calls app.run() to execute the DYNAMO pipeline, then saves:
    %     - stats_table: TF-peak statistics table (.csv, .mat, or both)
    %     - SOPHs: SO-Power Histograms (.tiff, .mat, or both)
    %
    %   Skips execution if all output files already exist and
    %   OverwriteExistingFilesCheckBox is unchecked.

    % Channel/output dirs prepared once in runBatch; reuse cached paths
    chanDir     = fullfile(app.OutputDirEditField.Value, app.channel);
    tfpeaksDir  = fullfile(chanDir, 'TFpeaks');
    sophsDir    = fullfile(chanDir, 'SOPHs');
    statsBase   = fullfile(tfpeaksDir, [app.input_fbase '_stats_table_' app.channel]);
    sophBase    = fullfile(sophsDir,   [app.input_fbase '_SOPHs_' app.channel]);
    sophPowBase = fullfile(sophsDir,   [app.input_fbase '_SOPHs_power_' app.channel]);
    sophPhaBase = fullfile(sophsDir,   [app.input_fbase '_SOPHs_phase_' app.channel]);

    stats_csv = [statsBase '.csv'];
    stats_mat = [statsBase '.mat'];
    SOPH_mat  = [sophBase  '.mat'];

    % ---- (0) Build the list of files this stage would emit
    %      under the current (checkbox + dropdown) choices.
    %      Used both for the skip-when-cached gate at compute
    %      time AND for per-file save gating below — so a
    %      run with .csv on disk but the user requesting .mat
    %      still writes .mat instead of being silently skipped.
    overwrite = app.OverwriteExistingFilesCheckBox.Value;

    stats_choice = app.PeakStatsTableDropDown.Value;
    stats_expected = {};
    if app.SavePeakStatsCheckBox.Value && ~strcmp(stats_choice,'--')
        if any(strcmp(stats_choice, {'.csv','All'})), stats_expected{end+1} = stats_csv; end
        if any(strcmp(stats_choice, {'.mat','All'})), stats_expected{end+1} = stats_mat; end
    end

    soph_choice = app.SOPowerHistogramsDropDown.Value;
    soph_targets = {};   % each entry: struct('path', ..., 'kind', 'tiff_power'|'tiff_phase'|'mat')
    if app.SaveSOPHsCheckBox.Value && ~strcmp(soph_choice,'--')
        if any(strcmp(soph_choice, {'.tiff','All'}))
            soph_targets{end+1} = struct('path', [sophPowBase '.tiff'], 'kind', 'tiff_power');
            soph_targets{end+1} = struct('path', [sophPhaBase '.tiff'], 'kind', 'tiff_phase');
        end
        if any(strcmp(soph_choice, {'.mat','All'}))
            soph_targets{end+1} = struct('path', SOPH_mat, 'kind', 'mat');
        end
    end

    % ---- (1) Make sure SOPHs + stats_table are in memory ----
    % The overwrite flag gates the on-disk cache: when checked,
    % previous in-memory copies are cleared and the disk-load
    % shortcut is skipped so we always recompute via runDYNAMO.
    if overwrite
        app.SOPHs       = [];
        app.stats_table = [];
    end
    need_compute = isempty(app.SOPHs) || isempty(app.stats_table);
    if need_compute && ~overwrite && isfile(SOPH_mat) && isfile(stats_mat)
        app.TextArea.addnl('   Loading cached SOPHs and stats table...');
        app.SOPHs       = load(SOPH_mat).SOPHs;
        app.stats_table = load(stats_mat).stats_table;
        need_compute    = false;
    end
    if need_compute
        app.anything_run = 1;
        app.TextArea.addnl('   Running DYNAMO...');
        app.TextArea.addnl('   Computing TF peak stats table...');
        drawnow;
        app.runDYNAMO();
    end

    stats_table = app.stats_table;
    SOPHs       = app.SOPHs;

    % ---- (2) Save according to user choices, with per-file
    %      overwrite gating — write only the (format × file)
    %      combinations that don't already exist (or all of
    %      them when overwrite is on).
    if ~isempty(stats_expected)
        wrote_any = false;
        for ii = 1:numel(stats_expected)
            p = stats_expected{ii};
            if ~overwrite && isfile(p), continue, end
            if ~wrote_any
                app.TextArea.addnl('   Saving stats table...');
                wrote_any = true;
            end
            [~,~,ext] = fileparts(p);
            app.output_stats_name = p;
            switch lower(ext)
                case '.csv', table2csv(stats_table, p);
                case '.mat', save(p, 'stats_table');
            end
        end
    end

    if ~isempty(soph_targets)
        powMeta = jsonencode(struct( ...
            'freq_bins',    SOPHs.freq_bins(:).', ...
            'SOpower_bins', SOPHs.SOpower_bins(:).'));
        phaMeta = jsonencode(struct( ...
            'freq_bins',    SOPHs.freq_bins(:).', ...
            'SOphase_bins', SOPHs.SOphase_bins(:).'));
        wrote_any = false;
        for ii = 1:numel(soph_targets)
            t = soph_targets{ii};
            if ~overwrite && isfile(t.path), continue, end
            if ~wrote_any
                app.TextArea.addnl('   Saving SOPHs');
                wrote_any = true;
            end
            app.output_SOPH_name = t.path;
            switch t.kind
                case 'tiff_power', app.writeTiff(t.path, SOPHs.SOpower_mat, powMeta);
                case 'tiff_phase', app.writeTiff(t.path, SOPHs.SOphase_mat, phaMeta);
                case 'mat',        save(t.path, 'SOPHs');
            end
        end
    end
end % runStatsTable
