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
% Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

function [seconds, hh, mm, ss] = hmstext2seconds(hmstext)
% Initialize arrays for hours, minutes, and seconds
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
