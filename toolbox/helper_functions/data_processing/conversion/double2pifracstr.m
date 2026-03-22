%%
%DOUBLE2PIFRACSTR Convert a double to a string representation in terms of pi fractions
%
%   Usage:
%       pi_str = double2pifracstr(val, tol)
%
%   Input:
%       val: double - the value to convert to a pi fraction string -- required
%       tol: double - the tolerance for determining the closeness to a pi fraction (default: 1e-4)
%
%   Output:
%       pi_str: char - the string representation of the input value as a fraction of pi or the value itself if not close to a pi fraction
%
%   Example:
%   In this example, we convert a value close to pi/2 and a value that is not close to any pi fraction.
%       val1 = pi/2;
%       tol = 1e-4;
%       pi_str1 = double2pifracstr(val1, tol);
%       % pi_str1 should be 'pi/2'
%
%       val2 = 3;
%       pi_str2 = double2pifracstr(val2);
%       % pi_str2 should be '3'
%
%    Copyright 2023 Prerau Laboratory - sleepEEG.org
%% ********************************************************************

function pi_str = double2pifracstr(val, tol)
if nargin < 2
    tol = 1e-10;
end

[n,d] = rat(val/pi,tol);

if n<100 && d<100

    if n == -1
        pi_str = '-pi';
    elseif n == 1
        pi_str = 'pi';
    else
        pi_str = [num2str(n) '*pi'];
    end

    if d>1
        pi_str = [pi_str '/' num2str(d)];
    end
else
   pi_str = [];
end
