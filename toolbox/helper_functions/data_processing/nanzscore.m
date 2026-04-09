function [zscored, mu, sigma] = nanzscore(data, varargin)
%NANZSCORE  Compute z-scores ignoring NaN values
%
%   Usage:
%       [zscored, mu, sigma] = nanzscore(data, ...)
%
%   Input:
%       data: numeric array - data to z-score (NaNs are ignored) -- required
%       ...:  additional arguments passed to zscore()
%
%   Output:
%       zscored: numeric array - z-scored data (same size as data)
%       mu:      double - mean used for z-scoring (computed over non-NaN values)
%       sigma:   double - standard deviation used for z-scoring
%
%   Note:
%       Only non-NaN elements of data are used to compute the z-score.
%       The resulting zscored array is the same size as the non-NaN subset.
%
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
inds = ~isnan(data);
[zscored, mu, sigma] = zscore(data(inds),varargin{:});

% %NANZSCORE compute zscores ignoring nans
% if any(isnan(data))
%     mu = mean(data,'all','omitnan');
%     sigma = std(data,0,'all','omitnan');
%     zscored = (data-mu)./sigma;
% else
%     [zscored, mu, sigma] = zscore(data(:));
% end

end

