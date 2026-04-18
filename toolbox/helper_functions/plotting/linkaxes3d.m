%LINKAXES3D Links 3D camera positions and xyz limits across multiple axes
%
%   Usage:
%   linkaxes3d(axs)
%
%   Input:
%   axs: should be set of 3D axes
%
%   Example:
%     axs(1)=subplot(121);
%     surf(peaks(500),'edgecolor','none');
% 
%     axs(2)=subplot(122);
%     surf(-peaks(500),'edgecolor','none');
%
%     %Link the axes
%     linkaxes3d(axs);
%
%   See also surfaceplot, surfaceplot_input, timesurfaceplot
%
function linkaxes3d(axs)
% Make hlink global to persist the linkage
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
global hlink; %#ok<GVMIS> 

% Link the 3d limits and camera position of the specified axes
hlink =  linkprop(axs,{'CameraPosition','CameraUpVector'});
linkaxes(axs,'xyz');
