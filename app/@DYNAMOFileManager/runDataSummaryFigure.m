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
    if isempty(app.SOPHs)
        if isfile(sophMat)
            app.SOPHs = load(sophMat).SOPHs;
        else
            runStatsTable(app);   % Compute from scratch
        end
    end

    % ---- Ensure stats_table is available ----
    if isempty(app.stats_table)
        statsBase = fullfile(chanDir, 'TFpeaks', [app.input_fbase '_stats_table_' app.channel]);
        csvPath = [statsBase '.csv'];
        matPath = [statsBase '.mat'];
        matExists = isfile(matPath);
        csvExists = isfile(csvPath);

        if matExists
            app.stats_table = load(matPath,'stats_table').stats_table;
        elseif csvExists
            app.stats_table = csv2table(csvPath);
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
