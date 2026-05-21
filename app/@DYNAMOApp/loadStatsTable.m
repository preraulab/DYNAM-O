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
    %   .mat files are HDF5 internally (-v7.3) and externally readable
    %   via h5py / h5dump despite the .mat extension; MATLAB's load()
    %   handles them as a normal MAT-file.
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
                % Promote a separate subjectID variable to a column for
                % parity with the CSV layout. Accept legacy `subject_id`
                % (snake_case from pre-rename .mats) as a fallback.
                sid_var = '';
                if isfield(S, 'subjectID') && ~isempty(S.subjectID)
                    sid_var = char(string(S.subjectID));
                elseif isfield(S, 'subject_id') && ~isempty(S.subject_id)
                    sid_var = char(string(S.subject_id));
                end
                if ~isempty(sid_var) && ...
                        ~any(strcmpi(T.Properties.VariableNames, 'subjectID'))
                    T.subjectID = repmat({sid_var}, height(T), 1);
                    T = movevars(T, 'subjectID', 'Before', 1);
                end
                return
            end
        catch
        end
    end

    if isfile(csvPath)
        try
            T = csv2table(csvPath);
            % The compact CSV matches the app's 16-column schema and carries
            % no subjectID column; recover it from the filename (fbase) for
            % parity with the .mat/.h5 path.
            if istable(T) && height(T) > 0 && ...
                    ~any(strcmpi(T.Properties.VariableNames, 'subjectID'))
                T.subjectID = repmat({char(fbase)}, height(T), 1);
                T = movevars(T, 'subjectID', 'Before', 1);
            end
        catch
        end
    end
end
