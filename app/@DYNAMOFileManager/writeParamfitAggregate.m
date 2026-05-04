function writeParamfitAggregate(app, partial, outDir, channelName, tag, label)
    % writeParamfitAggregate  Write CSV / MAT aggregate for one paramfit
    % category. Skips entirely if no contributors were found, or if the
    % user declines to overwrite an existing aggregate.
    hasCsv = istable(partial.csv_table) && height(partial.csv_table) > 0;
    hasMat = istable(partial.mat_table) && height(partial.mat_table) > 0;
    if ~hasCsv && ~hasMat, return, end

    base = fullfile(outDir, [channelName '_aggregate_' tag]);
    if ~app.confirmAggregateOverwrite(base, {'.csv','.mat'}, channelName, label)
        app.logResultsBrowser(sprintf('  [%s] %s: kept existing (skipped)', channelName, label));
        return
    end
    if ~isfolder(outDir), mkdir(outDir); end

    if hasCsv
        writetable(partial.csv_table, [base '.csv']);
        app.logResultsBrowser(sprintf('  [%s] wrote %s.csv (%d rows)', ...
            channelName, [channelName '_aggregate_' tag], height(partial.csv_table)));
    end
    if hasMat
        aggregate = struct( ...
            'params',     partial.mat_table, ...
            'subjectIDs', {partial.subjectIDs}); %#ok<NASGU>
        save([base '.mat'], 'aggregate');
        app.logResultsBrowser(sprintf('  [%s] wrote %s.mat (%d rows)', ...
            channelName, [channelName '_aggregate_' tag], height(partial.mat_table)));
    end
end
