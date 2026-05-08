function runDataSummaryFigure(app)
    % runDataSummaryFigure  Generate and save the data summary figure.
    %
    %   Loads SOPHs and stats_table from memory or disk as needed, then
    %   calls displaySummaryPlot and saves the result using the format
    %   specified by DataSummaryDropDown.

    % Channel/output dirs prepared once in runBatch; reuse cached paths
    chanDir    = fullfile(app.OutputDirEditField.Value, app.channel);
    summaryDir = fullfile(chanDir, 'figures', 'summary');
    sophMat    = fullfile(chanDir, 'SOPHs', [app.input_fbase '_SOPHs_' app.channel '.mat']);

    % ---- Skip-when-cached gate ----
    % If the dropdown is '--' there's nothing to write, and if
    % the target file already exists and overwrite is off we
    % can short-circuit before paying the SOPH/stats load cost.
    fig_choice = app.DataSummaryDropDown.Value;
    if strcmp(fig_choice,'--')
        return
    end
    figPath = fullfile(summaryDir, ...
        [app.input_fbase '_summary_figure_' app.channel fig_choice]);
    overwrite = app.OverwriteExistingFilesCheckBox.Value;
    if ~overwrite && isfile(figPath)
        app.TextArea.addnl('   Skipping summary figure (file already exists).');
        return
    end

    % ---- Ensure SOPHs are available ----
    % Unified loader: in-memory → SOPHs.mat → TIFF + aux reconstruction.
    % displaySummaryPlot needs SOpower_norm + SOpower_times for the
    % SO-power overlay; both come from auxiliary_data via the loader
    % (SOpower_times is synthesised from Fs + retain_Fs + window_params).
    if isempty(app.SOPHs)
        SOPHs_resolved = app.loadOrReconstructSOPHs(app.channel, app.input_fbase);
        if isfield(SOPHs_resolved, 'SOpower_mat') || ...
                isfield(SOPHs_resolved, 'SOphase_mat')
            app.SOPHs = SOPHs_resolved;
        else
            runStatsTable(app);   % Compute from scratch
        end
    end

    % ---- Ensure stats_table is available ----
    if isempty(app.stats_table)
        T_loaded = app.loadStatsTable(app.channel, app.input_fbase);
        if ~isempty(T_loaded)
            app.stats_table = T_loaded;
        else
            runStatsTable(app);      % Compute from scratch
        end
    end

    app.output_fig_name = figPath;
    app.anything_run    = 1;
    app.TextArea.addnl('   Generating summary figure...');
    fh = app.displaySummaryPlot;
    app.TextArea.addnl('   Saving summary figure...');
    exportgraphics(fh, figPath, 'Resolution', 300);
    close all;
end % runDataSummaryFigure
