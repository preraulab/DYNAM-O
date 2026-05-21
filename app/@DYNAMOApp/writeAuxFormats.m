function writeAuxFormats(app, auxiliary_data, auxBase, subject_id, formats, overwrite)
    % writeAuxFormats  Write auxiliary_data to each requested format.
    %
    %   app.writeAuxFormats(auxiliary_data, auxBase, subject_id, ...
    %                       formats, overwrite)
    %
    %   auxiliary_data : canonical struct in the compact schema
    %                    (Fs, SOpower_norm [native grid], SOpower_t_start,
    %                    SOpower_norm_method, SOpower_window_params,
    %                    SOpower_freqrange, artifact_spans, stage_times,
    %                    stage_vals [uint8]).
    %   auxBase        : path prefix without extension.
    %   subject_id     : char (== fbase). Embedded as a top-level
    %                    /subjectID dataset in .h5 / a struct field
    %                    `auxiliary_data.subjectID` in .mat.
    %   formats        : cellstr; subset of {'.h5', '.mat'}. The .h5
    %                    output is written via the shared writeAuxH5 helper
    %                    (top-level datasets, externally clean). The .mat
    %                    output is the legacy fallback — save(...,'-v7.3'),
    %                    HDF5 internally too but wrapped in MATLAB's MAT-file
    %                    header so load() reads it back as a struct.
    %   overwrite      : logical.
    %
    %   See also: loadAuxData, regenAuxData, saveAuxData, writeAuxH5.

    if isempty(formats), return, end
    if ~iscell(formats), formats = {formats}; end

    % Drop read-time-only / legacy fields so only the canonical compact
    % schema is written. normalizeAuxStruct (on load) synthesizes
    % is_compact / SOpower_step, and a normalized legacy struct may still
    % carry artifacts / SOpower_retain_Fs — none of those belong on disk.
    transient = {'is_compact', 'SOpower_step', 'artifacts', 'SOpower_retain_Fs'};
    for tt = 1:numel(transient)
        if isfield(auxiliary_data, transient{tt})
            auxiliary_data = rmfield(auxiliary_data, transient{tt});
        end
    end

    if ~isempty(subject_id)
        auxiliary_data.subjectID = char(subject_id);
    end

    for ii = 1:numel(formats)
        ext = lower(char(formats{ii}));
        switch ext
            case '.h5'
                p = [auxBase '.h5'];
                if ~overwrite && isfile(p), continue, end
                app.TextArea.addnl('Saving auxiliary data...');
                if isfile(p), delete(p); end
                writeAuxH5(p, auxiliary_data);
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
