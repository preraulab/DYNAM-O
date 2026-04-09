function [xmeans, ymeans] = mode_means(fitobj, xparam, yparam)
%MODE_MEANS  Extract the mean parameter values for each mode from a fitted model
%
%   Usage:
%       [xmeans, ymeans] = mode_means(fitobj, xparam, yparam)
%
%   Input:
%       fitobj: sfit object - fitted model containing mode coefficients -- required
%       xparam: char - coefficient name prefix for x-axis means (e.g., 'pmean') -- required
%       yparam: char - coefficient name prefix for y-axis means (e.g., 'fmean') -- required
%
%   Output:
%       xmeans: [1xN] double - x-axis mean values for each mode
%       ymeans: [1xN] double - y-axis mean values for each mode
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
cvals = coeffvalues(fitobj);
xmeans = cvals(cellfun(@(x)~isempty(x),strfind(coeffnames(fitobj),xparam)));
ymeans = cvals(cellfun(@(x)~isempty(x),strfind(coeffnames(fitobj),yparam)));
