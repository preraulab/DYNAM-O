function writeStatsTableCsv(path, stats_table, stamp, varargin)
%WRITESTATSTABLECSV  Write a stats_table as a canonical format-3 stats CSV
%
%   Usage:
%       writeStatsTableCsv(path, stats_table, stamp)
%       writeStatsTableCsv(path, stats_table, stamp, 'subjectID', 'S001')
%
%   Inputs:
%       path        : char - output .csv path (parent dirs created) -- required
%       stats_table : table - per-peak feature table from runDYNAMO. Must
%                     carry PeakTime, PeakFrequency, Duration, Bandwidth,
%                     Height, Volume, SegmentNum, Area, Peakiness,
%                     PeakStage, SOpower, SOphase, and the bounding-box
%                     top-left either as an Nx4 BoundingBox matrix column
%                     (columns 1:2 are used) or as bbox_tl_s / bbox_tl_Hz
%                     scalar columns -- required
%       stamp       : struct - provenance stamp from dynamo_stamp
%                     (.writer, .writer_version, .kernel_version) -- required
%
%   Name-Value Pairs:
%       'subjectID' : char - emitted as '# subjectID:' when non-empty
%                     (default: '')
%
%   Outputs:
%       none (side effects only)
%
%   Notes:
%       Emits the DYNAM-O stats-CSV format 3 (DesktopApp OUTPUT_FORMAT.md
%       sections 2.1 and 8): a '#'-prefixed provenance preamble followed
%       by the canonical 14-column header, byte-identical across all
%       DYNAM-O writers:
%           PeakTime,PeakFrequency,Duration,Bandwidth,Height,Volume,
%           SegmentNum,Area,Peakiness,bbox_tl_s,bbox_tl_Hz,PeakStage,
%           SOpower,SOphase
%       The bbox extent columns of older layouts (bbox_width_s and
%       bbox_height_Hz) are not written: they duplicate Duration and
%       Bandwidth exactly. Non-schema columns in the input table
%       (HeightData, Boundaries, Label, ...) are ignored.
%
%       Numeric cells use shortest-round-trip text: %.15g when that
%       parses back bit-exactly, widening to %.17g otherwise. NaN prints
%       as the literal NaN, which every DYNAM-O reader accepts.
%
%   Example:
%       stamp = dynamo_stamp();
%       writeStatsTableCsv('S001_stats_table_C3.csv', stats_table, stamp, ...
%           'subjectID', 'S001');
%
%   See also: loadStatsTable, dynamo_stamp, writeParamfitCsv, writeSOPHsTiff
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

p = inputParser;
addRequired(p, 'path', @(x) validateattributes(x, {'char','string'}, {'scalartext','nonempty'}));
addRequired(p, 'stats_table', @(x) validateattributes(x, {'table'}, {}));
addRequired(p, 'stamp', @(x) validateattributes(x, {'struct'}, {'scalar'}));
addParameter(p, 'subjectID', '', @(x) validateattributes(x, {'char','string'}, {'scalartext'}));
parse(p, path, stats_table, stamp, varargin{:});
path      = char(p.Results.path);
T         = p.Results.stats_table;
stamp     = p.Results.stamp;
subjectID = char(p.Results.subjectID);

assert(all(isfield(stamp, {'writer','writer_version','kernel_version'})), ...
    'stamp must carry writer, writer_version, and kernel_version (see dynamo_stamp).');

vn = T.Properties.VariableNames;

% Bounding-box top-left: prefer explicit bbox_tl_* columns, fall back to
% decomposing the Nx4 BoundingBox matrix column [tl_s, tl_Hz, w_s, h_Hz].
if all(ismember({'bbox_tl_s','bbox_tl_Hz'}, vn))
    bbox_tl_s  = double(T.bbox_tl_s);
    bbox_tl_Hz = double(T.bbox_tl_Hz);
else
    bbHit = strcmpi(vn, 'BoundingBox');
    if ~any(bbHit)
        error('writeStatsTableCsv:missingColumn', ...
            'stats_table needs bbox_tl_s/bbox_tl_Hz columns or an Nx4 BoundingBox column.');
    end
    BB = T.(vn{find(bbHit, 1)});
    assert(size(BB, 2) >= 2, 'BoundingBox must have at least 2 columns [tl_s, tl_Hz, ...].');
    bbox_tl_s  = double(BB(:, 1));
    bbox_tl_Hz = double(BB(:, 2));
end

% Scalar schema columns, in output order around the bbox pair.
pre_cols  = {'PeakTime','PeakFrequency','Duration','Bandwidth','Height', ...
             'Volume','SegmentNum','Area','Peakiness'};
post_cols = {'PeakStage','SOpower','SOphase'};
missing = [pre_cols, post_cols];
missing = missing(~ismember(missing, vn));
if ~isempty(missing)
    error('writeStatsTableCsv:missingColumn', ...
        'stats_table is missing required column(s): %s. PeakStage/SOpower/SOphase are added by runDYNAMO after peak extraction.', ...
        strjoin(missing, ', '));
end

ncol = numel(pre_cols) + 2 + numel(post_cols);
M = zeros(height(T), ncol);
for ii = 1:numel(pre_cols)
    M(:, ii) = double(T.(pre_cols{ii}));
end
M(:, numel(pre_cols) + 1) = bbox_tl_s;
M(:, numel(pre_cols) + 2) = bbox_tl_Hz;
for ii = 1:numel(post_cols)
    M(:, numel(pre_cols) + 2 + ii) = double(T.(post_cols{ii}));
end

outdir = fileparts(path);
if ~isempty(outdir) && ~isfolder(outdir)
    mkdir(outdir);
end

fid = fopen(path, 'w');
if fid < 0
    error('writeStatsTableCsv:openFailed', 'Could not open %s for writing.', path);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

% Provenance preamble (format 3). Key order matches the Rust writers.
fprintf(fid, '# DYNAM-O stats table\n');
fprintf(fid, '# format: 3\n');
fprintf(fid, '# writer: %s\n', char(stamp.writer));
fprintf(fid, '# writer_version: %s\n', char(stamp.writer_version));
fprintf(fid, '# kernel_version: %s\n', char(stamp.kernel_version));
if ~isempty(subjectID)
    fprintf(fid, '# subjectID: %s\n', subjectID);
end

% Header line: byte-identical to the Rust write_stats_csv header.
fprintf(fid, '%s\n', ['PeakTime,PeakFrequency,Duration,Bandwidth,Height,Volume,' ...
    'SegmentNum,Area,Peakiness,bbox_tl_s,bbox_tl_Hz,PeakStage,SOpower,SOphase']);

for rr = 1:size(M, 1)
    cells = cell(1, ncol);
    for cc = 1:ncol
        cells{cc} = shortest_g_(M(rr, cc));
    end
    fprintf(fid, '%s\n', strjoin(cells, ','));
end
end


function s = shortest_g_(v)
%SHORTEST_G_  Shortest %g text that parses back to exactly v
%
%   Inputs:
%       v : double - value to encode -- required
%
%   Outputs:
%       s : char - '%.15g' when lossless, else '%.17g'; 'NaN'/'Inf' pass
%           through via the %g formatting of non-finite values
if ~isfinite(v)
    % sprintf('%g', nan) is 'NaN', ('%g', inf) is 'Inf' - both readable
    % by readtable and str2double.
    s = sprintf('%g', v);
    return
end
s = sprintf('%.15g', v);
if str2double(s) ~= v
    s = sprintf('%.17g', v);
end
end
