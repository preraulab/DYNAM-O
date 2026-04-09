function isValid = isShiftstr(str)
% ISSHIFTSTRING- Check if a string follows a specific format for shift strings.
%
%   isValid = is_valid_shiftstring(str) checks whether the input string 'str'
%   follows the specified format for a shift string. The format is defined as
%   'pNshiftX', where N is a number between 0 and 100 with optional leading zeros,
%   and X is a sequence of digits from 1 to 5. The function returns 'true' if the
%   string matches the format, and 'false' otherwise.
%
%   Inputs:
%   str - The input string to be checked for validity.
%
%   Output:
%   isValid - A logical value indicating whether the input string follows the
%             specified format (true) or not (false).
%
%   Example:
%   isValid = is_valid_shiftstring('p23shift12345');
%   % Returns: isValid = true
%
%   Note:
%   The regular expression pattern used to validate the string is '^p(0*[0-9]|[1-9][0-9]|100)shift[1-5]+$'.
%
%
% Define the regular expression pattern
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
pattern = '^p(0*[0-9]|[1-9][0-9]|100)shift[1-5]+$';

% Check if the input string matches the pattern
isValid = ~isempty(regexp(str, pattern, 'once'));
end
