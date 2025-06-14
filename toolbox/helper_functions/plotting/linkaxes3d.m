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
%  Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

function linkaxes3d(axs)
% Make hlink global to persist the linkage
global hlink; %#ok<GVMIS> 

% Link the 3d limits and camera position of the specified axes
hlink =  linkprop(axs,{'CameraPosition','CameraUpVector'});
linkaxes(axs,'xyz');
