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
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://harvard.edu
%   GITHUB     https://github.com
%
%   CITATION
%   If you use this toolbox, please cite:
%
%   He, M., Prerau, M. J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%    in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%    for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================

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
