function overlap = mode_overlap(powfit, goodpeaks, SOpow_bins, freq_bins)
%MODE_OVERLAP  Computes the pairwise proportional volume overlap between modes.
%
%   Usage:
%       overlap = mode_overlap(powfit, goodpeaks, SOpow_bins, freq_bins)
%
%   Required Inputs:
%       powfit      - cfit   - fitted parametric model object from fit_rotGauss or fit_vmGauss
%       goodpeaks   - vector - indices of modes to compare
%       SOpow_bins  - vector - SO-power or SO-phase bin centers
%       freq_bins   - vector - frequency bin centers (Hz)
%
%   Outputs:
%       overlap     - [NxN] double - upper-triangular matrix of pairwise
%                     overlap fractions; overlap(p,q) = sum(min(p1,p2)) /
%                     sum(max(p1,p2)) for modes p and q

N = length(goodpeaks);
overlap = zeros(N);

% Pre-compute each mode surface once, then use cached results for all pairs
surfaces = cell(N, 1);
for p = 1:N
    surfaces{p} = select_modes(powfit, goodpeaks(p), SOpow_bins, freq_bins);
end

for p = 1:N
    for q = p+1:N
        p1 = surfaces{p};
        p2 = surfaces{q};
        overlap(p,q) = sum(min(p1,p2),'all') / sum(max(p1,p2),'all');
    end
end
