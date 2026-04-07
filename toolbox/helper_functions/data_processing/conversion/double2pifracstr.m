function pi_str = double2pifracstr(val, tol)
%DOUBLE2PIFRACSTR  Convert a double to a string representation in terms of pi fractions
%
%   Usage:
%       pi_str = double2pifracstr(val, tol)
%
%   Input:
%       val: double - the value to convert to a pi fraction string -- required
%       tol: double - tolerance for determining closeness to a pi fraction (default: 1e-10)
%
%   Output:
%       pi_str: char - the string representation of the input value as a fraction of pi,
%               or the numeric string itself if not close to any simple pi fraction
%
%   Example:
%       val1 = pi/2;
%       pi_str1 = double2pifracstr(val1);   % Returns 'pi/2'
%
%       val2 = 3;
%       pi_str2 = double2pifracstr(val2);   % Returns '3'
%
%   Copyright 2023 Prerau Laboratory - sleepEEG.org
%% ********************************************************************
if nargin < 2
    tol = 1e-10;
end

[n,d] = rat(val/pi,tol);

if n<100 && d<100

    if n == -1
        pi_str = '-pi';
    elseif n == 1
        pi_str = 'pi';
    elseif n == 0
        pi_str = '0';
    elseif d == 1
        pi_str = [num2str(n) '*pi'];
    else
        pi_str = ['(' num2str(n) '*pi)/' num2str(d)];
    end
else
    pi_str = num2str(val);
end
