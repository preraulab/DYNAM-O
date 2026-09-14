function members = assign_mode_peaks(params6, axis_kind, stats_table, assign, background)
%ASSIGN_MODE_PEAKS  Member peaks of every mode under one assignment rule.
%
%   members = assign_mode_peaks(params6, axis_kind, stats_table, assign, background)
%
%   Inputs:
%       params6     : nM x 6 mode parameters [amp, fmean, fstd, so_mean,
%                     so_std, theta] (param_basis convention).
%       axis_kind   : 'power' or 'phase'.
%       stats_table : TF-peak stats table, ALREADY restricted to the
%                     population that fed the SOPH (the caller's job, as
%                     for GET_MODE_PEAKS).
%       assign      : parse_peak_assign struct, or any raw value it
%                     accepts (0.3, '0.3 p', '1.3 sigma', 'background',
%                     'argmax').
%       background  : 1x3 [xxx yyy zzz] fit background (GET_FIT_BACKGROUND).
%                     Only consulted by the density rules.
%
%   Output:
%       members : nPeaks x nM logical - members(i, m) is true when peak i
%                 belongs to mode m.
%
%   Rules (identical to Rust `dynamo_pipeline::mode_peaks::assign_members`
%   and the DYNAM-O_py mirror):
%     * numeric ('p' / 'sigma'): per-mode independent contour Q <= thr
%       (may overlap between modes).
%     * 'background' (power axis): member iff the mode's density at the
%       peak, amp*exp(-Q), is at least the background plane
%       xxx*P + yyy*F + zzz evaluated AT THE PEAK - both finite, density
%       > 0. Non-exclusive; a non-finite background fails closed.
%     * 'argmax' (power axis, exclusive): the peak goes to the first mode
%       attaining the maximal density, and only when that density beats
%       the background there (ties with the background go to the
%       background; non-finite background -> unassigned).
%     * Both density rules operate within each mode's footprint ellipse
%       (assign.q_cap = footprint^2/2; bare 'argmax'/'background' mean a
%       1.5-sigma footprint, 'argmax 2 s' overrides it): outside it a mode
%       neither claims a peak nor blocks another mode's argmax. Where the
%       background plane approaches zero, an uncapped comparison would
%       admit arbitrarily far tails (any positive mode density beats a
%       ~zero background). Numeric contours are NOT capped - their radius
%       is the user's explicit choice.
%     * On the PHASE axis the density rules fall back to the '0.95 p'
%       contour: phase Density is a row-normalized empirical height while
%       the stored phase background is pre-normalization, so a density
%       comparison is not well-defined there.
%
%   See also: parse_peak_assign, get_mode_peaks, get_fit_background,
%             annotateModesWithPeakStats
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
% =========================================================================
if ~isstruct(assign)
    assign = parse_peak_assign(assign);
end
is_phase = strcmpi(axis_kind, 'phase');
if is_phase && any(strcmp(assign.kind, {'background', 'argmax'}))
    assign = parse_peak_assign('0.95 p');   % phase fallback (documented above)
end

nM = size(params6, 1);
nP = height(stats_table);
members = false(nP, nM);
if nP == 0 || nM == 0
    return
end

% Per-peak Q for every mode (get_mode_peaks carries the containment math
% and its degenerate-mode guards; its Q is the shared primitive).
Q = nan(nP, nM);
ok = false(nP, nM);   % finite-input & non-degenerate mask per mode
for m = 1:nM
    [~, Qm] = get_mode_peaks(params6(m, :), axis_kind, stats_table, 0.95);
    Q(:, m) = Qm;
    % Same validity mask get_mode_peaks applies, minus the threshold.
    fstd = params6(m, 3); so_std = params6(m, 5);
    degenerate = ~(fstd > 0) || ~(so_std > 0);
    ok(:, m) = isfinite(Qm) & ~degenerate;
end

switch assign.kind
    case {'p', 'sigma'}
        members = ok & (Q <= assign.thr);
    otherwise
        % Density rules (power axis only by this point).
        F = stats_table.PeakFrequency(:);
        S = stats_table.SOpower(:);
        amps = params6(:, 1).';
        D = zeros(nP, nM);
        for m = 1:nM
            if isfinite(amps(m)) && amps(m) > 0
                in_cap = ok(:, m) & (Q(:, m) <= assign.q_cap);
                D(in_cap, m) = amps(m) .* exp(-Q(in_cap, m));
            end
        end
        bgv = background(1) .* S + background(2) .* F + background(3);
        if strcmp(assign.kind, 'background')
            members = (D > 0) & (D >= bgv) & isfinite(bgv);
        else % argmax
            % Background column FIRST so a tie goes to the background, and
            % MATLAB max's first-maximizer rule keeps earlier modes on
            % mode-mode ties (matching the Rust strict-> scan / np.argmax).
            [dmax, wi] = max([bgv, D], [], 2);
            for m = 1:nM
                members(:, m) = (wi == m + 1) & (dmax > 0) & isfinite(bgv);
            end
        end
end
end
