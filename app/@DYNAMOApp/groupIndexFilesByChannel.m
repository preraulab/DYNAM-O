function map = groupIndexFilesByChannel(~, root, idx)
    %GROUPINDEXFILESBYCHANNEL  Bin idx.entries' files cell by channel,
    %   resolving each entry's root-relative paths to absolute paths.
    %   Returns a containers.Map of channel name → cell of absolute
    %   paths (deduped). Used by aggregateResultsRoot to drive the
    %   aggregator without any filesystem walk.
    map = containers.Map('KeyType','char','ValueType','any');
    for ii = 1:numel(idx.entries)
        e = idx.entries{ii};
        if ~isfield(e,'files') || isempty(e.files), continue, end
        chan = char(e.channel);
        if isKey(map, chan)
            fpaths = map(chan);
        else
            fpaths = {};
        end
        for jj = 1:numel(e.files)
            rel = strrep(char(e.files{jj}), '/', filesep);
            fpaths{end+1} = fullfile(root, rel); %#ok<AGROW>
        end
        map(chan) = fpaths;
    end
    % Dedupe each channel's list (synth can produce duplicates when
    % multiple components share a category subdir).
    chKeys = map.keys;
    for ii = 1:numel(chKeys)
        map(chKeys{ii}) = unique(map(chKeys{ii}), 'stable');
    end
end
