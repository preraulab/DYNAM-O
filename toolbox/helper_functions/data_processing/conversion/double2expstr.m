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