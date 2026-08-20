function [aux, meta] = loadAuxData(path)
%LOADAUXDATA  Read an auxiliary_data .h5, splitting data from provenance
%
%   Usage:
%       [aux, meta] = loadAuxData(path)
%
%   Inputs:
%       path : char - auxiliary_data .h5 path -- required
%
%   Outputs:
%       aux  : struct - data datasets (Fs, subjectID, SOpower_norm,
%              stage_times, ...), normalized to the compact schema by
%              normalizeAuxStruct (adds SOpower_step / SOpower_t_start /
%              artifact_spans defaults for legacy files and the
%              is_compact flag). String datasets come back as char, and
%              a legacy subject_id dataset is renamed subjectID.
%       meta : struct - provenance datasets (aux format 2, DesktopApp
%              OUTPUT_FORMAT.md section 8.2), each tolerated when absent:
%                .format         : double - 2 for stamped files, [] when
%                                  the dataset is missing (format-1 file)
%                .writer         : char ('' when absent)
%                .writer_version : char - '/writer_version', falling back
%                                  to the legacy '/code_version'
%                .kernel_version : char ('' when absent)
%                .code_version   : char - the legacy dataset verbatim
%
%   Notes:
%       The provenance datasets are removed from aux so downstream
%       consumers that iterate aux fields (writers, plotters) never
%       mistake stamp strings for data. Unknown datasets are kept in aux
%       untouched (readers must ignore unknown names, not drop them).
%
%   Example:
%       [aux, meta] = loadAuxData('S001_auxiliary_data_C3.h5');
%       plot((0:numel(aux.SOpower_norm)-1) * aux.SOpower_step + ...
%           aux.SOpower_t_start, aux.SOpower_norm);
%
%   See also: writeAuxH5, normalizeAuxStruct, convert_aux_to_compact
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

assert(ischar(path) || (isstring(path) && isscalar(path)), 'path must be char or string.');
path = char(path);
if ~isfile(path)
    error('loadAuxData:fileNotFound', 'No such file: %s', path);
end

aux = struct();
info = h5info(path);
for ii = 1:numel(info.Datasets)
    name = info.Datasets(ii).Name;
    v = h5read(path, ['/' name]);
    if isstring(v)
        if isscalar(v)
            v = char(v);
        else
            v = cellstr(v);
        end
    end
    if strcmp(name, 'subject_id')
        name = 'subjectID';
    end
    aux.(name) = v;
end

% Split the provenance datasets out of the data struct. All are optional
% (format-1 files carry code_version only, or nothing at all).
meta = struct('format', [], 'writer', '', 'writer_version', '', ...
    'kernel_version', '', 'code_version', '');
if isfield(aux, 'format') && isnumeric(aux.format)
    meta.format = double(aux.format(1));
end
str_keys = {'writer', 'writer_version', 'kernel_version', 'code_version'};
for ii = 1:numel(str_keys)
    if isfield(aux, str_keys{ii}) && ischar(aux.(str_keys{ii}))
        meta.(str_keys{ii}) = aux.(str_keys{ii});
    end
end
aux = rmfield(aux, intersect(fieldnames(aux), [{'format'}, str_keys]));

% Legacy fallback: pre-stamp files identify their build via code_version.
if isempty(meta.writer_version)
    meta.writer_version = meta.code_version;
end

% Legacy dtype fixups mirroring convert_aux_to_compact's reader.
if isfield(aux, 'artifacts')
    aux.artifacts = logical(aux.artifacts);
end
if isfield(aux, 'SOpower_retain_Fs')
    aux.SOpower_retain_Fs = logical(aux.SOpower_retain_Fs);
end

aux = normalizeAuxStruct(aux);
end
