function [ids, source] = recoverAggregateSubjectIDs(app, tiffPath, axisKind, nPages)
    % recoverAggregateSubjectIDs  Resolve per-page subject IDs for an
    %   aggregate SOPH TIFF, with a four-way fallback so the file
    %   works "TIFF alone" wherever possible:
    %
    %     1. Embedded JSON in page-1 ImageDescription (`subjectIDs`).
    %        Newer aggregates carry IDs here directly.
    %     2. Sibling <base>_subjectIDs.txt sidecar (older aggregates).
    %     3. Per-subject TIFFs found in <root>/<channel>/SOPHs/, sorted
    %        alphabetically by fbase — replicates the aggregator's
    %        deterministic page order. Each file's own
    %        ImageDescription `subject_id` is preferred over the
    %        filename-derived stem.
    %     4. Runs JSONL index (<root>/_runs/*.jsonl) — subjects with a
    %        SOPHs TIFF artifact in this channel, sorted alphabetically.
    %
    %   Returns {} when none of the four can produce a vector matching
    %   nPages. `source` is one of {'embedded','sidecar','per_subject',
    %   'runs','none'} for diagnostics.
    if nargin < 4, nPages = NaN; end
    ids    = {};
    source = 'none';

    % ---- 1. Embedded JSON ----
    try
        info = imfinfo(tiffPath);
        if isfield(info, 'ImageDescription') && ~isempty(info(1).ImageDescription)
            meta = jsondecode(info(1).ImageDescription);
            if isfield(meta, 'subjectIDs')
                cand = normalize_idlist_(meta.subjectIDs);
                if ids_ok_(cand, nPages)
                    ids = cand; source = 'embedded'; return
                end
            end
        end
    catch
    end

    % ---- 2. Sibling .txt sidecar ----
    try
        [d, nm, ~] = fileparts(tiffPath);
        txt = fullfile(d, [nm '_subjectIDs.txt']);
        if isfile(txt)
            fid = fopen(txt, 'r');
            c   = onCleanup(@() fclose(fid)); %#ok<NASGU>
            cell_ids = textscan(fid, '%s', 'Delimiter', '\n', 'WhiteSpace', '');
            cand = normalize_idlist_(strtrim(cell_ids{1}));
            if ids_ok_(cand, nPages)
                ids = cand; source = 'sidecar'; return
            end
        end
    catch
    end

    % ---- 3. Walk per-subject TIFFs in <root>/<channel>/SOPHs/ ----
    try
        [chRoot, channel] = aggregate_channel_root_(tiffPath);
        if ~isempty(chRoot)
            sopDir = fullfile(chRoot, 'SOPHs');
            if isfolder(sopDir)
                pat = ['*_SOPHs_' axisKind '_' channel '.tiff'];
                matches = dir(fullfile(sopDir, pat));
                if isempty(matches)
                    pat = ['*_SOPHs_' channel '_' axisKind '.tiff']; % older naming
                    matches = dir(fullfile(sopDir, pat));
                end
                cand = cell(numel(matches), 1);
                for ii = 1:numel(matches)
                    cand{ii} = recover_id_from_subject_tiff_( ...
                        fullfile(matches(ii).folder, matches(ii).name));
                end
                cand = normalize_idlist_(cand);
                cand = sort(cand);          % deterministic order
                if ids_ok_(cand, nPages)
                    ids = cand; source = 'per_subject'; return
                end
            end
        end
    catch
    end

    % ---- 4. Runs JSONL ----
    try
        [rootDir, channel] = aggregate_results_root_(tiffPath);
        if ~isempty(rootDir) && ~isempty(channel)
            idx = dynamo_index_runs(rootDir);
            if isfield(idx, 'entries') && ~isempty(idx.entries)
                cand = {};
                for ii = 1:numel(idx.entries)
                    e = idx.entries{ii};
                    if ~isfield(e, 'channel') || ~strcmp(char(e.channel), channel), continue, end
                    if has_sophs_tiff_artifact_(e, axisKind, channel)
                        cand{end+1} = char(e.subject); %#ok<AGROW>
                    end
                end
                cand = normalize_idlist_(unique(cand, 'stable'));
                cand = sort(cand);
                if ids_ok_(cand, nPages)
                    ids = cand; source = 'runs'; return
                end
            end
        end
    catch
    end
end


function tf = ids_ok_(c, nPages)
    tf = ~isempty(c);
    if tf && ~isnan(nPages), tf = numel(c) == nPages; end
end


function out = normalize_idlist_(in)
    if isstring(in), in = cellstr(in); end
    if ischar(in),   in = {in}; end
    if iscell(in)
        out = reshape(cellfun(@(s) char(strtrim(string(s))), in, ...
            'UniformOutput', false), [], 1);
        out = out(~cellfun('isempty', out));
    else
        out = {};
    end
end


function [chRoot, channel] = aggregate_channel_root_(tiffPath)
    % aggregate path is <root>/aggregates/<channel>/*.tiff —
    % chRoot must be <root>/<channel>/ to find sibling SOPHs/.
    chRoot = ''; channel = '';
    [d, ~, ~] = fileparts(tiffPath);
    [parent, leaf] = fileparts(d);
    [~, parentLeaf] = fileparts(parent);
    if ~strcmp(parentLeaf, 'aggregates'), return, end
    rootDir = fileparts(parent);
    candCh  = fullfile(rootDir, leaf);
    if isfolder(candCh)
        chRoot  = candCh;
        channel = leaf;
    end
end


function [rootDir, channel] = aggregate_results_root_(tiffPath)
    rootDir = ''; channel = '';
    [d, ~, ~] = fileparts(tiffPath);
    [parent, leaf] = fileparts(d);
    [~, parentLeaf] = fileparts(parent);
    if ~strcmp(parentLeaf, 'aggregates'), return, end
    rootDir = fileparts(parent);
    channel = leaf;
end


function id = recover_id_from_subject_tiff_(p)
    id = '';
    try
        info = imfinfo(p);
        if isfield(info, 'ImageDescription') && ~isempty(info(1).ImageDescription)
            meta = jsondecode(info(1).ImageDescription);
            if isfield(meta, 'subject_id')
                id = char(strtrim(string(meta.subject_id)));
            end
        end
    catch
    end
    if isempty(id)
        % Filename fallback: strip the trailing _SOPHs_<axis>_<chan>.tiff
        % without bringing in extra knowledge about the channel/axis.
        [~, nm, ~] = fileparts(p);
        tok = regexp(nm, '^(?<fbase>.+?)_SOPHs_', 'names', 'once');
        if ~isempty(tok), id = tok.fbase; end
    end
end


function tf = has_sophs_tiff_artifact_(entry, axisKind, channel)
    tf = false;
    if ~isfield(entry, 'files') || isempty(entry.files), return, end
    files = entry.files;
    if isstruct(files), files = {files}; end
    needle = ['_SOPHs_' axisKind '_' channel '.tiff'];
    for ii = 1:numel(files)
        f = files{ii};
        if isstruct(f) && isfield(f, 'path'), f = f.path; end
        if ischar(f) && endsWith(f, needle, 'IgnoreCase', true)
            tf = true; return
        end
    end
end
