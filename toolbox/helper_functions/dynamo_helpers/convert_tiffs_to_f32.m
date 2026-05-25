function report = convert_tiffs_to_f32(root, varargin)
%CONVERT_TIFFS_TO_F32  Re-encode DYNAM-O SOPH/splinefit TIFFs as 32-bit float.
%
%   Walks ROOT for per-subject SOPH (<chan>/SOPHs/) and splinefit
%   (<chan>/spline_basis/) TIFFs and rewrites any 64-bit-float page as
%   32-bit float (Gray32Float), matching the DYNAM-O desktop app — which
%   validates TIFF dtype on read. The ImageDescription JSON is augmented to
%   the app's schema (SOPH: label/rows/cols/row_centers/col_centers/format;
%   splinefit: label/format). Pixel values and bins are preserved; only the
%   storage dtype narrows (f64->f32, lossless for SOPH rates / spline coefs).
%
%   Already-32-bit TIFFs are skipped (idempotent). Aggregate stacks (multi-
%   subject, under aggregates/ or carrying a `subjectIDs` array) are skipped —
%   regenerate those by re-aggregating.
%
%   Usage:
%       report = convert_tiffs_to_f32(root)
%       report = convert_tiffs_to_f32(root, 'DryRun', true)
%       report = convert_tiffs_to_f32(root, 'Backup', false)
%
%   Name-Value:
%       'DryRun'  logical - classify + print intended action, write nothing
%       'Verbose' logical - one line per file (default: true)
%       'Backup'  logical - keep a .bak copy of each original (default: true)
%
%   Output:
%       report - struct: .scanned, .converted, .skipped {path,reason},
%                .failed {path,reason}.
%
%   Requires DYNAMO on the path (run init_DYNAMO first) — uses
%   DYNAMO.writeTiff as the single source of the f32 TIFF format.
%
%   Safety: temp-then-rename; with 'Backup' (default) the original is copied
%   to '<file>.bak' before the f32 file replaces it.
%
%   See also: writeSOPHsFormats, writeSplinefitFormats, DYNAMO.writeTiff,
%             convert_dynamo_outputs_to_app.
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

ip = inputParser;
addRequired(ip, 'root', @(x) (ischar(x) || isstring(x)) && ~isempty(x));
addParameter(ip, 'DryRun',  false, @(x) islogical(x) || isnumeric(x));
addParameter(ip, 'Verbose', true,  @(x) islogical(x) || isnumeric(x));
addParameter(ip, 'Backup',  true,  @(x) islogical(x) || isnumeric(x));
parse(ip, root, varargin{:});
root     = char(ip.Results.root);
dryRun   = logical(ip.Results.DryRun);
verbose  = logical(ip.Results.Verbose);
doBackup = logical(ip.Results.Backup);

assert(isfolder(root), 'convert_tiffs_to_f32:badRoot', 'Root not a folder: %s', root);
assert(exist('DYNAMO', 'class') == 8, 'convert_tiffs_to_f32:noDYNAMO', ...
    'DYNAMO class not on path — run init_DYNAMO first.');

chunks = {};
for sub = {'SOPHs', 'spline_basis'}
    f = dir(fullfile(root, '**', sub{1}, '**', '*.tiff'));
    if ~isempty(f), chunks{end+1} = f(:); end %#ok<AGROW>
end
if isempty(chunks)
    listing = dir(fullfile(root, '__no_match__'));
else
    listing = vertcat(chunks{:});
    paths   = arrayfun(@(s) fullfile(s.folder, s.name), listing, 'UniformOutput', false);
    [~, keep] = unique(paths, 'stable');
    listing = listing(keep);
end
n = numel(listing);

report = struct('scanned', n, 'converted', {{}}, 'skipped', {{}}, 'failed', {{}});

if verbose
    fprintf('convert_tiffs_to_f32: scanning %s\n  found %d TIFF(s)\n', root, n);
    if dryRun, fprintf('  DRY RUN — no files will be written\n'); end
end

