function [idx, Q] = get_mode_peaks(mode_params, axis_kind, stats_table, prob)
%GET_MODE_PEAKS  Indices of TF-peaks inside a mode's assignment contour.
%
%   [idx, Q] = get_mode_peaks(mode_params, axis_kind, stats_table, prob)
%
%   Returns a logical column `idx` (one entry per row of STATS_TABLE) that
%   is true for peaks falling inside the parametric mode's assignment
%   contour, and the per-peak negative log-relative-height `Q` (a peak is
%   inside iff Q <= -log(1-prob)). For power modes this contour encloses
%   `prob` of the fitted Gaussian's mass. For phase modes it is a
%   `(1-prob)` relative-height contour, not generally a `prob` mass region.
%
%   Inputs:
%       mode_params : 1x6 vector [amp, fmean, fstd, so_mean, so_std, theta]
%                     in the param_basis convention. `fstd` is the frequency
%                     standard deviation for both power and phase modes.
%       axis_kind   : 'power' or 'phase'.
%       stats_table : TF-peak stats table with columns PeakFrequency and
%                     SOpower (power) / SOphase (phase).
%       prob        : contour parameter in (0,1). Default 0.95. It is the
%                     enclosed Gaussian mass for power; for phase it sets
%                     the relative-height cutoff to 1-prob.
%
%   Geometry (identical to rotGauss.m / vmGauss.m and the Rust port).
%   Q is the negative log of the standalone kernel's relative height at the
%   peak, Q = -log(kernel/amp), with the background excluded:
%     power: u =  (F-fmean)cosθ + (P-so_mean)sinθ
%            v = -(F-fmean)sinθ + (P-so_mean)cosθ
%            Q = 0.5*( (u/fstd)^2 + (v/so_std)^2 )
%     phase: Δ = wrap( φ - so_mean + (F-fmean)sinθ ),  k = 1/so_std^2
%            Q = 0.5*((F-fmean)/fstd)^2 + k*(1 - cos Δ)
%
%   A peak is inside iff Q <= -log(1-prob)  (p=0.95 -> log(20) ~ 2.996),
%   equivalently kernel/amp >= 1-prob. For the power kernel this is also the
%   exact `prob` mass contour of a bivariate Gaussian. The phase kernel is
%   von Mises x Gaussian, so the mass inside this relative-height contour
%   depends on k and is not generally `prob`.
%
%   The factor of one half sits on the GAUSSIAN terms only, never on
%   k*(1 - cos Δ). The von Mises factor is its own small-angle Gaussian and
%   already carries the half intrinsically, so halving it too would double
%   the effective phase concentration. Equivalently: do NOT collapse this by
%   dropping the half and doubling the threshold to -2*log(1-prob) -- that is
%   right on the power axis and wrong on the phase axis.
%
%   Q and the threshold must move together with the kernels. For the power
%   Gaussian, adding the half to rotGauss.m without adding it here drops
%   95% mass containment to ~77.7% with no error raised anywhere. For phase,
%   omitting the half would instead change the specified relative-height
%   contour; its enclosed mass remains k-dependent. Q = -log(kernel/amp) is
%   the invariant that keeps both branches aligned with their kernels.
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
% =========================================================================
if nargin < 4 || isempty(prob); prob = 0.95; end
assert(isscalar(prob) && prob > 0 && prob < 1, 'prob must be in (0,1).');

is_phase = strcmpi(axis_kind, 'phase');
fmean  = mode_params(2);
fstd   = mode_params(3);
so_mean = mode_params(4);
so_std  = mode_params(5);
theta   = mode_params(6);

thr = -log(1 - prob);

F = stats_table.PeakFrequency;
if is_phase
    S = stats_table.SOphase;
else
    S = stats_table.SOpower;
end
F = F(:); S = S(:);
df = F - fmean;

if is_phase
    k = 1 / so_std^2;
    delta = mod(S - so_mean + df.*sin(theta) + pi, 2*pi) - pi;   % wrap to (-pi,pi]
    % Half on the Gaussian frequency term only. k*(1-cos delta) is already
    % the von Mises negative-log-ratio and must not be halved.
    Q = 0.5 .* (df ./ fstd).^2 + k .* (1 - cos(delta));
else
    u =  df.*cos(theta) + (S - so_mean).*sin(theta);
    v = -df.*sin(theta) + (S - so_mean).*cos(theta);
    Q = 0.5 .* ((u ./ fstd).^2 + (v ./ so_std).^2);
end

idx = isfinite(F) & isfinite(S) & isfinite(Q) & (Q <= thr);
if (~(fstd > 0)) || (~is_phase && ~(so_std > 0)) || (is_phase && ~(so_std > 0))
    idx = false(size(F));   % degenerate mode contains nothing
end
end
