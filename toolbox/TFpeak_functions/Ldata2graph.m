function [rgn, rgn_lbls, Lborders, adj_list] = Ldata2graph(Ldata, exclusion_val, f_disp, ax)
% LDATA2GRAPH label region border pixels and determine region adjacencies.
%
% Usage:
%    [rgn, rgn_lbls, Lborders, adj_list] = Ldata2graph(Ldata, exclusion_val, f_disp, ax)
%
% INPUTS:
%   Ldata  -- 2D matrix of labeled image data. Assumes boundaries are
%             labeled 0 as for the output of watershed.
%             defaults to abs(peaks(50))+randn(50)*.01.
%   exclusion_val -- value of
%   f_disp -- flag indicator whether to plot.
%             defaults to false, unless using default Ldata.
% OUTPUTS:
%   rgn         -- 1D cell array of vector lists of linear idx of all pixels for each region.
%   rgn_lbls    -- vector of region labels.
%   Lborders    -- 1D cell array of vector lists of linear idx of border pixels for each region.
%   adj_list       -- two-column matrix of region adjacencies.
%                  each row contains region lables of two adjacent regions.
%
%   Copyright 2024 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%      
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach, 
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis 
%       for Electroencephalographic Phenotyping and Biomarker Identification, 
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%
%**********************************************************************

%*************************
% Handle variable inputs *
%*************************
if nargin < 4
    ax = [];
end
if nargin < 3
    f_disp = [];
end
if nargin < 2
    exclusion_val = [];
end
if nargin < 1
    Ldata = [];
end

%************************
% Set default arguments *
%************************
if isempty(f_disp)
    f_disp = 0;
end
if isempty(Ldata)
    error('Ldata must be specified')
end
if f_disp > 0 && isempty(ax)
    fh = figure;
    ax = axes(fh);
    imagesc(ax,Ldata);
    axis(ax,'xy');
    axis(ax,'tight');
end

%***********************
% Initialize variables *
%***********************
% Data image size
[num_rows,num_cols] = size(Ldata);

% Determine region labels
Ldata = double(Ldata);

% Convolution matrix to get border
H_border = [1 1 1; 1 -8 1; 1 1 1];

% Convolution matrix for dilation to get neighbors. Same as strel3.Neighborhood
H_dilate = [1   1   1   1   1; ...
    1   1   1   1   1; ...
    1   1   1   1   1; ...
    1   1   1   1   1; ...
    1   1   1   1   1];

%*******************************************************************
% For each region, determine border pixels and neighboring regions *
%*******************************************************************
region_props = regionprops(Ldata,'PixelIdxList','Area');

% If exclusion_val, remove empty regions
if ~isempty(exclusion_val)
    good_regions = cat(1,region_props.Area) > 0;
    % Last region contains all excluded regions, so ignore
    good_regions(end) = 0;
    region_props = region_props(good_regions);
end

% Get region label of first pixel in each region
rgn_lbls = Ldata(cellfun(@(x)x(1),{region_props.PixelIdxList}));

num_rgns = length(rgn_lbls);

% Create a cell for the number of regions
rgn = cell(1,num_rgns);
Lborders = cell(1,num_rgns);
nbr_matrs = cell(1,num_rgns);

for ii = 1:num_rgns
    curr_rgn_lbl = rgn_lbls(ii);

    % Get linear indices of current region pixels
    % curr_rgn_img = (Ldata == curr_rgn_lbl);
    % rgn{ii} = find(curr_rgn_img);
    rgn{ii} = region_props(ii).PixelIdxList;

    % Convert to row and column coordinates of region pixels
    [i_full,j_full] = ind2sub([num_rows,num_cols],rgn{ii});

    %**********************************************
    % Convert to subimage for faster computations *
    %**********************************************
    % Size of padding around current region
    im_buffer = 3;

    % Get the bounds of the selected pixels
    i_min = max(min(i_full)-im_buffer,1);
    i_max = min(max(i_full)+im_buffer,num_rows);

    j_min = max(min(j_full)-im_buffer,1);
    j_max = min(max(j_full)+im_buffer,num_cols);

    % Extract the sub_image
    % sub_img = curr_rgn_img(i_min:i_max,j_min:j_max);
    sub_Ldata = Ldata(i_min:i_max,j_min:j_max);
    sub_img = sub_Ldata==curr_rgn_lbl;

    %**********************************
    % Determine current border pixels *
    %**********************************
    % Filter the subimage to get border
    sub_border = find(conv2(double(sub_img),H_border,'same')>0);

    % Convert linear indices of border to coords in subimage
    [i_sub,j_sub] = ind2sub(size(sub_img),sub_border);

    % Convert from sub_image coords to back to the original coords
    i_full = i_sub+i_min-1;
    j_full = j_sub+j_min-1;

    % Convert to linear indicies
    Lborders{ii} = sub2ind([num_rows num_cols],i_full,j_full);

    %******************************
    % Determine current neighbors *
    %******************************
    % Filter the subimage to dilate the region by two pixels.
    % Actually need strel3 to grow by 2.
    msk3 = conv2(double(sub_img),H_dilate,'same')>0;

    % Remove orginal region and borders from dilation
    msk3(sub_img | sub_Ldata == 0) = false;

    % Retrieve the list of neighbors
    nbr_rgns = unique(sub_Ldata(msk3));
    nbr_rgns = setdiff(nbr_rgns, [0, exclusion_val]);

    % Form submatrix of current neighbors list
    nbr_matrs{ii} = [curr_rgn_lbl*ones(length(nbr_rgns),1), nbr_rgns];

end

%****************************************************
% Form adjacency matrix by appending neighbor lists *
%****************************************************
adj_list = [];
if num_rgns>1
    %Create 2xN adjacency matrix
    adj_list = cat(1,nbr_matrs{:});

    %Reduce to non-digraph
    adj_list = unique(sort(adj_list,2),'rows');
    %Amatr = unique(Amatr,'rows'); %keep as digraph
end

%****************************************
% Include border pixels in region lists *
%****************************************
for ii = 1:num_rgns
    rgn{ii} = unique([rgn{ii}; Lborders{ii}]);
end

%*******************************************
% Show image. Sequentially display borders *
%*******************************************
if f_disp > 0
    hold on;
    for ii = 1:length(Lborders)
        [tmp_row, tmp_col] = ind2sub([num_rows num_cols],Lborders{ii});
        p = plot(ax,tmp_col,tmp_row,'wo','markerfacecolor','w','markersize',3);
        title(ax,['Border for Region ' num2str(rgn_lbls(ii))]);
        pause(1);
        delete(p);
    end
end
