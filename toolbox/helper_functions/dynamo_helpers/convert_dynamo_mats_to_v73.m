function report = convert_dynamo_mats_to_v73(root, varargin)
%CONVERT_DYNAMO_MATS_TO_V73  Re-save legacy v7 DYNAM-O .mat outputs as -v7.3.
%
%   Walks ROOT recursively and re-saves any .mat file living in a known
%   DYNAM-O output subdirectory (SOPHs/, stats_table/, param_basis/,
%   spline_basis/, auxiliary_data/, or under aggregates/) with the -v7.3
%   flag so that downstream readers can use matfile() partial-field
%   access. Files already in v7.3 (HDF5) format are skipped. Files under
%   any other directory are left alone.
%
%   Usage:
%       convert_dynamo_mats_to_v73(root)
%       convert_dynamo_mats_to_v73(root, 'DryRun', true)     % preview only
%       convert_dynamo_mats_to_v73(root, 'Verbose', false)
%       convert_dynamo_mats_to_v73(root, 'Parallel', true)   % parfor over files
%
%   Inputs:
%       root      char/string - results root, channel folder, or any
%                  ancestor directory containing DYNAM-O output subdirs
%
%   Name-Value:
%       'DryRun'    logical - list what would be converted without writing
%                             (default: false)
%       'Verbose'   logical - print one line per file (default: true)
%       'Parallel'  logical - run conversions in parfor (default: false).
%                             Workers act on independent files; print order
%                             may interleave. Helpful on networked storage
%                             or fast SSDs with many subjects; can thrash
%                             on a single slow spinning disk.
%
%   Output:
%       report - struct with fields:
%           .scanned    - total .mat files seen under DYNAM-O output subdirs
%           .converted  - cell of paths re-saved as v7.3
%           .skipped    - cell of {path, reason} for files left alone
%           .failed     - cell of {path, errmsg} for files that errored
%
%   Safety:
%       Each file is rewritten via temp-then-rename: the new -v7.3 file
%       is written to '<orig>.tmp_v73', and only on a successful save is
%       it moved over the original. A failure mid-save leaves the
%       original file intact.

ip = inputParser;
addRequired(ip, 'root', @(x) (ischar(x) || isstring(x)) && ~isempty(x));
addParameter(ip, 'DryRun',   false, @(x) islogical(x) || isnumeric(x));
addParameter(ip, 'Verbose',  true,  @(x) islogical(x) || isnumeric(x));
addParameter(ip, 'Parallel', false, @(x) islogical(x) || isnumeric(x));
parse(ip, root, varargin{:});
root     = char(ip.Results.root);
dryRun   = logical(ip.Results.DryRun);
verbose  = logical(ip.Results.Verbose);
parallel = logical(ip.Results.Parallel);

assert(isfolder(root), 'convert_dynamo_mats_to_v73:badRoot', ...
    'Root not a folder: %s', root);

% Walk every .mat under the known DYNAM-O output subdirectories. The
% subdir names below are the leaf folders the App writes into per
% channel (plus 'aggregates' which sits at the results root). Anchoring
% on these names keeps us from rewriting unrelated .mat files the user
% may have parked alongside their results.
dynamo_subdirs = {'SOPHs', 'stats_table', 'param_basis', 'spline_basis', ...
    'auxiliary_data', 'aggregates'};
% Collect each dir() result into a cell, then vertcat at the end.
% Pre-allocating a typed struct fails because dir()'s field set varies
% across MATLAB releases (date / datenum / isdir).
chunks = cell(1, numel(dynamo_subdirs));
for kk = 1:numel(dynamo_subdirs)
    found = dir(fullfile(root, '**', dynamo_subdirs{kk}, '**', '*.mat'));
    if ~isempty(found)
        chunks{kk} = found(:);
    end
end
chunks(cellfun(@isempty, chunks)) = [];
if isempty(chunks)
    listing = dir(fullfile(root, '__no_match__'));   % typed empty struct
else
    listing = vertcat(chunks{:});
end
% Deduplicate by absolute path — `aggregates/<channel>/SOPHs/...` would
% otherwise be matched twice (once via 'aggregates', once via 'SOPHs').
if ~isempty(listing)
    paths = arrayfun(@(s) fullfile(s.folder, s.name), listing, 'UniformOutput', false);
    [~, keep] = unique(paths, 'stable');
    listing = listing(keep);
end
n = numel(listing);

