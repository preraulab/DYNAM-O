function reportChannelCoverage(app)
    % reportChannelCoverage  Print a per-channel coverage table to the
    % TextArea + stdout, summarizing how many of the currently-cached
    % EDFs contain each channel.
    %
    %   When the channel composer has been used (app.ChannelList
    %   non-empty), the report is keyed on the user's configured output
    %   channels — running the dry-run resolver against each cached
    %   file's labels to learn whether at least one variant for each
    %   channel resolves there. This matches what the run loop will
    %   actually do.
    %
    %   When no channels are configured yet, falls back to a raw
    %   EDF-label coverage table so the user can still see what's in
    %   their files (and pick a sensible channel list).
    %
    %   Called from refreshEdfLabelCache after any cache mutation
    %   (initial scan, file-list add/remove, settings-JSON load) so
    %   the user sees the up-to-date numbers without asking.
    %
    % =====================================================================
    %                   DYNAM-O Toolbox  |  Prerau Laboratory
    % =====================================================================

    if isempty(app.EdfLabelCache_) || ~isa(app.EdfLabelCache_, 'containers.Map') ...
            || isempty(keys(app.EdfLabelCache_))
        return
    end

    paths = reshape(cellstr(app.DataList), 1, []);
    nFiles = numel(paths);
    if nFiles == 0
        return
    end

    if ~isempty(app.ChannelList)
        % Configured-channel coverage via the dry-run simulator. Same
        % path the run loop uses, so the numbers here predict exactly
        % what will run.
        try
            [resolves, ~] = app.simulateChannelResolution();
        catch
            resolves = false(nFiles, 0);
        end

        % Outname order matches simulateChannelResolution's columns,
        % which is first-occurrence order over ChannelList.
        chanList    = reshape(cellstr(app.ChannelList), 1, []);
        outnames    = cell(1, numel(chanList));
        for ii = 1:numel(chanList)
            spec = chanList{ii};
            eq = strfind(spec, '=');
            if isempty(eq)
                outnames{ii} = strtrim(spec);
            else
                outnames{ii} = strtrim(spec(1:eq(1)-1));
            end
        end
        names = unique(outnames, 'stable');

        if size(resolves, 2) ~= numel(names)
            return
        end

        emit(app, sprintf('=== Channel coverage (%d file(s)) ===', nFiles), ...
            names, sum(resolves, 1), nFiles);
    else
        % No channel composer configured yet. Show a flat EDF-label
        % coverage table so the user can pick channels intelligently.
        labelCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');
        for k = 1:nFiles
            p_ = paths{k};
            if ~app.EdfLabelCache_.isKey(p_), continue; end
            entry = app.EdfLabelCache_(p_);
            seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            for jj = 1:numel(entry.labels)
                lbl = entry.labels{jj};
                if seen.isKey(lbl), continue; end
                seen(lbl) = true;
                if labelCounts.isKey(lbl)
                    labelCounts(lbl) = labelCounts(lbl) + 1;
                else
                    labelCounts(lbl) = 1;
                end
            end
        end

        names_  = sort(keys(labelCounts));
        counts_ = zeros(1, numel(names_));
        for k = 1:numel(names_), counts_(k) = labelCounts(names_{k}); end
        % Sort by descending coverage, then alphabetic.
        [counts_, ord] = sort(counts_, 'descend');
        names_ = names_(ord);

        emit(app, sprintf('=== EDF label coverage (%d file(s); set up channels in the composer to see channel-level coverage) ===', nFiles), ...
            names_, counts_, nFiles);
    end
end


% =========================================================================
function emit(app, header, names, counts, nFiles)
    if isempty(names), return; end
    width = max(cellfun(@length, names));
    width = max(width, 6);

    lines = cell(1, numel(names) + 1);
    lines{1} = header;
    for k = 1:numel(names)
        lines{k+1} = sprintf('  %-*s  %d / %d files', width, names{k}, counts(k), nFiles);
    end

    msg = strjoin(lines, newline);
    try, app.TextArea.addnl(msg); catch, end
    fprintf('\n%s\n', msg);
end
