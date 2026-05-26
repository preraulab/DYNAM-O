function [SOPH_paramfit] = createSOPHparamfitStruct(type, params, fitobj, gof, model_SOPH, wshed_img)
%CREATESOPHPARAMFITSTRUCT  Pack parametric-basis fit outputs into a struct.
%
%   type:    'power' or 'phase' — selects column names for the returned
%            params table.
%   params:  N×6 numeric matrix from param_basis_{power,phase}, with
%            columns [amp0, fmean0, fstd0, pmean0, pstd0, theta0].
%
%   The returned .params field is a MATLAB table. The first column is
%   `Density` — the rotgauss / vmGauss `amp` parameter, which (because
%   the model is fit to a peak-density-style histogram) corresponds
%   semantically to TF-peak density at the mode location. Renamed
%   from the historical `Amplitude` to make the meaning explicit;
%   the underlying mathematical model is unchanged.
%
%     power: Density (peaks/min/bin), FreqMean (Hz), FreqStd (Hz),
%            SOpowerMean (dB), SOpowerStd (dB), Theta (rad),
%            Volume (peaks/min — Density × area-under-mode),
%            and (after fitParamBasis annotation) six additional columns:
%            PrefPhaseArgmax (rad),  CouplingArgmax (proportion/phase-bin),
%            PrefPhaseCirc   (rad),  CouplingCirc   ([0,1] MRL),
%            PrefPhaseModel  (rad),  CouplingModel  (proportion/phase-bin).
%     phase: Density (proportion/phase-bin), FreqMean (Hz), FreqStd (Hz),
%            SOphaseMean (rad), SOphaseStd (rad), Theta (rad),
%            Volume (proportion·rad·Hz — Density × area-under-mode).
%
%   NOTE: power Density is peaks/min/bin; phase Density and the argmax/model coupling columns are proportion/phase-bin (phase histogram is row-normalized upstream); CouplingCirc is dimensionless MRL in [0,1].
%
%   Volume column — closed-form integral of the fitted basis surface:
%
%     power (rotGauss, exp(-(u/sigma)^2) form, no factor of 1/2):
%         V = Density · pi · SOpowerStd · FreqStd
%         theta drops out (rotation is volume-preserving).
%
%     phase (vmGauss, von Mises × Gaussian; the freq Gaussian uses
%            exp(-dy^2/FreqStd) so FreqStd has variance-units):
%         k = 1 / SOphaseStd^2
%         V = Density · 2*pi · besseli(0,k,1) · sqrt(pi · FreqStd)
%         (besseli(0,k,1) is the scaled form exp(-k)·I0(k), used to
%         keep the product finite for sharp phase modes where exp(-k)
%         and I0(k) would each over/underflow separately.)
%         For k >> 1 (sharp phase modes), this asymptotes to
%             V ≈ Density · SOphaseStd · pi · sqrt(2 · FreqStd).
%
%     For phase, Density carries the empirical no-sin amplitude (set
%     by param_basis_phase after fit), so Volume here is the integral
%     of the *displayed* mode amplitude — not the integral of the raw
%     fitobj. Power Density is the raw fit coefficient, so power
%     Volume is the exact analytic integral.
%
%   Empty params produce an empty table with the right VariableNames so
%   downstream isempty(...) checks still hold and column-name access
%   (e.g. T.PrefPhaseModel) does not error on a zero-mode fit.
switch lower(type)
    case 'power'
        % 13 names: 6 from the fit + Volume (derived) + 6 added by
        % fitParamBasis annotation. Declared up front so the empty-
        % fallback table exposes all columns; the annotation block
        % in fitParamBasis appends real values when params is non-empty.
        vn      = {'Density','FreqMean','FreqStd','SOpowerMean','SOpowerStd','Theta','Volume'};
        vn_full = [vn, {'PrefPhaseArgmax','CouplingArgmax', ...
                        'PrefPhaseCirc','CouplingCirc', ...
                        'PrefPhaseModel','CouplingModel'}];
    case 'phase'
        vn      = {'Density','FreqMean','FreqStd','SOphaseMean','SOphaseStd','Theta','Volume'};
        vn_full = vn;
    otherwise
        error('createSOPHparamfitStruct:badType','type must be ''power'' or ''phase''.');
end
SOPH_paramfit = struct;
if isempty(params)
    SOPH_paramfit.params = array2table(zeros(0,numel(vn_full)),'VariableNames',vn_full);
else
    % Append Volume as a 7th column derived from the 6 fit parameters.
    vol = compute_volume_(lower(type), params);
    SOPH_paramfit.params = array2table([params, vol(:)],'VariableNames',vn);
end
SOPH_paramfit.fitobj = fitobj;
SOPH_paramfit.gof = gof;
SOPH_paramfit.model_SOPH = model_SOPH;
SOPH_paramfit.wshed_img = wshed_img;
end


function vol = compute_volume_(type, params)
% Analytic integral of the fitted basis surface per mode. See header
% docstring for derivations.
density = params(:,1);
fstd    = params(:,3);   % FreqStd
xstd    = params(:,5);   % SOpowerStd or SOphaseStd
switch type
    case 'power'
        % rotGauss: V = density * pi * xstd * fstd
        vol = density .* pi .* xstd .* fstd;
    case 'phase'
        % vmGauss: V = density * 2*pi * exp(-k) * I0(k) * sqrt(pi * fstd)
        % Use the SCALED Bessel besseli(0,k,1) = exp(-k)*I0(k) so the
        % product stays finite for sharp phase modes (small xstd ->
        % large k -> exp(-k) underflows and I0(k) overflows separately).
        k   = 1 ./ (xstd .^ 2);
        vol = density .* (2*pi) .* besseli(0, k, 1) .* sqrt(pi .* fstd);
    otherwise
        vol = nan(size(density));
end
end
