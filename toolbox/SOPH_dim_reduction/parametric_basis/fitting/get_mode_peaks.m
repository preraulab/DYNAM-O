function [idx, Q] = get_mode_peaks(mode_params, axis_kind, stats_table, prob)
%GET_MODE_PEAKS  Indices of TF-peaks inside a mode's confidence region.
%
%   [idx, Q] = get_mode_peaks(mode_params, axis_kind, stats_table, prob)
%
%   Returns a logical column `idx` (one entry per row of STATS_TABLE) that
%   is true for peaks falling inside the parametric mode's P-confidence
%   region, and the per-peak quadratic `Q` (Mahalanobis-style; a peak is
%   inside iff Q <= -log(1-prob)).
%
%   Inputs:
%       mode_params : 1x6 vector [amp, fmean, fstd, so_mean, so_std, theta]
%                     in the raw param_basis convention. For 'phase' the
%                     `fstd` is variance-form and is sqrt'd internally to a
%                     sigma (matching the power axis and the Rust
%                     `dynamo_pipeline::mode_peaks` implementation).
%       axis_kind   : 'power' or 'phase'.
%       stats_table : TF-peak stats table with columns PeakFrequency and
%                     SOpower (power) / SOphase (phase).
%       prob        : confidence level in (0,1). Default 0.95.
%
%   Geometry (identical to rotGauss.m / vmGauss.m and the Rust port):
%     power: u =  (F-fmean)cosθ + (P-so_mean)sinθ
%            v = -(F-fmean)sinθ + (P-so_mean)cosθ
%            Q = (u/fstd)^2 + (v/so_std)^2
%     phase: Δ = wrap( φ - so_mean + (F-fmean)sinθ ),  k = 1/so_std^2
%            Q = ((F-fmean)/fstd)^2 + k*(1 - cos Δ)
%
%   A peak is inside iff Q <= -log(1-prob)  (p=0.95 -> log(20) ~ 2.996).
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
if is_phase
    fstd = sqrt(fstd);   % variance -> sigma (matches the emitted FreqStd)
end

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
    Q = (df ./ fstd).^2 + k .* (1 - cos(delta));
else
    u =  df.*cos(theta) + (S - so_mean).*sin(theta);
    v = -df.*sin(theta) + (S - so_mean).*cos(theta);
    Q = (u ./ fstd).^2 + (v ./ so_std).^2;
end

idx = isfinite(F) & isfinite(S) & isfinite(Q) & (Q <= thr);
if (~(fstd > 0)) || (~is_phase && ~(so_std > 0)) || (is_phase && ~(so_std > 0))
    idx = false(size(F));   % degenerate mode contains nothing
end
end
