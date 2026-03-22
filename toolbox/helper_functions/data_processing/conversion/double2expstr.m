function result = double2expstr(value)
%EXP_RATIONAL_STRING  Convert a value to a string in terms of exp() and a simple rational fraction
%
%   Usage:
%       result = exp_rational_string(value)
%
%   Input:
%       value: double - the numerical value to be converted -- required
%
%   Output:
%       result: char array - the resulting string representation
%
%   Example:
%       value = 81.897225049716354;
%       result = exp_rational_string(value); % Returns '3/2*exp(4)'
%
%   See also:
%       exp, rat
%
%   Copyright 2024 Your Name. All rights reserved.

% Decompose the value into a factor and an exponential part
tol = 1e-5;

log_val = log(value);
exponent = round(log_val);

factor = value / exp(exponent);

if ~isempty(double2fracstr(factor))

    % Use the rat function to get the simple rational fraction
    [num, den] = rat(factor);

    % Form the result string
    if num == 1 && den == 1
        result = sprintf('exp(%d)', exponent);
    elseif den == 1
        result = sprintf('%d*exp(%d)', num, exponent);
    else
        result = sprintf('%d/%d*exp(%d)', num, den, exponent);
    end
else
    result = '';
end
end