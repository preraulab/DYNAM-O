function frac_str = double2fracstr(val, tol)
%DOUBLE2FRACSTR  Convert a double to a string representation in terms of a fraction
%
%   Usage:
%       frac_str = double2fracstr(val, tol)
%
%   Input:
%       val: double - the value to convert to a fraction string -- required
%       tol: double - tolerance for determining closeness to a simple fraction (default: 1e-10)
%
%   Output:
%       frac_str: char - the string representation of the input value as a fraction,
%                 or [] if no simple fraction approximation is found
%
%   Example:
%       val1 = 2/3;
%       frac_str = double2fracstr(val1);   % Returns '2/3'
%
%       val2 = 4/5;
%       frac_str = double2fracstr(val2);   % Returns '4/5'
%
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
%   GITHUB     https://github.com
%
%   ATTRIBUTION
%   If you use this toolbox, please cite:
%
%   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
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
