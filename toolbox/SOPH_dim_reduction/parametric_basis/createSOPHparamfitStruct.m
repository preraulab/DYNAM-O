function [SOPH_paramfit] = createSOPHparamfitStruct(type, params, fitobj, gof, model_SOPH, wshed_img)
%CREATESOPHPARAMFITSTRUCT  Pack parametric-basis fit outputs into a struct.
%
%   type:    'power' or 'phase' — selects column names for the returned
%            params table.
%   params:  N×6 numeric matrix from param_basis_{power,phase}, with
%            columns [amp0, fmean0, fstd0, pmean0, pstd0, theta0].
%
%   The returned .params field is a MATLAB table. The first column is
%   `Density`: the raw rotGauss `amp` for power, but an empirical
%   no-sinusoid, jointly normalized model height substituted by
%   param_basis_phase after fitting for phase.
%
%     power: Density (peaks/min/bin), FreqMean (Hz), FreqStd (Hz),
%            SOpowerMean (dB), SOpowerStd (dB), Theta (rad),
%            Volume (peaks/min — Density × area-under-mode),
%            and (after fitParamBasis annotation) two additional columns:
%            PrefPhase  (rad),  Coupling  (proportion/phase-bin).
%     phase: Density (proportion/phase-bin), FreqMean (Hz), FreqStd (Hz),
%            SOphaseMean (rad), SOphaseStd (rad), Theta (rad),
%            Volume (historical standalone-vmGauss area surrogate).
%
%   NOTE: power Density is peaks/min/bin; phase Density and the model coupling column are proportion/phase-bin (phase histogram is row-normalized upstream). The SO phase-coupling metric is model-based only: PrefPhase/Coupling are read from the fitted phase parametric surface (the older raw-histogram argmax and circular-mean estimators have been retired).
%
%   Volume column — standalone-kernel area derived from the six reported
%   parameters. Gaussian-width coefficients follow from
%   ∫exp(-0.5·(d/sigma)^2) dd = sigma·sqrt(2*pi):
%
%     power (rotGauss, exp(-0.5·(u/sigma)^2) form):
%         V = Density · 2*pi · SOpowerStd · FreqStd
%         theta drops out (rotation is volume-preserving).
%
%     phase (vmGauss, von Mises × Gaussian; the freq Gaussian uses
%            exp(-0.5·(dy/FreqStd)^2)):
%         k = 1 / SOphaseStd^2
%         V = Density · 2*pi · besseli(0,k,1) · sqrt(2*pi) · FreqStd
%         (besseli(0,k,1) is the scaled form exp(-k)·I0(k), used to
%         keep the product finite for sharp phase modes where exp(-k)
%         and I0(k) would each over/underflow separately.)
%         Only the frequency integral moved (sqrt(pi) → sqrt(2*pi)); the
%         von Mises factor and k are untouched because SOphaseStd stores the
%         existing recikappa = 1/sqrt(k) parameter.
%         For k >> 1 (sharp phase modes), this asymptotes to
%             V ≈ Density · 2*pi · SOphaseStd · FreqStd.
%
%     Power Density is the raw fit coefficient, so power Volume is the exact
%     full-plane integral of the standalone rotGauss component.
%
%     Phase Volume retains the historical surrogate: it multiplies the
%     standalone vmGauss area by the empirical no-sinusoid model height that
%     param_basis_phase reports as Density. That height comes from the full,
%     jointly row-normalized model (background and all modes), so this is not
%     the exact integral of an isolated jointly normalized component or of
%     the raw fitobj component. The updated Gaussian coefficient preserves
%     this surrogate under the frequency-width reparameterization.
%
%   Empty params produce an empty table with the right VariableNames so
%   downstream isempty(...) checks still hold and column-name access
%   (e.g. T.PrefPhase) does not error on a zero-mode fit.
switch lower(type)
    case 'power'
        % 6 from the fit + Volume (derived) + 2 (PrefPhase/Coupling) and 10
        % per-mode TF-peak summary columns (Pk*) added by fitParamBasis
        % annotation. Declared up front so the empty-fallback table exposes
        % all columns; the annotation blocks append real values when params
        % is non-empty.
        vn      = {'Density','FreqMean','FreqStd','SOpowerMean','SOpowerStd','Theta','Volume'};
        vn_full = [vn, {'PrefPhase','Coupling'}, pk_cols_()];
    case 'phase'
        vn      = {'Density','FreqMean','FreqStd','SOphaseMean','SOphaseStd','Theta','Volume'};
        vn_full = [vn, pk_cols_()];
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
% Standalone-kernel area per mode. Power is an exact component integral;
% phase is the historical empirical-height surrogate described above.
density = params(:,1);
fstd    = params(:,3);   % FreqStd
xstd    = params(:,5);   % SOpowerStd or SOphaseStd
switch type
    case 'power'
        % rotGauss: V = density * 2*pi * xstd * fstd
        vol = density .* (2*pi) .* xstd .* fstd;
    case 'phase'
        % vmGauss: V = density * 2*pi * exp(-k) * I0(k) * sqrt(2*pi) * fstd
        % Use the SCALED Bessel besseli(0,k,1) = exp(-k)*I0(k) so the
        % product stays finite for sharp phase modes (small xstd ->
        % large k -> exp(-k) underflows and I0(k) overflows separately).
        k   = 1 ./ (xstd .^ 2);
        vol = density .* (2*pi) .* besseli(0, k, 1) .* sqrt(2*pi) .* fstd;
    otherwise
        vol = nan(size(density));
end
end


function c = pk_cols_()
% Per-mode TF-peak summary column names (appended by
% annotateModesWithPeakStats). Must match the Rust mode_peaks Pk* columns.
c = {'PkCount','PkFreq','PkDuration','PkBandwidth','PkHeight', ...
     'PkVolume','PkArea','PkPeakiness','PkSOpower','PkSOphase'};
end
