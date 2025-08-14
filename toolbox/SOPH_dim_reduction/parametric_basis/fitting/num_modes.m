function N = num_modes(fitobj)
%NUM_MODES Get the number of modes in the fitted model
%
%   N = num_modes(fitobj)
%
%   This function returns the number of modes in the fitted model object `fitobj`.
%
%   Input:
%       fitobj: Fitted model object - The model to determine the number of modes
%
%   Output:
%       N: Numeric scalar - Number of modes in the model
%
%   The function counts the number of amplitude coefficients in the model, which
%   corresponds to the number of modes.
%
%   Example:
%       % Create a fitted model object `fitobj`
%       fitobj = ...; % Your fitted model object
%
%       % Get the number of modes in the model
%       num_modes = num_modes(fitobj);
%
%   See also: COEFFNAMES
%
%   Copyright 2023 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

inds = cell2mat(strfind(coeffnames(fitobj),'amp'));
if isempty(inds)
    N = 0;
else
    N = sum(inds);
end
