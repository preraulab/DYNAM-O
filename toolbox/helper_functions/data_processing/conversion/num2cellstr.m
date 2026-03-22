function out = num2cellstr(s)
% NUM2CELLSTR converts a numeric array into a cell array of strings.
%
% Syntax:
%   out = num2cellstr(s)
%
% Description:
%   NUM2CELLSTR takes a numeric array as input and converts it into a cell
%   array of strings, where each element of the array is converted into a
%   separate string. The resulting cell array has the same size as the
%   input array.
%
% Input Arguments:
%   - s: Numeric array to be converted into a cell array of strings.
%
% Output Arguments:
%   - out: Cell array of strings, where each element corresponds to a
%     converted string representation of the input array elements.
%
% Examples:
%   % Convert a numeric array into a cell array of strings
%   s = [1, 2, 3; 4, 5, 6];
%   out = num2cellstr(s)
%
%   % Convert a single value into a cell array of strings
%   s = 42;
%   out = num2cellstr(s)
%
% See also:
%   strtrim, cellstr, num2str
% 
% Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

% Convert the numeric array into a cell array of strings
out = reshape(strtrim(cellstr(num2str(s(:)))'), size(s));
end
