function report = convert_stats_csv_to_app(root, varargin)
%CONVERT_STATS_CSV_TO_APP  Rewrite stats_table CSVs in the app's 16-col schema.
%
%   Walks ROOT for per-subject stats_table CSVs (<chan>/TFpeaks/) and
%   rewrites any in the OLD layout (leading subjectID column, BoundingBox as
%   a single matrix column) into the DYNAM-O desktop app's strict schema:
%       PeakTime,PeakFrequency,Duration,Bandwidth,Height,Volume,SegmentNum,
%       Area,Peakiness,bbox_tl_s,bbox_tl_Hz,bbox_width_s,bbox_height_Hz,
%       PeakStage,SOpower,SOphase
%   subjectID is dropped (recovered from the filename on read); BoundingBox
%   is decomposed into the four bbox_* columns.
%
%   CSVs already in the app schema are skipped (idempotent).
%
%   Usage:
%       report = convert_stats_csv_to_app(root)
%       report = convert_stats_csv_to_app(root, 'DryRun', true)
%       report = convert_stats_csv_to_app(root, 'Backup', false)
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
%   Safety: temp-then-rename; with 'Backup' (default) the original is copied
%   to '<file>.bak' before the rewritten CSV replaces it.
%
%   See also: stats_table_to_app_csv, writeStatsTableFormats, csv2table,
%             table2csv, convert_dynamo_outputs_to_app.
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

APP_HEADER = ['PeakTime,PeakFrequency,Duration,Bandwidth,Height,Volume,' ...
    'SegmentNum,Area,Peakiness,bbox_tl_s,bbox_tl_Hz,bbox_width_s,' ...
    'bbox_height_Hz,PeakStage,SOpower,SOphase'];

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

assert(isfolder(root), 'convert_stats_csv_to_app:badRoot', 'Root not a folder: %s', root);

listing = dir(fullfile(root, '**', 'TFpeaks', '**', '*stats_table*.csv'));
if ~isempty(listing)
    paths   = arrayfun(@(s) fullfile(s.folder, s.name), listing, 'UniformOutput', false);
    [~, keep] = unique(paths, 'stable');
    listing = listing(keep);
end
n = numel(listing);

report = struct('scanned', n, 'converted', {{}}, 'skipped', {{}}, 'failed', {{}});

if verbose
    fprintf('convert_stats_csv_to_app: scanning %s\n  found %d stats CSV(s)\n', root, n);
    if dryRun, fprintf('  DRY RUN — no files will be written\n'); end
end

for ii = 1:n
    p = fullfile(listing(ii).folder, listing(ii).name);

    hdr = read_header_(p);
    if strcmp(hdr, APP_HEADER)
        report.skipped{end+1, 1} = {p, 'already app schema'}; %#ok<AGROW>
        if verbose, fprintf('  [%d/%d] skip (app schema): %s\n', ii, n, p); end
        continue
    end

    if dryRun
        report.converted{end+1, 1} = p; %#ok<AGROW>
        if verbose, fprintf('  [%d/%d] WOULD CONVERT: %s\n', ii, n, p); end
        continue
    end

    try
        T = csv2table(p);
        T = stats_table_to_app_csv(T);

        [pd, pn, pe] = fileparts(p);
        tmp = fullfile(pd, [pn '.tmpconv' pe]);   % keep .csv so writecell accepts it
        if isfile(tmp), delete(tmp); end
        table2csv(T, tmp);
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


function hdr = read_header_(p)
hdr = '';
fid = fopen(p, 'r');
if fid < 0, return, end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
line = fgetl(fid);
if ischar(line), hdr = strtrim(line); end
end
