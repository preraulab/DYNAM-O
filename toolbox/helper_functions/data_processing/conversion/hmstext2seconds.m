% HMSTEXT2SECONDS converts time in HH:MM:SS format to seconds.
%
% Syntax:
%   [seconds, hh, mm, ss] = hmstext2seconds(hmstext)
%
% Description:
%   HMSTEXT2SECONDS takes time values in HH:MM:SS format as input and
%   converts them to the corresponding time in seconds. It returns the
%   total seconds, as well as separate arrays for hours, minutes, and
%   seconds.
%
% Input Arguments:
%   - hmstext: Cell array of strings containing time values in HH:MM:SS
%     format.
%
% Output Arguments:
%   - seconds: Array of total seconds for each time value in hmstext.
%   - hh: Array of hours for each time value in hmstext.
%   - mm: Array of minutes for each time value in hmstext.
%   - ss: Array of seconds for each time value in hmstext.
%
% Examples:
%   % Convert time values to seconds
%   hmstext = {'12:34:56', '01:02:03', '00:00:45'};
%   [seconds, hh, mm, ss] = hmstext2seconds(hmstext)
%
%
% See also:
%   strfind, str2double, cumsum, mod
% 
function [seconds, hh, mm, ss] = hmstext2seconds(hmstext)
% Initialize arrays for hours, minutes, and seconds
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
hh = zeros(1, length(hmstext));
mm = hh;
ss = hh;

% Loop through each cell of text
for i = 1:length(hmstext)
    % Extract the hours, minutes, and seconds
    ctime = deblank(hmstext{i});
    
    tfields = strfind(ctime, ':');
    
    h = str2double(deblank(ctime(1:tfields(1) - 1)));
    hh(i) = h(~isnan(h));
    m = str2double(deblank(ctime(tfields(1) + 1:tfields(2) - 1)));
    mm(i) = m(~isnan(m));
    s = str2double(deblank(ctime(tfields(2) + 1:end)));
    ss(i) = s(~isnan(m));
end

% Compute the total time in seconds
totalsecs = ss + mm * 60 + hh * 3600;

% Convert to seconds with proper adjustment for overlapping days
seconds = [0, cumsum(mod(diff(totalsecs), 3600 * 24))];
end
