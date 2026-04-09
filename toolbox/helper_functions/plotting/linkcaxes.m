function linkcaxes(ax)
% LINKCAXES Links the color limits of multiple axes.
%
%   Inputs:
%   ax - Array of axis handles to be linked.
%
% GLOBAL VARIABLES:
%   hlink - Global variable that stores the linkage object.
%
% DESCRIPTION:
%   LINKCAXES links the color limits (CLim) of multiple axes specified by the input
%   argument 'ax'. The function utilizes the linkprop function from the MATLAB
%   graphics package to establish the linkage. The 'CLim' property controls the
%   mapping of data values to colors in plots. By linking the color limits of
%   multiple axes, changes in one axis will be reflected in all the linked axes.
%
%   If no input argument is provided, the function will throw an error, indicating
%   that axis handles must be provided.
%
%   The global variable 'hlink' is used to store the linkage object. This is
%   necessary because once the object is altered, the link properties will
%   disappear. By making 'hlink' global, the linkage will persist for the life of
%   the figure.
%
% EXAMPLE:
%      ax(1) = subplot(2, 1, 1);
%      imagesc(ax(1), peaks(100));
%      ax(2) = subplot(2, 1, 2);
%      imagesc(ax(2), peaks(300)*2-5);
%
%      %Link axes
%      linkcaxes(ax);
%      
%      % Alter both axes together
%      clims = [0, 10];
%      set(ax, 'CLim', clims);
%
% NOTES:
%   - This function requires the MATLAB graphics package.
%   - The 'CLim' property only applies to axes with color-related plots, such as
%     images, surface plots, or scatter plots using a color scale.
%
% See also linkprop, caxis.
%
% Check if axis handles are provided
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
if nargin == 0
    error('Must provide axis handles');
end

% Make hlink global to persist the linkage
global hlink; %#ok<GVMIS> 

% Link the color limits of the specified axes
hlink = linkprop(ax, 'CLim');
