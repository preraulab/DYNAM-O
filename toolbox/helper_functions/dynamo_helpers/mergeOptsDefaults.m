function opts = mergeOptsDefaults(opts, defaults)
%MERGEOPTSDEFAULTS  Backfill default option fields without overwriting user values.
%
%   opts = mergeOptsDefaults(opts, defaults)
%
%   Adds any field in `defaults` that's missing from `opts`. Fields already
%   set in `opts` are preserved (user-supplied values win). Returns a struct
%   with the union of fields. No-op when opts already has every field, or
%   when either argument is not a struct.
if ~isstruct(opts) || ~isstruct(defaults)
    return
end
fns = fieldnames(defaults);
for ii = 1:numel(fns)
    if ~isfield(opts, fns{ii})
        opts.(fns{ii}) = defaults.(fns{ii});
    end
end
end
