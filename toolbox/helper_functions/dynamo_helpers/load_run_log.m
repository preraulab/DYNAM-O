function S = load_run_log(filepath)
%LOAD_RUN_LOG  Read a DYNAM-O JSON settings file written by generate_run_log.
%
%   Usage:
%       S = load_run_log(filepath)
%
%   Output: a struct with fields .run_start, .schema_version, .options
%   The .options field is itself a struct keyed by config name (e.g.
%   .options.SOPH_options, .options.detection_options).
%
%   This is the SAFE deserializer — uses jsondecode only, no eval/run.
%
%   See also: generate_run_log

assert(exist(filepath, 'file') == 2, 'load_run_log: file not found: %s', filepath);
text = fileread(filepath);
S = jsondecode(text);

% Schema validation.
assert(isstruct(S), 'load_run_log: top-level must be a JSON object');
assert(isfield(S, 'options') && isstruct(S.options), ...
    'load_run_log: missing or invalid .options in %s', filepath);
if ~isfield(S, 'schema_version')
    S.schema_version = 1;
end

% Reverse the Inf/NaN sentinel substitution that generate_run_log applied
% to dodge JSON's lack of IEEE specials.
S.options = decode_specials(S.options);
end


function out = decode_specials(in)
%DECODE_SPECIALS  Reverse encode_specials in generate_run_log:
% - "__inf__" / "__-inf__" / "__nan__" strings        → Inf / -Inf / NaN scalars
% - cell arrays of all (numeric | special-string)     → numeric array
% - column vectors decoded from a JSON array           → row vector
%   (DYNAM-O option fields are stored as row vectors;
%   jsondecode returns JSON arrays as columns.)
if isstruct(in)
    out = in;
    fns = fieldnames(in);
    for k = 1:numel(fns)
        out.(fns{k}) = decode_specials(in.(fns{k}));
    end
elseif iscell(in)
    decoded = cellfun(@decode_specials, in, 'UniformOutput', false);
    if cell_is_all_numeric_scalar(decoded)
        % Recombine into a numeric array, preserving orientation.
        out = reshape([decoded{:}], size(decoded));
        if isvector(out); out = out(:).'; end
    else
        out = decoded;
    end
elseif (ischar(in) || isstring(in)) && isscalar(string(in))
    s = char(in);
    switch s
        case '__inf__';  out = Inf;
        case '__-inf__'; out = -Inf;
        case '__nan__';  out = NaN;
        otherwise;       out = in;
    end
elseif isnumeric(in) && isvector(in) && ~isscalar(in)
    out = in(:).';
else
    out = in;
end
end

function tf = cell_is_all_numeric_scalar(c)
tf = all(cellfun(@(x) isnumeric(x) && isscalar(x), c(:)));
end
