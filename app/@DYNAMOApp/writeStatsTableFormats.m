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
    %                 identifying:
    %                   - .csv : NOT a column — the CSV matches the DYNAM-O
    %                            desktop app's strict 16-column schema (no
    %                            subjectID). loadStatsTable recovers the id
    %                            from the filename. BoundingBox is decomposed
    %                            into bbox_tl_s/bbox_tl_Hz/bbox_width_s/
    %                            bbox_height_Hz.
    %                   - .mat : saved as a top-level `subjectID` var
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
                T = stats_table_to_app_csv(stats_table);
                table2csv(T, p);
                app.output_stats_name = p;
            case '.mat'
                p = [statsBase '.mat'];
                if ~overwrite && isfile(p), continue, end
                if ~wrote_any, app.TextArea.addnl('   Saving stats table...'); wrote_any = true; end
                subjectID = subject_id; %#ok<NASGU>
                save(p, 'stats_table', 'subjectID', '-v7.3');
                app.output_stats_name = p;
            otherwise
                % unrecognised — silently skip
        end
    end
end


