function  param_diff = mode_paramdiff(fitobj, param_name)
%MODE_PARAMDIFF Compute the pairwise differences between coefficients for a specific parameter
%
%   param_diff = mode_paramdiff(fitobj, param_name)
%
%   This function calculates the pairwise differences between coefficients of a
%   specific parameter named `param_name` in the fitted model `fitobj`.
%
%   Input:
%       fitobj: Fitted model object - The model containing the coefficients
%       param_name: String - Name of the parameter for which differences are computed
%
%   Output:
%       param_diff: Numeric matrix - Pairwise differences between coefficients
%
%   The function first extracts the coefficients associated with the specified
%   parameter from the model and then computes the differences between them.
%   The resulting `param_diff` matrix contains the absolute differences between
%   each pair of coefficients.
%
%   Example:
%       % Create a fitted model object `fitobj`
%       fitobj = ...; % Your fitted model object
%       
%       % Specify the parameter name
%       param_name = 'amplitude';
%       
%       % Compute the pairwise differences between amplitude coefficients
%       param_diff = mode_paramdiff(fitobj, param_name);
%
%   See also: COEFFVALUES, GET_PARAM_INDS
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
param_vals = cvals(get_param_inds(fitobj, param_name));
param_diff = triu(dist(param_vals)) + tril(nan(length(param_vals)));

function out = dist(vals)
out = sqrt((vals-vals').^2);