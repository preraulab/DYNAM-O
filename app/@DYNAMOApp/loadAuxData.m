function aux = loadAuxData(app, channel, fbase)
    % loadAuxData  Resolve an auxiliary_data struct from any saved format.
    %
    %   aux = loadAuxData(app, channel, fbase)
    %
    %   Resolution order:
    %     1. In-memory app.auxiliary_data when non-empty.
    %     2. <chan>/auxiliary_data/<fbase>_auxiliary_data_<chan>.h5
    %        (top-level HDF5 datasets — read via h5read per field).
    %     3. <chan>/auxiliary_data/<fbase>_auxiliary_data_<chan>.mat
    %        (legacy/fallback — read via load()).
    %     4. [] on total miss.
    %
    %   See also: writeAuxFormats, regenAuxData, saveAuxData.

    aux = [];

    if ~isempty(app.auxiliary_data) && isstruct(app.auxiliary_data) && ...
            ~isempty(fieldnames(app.auxiliary_data))
        aux = app.auxiliary_data;
        return
    end

    chanDir = fullfile(app.OutputDirEditField.Value, channel);
    base    = fullfile(chanDir, 'auxiliary_data', ...
        [fbase '_auxiliary_data_' channel]);

    h5p  = [base '.h5'];
    matp = [base '.mat'];

    if isfile(h5p)
        try
            aux = read_aux_h5_(h5p);
            if ~isempty(aux), return, end
        catch
        end
    end

    if isfile(matp)
        try
            S = load(matp, 'auxiliary_data');
            if isfield(S, 'auxiliary_data')
                aux = S.auxiliary_data;
                return
            end
        catch
        end
    end
end


function aux = read_aux_h5_(p)
    aux = struct();
    info = h5info(p);
    if isempty(info.Datasets), return, end
    for ii = 1:numel(info.Datasets)
        name = info.Datasets(ii).Name;
        try
            v = h5read(p, ['/' name]);
        catch
            continue
        end
        % MATLAB returns string-class for H5T_STRING; coerce subject_id
        % and norm_method back to char for downstream consistency.
        if isstring(v)
            if isscalar(v), v = char(v); else, v = cellstr(v); end
        end
        % Restore the logical class for fields that were stored as int8.
        if any(strcmp(name, {'artifacts','SOpower_retain_Fs'}))
            v = logical(v);
        end
        aux.(name) = v;
    end
end
