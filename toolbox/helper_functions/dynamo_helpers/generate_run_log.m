function [run_ID, fname] = generate_run_log(structs, struct_names, varargin)
%GENERATE_RUN_LOG  Serialize DYNAM-O option structs to a JSON settings file.
%
%   Usage:
%       [run_ID, fname] = generate_run_log(structs, struct_names, varargin)
%
%   Inputs:
%       structs:      cell array - option structs (one per DYNAM-O config) -- required
%       struct_names: cell array - names matched 1:1 to structs            -- required
%
%   Optional:
%       run_start:      char    - start timestamp; default = now (yyyyMMdd_HHmmss)
%       file_path:      char    - results root to write into; default = cwd.
%                                 The file lands in <file_path>/settings/
%                                 (created if absent), the canonical
%                                 settings location of the shared output
%                                 tree. A file_path already named
%                                 'settings' is used as-is.
%       out_path:       char    - explicit full path (dir + filename) to
%                                 write to. Overrides file_path/fname when
%                                 given. Useful when the caller already has
%                                 a uiputfile result. Default = '' (use
%                                 file_path + auto-generated fname).
%       write_file:     logical - if false, skip the file write (Default: true)
%       verbose:        logical - print to console (Default: false)
%       batch_settings: struct  - GUI batch-level state (data/staging file
%                                 lists, output dir, save toggles, etc.).
%                                 When non-empty, the payload includes a
%                                 top-level "batch_settings" object and
%                                 schema_version is set to 2 so the file
%                                 is reloadable into the DYNAMOApp GUI.
%                                 Default = [] (legacy v1 file).
%
%   Output:
%       run_ID: char - unique identifier (currently the timestamp)
%       fname:  char - file basename written
%
%   Schema (JSON):
%       {
%         "run_start": "<yyyyMMdd_HHmmss>",
%         "schema_version": 1 | 2,
%         "options": {
%             "<struct_names{1}>": <struct_1 fields>,
%             "<struct_names{2}>": <struct_2 fields>,
%             ...
%         },
%         "batch_settings": { ... }   // present when schema_version >= 2
%       }
%
%   This replaces the legacy `.txt` format (which stored MATLAB code and
%   was loaded via `run()` — a code-injection vector). The JSON format is
%   inert: `jsondecode` deserializes data only.
%
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
% =========================================================================

p = inputParser;
p.CaseSensitive = false;
addParameter(p, 'run_start', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'file_path', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'out_path',  '', @(x) ischar(x) || isstring(x));
addParameter(p, 'write_file', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'verbose', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'batch_settings', [], @(x) isempty(x) || isstruct(x));
parse(p, varargin{:});

run_start      = char(p.Results.run_start);
file_path      = char(p.Results.file_path);
out_path       = char(p.Results.out_path);
write_file     = p.Results.write_file;
verbose        = p.Results.verbose;
batch_settings = p.Results.batch_settings;

assert(~isempty(structs) && iscell(structs), 'structs must be a non-empty cell array');
assert(iscell(struct_names) && numel(struct_names) == numel(structs), ...
    'struct_names must be a cell array the same length as structs');

if isempty(run_start)
    dtime = datetime; dtime.Format = 'yyyyMMdd_HHmmss';
    run_start = char(dtime);
end
run_ID = run_start;
fname = sprintf('batch_settings_%s.json', run_start);

% Assemble payload.
options = struct();
for ii = 1:numel(structs)
    name = char(struct_names{ii});
    assert(isvarname(name), 'struct_names{%d}=%s is not a valid identifier', ii, name);
    options.(name) = structs{ii};
end
has_batch_settings = ~isempty(batch_settings) && isstruct(batch_settings);
if has_batch_settings
    schema_version = 2;
else
    schema_version = 1;
end

payload = struct( ...
    'run_start',      run_start, ...
    'schema_version', schema_version, ...
    'options',        options);

% Convert Inf/-Inf/NaN scalars to sentinel strings before encoding.
% jsonencode silently turns Inf/NaN into null (JSON has no IEEE
% specials), and we can't tell those apart from a legitimate empty
% on read-back. detection_options.max_merges = Inf is the canonical
% case that triggers this. load_run_log reverses the substitution.
payload.options = encode_specials(payload.options);

if has_batch_settings
    payload.batch_settings = encode_specials(batch_settings);
end

try
    json_text = jsonencode(payload, 'PrettyPrint', true);
catch
    json_text = jsonencode(payload);
end

if verbose
    fprintf('%% %s\n%s\n', fname, json_text);
end

if write_file
    if ~isempty(out_path)
        target = out_path;
    else
        if isempty(file_path)
            file_path = pwd;
        end
        % Settings files live under <out>/settings/ in the canonical
        % output tree (matching the desktop app and dynamo-cli). Skip the
        % nesting when the caller already points at a settings folder.
        [~, leaf] = fileparts(file_path);
        if ~strcmpi(leaf, 'settings')
            file_path = fullfile(file_path, 'settings');
        end
        if ~isfolder(file_path)
            mkdir(file_path);
        end
        target = fullfile(file_path, fname);
    end
    fid = fopen(target, 'w');
    assert(fid > 0, 'Could not open %s for writing', target);
    cleaner = onCleanup(@() fclose(fid));
    fwrite(fid, json_text, 'char');
end
end


function out = encode_specials(in)
%ENCODE_SPECIALS  Recursively walk a struct, replacing Inf/-Inf/NaN
%values with sentinel strings ("__inf__", "__-inf__", "__nan__") so
%the JSON encoder doesn't lose them. Numeric arrays that contain ANY
%Inf/NaN entries are converted to cell arrays of mixed numerics and
%sentinel strings — load_run_log reverses this back to numeric.
if isstruct(in)
    out = in;
    fns = fieldnames(in);
    for k = 1:numel(fns)
        out.(fns{k}) = encode_specials(in.(fns{k}));
    end
elseif iscell(in)
    out = cellfun(@encode_specials, in, 'UniformOutput', false);
elseif isnumeric(in) && isscalar(in)
    out = encode_special_scalar(in);
elseif isnumeric(in) && any(~isfinite(in(:)))
    % Mixed-content array: convert each element to a cell entry. Track
    % the original size so the decoder can reshape back.
    out = arrayfun(@encode_special_scalar, in, 'UniformOutput', false);
else
    out = in;
end
end

function s = encode_special_scalar(v)
if isinf(v) && v > 0
    s = '__inf__';
elseif isinf(v) && v < 0
    s = '__-inf__';
elseif isnan(v)
    s = '__nan__';
else
    s = v;
end
end
