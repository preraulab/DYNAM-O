function [SOPH_paramfit] = createSOPHparamfitStruct(params, fitobj, gof, model_SOPH, wshed_img)
%CREATESOPHPARAMFITSTRUCT  Pack parametric-basis fit outputs into a struct.
SOPH_paramfit = struct;
SOPH_paramfit.params = params; % Columns are: [amp0, fmean0, fstd0, pmean0, pstd0, theta0]
SOPH_paramfit.fitobj = fitobj;
SOPH_paramfit.gof = gof;
SOPH_paramfit.model_SOPH = model_SOPH;
SOPH_paramfit.wshed_img = wshed_img;
end
