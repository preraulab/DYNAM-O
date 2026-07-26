function [phase, mag] = get_mode_phase_argmax(mode_freqs, M, freq_bins, phase_bins)
%GET_MODE_PHASE_ARGMAX  Empirical / model preferred phase via argmax.
%
%   [phase, mag] = get_mode_phase_argmax(mode_freqs, M, freq_bins, phase_bins)
%
%   For each entry of MODE_FREQS, snap to the nearest entry of
%   FREQ_BINS and return:
%     - PHASE: the phase bin where M attains its maximum at that
%              frequency (rad).
%     - MAG:   the value of M at that argmax bin (same units as M;
%              for SOPHs.SOphase_mat that is events/min/bin).
%
%   M may be either the raw SOphase histogram (size [Nphase x Nfreq],
%   matching SOPHs.SOphase_mat) or a model surface from
%   param_basis_phase (size [Nfreq x Nphase]) — orientation is
%   detected and canonicalised to [Nphase x Nfreq] before lookup.

Np = numel(phase_bins);
Nf = numel(freq_bins);
if size(M,1) == Np && size(M,2) == Nf
    % already canonical
elseif size(M,1) == Nf && size(M,2) == Np
    M = M.';
else
    error('get_mode_phase_argmax:badShape', ...
        'M must be [Nphase x Nfreq] or [Nfreq x Nphase] (got %dx%d, Nphase=%d, Nfreq=%d).', ...
        size(M,1), size(M,2), Np, Nf);
end

freq_idx = knnsearch(freq_bins(:), mode_freqs(:));
col      = M(:, freq_idx);          % [Nphase x Nmodes]
[mag, k] = max(col, [], 1);
phase    = phase_bins(k(:));
phase    = phase(:);
mag      = mag(:);
end
