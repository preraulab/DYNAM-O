function T = joinMetadataToAggregate(app, T, channelName, axisKind)
    % joinMetadataToAggregate  Left-join the cached subject metadata
    %   onto a paramfit aggregate table on the 'ID' column. Both sides
    %   are normalised through normalizeSubjectId before the join so a
    %   metadata row keyed 'subj01.edf' matches an aggregate row keyed
    %   'subj01'.
    %
    %   Identity when no metadata file is configured. Unmatched
    %   aggregate rows survive the join with <missing> / NaN in the
    %   metadata columns; unmatched metadata rows are noted in the
    %   run-log once per (channel, axis) combo so the user knows
    %   which IDs didn't line up.
    if nargin < 3, channelName = ''; end
    if nargin < 4, axisKind    = ''; end
    if isempty(T) || ~istable(T) || ~ismember('ID', T.Properties.VariableNames)
        return
    end

    M = app.loadSubjectMetadata();
    if isempty(M) || ~istable(M) || height(M) == 0
        return
    end

    % Normalise both sides so the join is forgiving on .edf suffixes.
    T.ID = app.normalizeSubjectId(T.ID);
    % M.ID was already normalised by loadSubjectMetadata.

    % Note unmatched IDs once per channel|axis. Don't fail the join.
    aggIds  = unique(T.ID);
    metaIds = unique(M.ID);
    missing = setdiff(aggIds, metaIds);
    if ~isempty(missing)
        try
            tag = strtrim(sprintf('%s|%s', channelName, axisKind));
            app.appendResultsBrowserLog(sprintf( ...
                'Metadata [%s]: %d aggregate ID(s) not in metadata file: %s', ...
                tag, numel(missing), short_list_(missing, 8)));
        catch
        end
    end

    try
        T = outerjoin(T, M, 'Keys', 'ID', ...
            'Type', 'left', 'MergeKeys', true);
    catch ME
        try, app.appendResultsBrowserLog(sprintf( ...
                'Metadata join failed (%s|%s): %s', channelName, axisKind, ...
                ME.message)); catch, end
    end
end


function s = short_list_(items, n)
    if numel(items) <= n
        s = strjoin(string(items), ', ');
    else
        s = strjoin(string(items(1:n)), ', ');
        s = sprintf('%s, … (+%d more)', s, numel(items) - n);
    end
    s = char(s);
end
