function out = loadSplinefit(app, channel, fbase)
    % loadSplinefit  Resolve per-axis splinefit structs from any saved format.
    %
    %   out = loadSplinefit(app, channel, fbase)
    %
    %   Returns: struct with fields SOpower_splinefit and SOphase_splinefit.
    %   Each is either a splinefit struct (splinefit, coefs, knots_x,
    %   knots_y, spline_obj, fit_freq_bins, fit_SOfeature_bins) or [].
    %
    %   Per-axis resolution order:
    %     1. In-memory app.SOPHs.SO*_splinefit if non-empty.
    %     2. <chan>/spline_basis/<fbase>_SO{power,phase}_splinefit_<chan>.h5
    %     3. ... .mat   (legacy)
    %     4. ... .tiff  (page 1 = coefs, page 2 = rendered splinefit;
    %                    page-1 ImageDescription JSON carries knots + bins).
    %        spline_obj rebuilt via spmak from knots + coefs.
    %
    %   See also: writeSplinefitFormats, runSplineBasis.

    out = struct('SOpower_splinefit', [], 'SOphase_splinefit', []);

    chanDir   = fullfile(app.OutputDirEditField.Value, channel);
    splineDir = fullfile(chanDir, 'spline_basis');

    out.SOpower_splinefit = load_axis_(app, splineDir, fbase, channel, ...
        'SOpower', 'SOpower_splinefit', 'SOpower_bins');
    out.SOphase_splinefit = load_axis_(app, splineDir, fbase, channel, ...
        'SOphase', 'SOphase_splinefit', 'SOphase_bins');
end


function sf = load_axis_(app, splineDir, fbase, channel, axisTag, varName, soBinField)
    sf = [];

    if ~isempty(app.SOPHs) && isfield(app.SOPHs, varName) && ...
            ~isempty(app.SOPHs.(varName))
        sf = app.SOPHs.(varName);
        return
    end

    base   = fullfile(splineDir, [fbase '_' axisTag '_splinefit_' channel]);
    h5p    = [base '.h5'];
    matp   = [base '.mat'];
    tiffp  = [base '.tiff'];

    for binPath = {h5p, matp}
        p = binPath{1};
        if ~isfile(p), continue, end
        try
            S = load(p, varName);
            if isfield(S, varName) && ~isempty(S.(varName))
                sf = S.(varName);
                return
            end
            S = load(p);
            f = fieldnames(S);
            if ~isempty(f)
                sf = S.(f{1});
                return
            end
        catch
        end
    end

    if isfile(tiffp)
        try
            sf = build_from_tiff_(tiffp, soBinField);
        catch
            sf = [];
        end
    end
end


function sf = build_from_tiff_(tiffp, soBinField)
    info  = imfinfo(tiffp);
    coefs = double(imread(tiffp, 1));
    if numel(info) >= 2
        rendered = double(imread(tiffp, 2));
    else
        rendered = [];
    end

    meta = struct();
    if isfield(info, 'ImageDescription') && ~isempty(info(1).ImageDescription)
        try
            meta = jsondecode(info(1).ImageDescription);
        catch
        end
    end

    sf = struct();
    sf.coefs     = coefs;
    sf.splinefit = rendered;
    sf.knots_x   = local_get_(meta, 'knots_x', []);
    sf.knots_y   = local_get_(meta, 'knots_y', []);
    sf.fit_freq_bins        = local_get_(meta, 'freq_bins', []);
    sf.fit_SOfeature_bins   = local_get_(meta, soBinField,  []);

    % Rebuild B-form spline_obj from knots + coefs when possible.
    sf.spline_obj = [];
    try
        if exist('spmak', 'file') == 2 && ~isempty(sf.knots_x) && ~isempty(sf.knots_y)
            sf.spline_obj = spmak({sf.knots_x(:).', sf.knots_y(:).'}, coefs);
        end
    catch
    end

    sf.from_tiff = true;
end


function v = local_get_(s, name, default)
    if isstruct(s) && isfield(s, name)
        v = s.(name);
    else
        v = default;
    end
end
