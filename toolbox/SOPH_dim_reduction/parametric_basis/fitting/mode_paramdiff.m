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
%   Copyright 2023 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

cvals = coeffvalues(fitobj);
param_vals = cvals(get_param_inds(fitobj, param_name));
param_diff = triu(dist(param_vals)) + tril(nan(length(param_vals)));

function out = dist(vals)
out = sqrt((vals-vals').^2);