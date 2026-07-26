function [resolves, perFileResolved] = simulateChannelResolution(app)
    % simulateChannelResolution  Predict, per-file, which canonical outnames
    % from app.ChannelList will produce a column in read_EDF's output.
    %
    %   [resolves, perFileResolved] = simulateChannelResolution(app)
    %
    %   Returns:
    %     resolves        - logical [nFiles x nUniqueOutnames] matrix.
    %                       resolves(i, k) = true means file i has at least
    %                       one variant in ChannelList that resolves to the
    %                       k-th unique outname's canonical position.
    %     perFileResolved - [1 x nFiles] count of resolved outnames per file.
    %
    %   Uses apply_channel_derivations in dry_run mode against each file's
    %   cached EDF label set, so the simulation honors RefCollision /
    %   variant-fallback semantics exactly. Requires app.EdfLabelCache_ to
    %   already cover the current DataList — call refreshEdfLabelCache
    %   first if unsure.
    %
    %   Order of unique outnames in the columns of `resolves` matches the
    %   first-occurrence iteration over app.ChannelList, which is the same
    %   order runBatch.m uses for primarySpecMask. So the k-th column here
    %   corresponds 1:1 to the k-th `find(primarySpecMask)` entry.
    %
    %   See also: refreshEdfLabelCache, apply_channel_derivations,
    %             runBatch.
    %
    % =====================================================================
    %                   DYNAM-O Toolbox  |  Prerau Laboratory
    % =====================================================================

    paths       = reshape(cellstr(app.DataList),    1, []);
    channelList = reshape(cellstr(app.ChannelList), 1, []);

    if isempty(app.ReferenceList)
        referenceList = {};
    else
        referenceList = reshape(cellstr(app.ReferenceList), 1, []);
    end

    % Compute outnames (one per spec) and build the unique-outname
    % column index in first-occurrence order.
    outnames    = cell(1, numel(channelList));
    for ii = 1:numel(channelList)
        spec = channelList{ii};
        eq = strfind(spec, '=');
        if isempty(eq)
            outnames{ii} = strtrim(spec);
        else
            outnames{ii} = strtrim(spec(1:eq(1)-1));
        end
    end
    [uniqueOutnames, firstIdx] = unique(outnames, 'stable'); %#ok<ASGLU>
    nFiles    = numel(paths);
    nUnique   = numel(uniqueOutnames);
    resolves  = false(nFiles, nUnique);
    perFileResolved = zeros(1, nFiles);

    if nFiles == 0 || nUnique == 0
        return
    end

    % Cache must cover every path in DataList; if anything is missing
    % (e.g. a file failed its header read during the previous refresh)
    % the corresponding row stays all-false.
    if isempty(app.EdfLabelCache_) || ~isa(app.EdfLabelCache_, 'containers.Map')
        return
    end

    % Build a quick lookup from outname → unique-column index.
    outnameToCol = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for k = 1:nUnique
        outnameToCol(uniqueOutnames{k}) = k;
    end

    for ii = 1:nFiles
        p_ = paths{ii};
        if ~app.EdfLabelCache_.isKey(p_), continue; end
        entry = app.EdfLabelCache_(p_);

        % Build a stub signal_header struct array carrying labels + rates
        % only — apply_channel_derivations(dry_run) doesn't touch signal
        % data, so empty sc_in cells are fine.
        nLab = numel(entry.labels);
        if nLab == 0, continue; end
        sh_in = repmat(struct( ...
            'signal_labels',      '', ...
            'sampling_frequency', NaN, ...
            'physical_min',       0, ...
            'physical_max',       0), 1, nLab);
        for jj = 1:nLab
            sh_in(jj).signal_labels      = entry.labels{jj};
            sh_in(jj).sampling_frequency = entry.fs(jj);
        end
        sc_in = cell(1, nLab);   % all empty; dry_run never reads from this

        try
            [sh_out, ~] = apply_channel_derivations( ...
                sh_in, sc_in, channelList, referenceList, false, true);
        catch
            % Hard error in the dry run (e.g. malformed Reference) —
            % treat as "nothing resolves for this file" and move on.
            continue
        end

        % sh_out's labels are the canonical outnames that survived. Mark
        % the corresponding column for this file's row.
        survivedLabels = {sh_out.signal_labels};
        for jj = 1:numel(survivedLabels)
            lbl = survivedLabels{jj};
            if outnameToCol.isKey(lbl)
                resolves(ii, outnameToCol(lbl)) = true;
            end
        end
        perFileResolved(ii) = sum(resolves(ii, :));
    end
end
