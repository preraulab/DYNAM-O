function runStatsTable(app)
    % runStatsTable  Resolve stats_table + SOPHs and emit requested formats.
    %
    %   Three-step pattern:
    %     1. Load: try in-memory → .h5 → legacy .mat → .csv (stats only).
    %     2. Reuse: when only stats_table is present (CSV reuse case),
    %        forward it into runDYNAMO via the 'stats_table' kwarg so
    %        computeTFPeaks is skipped — only the spectrogram +
    %        SOpower / SOphase + SOPH binning steps run.
    %     3. Recompute: full runDYNAMO when both are missing.
    %
    %   Outputs:
    %     stats_table : .csv and/or .h5 (legacy .mat read-only).
    %     SOPHs       : per-axis .tiff pair and/or .h5 (flat top-level
    %                   datasets via save -struct).
    %
    %   Skips wholly when every requested format already exists on disk
    %   and OverwriteExistingFilesCheckBox is unchecked.

    % --- (0) Paths and requested-format resolution ---
    chanDir     = fullfile(app.OutputDirEditField.Value, app.channel);
    tfpeaksDir  = fullfile(chanDir, 'TFpeaks');
    sophsDir    = fullfile(chanDir, 'SOPHs');
    statsBase   = fullfile(tfpeaksDir, [app.input_fbase '_stats_table_' app.channel]);
    sophBase    = fullfile(sophsDir,   [app.input_fbase '_SOPHs_' app.channel]);
    sophPowBase = fullfile(sophsDir,   [app.input_fbase '_SOPHs_power_' app.channel]);
    sophPhaBase = fullfile(sophsDir,   [app.input_fbase '_SOPHs_phase_' app.channel]);

    overwrite = app.OverwriteExistingFilesCheckBox.Value;

    stats_choice = app.PeakStatsTableDropDown.Value;
    stats_formats = {};
    if app.SavePeakStatsCheckBox.Value && ~strcmp(stats_choice,'--')
        if any(strcmp(stats_choice, {'.csv','All'})), stats_formats{end+1} = '.csv'; end
        if any(strcmp(stats_choice, {'.mat','All'})), stats_formats{end+1} = '.mat'; end
    end

    soph_choice = app.SOPowerHistogramsDropDown.Value;
    soph_formats = {};
    if app.SaveSOPHsCheckBox.Value && ~strcmp(soph_choice,'--')
        if any(strcmp(soph_choice, {'.tiff','All'})), soph_formats{end+1} = '.tiff'; end
        if any(strcmp(soph_choice, {'.mat','All'})),  soph_formats{end+1} = '.mat';  end
    end

    % --- Existence-driven skip-when-cached gate ---
    % Legacy .mat counts as satisfying the binary slot for skip logic
    % so a pre-existing .mat dataset doesn't get redundantly re-emitted.
    stats_have = stats_present_(statsBase);
    soph_have  = soph_present_(sophBase, sophPowBase, sophPhaBase);

    stats_missing = setdiff(stats_formats, stats_have);
    soph_missing  = setdiff(soph_formats,  soph_have);

    if ~overwrite && isempty(stats_missing) && isempty(soph_missing) && ...
            ~isempty([stats_formats, soph_formats])
        app.TextArea.addnl('   Skipping stats / SOPHs (all requested outputs already exist).');
        return
    end

    % --- (1) Load whatever we can from disk into memory ---
    % Overwrite means "ignore existing artifacts, recompute everything"
    % — clear in-memory state AND skip the disk-load shortcuts below.
    % Without this gate, a prior run that left only slim TIFF outputs
    % on disk would short-circuit runDYNAMO and downstream stages
    % (e.g. saveAuxData) would come up missing SOpower_norm.
    if overwrite
        app.SOPHs       = [];
        app.stats_table = [];
    else
        if isempty(app.stats_table)
            T_loaded = app.loadStatsTable(app.channel, app.input_fbase);
            if ~isempty(T_loaded)
                app.TextArea.addnl('   Loaded stats_table from disk.');
                app.stats_table = T_loaded;
            end
        end
        if isempty(app.SOPHs)
            SOPHs_loaded = app.loadOrReconstructSOPHs(app.channel, app.input_fbase);
            % loadOrReconstructSOPHs can return a partially-populated struct
            % (e.g. only freq_bins from a stale TIFF metadata read). Require
            % at least one of the histogram matrices before promoting to
            % app.SOPHs — otherwise the recompute branch below is correctly
            % triggered. Mirrors the have_sophs check on the next block.
            if isstruct(SOPHs_loaded) && ...
                    (isfield(SOPHs_loaded,'SOpower_mat') || isfield(SOPHs_loaded,'SOphase_mat'))
                app.SOPHs = SOPHs_loaded;
            end
        end
    end

    % --- (2) Decide whether to (re)compute ---
    have_stats = ~isempty(app.stats_table);
    have_sophs = ~isempty(app.SOPHs) && ...
                 (isstruct(app.SOPHs) && (isfield(app.SOPHs,'SOpower_mat') || isfield(app.SOPHs,'SOphase_mat')));

    if have_stats && have_sophs
        % nothing to compute — fall through to write
    elseif have_stats && ~have_sophs
        % CSV-reuse path: skip TF-peak detection, run the rest of runDYNAMO.
        app.anything_run = 1;
        app.TextArea.addnl('   Reusing stats_table; computing SOPHs (skipping TF-peak extraction)...');
        drawnow;
        app.runDYNAMO();
    else
        app.anything_run = 1;
        app.TextArea.addnl('   Running DYNAMO...');
        app.TextArea.addnl('   Computing TF peak stats table...');
        drawnow;
        app.runDYNAMO();
    end

    % --- (3) Write missing formats ---
    write_stats = stats_formats;
    write_sophs = soph_formats;
    if ~overwrite
        write_stats = stats_missing;
        write_sophs = soph_missing;
    end

    if ~isempty(write_stats)
        app.writeStatsTableFormats( ...
            app.stats_table, statsBase, app.input_fbase, write_stats, overwrite);
    end
    if ~isempty(write_sophs)
        app.writeSOPHsFormats( ...
            app.SOPHs, sophsDir, app.input_fbase, app.channel, write_sophs, overwrite);
    end
end


function have = stats_present_(statsBase)
    have = {};
    if isfile([statsBase '.csv']), have{end+1} = '.csv'; end
    if isfile([statsBase '.mat']) || isfile([statsBase '.h5'])
        have{end+1} = '.mat';
    end
end


function have = soph_present_(sophBase, sophPowBase, sophPhaBase)
    have = {};
    if isfile([sophPowBase '.tiff']) && isfile([sophPhaBase '.tiff'])
        have{end+1} = '.tiff';
    end
    if isfile([sophBase '.mat']) || isfile([sophBase '.h5'])
        have{end+1} = '.mat';
    end
end
