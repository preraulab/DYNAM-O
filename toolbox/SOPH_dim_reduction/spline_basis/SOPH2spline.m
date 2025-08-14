function [splinefit, coefs, spline_obj, knots_x, knots_y, f] = SOPH2spline(varargin)
warning('Replace this call with spline_basis');
[splinefit, coefs, spline_obj, knots_x, knots_y, f] = spline_basis(varargin{:});