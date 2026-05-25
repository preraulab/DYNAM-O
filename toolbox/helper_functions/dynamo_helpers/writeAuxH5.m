function writeAuxH5(p, S)
%WRITEAUXH5  Write an auxiliary_data struct to a flat top-level HDF5 file.
%
%   Usage:
%       writeAuxH5(p, S)
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
%   This is shared by the app writer (writeAuxFormats) and the legacy
%   converter (convert_aux_to_compact) so both emit a byte-identical layout
%   matching the DYNAM-O desktop app's compact aux schema.
%
%   See also: writeAuxFormats, convert_aux_to_compact, loadAuxData.
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

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
end


function sz = size_for_h5_(v)
% h5create wants a non-scalar size vector; for scalars return [1 1].
if isscalar(v)
    sz = [1 1];
else
    sz = size(v);
end
end
