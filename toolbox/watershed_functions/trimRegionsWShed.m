function [trimmed_regions, trimmed_borders] = trimRegionsWShed(data,regions,vol_thresh,shift_val,conn,dur_min,bw_min,f_verb,verb_pref,f_disp)
%trimRegionsWShed takes data and regions from peaksWShed and regionsMergeByWeight
% and trims the regions to a certain fraction of volume.
%    
% INPUTS:
%   data       -- 2D matrix of image data. defaults to peaks(100).
%   regions    -- 1D cell array of vector lists of linear idx of all pixels for each region.
%   vol_thresh -- fraction maximum trimmed volume (from 0 to 1), 
%                 i.e. 1 means no trim. default 0.8. 
%   shift_val  -- value to be subtracted from image prior to evaulation of trim volume. 
%                 default min(min(img_data)).
%   conn       -- pixel connection to be used by trimRegionsWShed. default 8. 
%   f_verb     -- number indicating depth of output text statements of progress.
%                 0 - no output. 1 - output current function level.
%                 >1 - output at subfunction levels. defaults to 0, unless using defaul data. 
%   verb_pref  -- prefix string for verbose output. defaults to ''.
%   f_disp     -- flag indicator of whether to plot. 
%                 defaults to 0, unless using default data.
% OUTPUTS:
%   trimmed_regions -- 1D cell array of vector lists of linear idx of all pixels for each region.
%   trimmed_borders -- 1D cell array of vector lists of linear idx of border pixels for each region. 
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%      
%   Authors: Patrick Stokes
%
% Created on: 20171005 
% Modified: 20190413 -- commented
%           20190305 -- cleaned up for toolbox
%
% 
% TODO: For later optimization 
%           - do not trim regions that are already below the bandwidth and
%             duration thresholds for peak rejection. 
%           - throw out any regions that are constant/one pixel instead of
%             doing more computations on them

%*******************************
% Set variable inputs to empty *
%*******************************
if nargin < 1
    data = [];
end

if nargin < 2 
    regions = [];
end

if nargin < 3
    vol_thresh = [];
end

if nargin < 4
    shift_val = [];
end

if nargin < 5
    conn = [];
end

if nargin < 6 || isempty(dur_min)
    %Min TF-peak duration
    dur_min = 0;
end

if nargin < 7 || isempty(bw_min)
    %Min TF-peak bandwidth
    bw_min = 0;
end
if nargin < 8
    f_verb = [];
end
if nargin < 9
    verb_pref = [];
end
if nargin < 10
    f_disp = [];
end




%*************************
% Set default parameters *
%*************************
if isempty(vol_thresh)
    vol_thresh = 0.8;
end
if isempty(shift_val)
    shift_val = min(min(data));
end
if isempty(conn)
    conn = 8;
end
if isempty(f_verb)
    f_verb = 0;
end
if isempty(verb_pref)
    verb_pref = '';
end
if isempty(f_disp)
    f_disp = 0;
end

%******************************************
% Check required inputs: data and regions *
%******************************************
if isempty(data)
    if isempty(regions)
        if f_verb > 0
            disp([verb_pref 'Regions and data not provided to trimRegionsWShed. Generating simulated data...']);
        end
        data = abs(peaks(100))+randn(100)*.5;
        [regions, rgn_lbls, Lborders, amatr] = peaksWShed(data); 
        if f_verb > 0
            disp([verb_pref 'Computing regions...']);
        end
        [regions, ~] = regionMergeByWeight(data,regions,rgn_lbls,Lborders,amatr);
        f_valid_inputs = true;
    else
        f_valid_inputs = false;
        disp(['Warning: Image data for corresponding regions not provided to trimRegionsWShed.']);
    end
else
    if isempty(regions)
        if f_verb > 0
            disp([verb_pref 'Regions for image data not provided to trimRegionsWShed. Computing regions...']);
        end
        [regions, rgn_lbls, Lborders, amatr] = peaksWShed(data); 
        [regions, ~] = regionMergeByWeight(data,regions,rgn_lbls,Lborders,amatr);
        f_valid_inputs = true;

    else 
        f_valid_inputs = true;
    end
end

