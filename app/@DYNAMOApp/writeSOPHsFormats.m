function writeSOPHsFormats(app, SOPHs, sophsDir, fbase, channel, formats, overwrite)
    % writeSOPHsFormats  Write SOPHs to each requested format.
    %
    %   app.writeSOPHsFormats(SOPHs, sophsDir, fbase, channel, formats, overwrite)
    %
    %   SOPHs    : canonical struct (typically app.SOPHs).
    %   sophsDir : output dir, e.g. '<chan>/SOPHs'.
    %   fbase    : input filename base (subject id).
    %   channel  : channel string.
    %   formats  : cellstr of extensions to emit. Subset of
    %              {'.tiff', '.mat'}. The .mat is HDF5 internally
    %              (-v7.3) and saved via `save -struct slim` so each
    %              SOPHs field lands as a TOP-LEVEL dataset (h5py
    %              friendly).
    %   overwrite: logical.
    %
    %   Lossy direction warnings (one line per call):
    %     - h5 → tiff : timeseries fields not preserved.
    %     - tiff → h5 : SOphase / timeseries / SOfiltered absent.
    %   Detected by inspecting which SOPHs fields are present.
    %
    %   Layout: the .mat is written via `save('-struct', slim, '-v7.3')`
    %   so every SOPHs field lands as a TOP-LEVEL HDF5 dataset (e.g.
    %   /SOpower_mat, /freq_bins) — readable directly via h5py /
    %   h5dump despite the .mat extension:
    %     `with h5py.File(p,'r') as f: M = f['SOpower_mat'][:]`
    %   The legacy `/SOPHs/<field>` group layout (a single 'SOPHs'
    %   struct variable) is still readable via loadOrReconstructSOPHs,
    %   which falls back when no flat fields are found at the top level.
    %
    %   Fields excluded from the saved .h5 (carried in the in-memory
    %   canonical only): SO{power,phase}_paramfit, SO{power,phase}_splinefit.
    %   These are already saved separately by writeParamfitFormats /
    %   writeSplinefitFormats and contain MATLAB-specific cfit and
    %   spline_obj objects that don't flatten cleanly to HDF5. The model
    %   objects can be reconstructed from the per-axis paramfit / spline-
    %   fit files (coefnames+coefvalues for cfit, knots+coefs for spmak).
    %
    %   See also: loadOrReconstructSOPHs, writeTiff.

    if isempty(formats), return, end
    if ~iscell(formats), formats = {formats}; end

    sophBase    = fullfile(sophsDir, [fbase '_SOPHs_'       channel]);
    sophPowBase = fullfile(sophsDir, [fbase '_SOPHs_power_' channel]);
    sophPhaBase = fullfile(sophsDir, [fbase '_SOPHs_phase_' channel]);

    has_mat_target  = any(cellfun(@(e) strcmpi(e, '.mat'), formats));
    has_tiff_target = any(cellfun(@(e) strcmpi(e, '.tiff'), formats));

    has_timeseries  = isfield(SOPHs,'SOpower_norm') && ~isempty(SOPHs.SOpower_norm);
    has_full_struct = isfield(SOPHs,'SOphase_mat'); % TIFF reconstructions still set this
    is_slim_recon   = isfield(SOPHs,'from_tiff') && SOPHs.from_tiff;

    if has_tiff_target && has_timeseries
        app.TextArea.addnl('   [warn] SOPHs MAT→TIFF: timeseries fields not preserved. Re-run with overwrite to regenerate.');
    end
    if has_mat_target && is_slim_recon
        app.TextArea.addnl('   [warn] SOPHs TIFF→MAT: SOphase / SOfiltered absent (TIFF carries histograms only).');
    end
    if has_mat_target && ~has_full_struct
        app.TextArea.addnl('   [warn] SOPHs slim→MAT: phase axis not in source; .mat will lack SOphase_mat.');
    end

    subjectId = char(fbase);
    % ImageDescription JSON mirrors the DYNAM-O desktop app's SOPH TIFF
    % schema: row axis = SO bins, col axis = freq bins, plus row_centers/
    % col_centers aliases and a format tag. Existing MATLAB readers key off
    % freq_bins / SO*_bins (still present); the extra keys are additive.
    powMeta = jsonencode(struct( ...
        'label',        'sopower', ...
        'rows',         sz_(SOPHs, 'SOpower_mat', 1), ...
        'cols',         sz_(SOPHs, 'SOpower_mat', 2), ...
        'row_centers',  soph_get_(SOPHs, 'SOpower_bins'), ...
        'col_centers',  soph_get_(SOPHs, 'freq_bins'), ...
        'SOpower_bins', soph_get_(SOPHs, 'SOpower_bins'), ...
        'freq_bins',    soph_get_(SOPHs, 'freq_bins'), ...
        'subjectID',    subjectId, ...
        'format',       'f32 row-major'));
    phaMeta = jsonencode(struct( ...
        'label',        'sophase', ...
        'rows',         sz_(SOPHs, 'SOphase_mat', 1), ...
        'cols',         sz_(SOPHs, 'SOphase_mat', 2), ...
        'row_centers',  soph_get_(SOPHs, 'SOphase_bins'), ...
        'col_centers',  soph_get_(SOPHs, 'freq_bins'), ...
        'SOphase_bins', soph_get_(SOPHs, 'SOphase_bins'), ...
        'freq_bins',    soph_get_(SOPHs, 'freq_bins'), ...
        'subjectID',    subjectId, ...
        'format',       'f32 row-major'));

    wrote_any = false;
    for ii = 1:numel(formats)
        ext = lower(char(formats{ii}));
        switch ext
            case '.tiff'
                if isfield(SOPHs,'SOpower_mat') && ~isempty(SOPHs.SOpower_mat)
                    p = [sophPowBase '.tiff'];
                    if overwrite || ~isfile(p)
                        if ~wrote_any, app.TextArea.addnl('   Saving SOPHs'); wrote_any = true; end
                        app.writeTiff(p, SOPHs.SOpower_mat, powMeta);
                        app.output_SOPH_name = p;
                    end
                end
                if isfield(SOPHs,'SOphase_mat') && ~isempty(SOPHs.SOphase_mat)
                    p = [sophPhaBase '.tiff'];
                    if overwrite || ~isfile(p)
                        if ~wrote_any, app.TextArea.addnl('   Saving SOPHs'); wrote_any = true; end
                        app.writeTiff(p, SOPHs.SOphase_mat, phaMeta);
                        app.output_SOPH_name = p;
                    end
                end
            case '.mat'
                p = [sophBase '.mat'];
                if ~overwrite && isfile(p), continue, end
                if ~wrote_any, app.TextArea.addnl('   Saving SOPHs'); wrote_any = true; end
                slim = SOPHs;
                drop_fields = {'SOpower_paramfit','SOphase_paramfit', ...
                               'SOpower_splinefit','SOphase_splinefit'};
                for kk = 1:numel(drop_fields)
                    if isfield(slim, drop_fields{kk})
                        slim = rmfield(slim, drop_fields{kk});
                    end
                end
                % Embed subjectID as a top-level dataset so the .mat
                % is self-identifying alongside the TIFF JSON metadata.
                % save -struct flattens SOPHs to top-level vars so
                % h5py / h5dump can read individual fields directly
                % (-v7.3 .mat IS HDF5).
                slim.subjectID = subjectId; %#ok<STRNU>
                save(p, '-struct', 'slim', '-v7.3');
                app.output_SOPH_name = p;
            otherwise
                % unknown extension — skip
        end
    end
end


function v = soph_get_(SOPHs, name)
    if isfield(SOPHs, name) && ~isempty(SOPHs.(name))
        v = SOPHs.(name);
        v = v(:).';
    else
        v = [];
    end
end


function n = sz_(SOPHs, name, dim)
    if isfield(SOPHs, name) && ~isempty(SOPHs.(name))
        n = size(SOPHs.(name), dim);
    else
        n = 0;
    end
end
