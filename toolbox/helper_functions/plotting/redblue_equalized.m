function map = redblue_equalized(N_raw, min_L, white_prct)
%REDBLUE_EQUALIZED Creates a red blue colormap equalized in L in  CIELAB
%
%   Usage:
%   map = redblue_equalized(N, min_L, white_prct)
%
%   Input:
%   N: number of points (default: 1024)
%   min_L: double - minimum L value to equalize edges (cannot be below 53.5)
%   white_prct: percent white in the middle (default: 0.01)
%
%   Output:
%   map: Nx3 colormap
%
%   Example:
%
%     figure
%     imagesc(peaks(500));
%     colormap(redblue_equalized);
%     caxis([-8 8]); %Must set +- caxes to be equal magnitude to center on zero
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

%Set default N
if nargin<1
    N_raw=1024;
end

if nargin<2
    min_L = 54;
end

if min_L < 53.5
    warning('Values must be bigger than 53.5 to make sure L is equal');
end

%Set default percentage of white
if nargin<3
    white_prct=.01;
end

blue_part=[linspace(1,0,N_raw)',linspace(1,0,N_raw)',ones(N_raw,1)];
red_part=[ones(N_raw,1),linspace(0,1,N_raw)',linspace(0,1,N_raw)'];

%Create the white component
if white_prct==0
    num_white=1;
else
    num_white=round((white_prct*2*N_raw)/(1-white_prct));
end
white_part=ones(num_white,3);

%Create the full colormap
map_raw=[red_part; white_part; blue_part];
Nr = size(map_raw,1);

%Interpolate to correct size
map(:,1) = interp1(linspace(0,1,Nr), map_raw(:,1), linspace(0,1,N_raw));
map(:,2) = interp1(linspace(0,1,Nr), map_raw(:,2), linspace(0,1,N_raw));
map(:,3) = interp1(linspace(0,1,Nr), map_raw(:,3), linspace(0,1,N_raw));

map = equalize_divcmap(map, min_L, Nr, false);
