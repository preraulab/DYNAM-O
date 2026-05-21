function writeSplinefitFormats(app, fitData, base, axis_kind, default_freq_bins, default_so_bins, so_bin_field, subject_id, formats, overwrite)
    % writeSplinefitFormats  Write a splinefit struct to each requested format.
    %
    %   app.writeSplinefitFormats(fitData, base, axis_kind,
    %       default_freq_bins, default_so_bins, so_bin_field,
    %       formats, overwrite)
    %
    %   fitData          : splinefit struct (splinefit, coefs, knots_x,
    %                      knots_y, [spline_obj], [fit_freq_bins,
    %                      fit_SOfeature_bins]).
    %   base             : path prefix without extension.
    %   axis_kind        : 'power' | 'phase'.
    %   default_freq_bins: SOPHs.freq_bins, fallback when fit_freq_bins
    %                      is absent (older payloads).
    %   default_so_bins  : SOPHs.SO{power,phase}_bins, fallback for
    %                      fit_SOfeature_bins.
    %   so_bin_field     : 'SOpower_bins' | 'SOphase_bins' — JSON key.
    %   formats          : cellstr {'.tiff','.h5'}; legacy '.mat' aliased.
    %   overwrite        : logical.
    %
    %   Conversion fidelity: TIFF carries coefs (page 1) + rendered fit
    %   (page 2) + knots/bins in JSON ImageDescription, so loadSplinefit
    %   can rebuild spline_obj. .h5 saves the in-memory struct as-is.
    %
    %   See also: loadSplinefit, runSplineBasis, writeTiff.

    if isempty(fitData) || isempty(formats), return, end
    if ~iscell(formats), formats = {formats}; end

    varName = sprintf('SO%s_splinefit', axis_kind);

    % Resolve fit-domain bins (saved into TIFF metadata so a TIFF→struct
    % round-trip can reproduce the rendered fit on the same grid).
    if isfield(fitData,'fit_SOfeature_bins') && ~isempty(fitData.fit_SOfeature_bins)
        fitSO = fitData.fit_SOfeature_bins;
    else
        fitSO = default_so_bins;
    end
    if isfield(fitData,'fit_freq_bins') && ~isempty(fitData.fit_freq_bins)
        fitFB = fitData.fit_freq_bins;
    else
        fitFB = default_freq_bins;
    end

    metaStruct = struct( ...
        'label',       'splinefit', ...
        'knots_x',     local_row_(fitData, 'knots_x'), ...
        'knots_y',     local_row_(fitData, 'knots_y'), ...
        'freq_bins',   fitFB(:).', ...
        (so_bin_field), fitSO(:).', ...
        'subjectID',   char(subject_id), ...
        'page1',       'coefs', ...
        'page2',       'splinefit', ...
        'format',      'f32 row-major');
    meta  = jsonencode(metaStruct);
    pages = {fitData.coefs, fitData.splinefit};

    for ii = 1:numel(formats)
        ext = lower(char(formats{ii}));
        switch ext
            case '.tiff'
                p = [base '.tiff'];
                if ~overwrite && isfile(p), continue, end
                app.TextArea.addnl(sprintf('   Saving spline %s as .tiff (coefs + splinefit)...', axis_kind));
                app.writeTiff(p, pages, meta);
                if strcmp(axis_kind,'power')
                    app.output_splinefit_power_name = p;
                else
                    app.output_splinefit_phase_name = p;
                end
            case '.mat'
                p = [base '.mat'];
                if ~overwrite && isfile(p), continue, end
                app.TextArea.addnl(sprintf('   Saving %s as .mat...', varName));
                fitData_with_id = fitData;
                if ~isempty(subject_id)
                    fitData_with_id.subjectID = char(subject_id);
                end
                S.(varName) = fitData_with_id; %#ok<STRNU>
                save(p, '-struct', 'S', '-v7.3');
                if strcmp(axis_kind,'power')
                    app.output_splinefit_power_name = p;
                else
                    app.output_splinefit_phase_name = p;
                end
            otherwise
                % unknown — skip
        end
    end
end


function v = local_row_(S, name)
    if isfield(S, name) && ~isempty(S.(name))
        v = S.(name);
        v = v(:).';
    else
        v = [];
    end
end
