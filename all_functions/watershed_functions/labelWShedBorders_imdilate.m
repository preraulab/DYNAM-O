function [rgn, rgn_lbls, borders, Amatr] = labelWShedBorders_imdilate(Ldata,exclusion_val,f_disp,ax) 
%lableWShedBorders_imdilate determines the pixel linear indices of each region of a labeled image, 
% the pixel linear indices for the borders of each region, and the adjacencies of each region.
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
%   amatr       -- two-column matrix of region adjacencies.
%                  each row contains region lables of two adjacent regions.  
%
%   Copyright 2022 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%      
%   Authors: Patrick Stokes
%
% Created on: 20171016 -- forked from version in wshed1
% Modified: 20190422 -- made faster by using regionprops to get pixelIdxList
%           20190214 -- cleaned up for toolbox
%           20171016 -- changed to return rgn 
%

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
    N = 50;
    I = abs(peaks(N))+randn(N)*.01;
    Ldata = watershed(-I);
    f_disp = 1;
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
%rgn_lbls = unique(Ldata);
%rgn_lbls = setdiff(rgn_lbls,0); 
%rgn_lbls = setdiff(rgn_lbls,[0, exclusion_val]); %

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
borders = cell(1,num_rgns);
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
    borders{ii} = sub2ind([num_rows num_cols],i_full,j_full);
    
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
Amatr = [];
if num_rgns>1
    for ii = 1:length(nbr_matrs)
        Amatr = [Amatr; nbr_matrs{ii}];
    end
    Amatr = unique(Amatr,'rows');
end

%****************************************
% Include border pixels in region lists *
%****************************************
for ii = 1:num_rgns
    rgn{ii} = unique([rgn{ii}; borders{ii}]); 
end

%*******************************************
% Show image. Sequentially display borders *
%*******************************************
if f_disp > 0
    hold on;
    for ii = 1:length(borders)
        [tmp_row, tmp_col] = ind2sub([num_rows num_cols],borders{ii});
        p = plot(ax,tmp_col,tmp_row,'wo','markerfacecolor','w','markersize',3);
        title(ax,['Border for Region ' num2str(rgn_lbls(ii))]);
        pause(1);
        delete(p);
    end
end
