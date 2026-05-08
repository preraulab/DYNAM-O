function writeStatsTableFormats(app, stats_table, statsBase, subject_id, formats, overwrite)
    % writeStatsTableFormats  Write stats_table to each requested format.
    %
    %   app.writeStatsTableFormats(stats_table, statsBase, subject_id, ...
    %                              formats, overwrite)
    %
    %   stats_table : MATLAB table (canonical).
    %   statsBase   : path prefix without extension, e.g.
    %                 '<chan>/TFpeaks/<fbase>_stats_table_<chan>'.
    %   subject_id  : char (== fbase). Embedded so artifacts are self-
    %                 identifying without filename parsing:
    %                   - .csv : added as a `SubjectID` column.
    %                   - .h5  : saved as a top-level `subject_id` var
    %                            alongside `stats_table`.
    %   formats     : cellstr of extensions — subset of {'.csv', '.mat'}.
    %                 The `.mat` slot is HDF5 internally (-v7.3) so
    %                 h5py / h5dump can read it directly.
    %   overwrite   : logical. When false, files that already exist are
    %                 skipped silently.
    %
    %   See also: loadStatsTable, table2csv, csv2table.

    if isempty(formats), return, end
    if ~iscell(formats), formats = {formats}; end
    subject_id = char(subject_id); %#ok<NASGU>

    wrote_any = false;
    for ii = 1:numel(formats)
        ext = lower(char(formats{ii}));
        switch ext
            case '.csv'
                p = [statsBase '.csv'];
                if ~overwrite && isfile(p), continue, end
                if ~wrote_any, app.TextArea.addnl('   Saving stats table...'); wrote_any = true; end
                T = ensure_subject_column_(stats_table, subject_id);
                table2csv(T, p);
                app.output_stats_name = p;
            case '.mat'
                p = [statsBase '.mat'];
                if ~overwrite && isfile(p), continue, end
                if ~wrote_any, app.TextArea.addnl('   Saving stats table...'); wrote_any = true; end
                save(p, 'stats_table', 'subject_id', '-v7.3');
                app.output_stats_name = p;
            otherwise
                % unrecognised — silently skip
        end
    end
end


function T = ensure_subject_column_(T, subject_id)
    if ~istable(T) || isempty(subject_id), return, end
    if any(strcmpi(T.Properties.VariableNames, 'SubjectID'))
        return
    end
    n = height(T);
    T.SubjectID = repmat({subject_id}, n, 1);
    T = movevars(T, 'SubjectID', 'Before', 1);
end
