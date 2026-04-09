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
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://harvard.edu
%   GITHUB     https://github.com
%
%   CITATION
%   If you use this toolbox, please cite:
%
%   He, M., Prerau, M. J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%    in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%    for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
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
