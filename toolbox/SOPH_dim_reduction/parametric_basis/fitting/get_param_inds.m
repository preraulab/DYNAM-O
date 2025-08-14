function inds = get_param_inds(fitobj, param_name)
%GET_PARAM_INDS Get indices of a given parameter name in the coefficient list
%
%   inds = get_param_inds(fitobj, param_name)
%
%   This function retrieves the indices of coefficients with a specified
%   parameter name `param_name` in the coefficient list of the fitted model
%   object `fitobj`.
%
%   Input:
%       fitobj: Fitted model object - The model containing the coefficients
%       param_name: String - Name of the parameter to search for
%
%   Output:
%       inds: Numeric vector - Indices of coefficients with the specified parameter name
%
%   The function uses a case-sensitive search to locate coefficients in the
%   coefficient list of `fitobj` that match the specified `param_name`. It
%   returns a vector of indices indicating the positions of these coefficients.
%
%   Example:
%       % Create a fitted model object `fitobj`
%       fitobj = ...; % Your fitted model object
%       
%       % Specify the parameter name to search for
%       param_name = 'amp';
%       
%       % Get the indices of coefficients with the specified parameter name
%       inds = get_param_inds(fitobj, param_name);
%
%   See also: COEFFNAMES
%
%   Copyright 2023 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

inds = cellfun(@(x)~isempty(x),(strfind(coeffnames(fitobj),param_name)));
