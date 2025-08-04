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
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

% Define the regular expression pattern
pattern = '^p(0*[0-9]|[1-9][0-9]|100)shift[1-5]+$';

% Check if the input string matches the pattern
isValid = ~isempty(regexp(str, pattern, 'once'));
end
