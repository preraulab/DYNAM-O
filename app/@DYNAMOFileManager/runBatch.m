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

    % Build DYNAMO options struct from current GUI settings
    app.TextArea.Value = 'Updating advanced options...';
    drawnow;
    buildOptionsStruct(app)

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
    app.ProgressBar.N = nFiles * nChannels;
    app.ProgressBar.LabelPrefix = '';
    app.ProgressBar.start;

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
    for ii = 1:numel(channelList)
        spec = channelList{ii};
        eq = strfind(spec, '=');
        if isempty(eq)
            outname = strtrim(spec);
        else
            outname = strtrim(spec(1:eq(1)-1));
        end
        channelListSafe{ii} = app.fixFilename(outname,'');
    end

    % Pre-create every output subdirectory that enabled analysis steps
    % will write to. mkdir is idempotent but each call costs a syscall,
    % so doing this once per (channel) rather than per (channel x runner)
    % saves O(N_channels * N_runners) mkdir calls per batch.
    outDir = app.OutputDirEditField.Value;
    for ii = 1:numel(channelListSafe)
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

        bulk_data        = [];
        bulk_Fs          = [];
        bulk_stage_times = [];
        bulk_stage_vals  = [];
        subject_loaded_ok    = false;
        channel_load_failed  = false(1, nChannels);
        t_load = tic;
        try
            [bulk_data, bulk_Fs, bulk_stage_times, bulk_stage_vals] = load_data( ...
                dataList{jj}, ...
                stagingList{jj}, ...
                app.StagesColumnEditField.Value, ...
                app.TimesColumnEditField.Value, ...
                channelList, ...
                'References',  app.ReferenceList, ...
                'header_lines', app.HeaderRowsEditField.Value, ...
                'delimiter',    app.delimeter, ...
                'stage_vals_in', { app.ArtifactUserInput, app.WakeUserInput, ...
                app.REMUserInput,      app.N1UserInput, ...
                app.N2UserInput,       app.N3UserInput, ...
                app.UnknownUserInput });

            % Resample once for every column. With References
            % defined, load_data's read_EDF call already pushes
            % TargetFs in and bulk_Fs returns uniformly at the
            % target rate, making this a no-op — kept for the
            % References-empty path where read_EDF returned
            % native rates.
            if app.ResampleSwitch.Value
                target_fs = app.ResampleFsEditField.Value;
                if any(abs(bulk_Fs - target_fs) > 1e-9)
                    msg = sprintf('Resampling from %g Hz to %g Hz...', bulk_Fs(1), target_fs);
                    fprintf('%s\n', msg);
                    app.TextArea.addnl(['   ' msg]);
                    drawnow;
                    [pp, qq]  = rat(target_fs / bulk_Fs(1));
                    bulk_data = resample(bulk_data, pp, qq);
                    bulk_Fs   = repmat(target_fs, 1, size(bulk_data, 2));
                end
            end

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
                % Out-of-memory on the bulk read: fall back to
                % loading one channel at a time, stitching the
                % columns into bulk_data as we go. Channels that
                % still fail individually are flagged in
                % channel_load_failed so the inner loop skips
                % them but processes the survivors.
                msg = sprintf( ...
                    'Out of memory on bulk read of %d channel(s). Reverting to channel-by-channel load to save memory.', ...
                    nChannels);
                app.TextArea.addnl(['   ' msg]);
                fprintf('\n%s\n', msg);
                try, app.appendRunLog([msg, newline]); catch, end
                drawnow;

                % Free anything the failed bulk read may have
                % partially allocated before retrying.
                bulk_data = []; bulk_Fs = [];
                bulk_stage_times = []; bulk_stage_vals = [];

                per_ch_ok = false(1, nChannels);
                for ii_fb = 1:nChannels
                    try
                        [d_ii, f_ii, st_ii, sv_ii] = load_data( ...
                            dataList{jj}, ...
                            stagingList{jj}, ...
                            app.StagesColumnEditField.Value, ...
                            app.TimesColumnEditField.Value, ...
                            channelList(ii_fb), ...
                            'References',  app.ReferenceList, ...
                            'header_lines', app.HeaderRowsEditField.Value, ...
                            'delimiter',    app.delimeter, ...
                            'stage_vals_in', { app.ArtifactUserInput, app.WakeUserInput, ...
                            app.REMUserInput,      app.N1UserInput, ...
                            app.N2UserInput,       app.N3UserInput, ...
                            app.UnknownUserInput });
                        if app.ResampleSwitch.Value
                            target_fs = app.ResampleFsEditField.Value;
                            if any(abs(f_ii - target_fs) > 1e-9)
                                [pp, qq] = rat(target_fs / f_ii(1));
                                d_ii = resample(d_ii, pp, qq);
                                f_ii = repmat(target_fs, 1, size(d_ii, 2));
                            end
                        end
                        if isempty(bulk_data)
                            bulk_data        = nan(size(d_ii, 1), nChannels);
                            bulk_Fs          = nan(1, nChannels);
                            bulk_stage_times = st_ii;
                            bulk_stage_vals  = sv_ii;
                        end
                        bulk_data(:, ii_fb) = d_ii;
                        bulk_Fs(ii_fb)      = f_ii(1);
                        per_ch_ok(ii_fb)    = true;
                    catch e_ch
                        channel_load_failed(ii_fb) = true;
                        chFailMsg = sprintf( ...
                            'Channel %s: per-channel fallback load failed (%s).', ...
                            channelList{ii_fb}, e_ch.message);
                        app.TextArea.addnl(['   ' chFailMsg]);
                        fprintf('   %s\n', chFailMsg);
                        try, app.appendRunLog([chFailMsg, newline]); catch, end
                    end
                end

                if any(per_ch_ok)
                    if app.use_no_stages
                        first_ok_ii = find(per_ch_ok, 1);
                        bulk_stage_times = [0, size(bulk_data, 1) / bulk_Fs(first_ok_ii)];
                        bulk_stage_vals  = [2, 2];
                    end
                    subject_loaded_ok = true;
                else
                    allFailMsg = sprintf( ...
                        'Subject %s: bulk read OOM and every per-channel retry also failed. All %d channel(s) skipped.', ...
                        app.input_fbase, nChannels);
                    app.TextArea.addnl(allFailMsg);
                    fprintf('\nERROR — %s\n', allFailMsg);
                    try, app.appendRunLog([allFailMsg, newline]); catch, end
                end
            else
                loadFailMsg = sprintf( ...
                    'Subject %s: load failed. All %d channel(s) skipped.', ...
                    app.input_fbase, nChannels);
                app.TextArea.addnl(loadFailMsg);
                fprintf('\nERROR — %s\n%s\n', loadFailMsg, getReport(e_load, 'basic'));
                app.appendRunLog(sprintf('%s\n%s\n', loadFailMsg, e_load.message));
            end
            drawnow;
        end

        for ii = 1:length(channelList)
            app.channel = channelListSafe{ii};

            % Update the progress-bar label so the user can see
            % which subject/channel is currently running. The bar
            % itself is ticked at the end of this iteration.
            try
                app.ProgressBar.LabelPrefix = sprintf( ...
                    'Subject %d/%d, Channel %d/%d', ...
                    jj, nFiles, ii, nChannels);
            catch
                % progress bar UI errors must never abort the batch
            end

            % Honor stop request before starting each new iteration
            if app.isStopBatchButtonPushed == true
                haltMsg = sprintf('Run halted by user before subject %d/%d, channel %d/%d (%s | %s).', ...
                    jj, nFiles, ii, nChannels, ...
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

            if ~subject_loaded_ok || channel_load_failed(ii)
                % Either the whole subject failed to load, or
                % we fell back to per-channel mode and this
                % particular channel still failed. Either way,
                % log load_failed and tick the progress bar so
                % totals stay consistent with the planned work
                % units.
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

            % Slice this channel from the bulk read.
            app.data        = bulk_data(:, ii);
            app.Fs          = bulk_Fs(ii);
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
        'Batch run complete. Total time: %s (%d subject(s) x %d channel(s) = %d run unit(s)).', ...
        batchTimeStr, nFiles, nChannels, nFiles * nChannels);
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
