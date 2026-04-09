function z = normalized_vmGauss(X, Y, unit_row, xxx, yyy, zzz, varargin)
%NORMALIZED_VMGAUSS  Evaluate a sum of von Mises Gaussians with optional row-wise normalization
%
%   Usage:
%       z = normalized_vmGauss(X, Y, unit_row, xxx, yyy, zzz, amp1, fmean1, fstd1, phasepref1, recikappa1, theta1, ...)
%
%   Inputs:
%       X:        2D matrix - X-coordinates (phase axis) of the data grid -- required
%       Y:        2D matrix - Y-coordinates (frequency axis) of the data grid -- required
%       unit_row: logical - if true, normalize each row so that values sum to 1 -- required
%       xxx:      double - amplitude of the sinusoidal baseline along X -- required
%       yyy:      double - phase shift of the sinusoidal baseline -- required
%       zzz:      double - constant offset of the baseline -- required
%       varargin: parameter groups of 6 values per mode: [amp, fmean, fstd, phasepref, recikappa, theta]
%                 Each group defines one von Mises Gaussian peak via vmGauss().
%
%   Output:
%       z:        2D matrix - summed (and optionally row-normalized) model surface
%
%   Notes:
%       The number of varargin entries must be divisible by 6 (6 parameters per mode).
%
%   See also: vmGauss
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
%   ATTRIBUTION
%   If you use this toolbox, please cite:
%
%   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
assert(mod(length(varargin), 6) == 0, 'Number of varargin cannot be divided by 6. Cannot convert to vmGauss peaks.')
N_peaks = length(varargin) / 6;

z = xxx*sin(X + yyy) + zzz;

for ii = 1:N_peaks
    amp =       varargin{(ii-1) * 6 + 1};
    fmean =     varargin{(ii-1) * 6 + 2};
    fstd =      varargin{(ii-1) * 6 + 3};
    phasepref = varargin{(ii-1) * 6 + 4};
    recikappa = varargin{(ii-1) * 6 + 5};
    theta =     varargin{(ii-1) * 6 + 6};

    % vmGauss(X,Y, amp, ymean, ystd, xmean, xstd, theta)
    z = z + vmGauss(X, Y, amp, fmean, fstd, phasepref, recikappa, theta);
end

% Normalize across unique values of Y
if unit_row
    uniqueY = unique(Y);
    for jj = 1:length(uniqueY)
        sel_idx = Y == uniqueY(jj);
        z(sel_idx) = z(sel_idx) / sum(z(sel_idx));
    end
end
