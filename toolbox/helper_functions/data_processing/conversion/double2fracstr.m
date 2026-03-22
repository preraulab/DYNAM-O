%%
%DOUBLE2FRACSTR Convert a double to a string representation in terms of a fraction
%
%   Usage:
%       frac_str = double2frac2str(val, tol)
%
%   Input:
%       val: double - the value to convert to a fraction string -- required
%       tol: double - the tolerance for determining the closeness to a simple fraction fraction (default: 1e-10)
%
%   Output:
%       frac_str: char - the string representation of the input value as a fraction
%
%   Example:
%   In this example, we convert a value close to pi/2 and a value that is not close to any pi fraction.
%       val1 = 2/3;
%       tol = 1e-10;
%       frac_str = double2frac2str(val1, tol);
%
%       val2 = 4/5;
%       frac_str = double2frac2str(val2);
%
%    Copyright 2023 Prerau Laboratory - sleepEEG.org
%% ********************************************************************

function frac_str = double2fracstr(val, tol)
if nargin < 2
    tol = 1e-10;
end

[n,d] = rat(val,tol);

if n<100 && d<100
    if d==1
        frac_str = num2str(n);
    else
        frac_str = [num2str(n) '/' num2str(d)];
    end
else
   frac_str = [];
end
