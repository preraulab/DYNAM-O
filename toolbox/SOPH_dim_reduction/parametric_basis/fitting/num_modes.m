function N = num_modes(fitobj)
%NUM_MODES Get the number of modes in the fitted model
%
%   N = num_modes(fitobj)
%
%   This function returns the number of modes in the fitted model object `fitobj`.
%
%   Input:
%       fitobj: Fitted model object - The model to determine the number of modes
%
%   Output:
%       N: Numeric scalar - Number of modes in the model
%
%   The function counts the number of amplitude coefficients in the model, which
%   corresponds to the number of modes.
%
%   Example:
%       % Create a fitted model object `fitobj`
%       fitobj = ...; % Your fitted model object
%
%       % Get the number of modes in the model
%       num_modes = num_modes(fitobj);
%
%   See also: COEFFNAMES
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
inds = cell2mat(strfind(coeffnames(fitobj),'amp'));
if isempty(inds)
    N = 0;
else
    N = sum(inds);
end
