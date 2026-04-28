function [SOPH_splinefit] = createSOPHsplinefitStruct(splinefit, coefs, spline_obj, knots_x, knots_y)
%CREATESOPHSPLINEFITSTRUCT  Pack spline-basis fit outputs into a struct.
SOPH_splinefit = struct;
SOPH_splinefit.splinefit = splinefit;
SOPH_splinefit.coefs = coefs;
SOPH_splinefit.spline_obj = spline_obj;
SOPH_splinefit.knots_x = knots_x;
SOPH_splinefit.knots_y = knots_y;
end
