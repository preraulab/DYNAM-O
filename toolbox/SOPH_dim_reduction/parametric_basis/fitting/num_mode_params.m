function N = num_mode_params(fitobj)
%NUM_MODE_PARAMS Get the number of parameters per mode in the fitted model
%
%   N = num_modes(fitobj)
%
%   This function returns the number of parameters per mode in the fitted model object `fitobj`.
%
%   Input:
%       fitobj: Fitted model object - The model to determine the number of modes
%
%   Output:
%       N: Numeric scalar - Number of parameters per mode
%
%
%   Example:
%       % Create a fitted model object `fitobj`
%       fitobj = ...; % Your fitted model object
%       
%       % Get the number of modes in the model
%       num_mode_params = num_modes(fitobj);
%
%   See also: COEFFNAMES
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
N = sum(endsWith(coeffnames(fitobj),'_1'));