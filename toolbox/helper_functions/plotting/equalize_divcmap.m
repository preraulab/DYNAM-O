function cmap_new = equalize_divcmap(cmap,min_L, N, plot_on)
%% EQUALIZE_DIVCMAP Equalizes CIELAB lightness for divergent colormaps
%
%   Usage:
%   cmap_new = equalize_divcmap(cmap, min_L, N, plot_on)
%
%   Input:
%   cmap: N x 3 divergent colormap
%   min_L: minimum lux on either end (default:30)
%   N: Number of points in colormap (final N will be odd to keep max value)
%   plot_on: plot output (default: false)
%
%   Output:
%   cmap_new: Nx3 equalized colormap
%
%   Example:
%
%     equalize_divcmap; %Run demo
%
%   Copyright 2024 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%
%********************************************************************
if nargin == 0
    cmap = redbluedark;
    equalize_divcmap(cmap,30,500,true);
    return;
end

if nargin<2
    min_L = .3;
end

if nargin<3
    N = size(cmap,1);
end

if nargin<4
    plot_on = false;
end

%Compute L
L = getL(cmap);
assert(~issorted(L,'monotonic'),'Must be divergent colormap');

%Find max lux
[~,imax] = max(L);

%Find edges of lux
istart = find(L>= min_L,1,'first');
iend = find(L>=min_L,1,'last');

%Interpolate ramp up
Rup = interp1(istart:imax,cmap(istart:imax,1),linspace(istart,imax,floor(N/2)))';
Gup = interp1(istart:imax,cmap(istart:imax,2),linspace(istart,imax,floor(N/2)))';
Bup = interp1(istart:imax,cmap(istart:imax,3),linspace(istart,imax,floor(N/2)))';

%Interplot ramp dow
Rdown = interp1(imax:iend,cmap(imax:iend,1),linspace(imax,iend,floor(N/2))');
Gdown = interp1(imax:iend,cmap(imax:iend,2),linspace(imax,iend,floor(N/2))');
Bdown = interp1(imax:iend,cmap(imax:iend,3),linspace(imax,iend,floor(N/2))');

%Make new cmap
cmap_new = [Rup(1:end-1) Gup(1:end-1) Bup(1:end-1); Rdown Gdown Bdown];

if plot_on
    a = peaks(500);
    climits = max(abs(min(a(:))), abs(max(a(:)))) * [-1 1];
    figure
    subplot(211)
    imagesc(a);
    colormap(gca,cmap);
    caxis(gca,climits);
    colorbar
    title('Original')

    subplot(212)
    imagesc(a);
    colormap(gca,cmap_new);
    caxis(gca,climits);
    colorbar
    title('Lux Equalized')

    figure
    hold all
    plot(interp1(linspace(0,1,size(cmap,1)),getL(cmap),linspace(0,1,500)));
    plot(interp1(linspace(0,1,size(cmap_new,1)),getL(cmap_new),linspace(0,1,500)));
    legend('Original','Equalized')
    ylabel('Lightness (L*a*b)')

end

function L = getL(cmap)
LAB = rgb2lab(cmap);
L = LAB(:,1);




