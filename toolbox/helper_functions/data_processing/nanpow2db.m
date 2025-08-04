function ydB = nanpow2db(y)
%NANPOW2DB   Power to dB conversion, setting all bad values to nan
%   YDB = POW2DB(Y) convert the data Y into its corresponding dB value YDB
%
%   % Example:
%   %   Calculate ratio of 2000W to 2W in decibels
%
%   y1 = pow2db(2000/2)     % Answer in db

%   Copyright 2006-2014 The MathWorks, Inc.
% EDITED BY MJP 2/7/2020

%ydB = 10*log10(y);
%ydB = db(y,'power');
% We want to guarantee that the result is an integer
% if y is a negative power of 10.  To do so, we force
% some rounding of precision by adding 300-300.

ydB = (10.*log10(y)+300)-300;
ydB(y(:)<=0) = nan;


% [EOF]