function [phase, r] = get_mode_phase_circmean(mode_freqs, SOphase_mat, freq_bins, phase_bins)
%GET_MODE_PHASE_CIRCMEAN  Weighted circular mean of phase histogram per mode.
%
%   [phase, r] = get_mode_phase_circmean(mode_freqs, SOphase_mat, freq_bins, phase_bins)
%
%   For each MODE_FREQS, snap to the nearest FREQ_BINS column and take
%   the weighted circular mean of the SOphase distribution at that
%   frequency:
%
%     z      = sum_k  H[k] * exp(i * phi[k])
%     phase  = angle(z)
%     r      = |z| / sum(H[k])
%
%   PHASE is the preferred phase (rad, in [-pi, pi]). R is the mean
%   resultant length in [0,1] — same construct as Canolty PAC mean
%   vector length, the phase-locking value, and vector strength: a
%   coupling-magnitude measure that says how concentrated the events
%   are around PHASE.
%
%   SOPHASE_MAT may be sized [Nphase x Nfreq] (canonical, matches
%   SOPHs.SOphase_mat) or [Nfreq x Nphase] — orientation is auto-
%   detected.

Np = numel(phase_bins);
Nf = numel(freq_bins);
if size(SOphase_mat,1) == Np && size(SOphase_mat,2) == Nf
    M = SOphase_mat;
elseif size(SOphase_mat,1) == Nf && size(SOphase_mat,2) == Np
    M = SOphase_mat.';
else
    error('get_mode_phase_circmean:badShape', ...
        'SOphase_mat must be [Nphase x Nfreq] or [Nfreq x Nphase] (got %dx%d, Nphase=%d, Nfreq=%d).', ...
        size(SOphase_mat,1), size(SOphase_mat,2), Np, Nf);
end

freq_idx = knnsearch(freq_bins(:), mode_freqs(:));
col      = M(:, freq_idx);                 % [Nphase x Nmodes]
col(~isfinite(col)) = 0;                   % defensive: NaN/Inf bins → 0 weight
phib     = phase_bins(:);
z        = sum(col .* exp(1i * phib), 1);  % [1 x Nmodes]
denom    = sum(col, 1);
r        = abs(z) ./ max(denom, eps);      % avoid 0/0; r=0 when row is all zeros
phase    = angle(z(:));
r        = r(:);
end
