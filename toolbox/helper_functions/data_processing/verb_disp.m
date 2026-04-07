function tic_h = verb_disp(verbose, message)
%VERB_DISP  Conditionally display a message and optionally start a timer
%
%   Usage:
%       verb_disp(verbose, message)
%       tic_h = verb_disp(verbose, message)
%
%   Input:
%       verbose: logical - if true, display the message -- required
%       message: char or string - message to display -- required
%
%   Output:
%       tic_h: timer handle (optional) - timer started with tic() if output is requested
%
%   Example:
%       verb_disp(true, 'Processing data...');
%       tic_h = verb_disp(true, 'Starting timer...');
%
%   Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%% ********************************************************************
    if verbose
        disp(message)
    end
    if nargout > 0
        tic_h = tic;
    end
end