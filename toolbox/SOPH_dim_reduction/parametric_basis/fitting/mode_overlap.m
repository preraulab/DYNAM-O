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

overlap = zeros(length(goodpeaks));
%Get all pairwise overlap
for p = 1:length(goodpeaks)
    for q = p+1:length(goodpeaks)
        p1 = select_modes(powfit, goodpeaks(p), SOpow_bins, freq_bins);
        p2 = select_modes(powfit, goodpeaks(q), SOpow_bins, freq_bins);

        overlap(p,q) = sum(min(p1,p2),'all')/(sum(max(p1,p2),'all'));
    end
end
