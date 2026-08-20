function writeAuxH5(p, S, stamp)
%WRITEAUXH5  Write an auxiliary_data struct to a flat top-level HDF5 file.
%
%   Usage:
%       writeAuxH5(p, S)
%       writeAuxH5(p, S, stamp)
%
%   Each field of struct S becomes a top-level dataset in the .h5 at path p
%   (which must not already exist — the caller deletes any stale file first).
%   Serialization rules:
%       - char/string  -> H5T_STRING (MATLAB 'string' datatype)
%       - integer      -> native integer class (e.g. uint8 stage_vals)
%       - logical      -> int8 (HDF5 has no native bool)
%       - other numeric-> double
%       - empty fields -> skipped (h5create rejects zero-extent datasets), so
%                         an absent dataset means "no data" (e.g. no artifacts).
%
%   When STAMP (a struct from dynamo_stamp) is supplied, the aux format-2
%   provenance datasets of DesktopApp OUTPUT_FORMAT.md section 8.2 are
%   written after the data fields, mirroring the Rust aux_h5 writer:
%       /format         (1,1) double  = 2
%       /writer         string        = stamp.writer
%       /writer_version string        = stamp.writer_version
%       /kernel_version string        = stamp.kernel_version
%       /code_version   string        = stamp.writer_version (legacy alias
%                                       kept for pre-stamp readers)
%   Without STAMP the on-disk layout is unchanged (format-1 file).
%
%   This is shared by the app writer (writeAuxFormats) and the legacy
%   converter (convert_aux_to_compact) so both emit a byte-identical layout
%   matching the DYNAM-O desktop app's compact aux schema.
%
%   See also: writeAuxFormats, convert_aux_to_compact, loadAuxData,
%             dynamo_stamp.
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

if nargin < 3
    stamp = [];
end

fn = fieldnames(S);
for ii = 1:numel(fn)
    v    = S.(fn{ii});
    path = ['/' fn{ii}];
    if isempty(v)
        continue
    end
    if ischar(v) || isstring(v)
        sval = string(v);
        if isscalar(sval)
            h5create(p, path, [1 1], 'Datatype', 'string');
        else
            h5create(p, path, size(sval), 'Datatype', 'string');
        end
        h5write(p, path, sval);
    elseif isinteger(v)
        sz = size_for_h5_(v);
        h5create(p, path, sz, 'Datatype', class(v));
        h5write(p, path, v);
    elseif islogical(v)
        iv = int8(v);
        sz = size_for_h5_(iv);
        h5create(p, path, sz, 'Datatype', 'int8');
        h5write(p, path, iv);
    elseif isnumeric(v)
        iv = double(v);
        sz = size_for_h5_(iv);
        h5create(p, path, sz, 'Datatype', 'double');
        h5write(p, path, iv);
    else
        warning('writeAuxH5:skipField', ...
            'Skipping unsupported aux field "%s" (class %s).', fn{ii}, class(v));
    end
end

% Provenance stamp datasets (aux format 2). Written last so a stale
% partial file is detectable by their absence.
if ~isempty(stamp)
    assert(all(isfield(stamp, {'writer','writer_version','kernel_version'})), ...
        'stamp must carry writer, writer_version, and kernel_version (see dynamo_stamp).');
    h5create(p, '/format', [1 1], 'Datatype', 'double');
    h5write(p, '/format', 2);
    write_string_scalar_(p, '/writer',         char(stamp.writer));
    write_string_scalar_(p, '/writer_version', char(stamp.writer_version));
    write_string_scalar_(p, '/kernel_version', char(stamp.kernel_version));
    % Legacy alias: same value as writer_version, read by pre-stamp tools.
    write_string_scalar_(p, '/code_version',   char(stamp.writer_version));
end
end


function write_string_scalar_(p, path, s)
%WRITE_STRING_SCALAR_  Create + write a (1,1) string dataset
%
%   Inputs:
%       p    : char - .h5 file path -- required
%       path : char - dataset path, e.g. '/writer' -- required
%       s    : char - value to store -- required
%
%   Outputs:
%       none (side effects only)
h5create(p, path, [1 1], 'Datatype', 'string');
h5write(p, path, string(s));
end


function sz = size_for_h5_(v)
% h5create wants a non-scalar size vector; for scalars return [1 1].
if isscalar(v)
    sz = [1 1];
else
    sz = size(v);
end
end
