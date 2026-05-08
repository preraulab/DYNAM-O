function writeParamfitFormats(app, fitData, base, axis_kind, freq_bins, so_bins, subject_id, formats, overwrite)
    % writeParamfitFormats  Write a paramfit struct to each requested format.
    %
    %   app.writeParamfitFormats(fitData, base, axis_kind, freq_bins,
    %                            so_bins, formats, overwrite)
    %
    %   fitData   : paramfit struct (params, fitobj, gof, [model_SOPH],
    %               [wshed_img]). Fitobj may be a real cfit (CSV-write
    %               possible) or a from-CSV struct stand-in (CSV-write
    %               degrades — coefnames/coefvalues empty).
    %   base      : path prefix without extension, e.g.
    %               '<chan>/param_basis/<fbase>_SOpower_paramfit_<chan>'.
    %   axis_kind : 'power' | 'phase' (used by writeParamfitCsv).
    %   freq_bins : SOPHs.freq_bins for the CSV header.
    %   so_bins   : SOPHs.SO{power,phase}_bins for the CSV header.
    %   formats   : cellstr {'.csv','.h5'}; legacy '.mat' aliased to '.h5'.
    %   overwrite : logical.
    %
    %   Conversion warnings:
    %     - h5 → csv  : (none — CSV preamble carries gof + bg + coefs)
    %                   except note that model_SOPH/wshed_img are CSV-absent.
    %     - csv → h5  : model_SOPH and wshed_img absent (re-render via re-fit).
    %
    %   See also: loadParamfit, writeParamfitCsv, parseParamfitCsvHeader.

    if isempty(fitData) || isempty(formats), return, end
    if ~iscell(formats), formats = {formats}; end

    is_slim_csv  = isfield(fitData, 'from_csv') && fitData.from_csv;
    has_full_h5  = isfield(fitData, 'model_SOPH') && ~isempty(fitData.model_SOPH);

    has_csv_target = any(cellfun(@(e) strcmpi(e, '.csv'), formats));
    has_mat_target = any(cellfun(@(e) strcmpi(e, '.mat'), formats));

    if has_csv_target && has_full_h5
        app.TextArea.addnl(sprintf('   [warn] paramfit (%s) MAT→CSV: model_SOPH and wshed_img not preserved.', axis_kind));
    end
    if has_mat_target && is_slim_csv
        app.TextArea.addnl(sprintf('   [warn] paramfit (%s) CSV→MAT: model_SOPH and wshed_img absent (re-render via re-fit if needed).', axis_kind));
    end

    varName = sprintf('SO%s_paramfit', axis_kind);

    for ii = 1:numel(formats)
        ext = lower(char(formats{ii}));
        switch ext
            case '.csv'
                p = [base '.csv'];
                if ~overwrite && isfile(p), continue, end
                app.TextArea.addnl(sprintf('   Saving parametric %s as .csv...', axis_kind));
                app.writeParamfitCsv(p, fitData, axis_kind, freq_bins, so_bins, subject_id);
                if strcmp(axis_kind,'power')
                    app.output_paramfit_power_name = p;
                else
                    app.output_paramfit_phase_name = p;
                end
            case '.mat'
                p = [base '.mat'];
                if ~overwrite && isfile(p), continue, end
                app.TextArea.addnl(sprintf('   Saving %s as .mat...', varName));
                fitData_with_id = fitData;
                if ~isempty(subject_id)
                    fitData_with_id.subject_id = char(subject_id);
                end
                % Strip CSV-reconstruction provenance flags so a future
                % reload from this .mat doesn't keep flagging itself slim.
                if isfield(fitData_with_id, 'from_csv')
                    fitData_with_id = rmfield(fitData_with_id, 'from_csv');
                end
                if isstruct(fitData_with_id.fitobj) && ...
                        isfield(fitData_with_id.fitobj, 'from_csv')
                    fitData_with_id.fitobj = ...
                        rmfield(fitData_with_id.fitobj, 'from_csv');
                end
                S.(varName) = fitData_with_id; %#ok<STRNU>
                save(p, '-struct', 'S', '-v7.3');
                if strcmp(axis_kind,'power')
                    app.output_paramfit_power_name = p;
                else
                    app.output_paramfit_phase_name = p;
                end
            otherwise
                % unknown — skip
        end
    end
end
