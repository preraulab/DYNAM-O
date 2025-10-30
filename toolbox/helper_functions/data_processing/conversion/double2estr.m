%DOUBLE2ESTR Convert a double to a string representation in terms of a fraction times an exponential
%
%   Usage:
%       e_str = double2estr(val, tol)
%
%   Input:
%       val: double - the value to convert to a string representation -- required
%       tol: double - the tolerance for determining the closeness to a simple fraction (default: 1e-10)
%
%   Output:
%       e_str: char - the string representation of the input value as a fraction times an exponential
%
%   Example:
%   In this example, we convert a value close to e and a value that is not close to any simple fraction of e.
%       val1 = 2/4*exp(5); % Value close to e
%       tol = 1e-10;
%       e_str = double2estr(val1, tol);
%
%       val2 = 4.7; % Value not close to any simple fraction of e
%       e_str = double2estr(val2); % Should return ''
%
%   Copyright 2024 Prerau Laboratory - sleepEEG.org
%% ********************************************************************

function e_str = double2estr(val, tol)
if nargin < 2
    tol = 1e-10;
end

best_approximation = Inf;
best_a = NaN;
best_b = NaN;


% Iterate through values of b from 2 to 20
for b = 1:20
    % Calculate a
    a = val / exp(b);

    [n,d] = rat(a,tol);

    if n<10 && d<10 && n>0 && d>0
        % Calculate the approximation
        approximation = a * exp(b);

        if isempty(double2fracstr(a))
            continue;
        end

        % Check if this approximation is better than the current best
        if abs(val - approximation) < abs(val - best_approximation) && abs(val-approximation)<tol
            best_approximation = approximation;
            best_a = a;
            best_b = b;
        end
    end
end
if isnan(best_a) || isnan(best_b)
    e_str = '';
else
    if best_a == 1
        e_str =  ['exp(', num2str(best_b), ')'];
    else
        [n,d] = rat(best_a,tol);
        if d == 1
            e_str =  [num2str(n) ' * exp(', num2str(best_b), ')'];
        else
            e_str =  [num2str(n) '/' num2str(d) ' * exp(', num2str(best_b), ')'];
        end
    end
end

