function M = loadSubjectMetadata(app)
    % loadSubjectMetadata  Read the user-supplied metadata table from
    %   app.MetadataFile_, canonicalise its first column to 'ID', and
    %   cache the result on app.MetadataTable_. Returns the cached
    %   table, or an empty table when no file is configured / readable.
    %
    %   Read once and re-use: setMetadataFile clears the cache when
    %   the path changes, so subsequent calls (per channel|axis load,
    %   per Mean SOPH redraw) hit memory.
    %
    %   Schema:
    %     - First column → 'ID' (rest left as-is, with original headers).
    %     - Empty / missing IDs are dropped.
    %     - .edf / .EDF stripped from the ID via normalizeSubjectId so
    %       lenient filename matching works.
    %     - Duplicate IDs (after normalisation) keep the first occurrence
    %       and drop the rest with a warning to the run-log console.
    M = table.empty;

    if ~isempty(app.MetadataTable_)
        M = app.MetadataTable_;
        return
    end

    p = char(app.MetadataFile_);
    if isempty(p) || ~isfile(p)
        return
    end

    try
        raw = readtable(p, 'VariableNamingRule', 'preserve');
    catch ME
        try, app.appendResultsBrowserLog(sprintf( ...
                'Metadata: read failed for %s — %s', p, ME.message)); catch, end
        return
    end
    if isempty(raw) || width(raw) < 1
        return
    end

    % Force the first column's name to 'ID' so the join site has a
    % stable key regardless of what the user typed in row 1.
    raw.Properties.VariableNames{1} = 'ID';

    % Normalise IDs and drop empties.
    raw.ID = app.normalizeSubjectId(raw.ID);
    keep   = cellfun(@(s) ischar(s) && ~isempty(s), raw.ID);
    raw    = raw(keep, :);
    if isempty(raw), return, end

    % Drop duplicate IDs (first wins) so outerjoin keys are unique.
    [~, ia, ic] = unique(raw.ID, 'stable');
    if numel(ia) < height(raw)
        dups = raw.ID(setdiff(1:height(raw), ia));
        try, app.appendResultsBrowserLog(sprintf( ...
                'Metadata: %d duplicate ID row(s) ignored (first kept): %s', ...
                numel(dups), strjoin(unique(dups), ', '))); catch, end
        raw = raw(ia, :);
    end %#ok<NASGU>  % `ic` unused, suppress

    app.MetadataTable_ = raw;
    M = raw;
end