%***************
% Trim regions *
%***************
if f_valid_inputs
    if f_verb > 0
        disp([verb_pref 'Trimming regions...']);
    end
    if f_verb > 1
        waitbar(0);
    end
    
    % Constants and initialization
    [num_rows,num_cols] = size(data);
    num_regions = length(regions);
    trimmed_regions = regions;
    trimmed_borders = cell(num_regions,1);
    
    % Shift data for determination of volume
    shift_data = data - shift_val;
    shift_data(shift_data<0) = 0;
    
    for ii = 1:num_regions
        if ~isempty(regions{ii})
            % Get pixel list of current region and sort by height
            list_pixels = regions{ii};
            [list_vals,idx_sort] = sort(shift_data(list_pixels));
            list_pixels = list_pixels(idx_sort);
            
            %***********************************
            % Convert to subimage for trimming *
            %***********************************
            % Get row-col locations of region pixels
            [i_full,j_full] = ind2sub([num_rows,num_cols],list_pixels);
            
            % Size of padding around subimage
            im_buffer = 1;
            
            % Get bounding box of region pixels
            i_min = max(min(i_full)-im_buffer,1);
            i_max = min(max(i_full)+im_buffer,num_rows);
            j_min = max(min(j_full)-im_buffer,1);
            j_max = min(max(j_full)+im_buffer,num_cols);
            
            % Size of the subimage
            num_sub_rows = i_max-i_min+1;
            num_sub_cols = j_max-j_min+1;
            
            % Convert row-col locations to those in subimage
            i_sub = i_full-(i_min-1);
            j_sub = j_full-(j_min-1);
            
            % Get linear pixel indices in subimage
            sub_pixels = sub2ind([num_sub_rows num_sub_cols],i_sub,j_sub);
            
            %***********************
            % Find cutoff and trim *
            %***********************
            % Get total region volume and cutoff index
            total_volume = sum(list_vals);
            jj = find(cumsum(list_vals)/total_volume >= (1-vol_thresh),1);
            
            % Check for constant region, one pixel region, or impossible threshold
            if max(list_vals)~=min(list_vals) && length(list_vals)>1 && ~isempty(jj)
                
                % Find pixels above cutoff
                level = list_vals(jj);
                sub_trim = sub_pixels(list_vals>=level);
                
                % Form binary subimage
                tmp_data = zeros(num_sub_rows,num_sub_cols);
                tmp_data(sub_trim) = 1;
                
                % Fill any holes and get connected components
                tmp_data = imfill(tmp_data,'holes');
                tmp_cc = bwconncomp(tmp_data,conn);
                
                % Use largest connected component as trimmed region
                trimmed_vols = cellfun(@(x)sum(shift_data(x)),tmp_cc.PixelIdxList);
                [~,idx] = max(trimmed_vols);
                
                % Get linear pixel indices of trimmed region in subimage
                sub_trim_cc = tmp_cc.PixelIdxList{idx}; 
                
                % Convert pixel indices back to full image
                trimmed_regions{ii} = subLidx2FullLidx(sub_trim_cc,[num_sub_rows num_sub_cols],[i_min j_min],[num_rows num_cols]);
                
                % Get boundaries of trimmed region
                tmp_data = zeros(num_sub_rows,num_sub_cols);
                tmp_data(sub_trim_cc) = 1;
                tmp2 = bwboundaries(tmp_data,conn,'noholes');
                
                % Convert row-col subimage boundaries to full image
                tmp2{1}(:,1) = tmp2{1}(:,1) + i_min-1;
                tmp2{1}(:,2) = tmp2{1}(:,2) + j_min-1;
                
                % Convert row-col boundaries to linear pixel indices
                trimmed_borders{ii} = sub2ind([num_rows num_cols],tmp2{1}(:,1),tmp2{1}(:,2));
                
                if f_verb > 1
                    if mod(ii,50)==0
                        waitbar(ii/num_regions);
                    end
                end
                
            else
                % Check for constant region, one pixel region, or impossible threshold
                if f_verb > 0
                    disp([verb_pref '  Constant region encountered: ' num2str(ii)]);
                end
                region_img = zeros(size(data));
                region_img(list_pixels) = 1;
                tmp1 = regionprops(region_img,'centroid');
                tmp2 = round(cat(1,tmp1.Centroid));
                tmp3 = sub2ind(size(data),tmp2(:,2),tmp2(:,1));
                if tmp2(:,1) > 1 && tmp2(:,1) < size(data,2)
                    pad_col = [-1 0 1];
                elseif tmp2(:,1) > 1
                    pad_col = [-1 0];
                elseif tmp2(:,1) < size(data,2)
                    pad_col = [0 1];
                else
                    pad_col = 0;
                end
                if tmp2(:,2) > 1 && tmp2(:,2) < size(data,1)
                    pad_row = [-1 0 1];
                elseif tmp2(:,2) > 1
                    pad_row = [-1 0];
                elseif tmp2(:,2) < size(data,1)
                    pad_row = [0 1];
                else
                    pad_row = 0;
                end
                tmp4 = zeros(length(pad_col)*length(pad_row),1);
                for aa = 1:length(pad_col)
                    for bb = 1:length(pad_row)
                        tmp4((aa-1)*length(pad_row)+bb) = tmp3+pad_col(aa)*size(data,1)+pad_row(bb);
                    end
                end
                trimmed_regions{ii} = intersect(list_pixels,tmp4); % []; %
                trimmed_borders{ii} = setdiff(trimmed_regions{ii},tmp3); % []; %
            end
        else
            % Region is empty
            trimmed_regions{ii} = [];
            trimmed_borders{ii} = [];
        end
    end
    if f_verb > 1
        waitbar(1);
    end
    
    % Display trimmed regions
    if f_disp > 0
        tmp_Ldata = cell2Ldata(trimmed_regions,size(data),trimmed_borders);
        RGB2 = label2rgb(tmp_Ldata, 'jet', 'c', 'shuffle');
        R = squeeze(RGB2(:,:,1));
        G = squeeze(RGB2(:,:,2));
        B = squeeze(RGB2(:,:,3));
        R(~tmp_Ldata) = 100;
        G(~tmp_Ldata) = 100;
        B(~tmp_Ldata) = 100;
        RGB2 = cat(3,R,G,B);
        fh = figure('units','normalized','position',[0.7674    0.3978    0.4007    0.4811]);
        ax = axes(fh);
        imagesc(ax,RGB2);
        axis(ax,'xy');
        title(ax,['Regions Trimmed to ' num2str(vol_thresh*100) ' Percent Volume']);
    end

else
    % Image data not provided for regions
    disp('         Returning original regions and empty boundaries.');
    trimmed_regions = regions;
    trimmed_borders = cell(length(regions),1);
end

