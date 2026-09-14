function [T, meta] = loadParamfitCsv(path)
%LOADPARAMFITCSV  Read a DYNAM-O paramfit CSV (formats 1, 2, and 3)
%
%   Usage:
%       [T, meta] = loadParamfitCsv(path)
%
%   Inputs:
%       path : char - paramfit .csv path -- required
%
%   Outputs:
%       T    : table - one row per fitted mode, columns as written
%              (variable names preserved verbatim)
%       meta : struct - preamble metadata:
%                .format            : 1, 2, or 3. From '# format:' or the
%                                     legacy '# version:'; 1 when neither
%                                     key is present
%                .writer            : char ('' when absent)
%                .writer_version    : char - from '# writer_version:' or
%                                     the legacy '# code_version:'
%                .kernel_version    : char ('' when absent)
%                .subjectID         : char ('' when absent)
%                .fit_type          : char - 'power' | 'phase' | ''
%                .n_modes           : double (NaN when absent)
%                .background        : struct - one field per
%                                     '# background.<key>:' line
%                .unit_row          : double (NaN when absent)
%                .gof               : struct - sse/rsquare/dfe/adjrsquare/
%                                     rmse (NaN when absent)
%                .freq_bins         : double vector ([] when absent)
%                .so_bins           : double vector - from SOpower_bins or
%                                     SOphase_bins ([] when absent)
%                .fitobj_coefnames  : cellstr ({} when absent/empty)
%                .fitobj_coefvalues : double vector ([] when absent/empty)
%
%   Notes:
%       Format semantics matter for pooling: format 1 stored sqrt(2)-
%       scaled sigma widths (FreqStd, SOpowerStd) and must never be
%       pooled with formats 2/3, whose widths are true standard
%       deviations. aggregate_DYNAMO_outputs enforces this; use
%       meta.format for any custom pooling.
%
%       The stamp is recovered by an fgetl scan of the leading '#' lines
%       (never via readtable's CommentStyle, which strips '#' anywhere in
%       a line). Unknown preamble keys are ignored.
%
%   Example:
%       [T, meta] = loadParamfitCsv('S001_SOpower_paramfit_C3.csv');
%       assert(meta.format >= 2, 'format-1 widths are sqrt(2)-scaled');
%
%   See also: writeParamfitCsv, loadStatsTable, aggregate_DYNAMO_outputs
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

assert(ischar(path) || (isstring(path) && isscalar(path)), 'path must be char or string.');
path = char(path);
if ~isfile(path)
    error('loadParamfitCsv:fileNotFound', 'No such file: %s', path);
end

meta = struct('format', [], 'writer', '', 'writer_version', '', ...
    'kernel_version', '', 'subjectID', '', 'fit_type', '', 'n_modes', NaN, ...
    'peak_assign', '', ...
    'background', struct(), 'unit_row', NaN, ...
    'gof', struct('sse', NaN, 'rsquare', NaN, 'dfe', NaN, 'adjrsquare', NaN, 'rmse', NaN), ...
    'freq_bins', [], 'so_bins', [], ...
    'fitobj_coefnames', {{}}, 'fitobj_coefvalues', []);

fid = fopen(path, 'r');
if fid < 0
    error('loadParamfitCsv:openFailed', 'Could not open %s for reading.', path);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
while true
    line = fgetl(fid);
    if ~ischar(line) || ~startsWith(line, '#')
        break
    end
    meta = absorb_line_(meta, line);
end
clear cleanup

% Absent both '# format:' and legacy '# version:' means format 1.
if isempty(meta.format)
    meta.format = 1;
end

T = readtable(path, 'Delimiter', ',', 'CommentStyle', '#', ...
    'VariableNamingRule', 'preserve');
end


function meta = absorb_line_(meta, line)
%ABSORB_LINE_  Fold one '# key: value' preamble line into meta
%
%   Inputs:
%       meta : struct - accumulator -- required
%       line : char - raw preamble line -- required
%
%   Outputs:
%       meta : struct - updated accumulator (unknown keys ignored)
tok = regexp(line, '^#\s*([A-Za-z_][A-Za-z0-9_.]*)\s*:\s*(.*)$', 'tokens', 'once');
if isempty(tok)
    return
end
key = tok{1};
val = strtrim(tok{2});

% Dotted keys: background.<name> and gof.<name>.
dotted = regexp(key, '^(background|gof)\.(\w+)$', 'tokens', 'once');
if ~isempty(dotted)
    num = str2double(val);
    switch dotted{1}
        case 'background'
            meta.background.(dotted{2}) = num;
        case 'gof'
            meta.gof.(dotted{2}) = num;
    end
    return
end

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
    case 'fit_type'
        meta.fit_type = val;
    case 'n_modes'
        meta.n_modes = str2double(val);
    case 'peak_assign'
        meta.peak_assign = val;
    case 'unit_row'
        meta.unit_row = str2double(val);
    case 'freq_bins'
        meta.freq_bins = decode_json_vector_(val);
    case {'SOpower_bins', 'SOphase_bins'}
        meta.so_bins = decode_json_vector_(val);
    case 'fitobj_coefnames'
        c = decode_json_(val);
        if ischar(c)
            c = {c};
        end
        if iscell(c)
            meta.fitobj_coefnames = c(:)';
        elseif isstring(c)
            meta.fitobj_coefnames = cellstr(c(:)');
        end
    case 'fitobj_coefvalues'
        meta.fitobj_coefvalues = decode_json_vector_(val);
end
end


function v = decode_json_(txt)
%DECODE_JSON_  jsondecode with an empty-on-failure fallback
%
%   Inputs:
%       txt : char - JSON text -- required
%
%   Outputs:
%       v : any - decoded value, or [] when the text does not parse
try
    v = jsondecode(txt);
catch
    v = [];
end
end


function v = decode_json_vector_(txt)
%DECODE_JSON_VECTOR_  Decode a JSON numeric array to a double row vector
%
%   Inputs:
%       txt : char - JSON array text -- required
%
%   Outputs:
%       v : 1xN double - decoded values; JSON null entries (how writers
%           encode NaN/Inf, which JSON cannot represent) become NaN.
%           [] when the text does not parse.
raw = decode_json_(txt);
if isempty(raw)
    v = [];
    return
end
if iscell(raw)
    % jsondecode returns a cell when the array mixes numbers and nulls.
    v = nan(1, numel(raw));
    for ii = 1:numel(raw)
        if isnumeric(raw{ii}) && isscalar(raw{ii})
            v(ii) = double(raw{ii});
        end
    end
else
    v = double(raw(:)');
end
end
