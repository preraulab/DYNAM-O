function equalize_axes(ax, varargin)
%EQUALIZE_AXES Equalize the axes limits across multiple axes.
%   EQUALIZE_AXES(AX) equalizes the axes limits across multiple axes. The
%   function sets each axis to the tightest range and adjusts the color
%   limits if there are images present. The axes limits can be equalized
%   along the x, y, z, and/or c (color) dimensions.
%
%   EQUALIZE_AXES(AX, 'Name', Value) specifies optional name-value pairs:
%       - 'dimension': Specifies the dimensions along which the axes limits
%         should be equalized. It is a string that can contain the letters
%         'x', 'y', 'z', and 'c' (color), in any order or combination.
%         Default value is 'xyzc', meaning equalization across all
%         dimensions.
%       - 'linked': Specifies whether the axes should be linked or not. It
%         is a logical value (true or false). When set to true, the axes are
%         linked based on the specified dimensions. Default value is true.
%
%   Example:
%       % Create a figure with images and plots
%       figure
%       ax = figdesign(3, 2);
%
%       axes(ax(1))
%       imagesc(peaks(100) + 5)
%       colorbar
%
%       axes(ax(3))
%       imagesc(peaks(200) - 5)
%       colorbar
%
%       axes(ax(5))
%       imagesc(peaks(300))
%       colorbar
%
%       axes(ax(2))
%       N = 100;
%       t = 1:N;
%       plot(t, t * 3 - 4 + randn(size(t)) * 50, '.')
%
%       axes(ax(4))
%       N = 200;
%       t = 1:N;
%       plot(t, t * -3 + 6 + randn(size(t)) * 80, '.')
%
%       axes(ax(6))
%       N = 300;
%       t = 1:N;
%       plot(t, t * 4 - 12 + randn(size(t)) * 20, '.')
%
%       equalize_axes(ax([1 3 5]), 'c');
%       equalize_axes(ax([2 4 6]), 'xy');
%
% Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

if nargin == 0
    %Create a figure with images and plots
    figure
    ax = figdesign(3,2);

    axes(ax(1))
    imagesc(peaks(100)+5)
    colorbar

    axes(ax(3))
    imagesc(peaks(200)-5)
    colorbar

    axes(ax(5))
    imagesc(peaks(300))
    colorbar

    axes(ax(2))
    N = 100;
    t = 1:N;
    plot(t, t*3 - 4 + randn(size(t))*50,'.')

    axes(ax(4))
    N = 200;
    t = 1:N;
    plot(t, t*-3 + 6 + randn(size(t))*80,'.')

    axes(ax(6))
    N = 300;
    t = 1:N;
    plot(t, t*4 - 12 + randn(size(t))*20,'.')

    equalize_axes(ax([1 3 5]),'c');
    equalize_axes(ax([2 4 6]),'xy');
    return
end

assert(length(ax)>1,'Must have more than one axis to equalize across')

% Check if remaining inputs are valid
p = inputParser;
%Make sure there is at least one valid option
addOptional(p, 'dimension', 'xyzc', @(x)(any(strfind(x,'x')) || any(strfind(x,'y')) || any(strfind(x,'z')) || any(strfind(x,'c'))));
addOptional(p, 'linked', true, @(x)@islogical);

parse(p, varargin{:});
dimension = p.Results.dimension;
linked = p.Results.linked;

%Set each axis to the tightest range
for ii = 1:length(ax)
    %Set each axis tight to grab the data range
    axis(ax(ii),'tight')

    %Look for images to check for color ranges
    hIm = findall(ax(ii),'type','image');
    if ~isempty(hIm)
        assert(length(hIm) == 1,'More than one image found in axis. Use specific image handle');

        %Get color data
        data = hIm.CData(:);

        %Make sure it is not a flat image
        assert(range(data)>0,'Image data are all equal');

        %Make color axis "tight"
        ax(ii).CLim = [min(data) max(data)];
    end
end

%Get the total range across all axes and update values
if any(strfind(dimension,'x'))
    [xmin, xmax] = bounds([ax.XLim]);
    xlim(ax,[xmin xmax])
end

if any(strfind(dimension,'y'))
    [ymin, ymax] = bounds([ax.YLim]);
    ylim(ax,[ymin ymax])
end

if any(strfind(dimension,'z'))
    [zmin, zmax] = bounds([ax.ZLim]);
    zlim(ax,[zmin zmax])
end

if any(strfind(dimension,'c'))
    [cmin, cmax] = bounds([ax.CLim]);
    set(ax,'CLim',[cmin cmax])
end

%Link axes if requested
if linked
    %Get axes to be linked (e.g, 'x','xy','xyz',...)
    linkstr = sort(unique(dimension([strfind(dimension,'x') strfind(dimension,'y') strfind(dimension,'z')])));

    %Link axes
    if ~isempty(linkstr)
        linkaxes(ax,linkstr);
    end

    %Link color axes
    if any(strfind(dimension,'c'))
        % Make hlink global to persist the linkage
        global hlink; %#ok<*GVMIS,*TLEV>

        % Link the color limits of the specified axes
        hlink = linkprop(ax, 'CLim');
    end
end