for ii = 1:n
    p = fullfile(listing(ii).folder, listing(ii).name);

    % Skip aggregate stacks living under an aggregates/ folder.
    if contains(p, [filesep 'aggregates' filesep])
        report.skipped{end+1, 1} = {p, 'aggregate (regenerate)'}; %#ok<AGROW>
        continue
    end

    try
        info = imfinfo(p);
    catch ME
        report.failed{end+1, 1} = {p, ME.message}; %#ok<AGROW>
        continue
    end

    if ~isempty(info) && isfield(info, 'BitsPerSample') && info(1).BitsPerSample == 32
        report.skipped{end+1, 1} = {p, 'already f32'}; %#ok<AGROW>
        if verbose, fprintf('  [%d/%d] skip (f32): %s\n', ii, n, p); end
        continue
    end

    % Parse page-1 JSON.
    meta = struct();
    if isfield(info, 'ImageDescription') && ~isempty(info(1).ImageDescription)
        try
            meta = jsondecode(info(1).ImageDescription);
        catch
            meta = struct();
        end
    end
    if isfield(meta, 'subjectIDs')   % aggregate stack
        report.skipped{end+1, 1} = {p, 'aggregate (regenerate)'}; %#ok<AGROW>
        continue
    end

    if dryRun
        report.converted{end+1, 1} = p; %#ok<AGROW>
        if verbose, fprintf('  [%d/%d] WOULD CONVERT: %s\n', ii, n, p); end
        continue
    end

    try
        nPages = numel(info);
        pages = cell(1, nPages);
        for k = 1:nPages
            pages{k} = double(imread(p, k));
        end
        outMeta = augment_meta_(meta, pages{1}, p);
        data = pages; if nPages == 1, data = pages{1}; end

        [pd, pn, pe] = fileparts(p);
        tmp = fullfile(pd, [pn '.tmpconv' pe]);
        if isfile(tmp), delete(tmp); end
        DYNAMO.writeTiff(tmp, data, outMeta);
        if doBackup
            bak = [p '.bak'];
            if ~isfile(bak)
                [ok, msg] = copyfile(p, bak, 'f');
                if ~ok, delete(tmp); error('backup failed: %s', msg); end
            end
        end
        [ok, msg] = movefile(tmp, p, 'f');
        if ~ok, error('movefile failed: %s', msg); end

        report.converted{end+1, 1} = p; %#ok<AGROW>
        if verbose, fprintf('  [%d/%d] converted: %s\n', ii, n, p); end
    catch ME
        report.failed{end+1, 1} = {p, ME.message}; %#ok<AGROW>
        if verbose, fprintf('  [%d/%d] FAIL %s — %s\n', ii, n, p, ME.message); end
    end
end

if verbose
    fprintf('done: %d converted, %d skipped, %d failed (of %d)\n', ...
        numel(report.converted), numel(report.skipped), numel(report.failed), report.scanned);
end
end


function out = augment_meta_(meta, page1, p)
% Build the app-schema ImageDescription struct for one TIFF.
sid = '';
if isfield(meta, 'subjectID') && ~isempty(meta.subjectID)
    sid = char(string(meta.subjectID));
end
freq_bins = row_or_empty_(meta, 'freq_bins');

is_spline = isfield(meta, 'knots_x') || isfield(meta, 'page1') || ...
            contains(p, [filesep 'spline_basis' filesep]);

if is_spline
    % Preserve the spline JSON, add label/format.
    out = meta;
    out.label  = 'splinefit';
    out.format = 'f32 row-major';
    return
end

% SOPH: row axis = SO bins, col axis = freq bins.
if isfield(meta, 'SOpower_bins')
    label = 'sopower'; so_key = 'SOpower_bins';
elseif isfield(meta, 'SOphase_bins')
    label = 'sophase'; so_key = 'SOphase_bins';
else
    % Infer from filename when bins metadata is absent.
    if contains(lower(p), 'phase'), label = 'sophase'; so_key = 'SOphase_bins';
    else,                            label = 'sopower'; so_key = 'SOpower_bins';
    end
end
so_bins = row_or_empty_(meta, so_key);

out = struct( ...
    'label',       label, ...
    'rows',        size(page1, 1), ...
    'cols',        size(page1, 2), ...
    'row_centers', so_bins, ...
    'col_centers', freq_bins, ...
    'freq_bins',   freq_bins, ...
    'subjectID',   sid, ...
    'format',      'f32 row-major');
out.(so_key) = so_bins;
end


function v = row_or_empty_(s, name)
if isfield(s, name) && ~isempty(s.(name))
    v = double(s.(name)); v = v(:).';
else
    v = [];
end
end
