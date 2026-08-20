function [T, meta] = loadStatsTable(path)
%LOADSTATSTABLE  Read a DYNAM-O stats CSV (formats 1, 2, and 3)
%
%   Usage:
%       [T, meta] = loadStatsTable(path)
%
%   Inputs:
%       path : char - stats_table .csv path -- required
%
%   Outputs:
%       T    : table - per-peak features in the canonical 14-column order
%              (PeakTime ... bbox_tl_s, bbox_tl_Hz ... SOphase). The
%              legacy format-1 extent columns bbox_width_s/bbox_height_Hz
%              are dropped on read (they duplicate Duration/Bandwidth).
%       meta : struct - provenance:
%                .format         : 1, 2, or 3 (inferred when unstamped)
%                .writer         : char ('' when absent)
%                .writer_version : char ('' when absent)
%                .kernel_version : char ('' when absent)
%                .subjectID      : char ('' when absent)
%
%   Notes:
%       Formats per DesktopApp OUTPUT_FORMAT.md section 8.2:
%         3 = 14 columns + '#' provenance preamble
%         2 = 14 columns bare
%         1 = 16 columns bare (with bbox_width_s/bbox_height_Hz)
%       The stamp is recovered by an fgetl scan of the leading '#' lines.
%       readtable is never used for stamp extraction: its CommentStyle
%       option strips '#' anywhere in a line, so a '#' may only be
%       trusted as a comment marker at line start (reader rule 1).
%
%   Example:
%       [T, meta] = loadStatsTable('S001_stats_table_C3.csv');
%       fprintf('format %d written by %s\n', meta.format, meta.writer);
%
%   See also: writeStatsTableCsv, loadParamfitCsv, convert_stats_csv_to_app
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

assert(ischar(path) || (isstring(path) && isscalar(path)), 'path must be char or string.');
path = char(path);
if ~isfile(path)
    error('loadStatsTable:fileNotFound', 'No such file: %s', path);
end

canonical14 = ['PeakTime,PeakFrequency,Duration,Bandwidth,Height,Volume,' ...
    'SegmentNum,Area,Peakiness,bbox_tl_s,bbox_tl_Hz,PeakStage,SOpower,SOphase'];
legacy16 = ['PeakTime,PeakFrequency,Duration,Bandwidth,Height,Volume,' ...
    'SegmentNum,Area,Peakiness,bbox_tl_s,bbox_tl_Hz,bbox_width_s,' ...
    'bbox_height_Hz,PeakStage,SOpower,SOphase'];

% Preamble scan: leading '#' lines only, then the header line.
[pre, header] = scan_preamble_(path);
meta = struct('format', [], 'writer', '', 'writer_version', '', ...
    'kernel_version', '', 'subjectID', '');
meta = absorb_stamp_(meta, pre);

% Exact-header check + format inference for unstamped files (reader
% rule 2: 16 columns -> 1, 14 columns -> 2).
if strcmp(header, canonical14)
    if isempty(meta.format)
        if isempty(pre)
            meta.format = 2;
        else
            meta.format = 3;
        end
    end
elseif strcmp(header, legacy16)
    if isempty(meta.format)
        meta.format = 1;
    end
else
    error('loadStatsTable:badHeader', ...
        ['%s does not carry a recognized stats-CSV header. Expected the ' ...
         'canonical 14-column layout (or the legacy 16-column layout); ' ...
         'got: %s'], path, header);
end

% Tabular parse. The preamble rows are comments; data rows carry no '#'
% so CommentStyle is safe here.
T = readtable(path, 'Delimiter', ',', 'CommentStyle', '#', ...
    'VariableNamingRule', 'preserve');

% Map legacy 16-column files onto the canonical column set.
canonical_names = strsplit(canonical14, ',');
if meta.format == 1
    T = T(:, canonical_names);
else
    % Guard against readtable surprises: enforce canonical order.
    assert(isequal(T.Properties.VariableNames, canonical_names), ...
        'Parsed variable names do not match the canonical stats schema.');
end
end


function [pre, header] = scan_preamble_(path)
%SCAN_PREAMBLE_  Collect leading '#' lines and the first non-comment line
%
%   Inputs:
%       path : char - CSV path -- required
%
%   Outputs:
%       pre    : cell - leading '#'-prefixed lines, in order (may be empty)
%       header : char - first non-'#' line, whitespace-trimmed ('' at EOF)
pre = {};
header = '';
fid = fopen(path, 'r');
if fid < 0
    error('loadStatsTable:openFailed', 'Could not open %s for reading.', path);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
while true
    line = fgetl(fid);
    if ~ischar(line)
        return
    end
    if startsWith(line, '#')
        pre{end+1} = line; %#ok<AGROW>
    else
        header = strtrim(line);
        return
    end
end
end


function meta = absorb_stamp_(meta, pre)
%ABSORB_STAMP_  Parse '# key: value' stamp lines into the meta struct
%
%   Inputs:
%       meta : struct - initialized meta struct -- required
%       pre  : cell - preamble lines -- required
%
%   Outputs:
%       meta : struct - with format/writer/writer_version/kernel_version/
%              subjectID filled from any recognized keys. Unknown keys
%              are ignored (reader rule 3); the legacy '# version:' and
%              '# code_version:' keys map to format and writer_version.
for ii = 1:numel(pre)
    tok = regexp(pre{ii}, '^#\s*([A-Za-z_][A-Za-z0-9_.]*)\s*:\s*(.*)$', 'tokens', 'once');
    if isempty(tok)
        continue
    end
    key = tok{1};
    val = strtrim(tok{2});
    switch key
        case {'format', 'version'}
            n = str2double(val);
            if isfinite(n)
                meta.format = n;
            end
        case 'writer'
            meta.writer = val;
        case {'writer_version', 'code_version'}
            if isempty(meta.writer_version)
                meta.writer_version = val;
            end
        case 'kernel_version'
            meta.kernel_version = val;
        case 'subjectID'
            meta.subjectID = val;
    end
end
end
