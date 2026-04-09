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
    if verbose
        disp(message)
    end
    if nargout > 0
        tic_h = tic;
    end
end