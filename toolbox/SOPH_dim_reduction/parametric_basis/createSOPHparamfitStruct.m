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
%            and (after fitParamBasis annotation) six additional columns:
%            PrefPhaseArgmax (rad),  CouplingArgmax (proportion/phase-bin),
%            PrefPhaseCirc   (rad),  CouplingCirc   ([0,1] MRL),
%            PrefPhaseModel  (rad),  CouplingModel  (proportion/phase-bin).
%     phase: Density (proportion/phase-bin), FreqMean (Hz), FreqStd (Hz),
%            SOphaseMean (rad), SOphaseStd (rad), Theta (rad).
%
%   NOTE: power Density is peaks/min/bin; phase Density and the argmax/model coupling columns are proportion/phase-bin (phase histogram is row-normalized upstream); CouplingCirc is dimensionless MRL in [0,1].
%   Empty params produce an empty table with the right VariableNames so
%   downstream isempty(...) checks still hold and column-name access
%   (e.g. T.PrefPhaseModel) does not error on a zero-mode fit.
switch lower(type)
    case 'power'
        % 12 names: 6 from the fit + 6 added by fitParamBasis annotation.
        % Declared up front so the empty-fallback table exposes all
        % columns; the annotation block in fitParamBasis appends real
        % values when params is non-empty.
        vn      = {'Density','FreqMean','FreqStd','SOpowerMean','SOpowerStd','Theta'};
        vn_full = [vn, {'PrefPhaseArgmax','CouplingArgmax', ...
                        'PrefPhaseCirc','CouplingCirc', ...
                        'PrefPhaseModel','CouplingModel'}];
    case 'phase'
        vn      = {'Density','FreqMean','FreqStd','SOphaseMean','SOphaseStd','Theta'};
        vn_full = vn;
    otherwise
        error('createSOPHparamfitStruct:badType','type must be ''power'' or ''phase''.');
end
SOPH_paramfit = struct;
if isempty(params)
    SOPH_paramfit.params = array2table(zeros(0,numel(vn_full)),'VariableNames',vn_full);
else
    SOPH_paramfit.params = array2table(params,'VariableNames',vn);
end
SOPH_paramfit.fitobj = fitobj;
SOPH_paramfit.gof = gof;
SOPH_paramfit.model_SOPH = model_SOPH;
SOPH_paramfit.wshed_img = wshed_img;
end
