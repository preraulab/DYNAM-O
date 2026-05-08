function T = loadStatsTable(app, channel, fbase)
    % loadStatsTable  Resolve a stats_table from any saved format.
    %
    %   T = loadStatsTable(app, channel, fbase)
    %
    %   Resolution order:
    %     1. In-memory app.stats_table → return as-is.
    %     2. <chan>/TFpeaks/<fbase>_stats_table_<chan>.h5    → load.
    %     3. <chan>/TFpeaks/<fbase>_stats_table_<chan>.mat   → load (legacy).
    %     4. <chan>/TFpeaks/<fbase>_stats_table_<chan>.csv   → csv2table.
    %     5. Empty table on total miss.
    %
    %   The .h5 / .mat distinction is cosmetic — both are HDF5 written
    %   via save(...,'-v7.3'); MATLAB's load() handles either.
    %
    %   See also: writeStatsTableFormats, csv2table, table2csv.

    T = table.empty;

    if ~isempty(app.stats_table)
        T = app.stats_table;
        return
    end

    chanDir   = fullfile(app.OutputDirEditField.Value, channel);
    statsBase = fullfile(chanDir, 'TFpeaks', [fbase '_stats_table_' channel]);

    h5Path  = [statsBase '.h5'];
    matPath = [statsBase '.mat'];
    csvPath = [statsBase '.csv'];

    % .h5 → load() reads MATLAB's HDF5 layout regardless of extension.
    for binPath = {h5Path, matPath}
        p = binPath{1};
        if ~isfile(p), continue, end
        try
            S = load(p);
            if isfield(S, 'stats_table') && istable(S.stats_table)
                T = S.stats_table;
                % Promote a separate 'subject_id' variable to a SubjectID
                % column for parity with the CSV layout.
                if isfield(S, 'subject_id') && ~isempty(S.subject_id) && ...
                        ~any(strcmpi(T.Properties.VariableNames, 'SubjectID'))
                    sid = char(string(S.subject_id));
                    T.SubjectID = repmat({sid}, height(T), 1);
                    T = movevars(T, 'SubjectID', 'Before', 1);
                end
                return
            end
        catch
        end
    end

    if isfile(csvPath)
        try
            T = csv2table(csvPath);
        catch
        end
    end
end
