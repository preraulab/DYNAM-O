function [SOPH_splinefit] = createSOPHsplinefitStruct(splinefit, coefs, spline_obj, knots_x, knots_y, fit_SOfeature_bins, fit_freq_bins)
%CREATESOPHSPLINEFITSTRUCT  Pack spline-basis fit outputs into a struct.
%
%   fit_SOfeature_bins / fit_freq_bins (optional) are the filtered
%   fit-domain bins returned by spline_basis after applying the limits
%   and validity masks. The rendered `splinefit` field is on this
%   filtered grid (not on the original SOPH grid), so saving these
%   alongside coefs+knots makes the spline tiff self-sufficient for
%   reconstruction.
if nargin < 6, fit_SOfeature_bins = []; end
if nargin < 7, fit_freq_bins      = []; end
SOPH_splinefit = struct;
SOPH_splinefit.splinefit = splinefit;
SOPH_splinefit.coefs = coefs;
SOPH_splinefit.spline_obj = spline_obj;
SOPH_splinefit.knots_x = knots_x;
SOPH_splinefit.knots_y = knots_y;
SOPH_splinefit.fit_SOfeature_bins = fit_SOfeature_bins;
SOPH_splinefit.fit_freq_bins      = fit_freq_bins;
end
