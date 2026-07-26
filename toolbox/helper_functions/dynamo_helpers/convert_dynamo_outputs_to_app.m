function report = convert_dynamo_outputs_to_app(root, varargin)
%CONVERT_DYNAMO_OUTPUTS_TO_APP  Migrate a DYNAM-O output tree to the app format.
%
%   One-call, in-place migration of an existing results tree written by the
%   MATLAB toolbox into the DYNAM-O desktop app's on-disk formats. Runs, in
%   order, the three component converters:
%       1. aux files   -> convert_aux_to_compact   (native SOpower, spans, uint8)
%       2. SOPH/spline TIFFs -> convert_tiffs_to_f32 (f64 -> f32 + JSON aliases)
%       3. stats CSVs  -> convert_stats_csv_to_app  (16-col schema, no subjectID)
%   Each is idempotent and writes .bak backups by default, so this is safe to
%   re-run and safe to interrupt.
%
%   Usage:
%       report = convert_dynamo_outputs_to_app('/path/to/results')
%       report = convert_dynamo_outputs_to_app(root, 'DryRun', true)   % preview
%       report = convert_dynamo_outputs_to_app(root, 'Components', {'aux'})
%
%   Name-Value:
%       'DryRun'       logical  - classify + print, write nothing (default false)
%       'Verbose'      logical  - per-file logging (default true)
%       'Backup'       logical  - keep .bak copies of originals (default true)
%       'SO_freqrange' 1x2      - band stamped into legacy aux lacking it
%                                 (default [0.3 1.5])
%       'Components'   cellstr  - subset of {'aux','tiff','stats'}
%                                 (default: all three)
%
%   Output:
%       report - struct with .aux, .tiff, .stats sub-reports (each as
%                returned by its converter; absent components are []).
%
%   Requires DYNAMO on the path (run init_DYNAMO first). The aggregate stacks
%   under aggregates/ are intentionally left alone — regenerate them by
%   re-aggregating after migrating the per-subject files.
%
%   See also: convert_aux_to_compact, convert_tiffs_to_f32,
%             convert_stats_csv_to_app.
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

ip = inputParser;
addRequired(ip, 'root', @(x) (ischar(x) || isstring(x)) && ~isempty(x));
addParameter(ip, 'DryRun',       false,      @(x) islogical(x) || isnumeric(x));
addParameter(ip, 'Verbose',      true,       @(x) islogical(x) || isnumeric(x));
addParameter(ip, 'Backup',       true,       @(x) islogical(x) || isnumeric(x));
addParameter(ip, 'SO_freqrange', [0.3 1.5],  @(x) isnumeric(x) && numel(x) == 2);
addParameter(ip, 'Components',   {'aux','tiff','stats'}, @(x) iscell(x) || ischar(x) || isstring(x));
parse(ip, root, varargin{:});
root  = char(ip.Results.root);
comps = ip.Results.Components;
if ischar(comps) || isstring(comps), comps = cellstr(comps); end

common = {'DryRun', logical(ip.Results.DryRun), ...
          'Verbose', logical(ip.Results.Verbose), ...
          'Backup',  logical(ip.Results.Backup)};

report = struct('aux', [], 'tiff', [], 'stats', []);

if ip.Results.Verbose
    fprintf('=== convert_dynamo_outputs_to_app: %s ===\n', root);
end

if any(strcmpi(comps, 'aux'))
    if ip.Results.Verbose, fprintf('\n-- aux files --\n'); end
    report.aux = convert_aux_to_compact(root, common{:}, ...
        'SO_freqrange', double(ip.Results.SO_freqrange));
end
if any(strcmpi(comps, 'tiff'))
    if ip.Results.Verbose, fprintf('\n-- SOPH/splinefit TIFFs --\n'); end
    report.tiff = convert_tiffs_to_f32(root, common{:});
end
if any(strcmpi(comps, 'stats'))
    if ip.Results.Verbose, fprintf('\n-- stats CSVs --\n'); end
    report.stats = convert_stats_csv_to_app(root, common{:});
end

if ip.Results.Verbose
    fprintf('\n=== migration summary ===\n');
    print_bucket_('aux  ', report.aux);
    print_bucket_('tiff ', report.tiff);
    print_bucket_('stats', report.stats);
end
end


function print_bucket_(label, r)
if isempty(r), fprintf('  %s : (skipped)\n', label); return, end
nconv = numel(r.converted);
nskip = numel(r.skipped);
nfail = numel(r.failed);
extra = '';
if isfield(r, 'approximate'), extra = sprintf(' (%d approx)', numel(r.approximate)); end
fprintf('  %s : %d converted%s, %d skipped, %d failed (of %d)\n', ...
    label, nconv, extra, nskip, nfail, r.scanned);
end
