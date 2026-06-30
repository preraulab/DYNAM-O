function out = loadParamfit(app, channel, fbase)
    % loadParamfit  Resolve per-axis paramfit structs from any saved format.
    %
    %   out = loadParamfit(app, channel, fbase)
    %
    %   Returns: struct with fields SOpower_paramfit and SOphase_paramfit.
    %   Each is either a paramfit struct (params, fitobj, gof, [model_SOPH],
    %   [wshed_img]) or [] if no on-disk artifact is found for that axis.
    %
    %   Per-axis resolution order:
    %     1. In-memory app.SOPHs.SO*_paramfit if non-empty.
    %     2. <chan>/param_basis/<fbase>_SO{power,phase}_paramfit_<chan>.h5
    %     3. ... .mat   (legacy)
    %     4. ... .csv   (slim — model_SOPH and wshed_img absent;
    %                    fitobj is a stand-in struct with coefnames and
    %                    coefvalues fields built from the CSV preamble).
    %
    %   See also: writeParamfitFormats, parseParamfitCsvHeader,
    %             writeParamfitCsv.

    out = struct('SOpower_paramfit', [], 'SOphase_paramfit', []);

    chanDir  = fullfile(app.OutputDirEditField.Value, channel);
    paramDir = fullfile(chanDir, 'param_basis');

    out.SOpower_paramfit = load_axis_(app, paramDir, fbase, channel, ...
        'SOpower',  'SOpower_paramfit',  'SOpower_bins');
    out.SOphase_paramfit = load_axis_(app, paramDir, fbase, channel, ...
        'SOphase',  'SOphase_paramfit',  'SOphase_bins');
end


function pf = load_axis_(app, paramDir, fbase, channel, axisTag, varName, soBinField)
    pf = [];

    % In-memory shortcut.
    if ~isempty(app.SOPHs) && isfield(app.SOPHs, varName) && ...
            ~isempty(app.SOPHs.(varName))
        pf = app.SOPHs.(varName);
        return
    end

    base = fullfile(paramDir, [fbase '_' axisTag '_paramfit_' channel]);
    h5p  = [base '.h5'];
    matp = [base '.mat'];
    csvp = [base '.csv'];

    for binPath = {h5p, matp}
        p = binPath{1};
        if ~isfile(p), continue, end
        try
            S = load(p, varName);
            if isfield(S, varName) && ~isempty(S.(varName))
                pf = S.(varName);
                return
            end
        catch
        end
    end

    if isfile(csvp)
        try
            pf = build_from_csv_(app, csvp, axisTag, soBinField);
        catch
            pf = [];
        end
    end
end


function pf = build_from_csv_(app, csvp, axisTag, soBinField)
    % Slim reconstruction. Carries enough to re-emit .h5 (lossy: missing
    % model_SOPH and wshed_img) but downstream cfit-based evaluation is
    % not supported — fitobj is a struct stand-in.
    hdr = app.parseParamfitCsvHeader(csvp);
    T   = readtable(csvp, 'CommentStyle', '#');

    fitobj = struct();
    % Background coefficients map to the internal fitobj slots xxx/yyy/zzz
    % positionally. The CSV header carries axis-specific keys (power:
    % PowSlope/FreqSlope/Offset; phase: SinAmp/SinPhase/Offset); the retired
    % xxx/yyy/zzz keys are accepted too so pre-rename CSVs still load.
    fitobj.xxx      = local_get_(hdr, {'background_PowSlope','background_SinAmp','background_xxx'}, NaN);
    fitobj.yyy      = local_get_(hdr, {'background_FreqSlope','background_SinPhase','background_yyy'}, NaN);
    fitobj.zzz      = local_get_(hdr, {'background_Offset','background_zzz'}, NaN);
    fitobj.unit_row = local_get_(hdr, 'unit_row',       NaN);
    fitobj.coefnames  = local_get_(hdr, 'fitobj_coefnames',  {});
    fitobj.coefvalues = local_get_(hdr, 'fitobj_coefvalues', []);
    % Mark as reconstructed so callers can detect lossy provenance.
    fitobj.from_csv = true;

    gof = struct();
    gof.sse        = local_get_(hdr, 'gof_sse',        NaN);
    gof.rsquare    = local_get_(hdr, 'gof_rsquare',    NaN);
    gof.dfe        = local_get_(hdr, 'gof_dfe',        NaN);
    gof.adjrsquare = local_get_(hdr, 'gof_adjrsquare', NaN);
    gof.rmse       = local_get_(hdr, 'gof_rmse',       NaN);

    pf = struct();
    pf.params     = T;
    pf.fitobj     = fitobj;
    pf.gof        = gof;
    pf.model_SOPH = [];
    pf.wshed_img  = [];
    pf.freq_bins  = local_get_(hdr, 'freq_bins',  []);
    pf.(soBinField) = local_get_(hdr, soBinField, []);
    pf.fit_type   = axisTag;
    pf.from_csv   = true;
end


function v = local_get_(s, name, default)
    % name may be a single field name or a cell of candidate names (first
    % present wins) — used to accept axis-specific + legacy background keys.
    if iscell(name)
        for i = 1:numel(name)
            if isfield(s, name{i})
                v = s.(name{i});
                return
            end
        end
        v = default;
    elseif isfield(s, name)
        v = s.(name);
    else
        v = default;
    end
end