% Per-file outcome captured in a struct array so the parfor branch can
% reduce cleanly without sharing state. status: 'converted' | 'skipped' | 'failed'.
out(n) = struct('path', '', 'bytes', 0, 'status', '', 'reason', '', 'elapsed', 0);

if verbose
    fprintf('convert_dynamo_mats_to_v73: scanning %s\n', root);
    fprintf('  found %d candidate file(s) under DYNAM-O output subdirs\n', n);
    if dryRun,    fprintf('  DRY RUN — no files will be written\n'); end
    if parallel,  fprintf('  PARALLEL mode — print order may interleave\n'); end
end

if parallel && ~dryRun && n > 0
    % Ensure a pool exists. Honor whatever the user has already; otherwise
    % let MATLAB autocreate the default profile (ProcessPool by default).
    if isempty(gcp('nocreate'))
        try, parpool('Processes'); catch, end %#ok<CTCH>
    end
    parfor ii = 1:n
        out(ii) = process_one(listing(ii), dryRun, verbose, n, ii);
    end
else
    for ii = 1:n
        out(ii) = process_one(listing(ii), dryRun, verbose, n, ii);
    end
end

% Reduce outcomes into the same {converted, skipped, failed} buckets as
% the original API so callers don't need to know about parallel mode.
report.scanned   = n;
report.converted = {};
report.skipped   = {};
report.failed    = {};
for ii = 1:n
    switch out(ii).status
        case 'converted'
            report.converted{end+1, 1} = out(ii).path; %#ok<AGROW>
        case 'skipped'
            report.skipped{end+1, 1}   = {out(ii).path, out(ii).reason}; %#ok<AGROW>
        case 'failed'
            report.failed{end+1, 1}    = {out(ii).path, out(ii).reason}; %#ok<AGROW>
    end
end

if verbose
    fprintf('done: %d converted, %d skipped, %d failed (of %d scanned)\n', ...
        numel(report.converted), numel(report.skipped), ...
        numel(report.failed),    report.scanned);
end
end


function r = process_one(entry, dryRun, verbose, total, ii)
%PROCESS_ONE  Convert a single file. Self-contained for parfor safety.
r = struct('path', '', 'bytes', 0, 'status', '', 'reason', '', 'elapsed', 0);
r.path  = fullfile(entry.folder, entry.name);
r.bytes = entry.bytes;

if is_v73(r.path)
    r.status = 'skipped';
    r.reason = 'already v7.3';
    if verbose
        fprintf('  [%d/%d] skip (v7.3): %s\n', ii, total, r.path);
    end
    return
end

if dryRun
    r.status = 'converted';   % "would convert" — counted as converted in the dry-run report
    if verbose
        fprintf('  [%d/%d] WOULD CONVERT (%.1f MB): %s\n', ...
            ii, total, r.bytes/1e6, r.path);
    end
    return
end

if verbose
    fprintf('  [%d/%d] converting (%.1f MB): %s\n', ...
        ii, total, r.bytes/1e6, r.path);
end
t0  = tic;
tmp = [r.path, '.tmp_v73'];
try
    S = load(r.path);
    save(tmp, '-struct', 'S', '-v7.3');
    [ok, msg] = movefile(tmp, r.path, 'f');
    if ~ok, error('movefile failed: %s', msg); end
    r.status  = 'converted';
    r.elapsed = toc(t0);
    if verbose
        fprintf('       -> OK [%.1fs] %s\n', r.elapsed, r.path);
    end
catch ME
    if isfile(tmp)
        try, delete(tmp); catch, end %#ok<CTCH>
    end
    r.status = 'failed';
    r.reason = ME.message;
    if verbose
        fprintf('       -> FAIL %s — %s\n', r.path, ME.message);
    end
end
end


function tf = is_v73(path)
%IS_V73  Return true if PATH is a v7.3 (HDF5) MAT-file.
%   v7.3 files start with the HDF5 signature: 0x89 'H' 'D' 'F' 0x0D 0x0A
%   0x1A 0x0A. v7 (and earlier) MAT-files begin with the ASCII header
%   "MATLAB 5.0 MAT-file...". Reading the first 8 bytes is sufficient
%   and avoids opening the whole file.
tf  = false;
fid = fopen(path, 'r');
if fid < 0, return, end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
sig = fread(fid, 8, 'uint8=>uint8')';
if numel(sig) < 8, return, end
hdf5_sig = uint8([137 72 68 70 13 10 26 10]);   % \x89 H D F \r \n \x1a \n
tf = isequal(sig, hdf5_sig);
end
