function report = convert_stats_csv_to_app(root, varargin)
%CONVERT_STATS_CSV_TO_APP  Verify stats_table CSVs are app/canonical readable.
%
%   Walks ROOT for per-subject stats_table CSVs (<chan>/TFpeaks/) and
%   classifies each against the recognized stats-CSV formats:
%       format 3 - '#' provenance preamble + canonical 14-column header
%       format 2 - canonical 14-column header, bare
%       format 1 - legacy 16-column header (with bbox_width_s/bbox_height_Hz)
%   All three are readable by loadStatsTable and the desktop app, so they
%   are skipped (nothing to convert). Any other layout is reported as
%   failed with an error directing to loadStatsTable.
%
%   The old in-place rewriter (csv2table -> stats_table_to_app_csv ->
%   table2csv) was removed: csv2table decodes cells via eval and silently
%   mangles CLI-written 14-column files, so automated rewriting is no
%   longer offered. To migrate a pre-app CSV, load it with the reader
%   that matches how it was written and re-save with writeStatsTableCsv.
%
%   Usage:
%       report = convert_stats_csv_to_app(root)
%       report = convert_stats_csv_to_app(root, 'DryRun', true)
%
%   Name-Value:
%       'DryRun'  logical - retained for call compatibility; scanning
%                 never writes, so this only labels the log output
%       'Verbose' logical - one line per file (default: true)
%       'Backup'  logical - retained for call compatibility; unused now
%                 that no files are rewritten
%
%   Output:
%       report - struct: .scanned, .converted (always empty now),
%                .skipped {path,reason}, .failed {path,reason}.
%
%   See also: loadStatsTable, writeStatsTableCsv,
%             convert_dynamo_outputs_to_app.
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

CANONICAL14 = ['PeakTime,PeakFrequency,Duration,Bandwidth,Height,Volume,' ...
    'SegmentNum,Area,Peakiness,bbox_tl_s,bbox_tl_Hz,PeakStage,SOpower,SOphase'];
LEGACY16 = ['PeakTime,PeakFrequency,Duration,Bandwidth,Height,Volume,' ...
    'SegmentNum,Area,Peakiness,bbox_tl_s,bbox_tl_Hz,bbox_width_s,' ...
    'bbox_height_Hz,PeakStage,SOpower,SOphase'];

ip = inputParser;
addRequired(ip, 'root', @(x) (ischar(x) || isstring(x)) && ~isempty(x));
addParameter(ip, 'DryRun',  false, @(x) islogical(x) || isnumeric(x));
addParameter(ip, 'Verbose', true,  @(x) islogical(x) || isnumeric(x));
addParameter(ip, 'Backup',  true,  @(x) islogical(x) || isnumeric(x));
parse(ip, root, varargin{:});
root    = char(ip.Results.root);
verbose = logical(ip.Results.Verbose);

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
end

for ii = 1:n
    p = fullfile(listing(ii).folder, listing(ii).name);

    try
        [hdr, preambled] = read_header_(p);
        if strcmp(hdr, CANONICAL14)
            if preambled
                reason = 'already canonical (format 3)';
            else
                reason = 'already canonical (format 2)';
            end
            report.skipped{end+1, 1} = {p, reason}; %#ok<AGROW>
            if verbose, fprintf('  [%d/%d] skip (%s): %s\n', ii, n, reason, p); end
            continue
        end
        if strcmp(hdr, LEGACY16) && ~preambled
            report.skipped{end+1, 1} = {p, 'already app schema (format 1)'}; %#ok<AGROW>
            if verbose, fprintf('  [%d/%d] skip (app schema, format 1): %s\n', ii, n, p); end
            continue
        end
        % Anything else is a pre-app layout (or a corrupted file). The
        % eval-based rewriter that used to handle these was removed
        % because it corrupted CLI-written canonical files; direct the
        % user to the explicit load/rewrite path instead.
        error('convert_stats_csv_to_app:legacyLayout', ...
            ['unrecognized stats-CSV header. Automated rewriting was removed ' ...
             '(the old csv2table/eval fallback corrupts canonical 14-column ' ...
             'files). Load this file with the reader matching its writer, ' ...
             'then re-save with writeStatsTableCsv. See loadStatsTable.']);
    catch ME
        report.failed{end+1, 1} = {p, ME.message}; %#ok<AGROW>
        if verbose, fprintf('  [%d/%d] FAIL %s — %s\n', ii, n, p, ME.message); end
    end
end

if verbose
    fprintf('done: %d skipped, %d failed (of %d)\n', ...
        numel(report.skipped), numel(report.failed), report.scanned);
end
end


function [hdr, preambled] = read_header_(p)
%READ_HEADER_  First non-comment line of a CSV, noting a '#' preamble
%
%   Inputs:
%       p : char - CSV path -- required
%
%   Outputs:
%       hdr       : char - first line that does not start with '#',
%                   whitespace-trimmed ('' when the file is empty)
%       preambled : logical - true when leading '#' lines were skipped
hdr = '';
preambled = false;
fid = fopen(p, 'r');
if fid < 0, return, end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
while true
    line = fgetl(fid);
    if ~ischar(line)
        return
    end
    if startsWith(line, '#')
        preambled = true;
        continue
    end
    hdr = strtrim(line);
    return
end
end
