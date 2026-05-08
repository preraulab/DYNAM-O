function writeAuxFormats(app, auxiliary_data, auxBase, subject_id, formats, overwrite)
    % writeAuxFormats  Write auxiliary_data to each requested format.
    %
    %   app.writeAuxFormats(auxiliary_data, auxBase, subject_id, ...
    %                       formats, overwrite)
    %
    %   auxiliary_data : canonical struct (SOpower_norm, Fs, artifacts,
    %                    SOpower_norm_method, SOpower_retain_Fs,
    %                    SOpower_window_params, stage_times, stage_vals).
    %   auxBase        : path prefix without extension.
    %   subject_id     : char (== fbase). Embedded as a top-level
    %                    /subject_id dataset in .h5 / a struct field in .mat.
    %   formats        : cellstr; subset of {'.h5', '.mat'}. The .h5
    %                    output is written via h5create+h5write per
    %                    field (top-level datasets, externally clean).
    %                    The .mat output is the legacy fallback —
    %                    save(...,'-v7.3'), HDF5 internally too but
    %                    wrapped in MATLAB's MAT-file header so load()
    %                    reads it back as a struct.
    %   overwrite      : logical.
    %
    %   See also: loadAuxData, regenAuxData, saveAuxData.

    if isempty(formats), return, end
    if ~iscell(formats), formats = {formats}; end

    if ~isempty(subject_id)
        auxiliary_data.subject_id = char(subject_id);
    end

    for ii = 1:numel(formats)
        ext = lower(char(formats{ii}));
        switch ext
            case '.h5'
                p = [auxBase '.h5'];
                if ~overwrite && isfile(p), continue, end
                app.TextArea.addnl('Saving auxiliary data...');
                if isfile(p), delete(p); end
                write_aux_h5_(p, auxiliary_data);
                app.output_aux_name = p;
            case '.mat'
                p = [auxBase '.mat'];
                if ~overwrite && isfile(p), continue, end
                app.TextArea.addnl('Saving auxiliary data...');
                save(p, 'auxiliary_data', '-v7.3'); %#ok<NASGU>
                app.output_aux_name = p;
            otherwise
                % unsupported — silently skip
        end
    end
end


function write_aux_h5_(p, S)
    % Write each field of struct S as a top-level HDF5 dataset.
    % Strings: written via H5T_STRING (MATLAB's 'string' datatype).
    % Logicals: stored as int8 (HDF5 has no native bool).
    fn = fieldnames(S);
    for ii = 1:numel(fn)
        v = S.(fn{ii});
        path = ['/' fn{ii}];
        % h5create rejects zero-size extents — skip empty fields
        % uniformly across all type branches. Realistic for subjects
        % with no staging events (empty stage_times / stage_vals) or
        % no excluded samples (empty artifacts).
        if isempty(v)
            continue
        end
        if ischar(v) || isstring(v)
            sval = string(v);
            if isscalar(sval)
                h5create(p, path, [1 1], 'Datatype', 'string');
                h5write(p, path, sval);
            else
                h5create(p, path, size(sval), 'Datatype', 'string');
                h5write(p, path, sval);
            end
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
            % Cells / structs / other types — skip with a warning.
            warning('writeAuxFormats:skipField', ...
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
