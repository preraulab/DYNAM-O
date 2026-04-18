
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
function z = lineNoise(X,Y, amp0, amp1, fmean, fstd, order)
%LINENOISE - Generate synthetic line noise for given data
%
%   z = lineNoise(X, Y, amp0, amp1, fmean, fstd, order)
%
%   This function generates synthetic line noise based on the provided parameters.
%
%   Input:
%       X: 2D matrix - X-coordinates of the data grid
%       Y: 2D matrix - Y-coordinates of the data grid
%       amp0: double - Intercept of the linear trend in amplitude as a function of X
%       amp1: double - Slope of the linear trend in amplitude as a function of X
%       fmean: double - Mean frequency of the line noise
%       fstd: double - Standard deviation of the line noise
%       order: integer - Order of the exponential term (default: 32)
%
%   Output:
%       z: 2D matrix - The generated line noise
%
%   Equation:
%       The line noise is computed using the following equation:
%           z = (amp0 + amp1 * X) .* exp(-((Y - fmean) / (fstd .^ 2)) .^ order);
%
%       where:
%       - amp0: Intercept of the linear trend in amplitude as a function of X
%       - amp1: Slope of the linear trend in amplitude as a function of X
%       - fmean: Mean frequency of the line noise
%       - fstd: Standard deviation of the frequency distribution
%       - order: Order of the exponential term
%
%   Example:
%       % Example usage of the lineNoise function
%       [X, Y] = meshgrid(0:0.1:20, 2:0.1:18);
%       amp0 = 0.5;
%       amp1 = -0.2;
%       fmean = 12.0;
%       fstd = 0.3;
%       order = 32;
%       z = lineNoise(X, Y, amp0, amp1, fmean, fstd, order);
%
if nargin<7
    order = 32;
end

z = (amp0+amp1*X).*exp(-((Y-fmean)/(fstd.^2)).^order);