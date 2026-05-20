function runBatch(app, dataList, stagingList)
    % runBatch  Main batch processing loop: iterates over all files and channels.
    %
    %   runBatch(app, dataList, stagingList)
    %
    %   dataList/stagingList are the ordered file lists to process. They are
    %   passed in (rather than read from app.DataList/StagingList) so that
    %   reverse-order runs do not permanently mutate the GUI state.
    %
    %   Execution order per iteration:
    %     1. Load EDF and staging data via load_data.
    %     2. Run selected analysis steps (stats, summary, param basis, spline, aux).
    %     3. Log the outcome (success or error) to the run log file.
    %     4. Update the progress bar.
    %
    %   The loop checks isStopBatchButtonPushed at the start of each
    %   file iteration and exits early if the Stop button was pressed.
    %
    %   On completion, all open log file handles are closed and diary is
    %   stopped automatically when consolelog_fid is closed.

    app.TextArea.Value = 'Beginning run...';
    app.curr_datetime   = char(datetime('now','Format','yyMMdd_HHmmSS'));
    app.setRunningState;
    drawnow;

    % Defensively disable parallel-pool auto-creation across the whole
    % batch. Justification: the rust backend's contract is "rayon inside
    % MEX, no MATLAB parpool"; the matlab backend's setup_parallel_pool
    % uses an EXPLICIT parpool() call which AutoCreate=false does not
    % block, so it still gets its pool. Without this guard, post-runDYNAMO
    % stages (fitParamBasis, save_*) can hit a MATLAB built-in (e.g.
    % imgaussfilt, fit() with NLS, prepareSurfaceData) that auto-spawns
    % a process pool — observed concretely on Linux as "Starting parallel
    % pool ... shutting down" between a rust-backend timing summary and
    % the param_basis_phase iterations. Restored via onCleanup so the
    % user's MATLAB session-level setting is unchanged after the batch. %#ok<NASGU>
    % parallel.Settings.Pool.AutoCreate has TWO shapes depending on the
    % MATLAB release: a Setting object (R2025+ ish, supports
    % .TemporaryValue) or a plain logical (R2024b on Linux, supports
    % only direct assignment). Detect at runtime and use the right API.
    pool_autocreate_orig_ = [];
    pool_autocreate_mode_ = 'none';
    if exist('parallel.Settings', 'class') == 8 || ...
            (exist('ver','builtin')~=0 && any(strcmp({ver().Name}, 'Parallel Computing Toolbox')))
        try
            ps_ = parallel.Settings;
            raw_ = ps_.Pool.AutoCreate;
            if isa(raw_, 'matlab.settings.Setting')
                % Modern: Setting object. TemporaryValue keeps the
                % override session-scoped (vs PersonalValue, which would
                % persist across sessions).
                pool_autocreate_orig_ = raw_.ActiveValue;
                ps_.Pool.AutoCreate.TemporaryValue = false;
                pool_autocreate_mode_ = 'temporary';
            else
                % Older: plain logical. Direct assignment is the only
                % option; we restore the captured value at exit.
                pool_autocreate_orig_ = logical(raw_);
                ps_.Pool.AutoCreate = false;
                pool_autocreate_mode_ = 'direct';
            end
            pool_autocreate_cleanup_ = onCleanup( ...
                @() restore_pool_autocreate_(pool_autocreate_orig_, pool_autocreate_mode_)); %#ok<NASGU>
        catch ME_pool_
            app.TextArea.addnl(sprintf('Note: could not disable Pool.AutoCreate (%s)', ME_pool_.message));
        end
    end

    % Build DYNAMO options struct from current GUI settings
    app.TextArea.Value = 'Updating advanced options...';
    drawnow;
    buildOptionsStruct(app)

    % Multi-subject runs with empty SOpower_range / SOpower_binsizestep
    % produce adaptive per-subject SO-power bins. The downstream
    % aggregator stacks those per-pixel, silently averaging
    % physically different SOpower values across subjects. Warn
    % once up front and let the user cancel or proceed.
    if numel(dataList) > 1 && isstruct(app.SOPH_options)
        sopr  = []; sopb = [];
        if isfield(app.SOPH_options, 'SOpower_range')
            sopr = app.SOPH_options.SOpower_range;
        end
        if isfield(app.SOPH_options, 'SOpower_binsizestep')
            sopb = app.SOPH_options.SOpower_binsizestep;
        end
        if isempty(sopr) || isempty(sopb)
            msg = sprintf(['SOpower_range and/or SOpower_binsizestep are empty.\n\n' ...
                'With multiple subjects (%d) this means each subject gets its own ' ...
                'SO-power bin edges (min..max of that subject''s normalized SOpower). ' ...
                'The aggregate "Mean SOPH" then averages bin columns that span ' ...
                'different SOpower values across subjects.\n\n' ...
                'To get comparable SOPHs, set fixed values in SOPH_options ' ...
                '(e.g. SOpower_range = [0 100] for percent norm, or ' ...
                '[-30 30] for shift norm; SOpower_binsizestep = [size step]).\n\n' ...
                'Proceed anyway?'], numel(dataList));
            try
                sel = uiconfirm(app.UIFigure, msg, 'Adaptive SOpower bins', ...
                    'Options', {'Cancel', 'Proceed anyway'}, ...
                    'DefaultOption', 'Cancel', ...
                    'CancelOption',  'Cancel', ...
                    'Icon', 'warning');
            catch
                sel = 'Proceed anyway'; % no UI available
            end
            if strcmp(sel, 'Cancel')
                app.TextArea.Value = 'Run cancelled: set fixed SOpower bins first.';
                app.resetRunUiState;
                return
            end
            % Recorded to the run log only after the log file is
            % opened below; queue it in TextArea now so it's visible
            % in the GUI immediately.
            app.TextArea.addnl( ...
                'WARNING: SOpower bins are adaptive per subject — cross-subject aggregates will be invalid.');
        end
    end

    % Create required output subdirectories and initialise logs (if enabled)
    if app.SaveLogsSwitch.Value
        if ~exist(strcat(app.OutputDirEditField.Value,'/settings/'),'dir')
            mkdir(strcat(app.OutputDirEditField.Value,'/settings/'))
        end
        if ~exist(strcat(app.OutputDirEditField.Value,'/logs/'),'dir')
            mkdir(strcat(app.OutputDirEditField.Value,'/logs/'))
        end
        app.TextArea.Value = 'Creating run log...';
        drawnow;
        createRunLogConsole(app)
        app.TextArea.Value = 'Creating console log...';
        drawnow;
        createConsoleLogPanel(app)
    end

    % Open the per-run JSONL logger. One file per batch
    % invocation, written to <output_dir>/_runs/. Concurrent
    % batches on different machines each open their own file
    % and union at read time via dynamo_index_runs.
    try
        app.RunLogger_ = DYNAMORunLogger(app.OutputDirEditField.Value);
    catch ME
        app.RunLogger_ = [];
        app.TextArea.addnl(['Warning: could not open run log: ', ME.message]);
    end

    % Parse channel list, stage identifiers, and delimiter once before the loop
    app.TextArea.Value = 'Processing channel inputs.';
    updateChannelInput(app)
    updateReferenceInput(app)
    updateStagesInput(app)
    updateDelimeterInput(app)
    drawnow;

    % Initialize the progress bar widget — ticks once per (file,
    % channel) pair so the bar reflects the full work unit count.
    % The label prefix is updated each channel to show "Subject m/M,
    % Channel n/N" so the user can see exactly where the run is.
    nFiles    = length(dataList);
    nChannels = length(app.ChannelList);
    app.ProgressBar.reset();
    app.ProgressBar.LabelPrefix = '';
    % ProgressBar.N must be set BEFORE start() — start() snapshots N
    % into the JS startAnim message, so a later N assignment doesn't
    % propagate. Set it after channelListSafe / nUniqueOutnames is
    % computed (further down) and start() is then invoked there.

    % ---------------------------------------------------------------
    %   MAIN BATCH LOOP
    %   Outer: EDF files | Inner: channels
    % ---------------------------------------------------------------
    warnState = warning('off','all');  % suppress all warnings during run
    set(0, 'DefaultFigureVisible', 'off');  % suppress figure windows during batch
    % Guaranteed-restore via onCleanup so an unhandled exception
    % below cannot leave the MATLAB session globally muted (no
    % warnings) or invisible (every new figure hidden until the
    % session restarts). The explicit restores in the normal
    % cleanup and Stop/error branches still run first; these
    % are the belt-and-braces backstops.
    cleanupWarn = onCleanup(@() warning(warnState)); %#ok<NASGU>
    cleanupVis  = onCleanup(@() set(0, 'DefaultFigureVisible', 'on')); %#ok<NASGU>
    app.curr_iteration = 0;

    % Cache the channel list (raw names for load_data) and a parallel
    % list of filesystem-safe names (used by analysis runners for paths).
    % Sanitising once up front avoids O(N_channels x N_runners)
    % redundant fixFilename calls during the loop.
    % For aliased channel specs ('NAME = expr') the output dir
    % name is the alias — never the raw expression — so that a
    % rereferenced or mean-derived channel writes to a clean
    % directory like CFS_LM/ instead of CFS_C3 - mean(A1,A2)/.
    channelList      = app.ChannelList;
    channelListSafe  = cell(size(channelList));
    channelListAlias = cell(size(channelList));   % raw outname (alias text emitted by read_EDF)
    for ii = 1:numel(channelList)
        spec = channelList{ii};
        eq = strfind(spec, '=');
        if isempty(eq)
            outname = strtrim(spec);
        else
            outname = strtrim(spec(1:eq(1)-1));
        end
        channelListAlias{ii} = outname;
        channelListSafe{ii}  = app.fixFilename(outname,'');
    end

    % Variant-fallback semantics: when the user lists multiple specs that
    % share an output name (e.g. {'C4-A1', 'C4-A1 = [C4-A1 - A]',
    % 'C4-A1 = [C4-A1 - B]'}), the first variant per file that resolves
    % "wins" and the rest are silently skipped — see the RefCollision
    % comment in apply_channel_derivations.m. So the unit of work is one
    % canonical outname per file, not one input spec per file. Mark which
    % input specs are "primary" (first-occurrence) to drive both the
    % progress-bar count and the inner-loop iteration.
    primarySpecMask = false(1, numel(channelList));
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    for ii = 1:numel(channelListSafe)
        if ~seen.isKey(channelListSafe{ii})
            seen(channelListSafe{ii})   = true;
            primarySpecMask(ii)         = true;
        end
    end
    nUniqueOutnames = sum(primarySpecMask);

    % --- Pre-flight: header-only scan + dry-run resolution simulation --
    % Bring the EDF label cache in sync with DataList (path-keyed —
    % files already cached from a prior composer-open are skipped).
    % Then simulate apply_channel_derivations against each file's
    % labels to learn EXACTLY which (file, outname) pairs will produce
    % a real work unit. This unlocks three things below:
    %   (a) the progress bar can be sized to actual expected work
    %       (sum(perFileResolved)), not the upper bound nFiles*K;
    %   (b) files with zero resolving outnames skip the load_data
    %       call entirely (no wasted EDF reads);
    %   (c) primary specs whose outname won't resolve for this file
    %       skip without entering the load logic.
    try
        app.refreshEdfLabelCache( ...
            'ShowProgress',    'progressbar', ...
            'ProgressMessage', 'Pre-flight: scanning EDF headers');
    catch ME_pf
        app.TextArea.addnl(sprintf('Note: pre-flight scan failed (%s); continuing without it.', ME_pf.message));
    end
    try
        [resolves, perFileResolved] = app.simulateChannelResolution();
    catch
        % If the simulator throws for any reason, fall back to the
        % old upper-bound behavior — the rest of the run loop still
        % handles dropped channels correctly.
        resolves        = true(nFiles, nUniqueOutnames);
        perFileResolved = repmat(nUniqueOutnames, 1, nFiles);
    end

    % Map primary-spec index → column in `resolves`. The unique-
    % outname column order in simulateChannelResolution matches the
    % first-occurrence iteration over channelList, which is exactly
    % `find(primarySpecMask)` — so iterate that and assign.
    primarySpecIdxList = find(primarySpecMask);
    primaryToCol       = zeros(1, numel(channelList));
    safeNameToCol      = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for kk = 1:numel(primarySpecIdxList)
        primaryToCol(primarySpecIdxList(kk))                     = kk;
        safeNameToCol(channelListSafe{primarySpecIdxList(kk)})   = kk;
    end

    expectedWorkUnits = sum(perFileResolved);
    if expectedWorkUnits == 0
        % Nothing will resolve in any file. Use upper bound so the
        % bar still completes; the load_failed branch below ticks it.
        expectedWorkUnits = nFiles * nUniqueOutnames;
    end
    app.ProgressBar.N = expectedWorkUnits;
    app.ProgressBar.start;

    % Pre-create every output subdirectory that enabled analysis steps
    % will write to. mkdir is idempotent but each call costs a syscall,
    % so doing this once per (canonical outname) rather than once per
    % (input spec) skips redundant calls when the user lists multiple
    % variants for the same outname.
    outDir = app.OutputDirEditField.Value;
    for ii = find(primarySpecMask)
        chanDir = fullfile(outDir, channelListSafe{ii});
        if app.SavePeakStatsCheckBox.Value || app.SaveSOPHsCheckBox.Value
            mkdir(fullfile(chanDir, 'TFpeaks'));
            mkdir(fullfile(chanDir, 'SOPHs'));
        end
        if app.SaveDataSummaryCheckBox.Value
            mkdir(fullfile(chanDir, 'figures', 'summary'));
        end
        if app.SaveParamBasisCheckBox.Value
            mkdir(fullfile(chanDir, 'param_basis'));
            mkdir(fullfile(chanDir, 'figures', 'param_basis'));
        end
        if app.SaveSplineBasisCheckBox.Value
            mkdir(fullfile(chanDir, 'spline_basis'));
            mkdir(fullfile(chanDir, 'figures', 'spline_basis'));
        end
        if app.SaveAuxDataCheckBox.Value
            mkdir(fullfile(chanDir, 'auxiliary_data'));
        end
    end

    t_batch = tic;
    for jj = 1:length(dataList)

        % --- Per-subject setup (formerly inside the channel loop) ---
        [~, app.input_fbase, ext] = fileparts(dataList{jj});
        % For .edf.gz / .edf.zst inputs fileparts returns
        % "<name>.edf" as the basename and ".gz" / ".zst" as
        % the ext — strip the trailing ".edf" so output
        % filenames don't carry it.
        if (strcmpi(ext, '.gz') || strcmpi(ext, '.zst')) ...
                && endsWith(app.input_fbase, '.edf', 'IgnoreCase', true)
            app.input_fbase = app.input_fbase(1:end-4);
        end

        % Subject-level stop check before incurring the EDF read
        if app.isStopBatchButtonPushed == true
            haltMsg = sprintf('Run halted by user before subject %d/%d (%s).', ...
                jj, nFiles, app.input_fbase);
            try, app.appendRunLog([haltMsg, newline]); catch, end
            try, fprintf('\n%s\n', haltMsg); catch, end
            warning(warnState);
            set(0, 'DefaultFigureVisible', 'on');
            app.stopLogConsoleTimer();
            app.refreshLogConsole();
            if ~isempty(app.consolelog_fid) && app.consolelog_fid > 0, fclose(app.consolelog_fid); app.consolelog_fid = []; end
            diary off;
            if ~isempty(app.runlog_fid) && app.runlog_fid > 0, fclose(app.runlog_fid); app.runlog_fid = []; end
            try
                if ~isempty(app.RunLogger_), app.RunLogger_.close(); end
            catch
            end
            app.RunLogger_ = [];
            app.RunBatchButton.Enabled  = true;
            app.StopBatchButton.Enabled = false;
            app.resetRunUiState;
            app.ProgressBar.reset();
            app.ProgressBar.Enabled = false;
            return
        end

        % --- Pre-flight short-circuit: if the simulator says no
        % outname will resolve in this file, skip the load_data call
        % entirely. Log one load_failed entry per primary outname so
        % the run-log accounting matches the planned-work-units view,
        % then advance to the next subject without paying for a full
        % EDF read just to discover everything was dropped.
        if perFileResolved(jj) == 0
            preFailMsg = sprintf( ...
                'Subject %s: pre-flight predicts 0 of %d outname(s) will resolve. Skipping (no EDF read).', ...
                app.input_fbase, nUniqueOutnames);
            app.TextArea.addnl(preFailMsg);
            fprintf('\n%s\n', preFailMsg);
            try, app.appendRunLog([preFailMsg, newline]); catch, end
            if ~isempty(app.RunLogger_)
                for ii_log = primarySpecIdxList
                    try
                        app.RunLogger_.recordSubject( ...
                            app.input_fbase, channelListSafe{ii_log}, ...
                            'InputFile',  dataList{jj}, ...
                            'Components', {}, ...
                            'Failures',   {'load'}, ...
                            'Status',     'load_failed', ...
                            'DurationSec', 0);
                    catch
                    end
                end
            end
            continue
        end

        % --- Bulk EDF + staging read for this subject ---
        % All channels in one read_EDF pass so the EDF/staging
        % files are touched once per subject (was once per
        % (subject, channel)). On remote storage this collapses
        % nFiles*nChannels full-file transfers into nFiles, and
        % reference derivations (mean(), A-B, etc.) get computed
        % once and shared across every output that uses them.
        fprintf('\n=== Subject: %s (%d/%d) ===\n', app.input_fbase, jj, nFiles);
        app.TextArea.addnl(sprintf('=== Subject: %s (%d/%d) ===', ...
            app.input_fbase, jj, nFiles));
        app.TextArea.addnl(sprintf('Loading staging and EDF data (%d channel(s))...', nChannels));

        bulk_data          = [];
        bulk_Fs            = [];
        bulk_stage_times   = [];
        bulk_stage_vals    = [];
        bulk_signal_labels = {};   % aliases that read_EDF actually emitted
        subject_loaded_ok  = false;
        t_load = tic;
        % Push resampling down into load_data: it pipes TargetFs
        % into read_EDF (References-defined fast path) AND also
        % runs a post-load smartresample(data, Fs, target) which
        % accepts a vector Fs — so heterogeneous-rate channels
        % (e.g. EEG@256 + EOG@100, no References) are resampled
        % per-channel correctly. The previous version reimplemented
        % resampling here at the matlab level using `bulk_Fs(1)`
        % for every column, which would silently mis-resample
        % channels 2..N if bulk_Fs was non-uniform.
        target_fs_arg = [];
        if app.ResampleSwitch.Value
            target_fs_arg = app.ResampleFsEditField.Value;
            msg = sprintf('Resample target: %g Hz (per-channel inside load_data)...', target_fs_arg);
            fprintf('%s\n', msg);
            app.TextArea.addnl(['   ' msg]);
            drawnow;
        end
        try
            [bulk_data, bulk_Fs, bulk_stage_times, bulk_stage_vals, bulk_signal_labels] = load_data( ...
                dataList{jj}, ...
                stagingList{jj}, ...
                app.StagesColumnEditField.Value, ...
                app.TimesColumnEditField.Value, ...
                channelList, ...
                'References',   app.ReferenceList, ...
                'resample_freq', target_fs_arg, ...
                'header_lines', app.HeaderRowsEditField.Value, ...
                'delimiter',    app.delimeter, ...
                'stage_vals_in', { app.ArtifactUserInput, app.WakeUserInput, ...
                app.REMUserInput,      app.N1UserInput, ...
                app.N2UserInput,       app.N3UserInput, ...
                app.UnknownUserInput });

            % use_no_stages override (after resample so length
            % reflects final Fs).
            if app.use_no_stages
                bulk_stage_times = [0, size(bulk_data, 1) / bulk_Fs(1)];
                bulk_stage_vals  = [2, 2];
            end

            subject_loaded_ok = true;
        catch e_load
            is_oom = strcmpi(e_load.identifier, 'MATLAB:nomem') ...
                  || strcmpi(e_load.identifier, 'MATLAB:array:SizeLimitExceeded') ...
                  || contains(lower(e_load.message), 'out of memory') ...
                  || contains(lower(e_load.message), 'requested array exceeds');

            if is_oom && nChannels > 1
                % Out-of-memory on the bulk read: fall back to one canonical
                % outname at a time. Variant-fallback siblings of an outname
                % that already loaded are skipped to honor the same "first
                % match wins" semantics as the bulk derived-channels
                % pipeline (otherwise per-channel reads, which can't
                % trigger RefCollision, would happily load BOTH variants
                % and put two signals into the same output dir).
                msg = sprintf( ...
                    'Out of memory on bulk read of %d channel spec(s). Reverting to per-outname load to save memory.', ...
                    nChannels);
                app.TextArea.addnl(['   ' msg]);
                fprintf('\n%s\n', msg);
                try, app.appendRunLog([msg, newline]); catch, end
                drawnow;

                % Free anything the failed bulk read may have
                % partially allocated before retrying.
                bulk_data = []; bulk_Fs = [];
                bulk_stage_times = []; bulk_stage_vals = [];
                bulk_signal_labels = {};

                outname_loaded = containers.Map('KeyType', 'char', 'ValueType', 'logical');
                for ii_fb = 1:nChannels
                    safe_name = channelListSafe{ii_fb};
                    if outname_loaded.isKey(safe_name)
                        % An earlier variant already produced data for
                        % this canonical outname. Don't try this fallback
                        % spec — it would just duplicate the column.
                        continue
                    end
                    % Skip variants whose canonical outname the
                    % pre-flight simulator already said won't resolve
                    % anywhere in this file. Works for any spec
                    % (primary or fallback variant) — keyed by safe
                    % outname, not spec index. Saves one full
                    % read_EDF round-trip per (never-resolving
                    % outname × variant) attempt.
                    fb_col = 0;
                    if safeNameToCol.isKey(safe_name)
                        fb_col = safeNameToCol(safe_name);
                    end
                    if fb_col > 0 && ~resolves(jj, fb_col)
                        continue
                    end
                    try
                        [d_ii, f_ii, st_ii, sv_ii, lbl_ii] = load_data( ...
                            dataList{jj}, ...
                            stagingList{jj}, ...
                            app.StagesColumnEditField.Value, ...
                            app.TimesColumnEditField.Value, ...
                            channelList(ii_fb), ...
                            'References',   app.ReferenceList, ...
                            'resample_freq', target_fs_arg, ...
                            'header_lines', app.HeaderRowsEditField.Value, ...
                            'delimiter',    app.delimeter, ...
                            'stage_vals_in', { app.ArtifactUserInput, app.WakeUserInput, ...
                            app.REMUserInput,      app.N1UserInput, ...
                            app.N2UserInput,       app.N3UserInput, ...
                            app.UnknownUserInput });
                        if isempty(d_ii) || size(d_ii, 2) == 0
                            % read_EDF dropped this spec (UnknownChannel,
                            % ParseError, etc.). Try the next variant.
                            continue
                        end
                        if isempty(bulk_data)
                            bulk_data        = nan(size(d_ii, 1), 0);
                            bulk_Fs          = nan(1, 0);
                            bulk_stage_times = st_ii;
                            bulk_stage_vals  = sv_ii;
                        end
                        bulk_data          = [bulk_data, d_ii(:)]; %#ok<AGROW>
                        bulk_Fs            = [bulk_Fs, f_ii(1)];   %#ok<AGROW>
                        bulk_signal_labels = [bulk_signal_labels, lbl_ii(1)]; %#ok<AGROW>
                        outname_loaded(safe_name) = true;
                    catch e_ch
                        chFailMsg = sprintf( ...
                            'Channel %s: per-outname fallback load failed (%s).', ...
                            channelList{ii_fb}, e_ch.message);
                        app.TextArea.addnl(['   ' chFailMsg]);
                        fprintf('   %s\n', chFailMsg);
                        try, app.appendRunLog([chFailMsg, newline]); catch, end
                    end
                end

                if ~isempty(bulk_data)
                    if app.use_no_stages
                        bulk_stage_times = [0, size(bulk_data, 1) / bulk_Fs(1)];
                        bulk_stage_vals  = [2, 2];
                    end
                    subject_loaded_ok = true;
                else
                    allFailMsg = sprintf( ...
                        'Subject %s: bulk read OOM and every per-outname retry also failed. All %d outname(s) skipped.', ...
                        app.input_fbase, nUniqueOutnames);
                    app.TextArea.addnl(allFailMsg);
                    fprintf('\nERROR — %s\n', allFailMsg);
                    try, app.appendRunLog([allFailMsg, newline]); catch, end
                end
            else
                loadFailMsg = sprintf( ...
                    'Subject %s: load failed. All %d outname(s) skipped.', ...
                    app.input_fbase, nUniqueOutnames);
                app.TextArea.addnl(loadFailMsg);
                fprintf('\nERROR — %s\n%s\n', loadFailMsg, getReport(e_load, 'basic'));
                app.appendRunLog(sprintf('%s\n%s\n', loadFailMsg, e_load.message));
            end
            drawnow;
        end

        % Build the (input-spec → bulk_data column) mapping for this file.
        % Read_EDF returned bulk_signal_labels[k] = the alias of whichever
        % spec resolved at column k. For each PRIMARY spec (first occurrence
        % of an outname), find the matching column. Specs whose outname is
        % nowhere in bulk_signal_labels are flagged as load-failed for this
        % file. Non-primary specs are silently skipped — by design they're
        % fallback variants whose canonical outname is processed by the
        % primary entry.
        spec_col = zeros(1, nChannels);
        if subject_loaded_ok
            label_to_col = containers.Map('KeyType', 'char', 'ValueType', 'double');
            for kk = 1:numel(bulk_signal_labels)
                lbl = bulk_signal_labels{kk};
                if ~label_to_col.isKey(lbl)
                    label_to_col(lbl) = kk;
                end
            end
            for ii = find(primarySpecMask)
                if label_to_col.isKey(channelListAlias{ii})
                    spec_col(ii) = label_to_col(channelListAlias{ii});
                end
            end
        end

        % Iterate over input specs, but only PRIMARY ones (first-occurrence
        % per outname) do work; the rest are fallback variants and are
        % silently skipped.
        chan_progress = 0;
        for ii = 1:length(channelList)
            if ~primarySpecMask(ii)
                continue
            end

            % Pre-flight short-circuit: simulator predicted no variant
            % of this outname resolves for this file. Log once and
            % move on without entering the load logic. Bar isn't
            % ticked because expectedWorkUnits already excluded this
            % iteration from the total.
            outname_col = primaryToCol(ii);
            if outname_col > 0 && ~resolves(jj, outname_col)
                if ~isempty(app.RunLogger_)
                    try
                        app.RunLogger_.recordSubject( ...
                            app.input_fbase, channelListSafe{ii}, ...
                            'InputFile',  dataList{jj}, ...
                            'Components', {}, ...
                            'Failures',   {'load'}, ...
                            'Status',     'load_failed', ...
                            'DurationSec', 0);
                    catch
                    end
                end
                continue
            end

            chan_progress = chan_progress + 1;
            app.channel = channelListSafe{ii};

            % Update the progress-bar label so the user can see
            % which subject/channel is currently running. The bar
            % itself is ticked at the end of this iteration.
            try
                app.ProgressBar.LabelPrefix = sprintf( ...
                    'Subject %d/%d, Channel %d/%d', ...
                    jj, nFiles, chan_progress, nUniqueOutnames);
            catch
                % progress bar UI errors must never abort the batch
            end

            % Honor stop request before starting each new iteration
            if app.isStopBatchButtonPushed == true
                haltMsg = sprintf('Run halted by user before subject %d/%d, channel %d/%d (%s | %s).', ...
                    jj, nFiles, chan_progress, nUniqueOutnames, ...
                    app.input_fbase, app.channel);
                try, app.appendRunLog([haltMsg, newline]); catch, end
                try, fprintf('\n%s\n', haltMsg); catch, end
                warning(warnState);
                set(0, 'DefaultFigureVisible', 'on');
                app.stopLogConsoleTimer();
                app.refreshLogConsole();
                if ~isempty(app.consolelog_fid) && app.consolelog_fid > 0, fclose(app.consolelog_fid); app.consolelog_fid = []; end
                diary off;
                if ~isempty(app.runlog_fid) && app.runlog_fid > 0, fclose(app.runlog_fid); app.runlog_fid = []; end
                try
                    if ~isempty(app.RunLogger_), app.RunLogger_.close(); end
                catch
                end
                app.RunLogger_ = [];
                app.RunBatchButton.Enabled  = true;
                app.StopBatchButton.Enabled = false;
                app.resetRunUiState;
                app.ProgressBar.reset();
                app.ProgressBar.Enabled = false;
                return
            end

            app.anything_run = 0;
            app.partial_failures = {};
            % Clear cached compute state from any prior channel.
            app.SOPHs            = [];
            app.stats_table      = [];
            app.auxiliary_data   = [];
            app.Fs               = [];

            fprintf('\n--- Subject: %s | Channel: %s ---\n', app.input_fbase, app.channel);
            app.TextArea.addnl(sprintf('--- Subject: %s | Channel: %s ---', ...
                app.input_fbase, app.channel));

            stage_failures = {};
            t_iter = tic;

            if ~subject_loaded_ok || spec_col(ii) == 0
                % Either the whole subject failed to load, or no variant
                % for this canonical outname resolved against this file's
                % EDF labels. Log load_failed and tick the progress bar
                % so totals stay consistent with the planned work units.
                if ~isempty(app.RunLogger_)
                    try
                        app.RunLogger_.recordSubject( ...
                            app.input_fbase, app.channel, ...
                            'InputFile',  dataList{jj}, ...
                            'Components', {}, ...
                            'Failures',   {'load'}, ...
                            'Status',     'load_failed', ...
                            'DurationSec', toc(t_load));
                    catch
                    end
                end
                try
                    app.curr_iteration = app.curr_iteration + 1;
                    app.ProgressBar.updateIteration(app.curr_iteration);
                catch
                end
                continue
            end

            % Slice this channel from the bulk read using the column that
            % read_EDF actually emitted for this outname (positional
            % `bulk_data(:, ii)` would be wrong — earlier specs may have
            % been silently dropped or deduped).
            app.data        = bulk_data(:, spec_col(ii));
            app.Fs          = bulk_Fs(spec_col(ii));
            app.stage_times = bulk_stage_times;
            app.stage_vals  = bulk_stage_vals;

            % ---- Run selected analysis steps (each isolated) ----
            % Each stage gets its own try/catch. On failure, log the
            % specific stage and continue with subsequent stages.
            stages = {};
            if app.SavePeakStatsCheckBox.Value || app.SaveSOPHsCheckBox.Value
                stages{end+1} = struct('name','TF-peaks / SOPH', 'fcn',@() runStatsTable(app));
            end
            if app.SaveDataSummaryCheckBox.Value
                stages{end+1} = struct('name','data summary figure', 'fcn',@() runDataSummaryFigure(app));
            end
            if app.SaveParamBasisCheckBox.Value
                stages{end+1} = struct('name','parametric basis fit', 'fcn',@() runParamBasis(app));
            end
            if app.SaveSplineBasisCheckBox.Value
                stages{end+1} = struct('name','spline basis fit', 'fcn',@() runSplineBasis(app));
            end
            if app.SaveAuxDataCheckBox.Value
                stages{end+1} = struct('name','auxiliary data', 'fcn',@() saveAuxData(app));
            end

            for ss = 1:numel(stages)
                try
                    stages{ss}.fcn();
                catch e_stage
                    stage_failures{end+1} = stages{ss}.name; %#ok<AGROW>
                    app.TextArea.addnl(['   [ERROR] ', stages{ss}.name, ...
                        ' failed — see log for details.']);
                    fprintf('\nERROR — Subject %s, channel %s, stage "%s": %s\n', ...
                        app.input_fbase, app.channel, stages{ss}.name, ...
                        getReport(e_stage, 'basic'));
                    app.appendRunLog(sprintf( ...
                        'Subject %s, channel %s: stage "%s" failed: %s\n', ...
                        app.input_fbase, app.channel, stages{ss}.name, e_stage.message));
                end
            end

            % ---- Per-subject summary ----
            % Stage-level failures (whole stage threw) and sub-step
            % failures (e.g. one of power/phase fits returned empty)
            % both count toward "partially run".
            all_failures = [stage_failures, app.partial_failures];
            if isempty(all_failures)
                if app.anything_run
                    app.TextArea.addnl([   'Successfully run subject ', ...
                        app.input_fbase,', channel ',app.channel,'.']);
                    app.appendRunLog(sprintf('Subject %s, channel %s: run successfully.\n', ...
                        app.input_fbase, app.channel));
                else
                    % Nothing new to compute: all outputs already existed
                    app.appendRunLog(sprintf( ...
                        'Subject %s, channel %s: all files already exist. Subject skipped.\n', ...
                        app.input_fbase, app.channel));
                end
            else
                failed_str = strjoin(all_failures, ', ');
                app.TextArea.addnl(['Subject ',app.input_fbase, ...
                    ', channel ',app.channel,' partially run. Failed: ',failed_str,'.']);
                app.appendRunLog(sprintf( ...
                    'Subject %s, channel %s: partially run. Failed: %s.\n', ...
                    app.input_fbase, app.channel, failed_str));
            end

            % Append a structured (subject, channel) event to the
            % per-run JSONL log so dynamo_index_runs can find it
            % later without walking the output directory tree.
            if ~isempty(app.RunLogger_)
                attempted = {};
                if app.SavePeakStatsCheckBox.Value, attempted{end+1} = 'TFpeaks';  end
                if app.SaveSOPHsCheckBox.Value,     attempted{end+1} = 'SOPHs';    end
                if app.SaveDataSummaryCheckBox.Value,attempted{end+1} = 'summary'; end
                if app.SaveParamBasisCheckBox.Value, attempted{end+1} = 'paramfit';end
                if app.SaveSplineBasisCheckBox.Value,attempted{end+1} = 'spline';  end
                if app.SaveAuxDataCheckBox.Value,    attempted{end+1} = 'aux';     end
                failed_components = {};
                for fi = 1:numel(all_failures)
                    switch all_failures{fi}
                        case 'TF-peaks / SOPH'
                            failed_components = [failed_components, {'TFpeaks','SOPHs'}]; %#ok<AGROW>
                        case 'data summary figure',  failed_components{end+1} = 'summary';   %#ok<AGROW>
                        case 'parametric basis fit', failed_components{end+1} = 'paramfit';  %#ok<AGROW>
                        case 'spline basis fit',     failed_components{end+1} = 'spline';    %#ok<AGROW>
                        case 'auxiliary data',       failed_components{end+1} = 'aux';       %#ok<AGROW>
                        otherwise,                   failed_components{end+1} = all_failures{fi}; %#ok<AGROW>
                    end
                end
                succeeded = setdiff(attempted, failed_components, 'stable');
                if ~isempty(all_failures), status_s = 'partial';
                elseif app.anything_run,   status_s = 'ok';
                else,                      status_s = 'skipped';
                end
                try
                    app.RunLogger_.recordSubject( ...
                        app.input_fbase, app.channel, ...
                        'InputFile',   dataList{jj}, ...
                        'Components',  succeeded, ...
                        'Failures',    failed_components, ...
                        'Status',      status_s, ...
                        'DurationSec', toc(t_iter));
                catch
                end
            end
            drawnow;

            % Tick the progress bar once per (file, channel) pair.
            % N was set to nFiles*nChannels so curr_iteration tracks
            % the total channel-subject work units completed.
            try
                app.curr_iteration = app.curr_iteration + 1;
                app.ProgressBar.updateIteration(app.curr_iteration);
            catch e
                warning(warnState);
                set(0, 'DefaultFigureVisible', 'on');
                disp(e);
                app.stopLogConsoleTimer();
                app.refreshLogConsole();
                if ~isempty(app.consolelog_fid) && app.consolelog_fid > 0, fclose(app.consolelog_fid); app.consolelog_fid = []; end
                diary off;
                if ~isempty(app.runlog_fid) && app.runlog_fid > 0, fclose(app.runlog_fid); app.runlog_fid = []; end
                try
                    if ~isempty(app.RunLogger_), app.RunLogger_.close(); end
                catch
                end
                app.RunLogger_ = [];
                app.resetRunUiState;
                app.ProgressBar.reset();
                app.ProgressBar.Enabled = false;
                % Restore the run/stop button state so the user can
                % start another batch. Without these, RUN stays
                % disabled and STOP stays enabled, leaving the GUI
                % stuck — the only escape is restarting the app.
                app.RunBatchButton.Enabled  = true;
                app.StopBatchButton.Enabled = false;
                return;
            end

        end % channel loop

    end % file loop

    % ---------------------------------------------------------------
    %   CLEANUP
    % ---------------------------------------------------------------
    warning(warnState);
    set(0, 'DefaultFigureVisible', 'on');
    app.ProgressBar.complete();
    drawnow
    app.ProgressBar.Enabled = false;

    % Total elapsed time for the whole batch — printed to the
    % UI textarea, the run log, and stdout/diary so it's easy
    % to compare runs across machines / network conditions.
    batchElapsed = toc(t_batch);
    hh = floor(batchElapsed / 3600);
    mm = floor(mod(batchElapsed, 3600) / 60);
    ss_t = mod(batchElapsed, 60);
    if hh > 0
        batchTimeStr = sprintf('%dh %02dm %05.2fs', hh, mm, ss_t);
    elseif mm > 0
        batchTimeStr = sprintf('%dm %05.2fs', mm, ss_t);
    else
        batchTimeStr = sprintf('%.2fs', ss_t);
    end
    totalMsg = sprintf( ...
        'Batch run complete. Total time: %s (%d subject(s) x %d outname(s) = %d run unit(s)).', ...
        batchTimeStr, nFiles, nUniqueOutnames, nFiles * nUniqueOutnames);
    app.TextArea.addnl(totalMsg);
    try, app.appendRunLog([totalMsg, newline]); catch, end
    fprintf('\n%s\n', totalMsg);
    drawnow;
    app.stopLogConsoleTimer();
    app.refreshLogConsole();  % final capture of any remaining diary output
    if ~isempty(app.consolelog_fid) && app.consolelog_fid > 0, fclose(app.consolelog_fid); app.consolelog_fid = []; end
    diary off;
    if ~isempty(app.runlog_fid) && app.runlog_fid > 0, fclose(app.runlog_fid); app.runlog_fid = []; end
    try
        if ~isempty(app.RunLogger_), app.RunLogger_.close(); end
    catch
    end
    app.RunLogger_ = [];
    app.RunBatchButton.Enabled  = true;
    app.StopBatchButton.Enabled = false;
    app.resetRunUiState;
    drawnow
end % runBatch

function restore_pool_autocreate_(orig, mode)
    % Restore the original parallel.Settings.Pool.AutoCreate value at
    % batch exit. mode tracks which API shape we used on entry so we
    % know how to undo: 'temporary' clears the TemporaryValue; 'direct'
    % assigns back the captured primitive value.
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
