function bounds = default_mode_shape_bounds(type)
%DEFAULT_MODE_SHAPE_BOUNDS  Default bounds on the shape parameters of a fitted mode
%
%   Usage:
%       bounds = default_mode_shape_bounds(type)
%
%   Inputs:
%       type : char - 'power' or 'phase', the fit the bounds are for -- required
%
%   Outputs:
%       bounds : struct - lower and upper bounds on the three shape
%                parameters of one mode, with fields
%                fstd_lower, fstd_upper   : frequency width, a standard
%                                           deviation in Hz
%                pstd_lower, pstd_upper   : width along the second axis.
%                                           For 'power' it is a standard
%                                           deviation in SO-power units.
%                                           For 'phase' it is recikappa =
%                                           1/sqrt(kappa) in radians.
%                theta_lower, theta_upper : rotation or skew parameter
%
%   Notes:
%       These are the same numbers as the Rust kernel's
%       paramfit::defaults (default_power_mode_shape_bounds and
%       default_phase_mode_shape_bounds in DYNAM-O_rs), which the desktop
%       app and the command-line tool read. The kernel is the reference.
%       A change to a value here needs the same change there, and the
%       kernel's MATLAB fixtures check that the two agree.
%
%       Only the shape parameters have fixed defaults. The bounds on the
%       amplitude and on the two centers depend on the histogram being
%       fitted, so the fit derives them from the data.
%
%   See also: param_basis_opts, param_basis_power, param_basis_phase
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

assert(ismember(type, {'power', 'phase'}), 'Invalid type. Valid types are ''power'' or ''phase''.');

switch type
    case 'power'
        % Rotated Gaussian modes. Both widths are standard deviations.
        bounds.fstd_lower = 0.1 / sqrt(2);
        bounds.fstd_upper = 2.5 / sqrt(2);
        bounds.pstd_lower = 2.5 / sqrt(2);
        bounds.pstd_upper = 30 / sqrt(2);
        bounds.theta_lower = -0.03;
        bounds.theta_upper = 0.03;
    case 'phase'
        % Von Mises by Gaussian modes. The frequency width is a standard
        % deviation and the phase width is recikappa.
        bounds.fstd_lower = 1 / sqrt(2);
        bounds.fstd_upper = sqrt(7.5);
        bounds.pstd_lower = pi / 5;
        bounds.pstd_upper = 2 * pi;
        bounds.theta_lower = -pi / 3;
        bounds.theta_upper = pi / 3;
end
end
