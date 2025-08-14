function N = num_mode_params(fitobj)
%NUM_MODE_PARAMS Get the number of parameters per mode in the fitted model
%
%   N = num_modes(fitobj)
%
%   This function returns the number of parameters per mode in the fitted model object `fitobj`.
%
%   Input:
%       fitobj: Fitted model object - The model to determine the number of modes
%
%   Output:
%       N: Numeric scalar - Number of parameters per mode
%
%
%   Example:
%       % Create a fitted model object `fitobj`
%       fitobj = ...; % Your fitted model object
%       
%       % Get the number of modes in the model
%       num_mode_params = num_modes(fitobj);
%
%   See also: COEFFNAMES
%
%   Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

N = sum(endsWith(coeffnames(fitobj),'_1'));