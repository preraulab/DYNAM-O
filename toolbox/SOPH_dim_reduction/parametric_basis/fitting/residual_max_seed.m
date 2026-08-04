function [seed_row, found] = residual_max_seed(SOPH_yx, model_SOPH_yx, x_axis, y_axis, accepted_modes, min_freq_diff, axis_kind)
%RESIDUAL_MAX_SEED  Matching-pursuit seed for iter-add paramfit.
%
%   [seed_row, found] = residual_max_seed(SOPH_yx, model_SOPH_yx, ...
%                                         x_axis, y_axis, accepted_modes, ...
%                                         min_freq_diff, axis_kind)
%
%   Returns a 1x6 [amp, fmean, fstd, pmean, pstd, theta] seed taken
%   from the (x, y) argmax of the residual `SOPH_yx - model_SOPH_yx`,
%   skipping y-axis (freq) bins within `min_freq_diff` of any
%   accepted-mode FreqMean (col 2 of `accepted_modes`). Returns
%   `found = false` and `seed_row = []` when no positive residual
%   remains after the mask — the caller falls back to mean(B0i) seeding.
%
%   Used by param_basis_power.m and param_basis_phase.m to seed modes
%   beyond the watershed-derived initial conditions, in place of the
%   prior mean(B0i, 1) synthetic seed. The mean-seed degenerates when
%   the watershed gave fewer seeds than max_peaks (the new seed lands
%   on top of the existing cluster, the LM never finds anything new);
%   matching-pursuit places the next mode at the largest currently-
%   unfit feature.
%
%   Required Inputs:
%       SOPH_yx        - [Ny, Nx] double - histogram (y = freq rows,
%                        x = power|phase cols).
%       model_SOPH_yx  - [Ny, Nx] double - last-iteration model on the
%                        same grid.
%       x_axis         - [1, Nx] double - power_bins or phase_bins.
%       y_axis         - [1, Ny] double - freq_bins.
%       accepted_modes - [k, 6]  double - accepted-mode parameter
%                        matrix (B0i pre-append).
%       min_freq_diff  - scalar - freq-exclusion radius (Hz). 0
%                        disables the freq mask (phase axis convention).
%       axis_kind      - 'power' or 'phase'. Required, because column 5 is
%                        polymorphic: it is the SO-power Gaussian standard
%                        deviation for 'power' but recikappa for 'phase',
%                        and the two carry different width conventions (see
%                        the fallback note below). Driving this by column
%                        index alone would corrupt every phase seed with no
%                        error raised.
%
%   Outputs:
%       seed_row - [1, 6] double or [] - [amp, fmean, fstd, pmean,
%                  pstd, theta] seed row; empty when no positive
%                  residual remains after the mask.
%       found    - logical - true when a seed was produced.
%
%   Width priors (fstd, pstd) default to median over accepted-mode stds
%   (cols 3 and 5), with safety floors so the LM bounds stay
%   non-degenerate. Theta starts at 0.
%
%   The medians ride whatever convention the accepted params already carry,
%   so they need no rescale. Only the literal fallbacks do: the historical
%   1.0 Hz and 5.0 were pre-half widths, so they divide by sqrt(2) to keep
%   the same seeded shape now that the parameters are standard deviations.
%   The col-5 fallback rescales for 'power' only -- for 'phase' it is
%   recikappa, which was always a true standard deviation.
%
%   See also param_basis_power, param_basis_phase, mode_overlap.
%
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
%   GITHUB     https://github.com
%
% =========================================================================

assert(nargin >= 7 && (ischar(axis_kind) || isstring(axis_kind)) && ...
    ismember(lower(char(axis_kind)), {'power', 'phase'}), ...
    'residual_max_seed:badAxisKind', ...
    'axis_kind must be supplied as ''power'' or ''phase''.');
is_phase = strcmpi(axis_kind, 'phase');

[ny, nx] = size(SOPH_yx);
assert(isequal(size(model_SOPH_yx), [ny, nx]), ...
    'residual_max_seed:shapeMismatch', ...
    'model_SOPH_yx must match SOPH_yx shape.');
assert(numel(y_axis) == ny && numel(x_axis) == nx, ...
    'residual_max_seed:axisMismatch', ...
    'y_axis / x_axis lengths must match SOPH_yx dims.');

% Anti-duplication freq mask: exclude freq bins within `min_freq_diff`
% of any accepted-mode FreqMean. Without this guard the residual peak
% right next to an undermodeled existing mode (alpha tail, spindle
% skirts) is picked, the LM puts the new mode on top of the existing
% one, and the run reverts on overlap (or worse, accepts a near-
% duplicate). min_freq_diff = 0 disables the mask (phase axis).
if min_freq_diff > 0 && ~isempty(accepted_modes)
    accepted_fmeans = accepted_modes(:, 2);
    excluded_y = false(ny, 1);
    for ii = 1:ny
        excluded_y(ii) = any(abs(accepted_fmeans - y_axis(ii)) < min_freq_diff);
    end
else
    excluded_y = false(ny, 1);
end

R = SOPH_yx - model_SOPH_yx;
R(~isfinite(R)) = -Inf;
R(excluded_y, :) = -Inf;

[max_val, lin_idx] = max(R(:));
if ~isfinite(max_val) || max_val <= 0
    seed_row = [];
    found = false;
    return;
end

[y_idx, x_idx] = ind2sub([ny, nx], lin_idx);
fmean = y_axis(y_idx);
pmean = x_axis(x_idx);
amp = max_val;

% Width priors: median of accepted-mode stds, with safety floors so
% the LM bounds stay non-degenerate when accepted_modes is empty or
% all-NaN.
fstd_fallback = 1.0 / sqrt(2);
if is_phase
    pstd_fallback = 5.0;            % recikappa: already a standard deviation
else
    pstd_fallback = 5.0 / sqrt(2);  % rotGauss SO-power standard deviation
end
if isempty(accepted_modes)
    fstd = fstd_fallback;
    pstd = pstd_fallback;
else
    fstd_med = median(accepted_modes(:, 3), 'omitnan');
    if ~isfinite(fstd_med) || fstd_med <= 0
        fstd_med = fstd_fallback;
    end
    pstd_med = median(accepted_modes(:, 5), 'omitnan');
    if ~isfinite(pstd_med) || pstd_med <= 0
        pstd_med = pstd_fallback;
    end
    fstd = fstd_med;
    pstd = pstd_med;
end

seed_row = [amp, fmean, fstd, pmean, pstd, 0];
found = true;
end
