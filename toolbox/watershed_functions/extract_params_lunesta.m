function[feature_matrix,feature_names,chunk_nums,dx,dy,loc,xywcntrd] = extract_params_lunesta(peaks_matr,matr_fields,matr_names, pixel_values)
% i/p: peaks_matr : num_peaksx(num_featuresxnum_columns of each feature) matrix containing all peaks data
%      matr_names : 1xnum_features array containing names of each feature
%      matr_fields: 1xnum_features array containing number of columns in peaks_matr of each feature
%      pixel_values: 1xnum_peaks cell array containg pixel information of
%      each peak

% o/p: feature_matrix : 9xnum_peaks feature matrix
%    : spect_info: 2xnum_peaks containing boundary information for each
%      peak
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%      
%   Authors: Patrick Stokes, Thomas Possidente, Michael Prerau


%% area

disp('      Extracting area...');
% find the indices of area in the peaks_matr
inds_area=find_indices_variable('xy_area',matr_names,matr_fields);

% extract area vector from peaks_matr
area_p=peaks_matr(:,inds_area(1))';

%% volume
disp('      Extracting volume...');
% get dx and dy
inds_dx=find_indices_variable('dx',matr_names,matr_fields);
inds_dy=find_indices_variable('dy',matr_names,matr_fields);

% volume=pixelvalue*dx*dy
volume_p=zeros(1,size(peaks_matr,1));
if ~isempty(pixel_values)
    for i=1:size(peaks_matr,1)
        volume_p(1,i)=sum(pixel_values{i,1})*peaks_matr(i,inds_dx(1))*peaks_matr(i,inds_dy(1));
    end
end

%% bandwidth
disp('      Extracting bandwidth...');
%get xy_bndbox indices
inds_xy_bndbox=find_indices_variable('xy_bndbox',matr_names,matr_fields);

% bandwidth is the 4th column in the xy_bndbox indices
bandwidth_p=peaks_matr(:,inds_xy_bndbox(2))';

%% duration
disp('      Extracting duration...');
% duration is the 3rd column in the xy_bndbox indices
duration_p=peaks_matr(:,(inds_xy_bndbox(2)-1))';

%% peak frequency
disp('      Extracting peak frequency...');
%get xy_wcentrd indices
inds_xy_wcentrd=find_indices_variable('xy_wcentrd',matr_names,matr_fields);

% peakfrequency is the 2nd column in the xy_wcentrd indices
peak_frequency_p=peaks_matr(:,inds_xy_wcentrd(2));

peak_frequency_p=(peak_frequency_p(:))';%column vector

xywcntrd = peaks_matr(:,inds_xy_wcentrd);

%% Height
disp('      Extracting height...');
% get index of height
inds_height=find_indices_variable('height',matr_names,matr_fields);

% extract height
height_p=peaks_matr(:,inds_height(1));

height_p=(height_p(:))';%column vector

%% extract PixelList
% extract chunk_nums
% get index of chunk_num
inds_chunk_nums=find_indices_variable('chunk_num',matr_names,matr_fields);

% extract chunk_nums
chunk_nums=peaks_matr(:,inds_chunk_nums(1));

chunk_nums=(chunk_nums(:));%column vector

% extract pixellist
% [PixelList]= extract_pixellist(chunks_minmax,PixelIdxList,chunk_nums);

%% Max Power
disp('      Extracting max power...');

% maxpower_p = compute_max_power_from_pixels(PixelIdxList,...
%     sspect,chunks_minmax,chunk_nums);
% 
% maxpower_p=(maxpower_p(:))';%column vector

maxpower_p=zeros(1,length(chunk_nums));

%% NUmber of Children and Perimeter
disp('      Extracting perimeter...');
% get indices
inds_perimeter=find_indices_variable('Perimeter',matr_names,matr_fields);
inds_n_children=find_indices_variable('n_children',matr_names,matr_fields);

% extract n_children and Perimeter
n_children_p=peaks_matr(:,inds_n_children(1));
perimeter_p=peaks_matr(:,inds_perimeter(1));

n_children_p=(n_children_p(:))';%column vector
perimeter_p=(perimeter_p(:))';%column vector

%% store all variables in feature matrix
feature_matrix=[area_p;volume_p;bandwidth_p;duration_p;peak_frequency_p;height_p;maxpower_p;perimeter_p]';
feature_names={'Area','Volume','Bandwidth','Duration','Peak Frequency','Height','Max Power','Perimeter'};

%% extract x and y
% get dx and dy
inds_dx=find_indices_variable('dx',matr_names,matr_fields);
inds_dy=find_indices_variable('dy',matr_names,matr_fields);

dx=peaks_matr(:,inds_dx(1));
dy=peaks_matr(:,inds_dy(1));


%% spect_info: peak boundary information and location

inds_loc=find_indices_variable('loc',matr_names,matr_fields);
% 
% spect_info=cell(2,size(peaks_matr,1));
% 
% for i=1:size(peaks_matr,1)
%     spect_info{1,i}=bndry{i,1};
%     spect_info{2,i}=peaks_matr(i,inds_loc);
% end
loc = peaks_matr(:,inds_loc);

end


function[inds_var] = find_indices_variable(variable_name,matr_names,matr_fields)
% function to find the start and index of the columns corresponding to a
% particular variable

% find the index of the variable name in matr_names
ind_var_matr_names=find(strcmp(variable_name,matr_names));

% cumsum the matr_fields to the end index of each of the variables in the
% columns of peaks_matr. The start index will be the previous value in the
% cumsum array+1
matr_fields_cumsum=cumsum(matr_fields);

if ((ind_var_matr_names)~=1)
    inds_var=[matr_fields_cumsum(ind_var_matr_names-1)+1,...
        matr_fields_cumsum(ind_var_matr_names)];
else
    inds_var=[1,1];
end
end


function [pixellist]= extract_pixellist(chunks_minmax,pixelidxlist,chunk_nums)
pixellist=cell(length(chunk_nums),1);

% iterate through every peak and extract it's chunk_num and find the
% corresponding minmax of that chunk
for i=1:length(chunk_nums)
    if chunk_nums(i)
        current_chunk_minmax=chunks_minmax(chunk_nums(i),:);
        % get the size of current chunk in pixels units
        chunk_xsize=current_chunk_minmax(3)-current_chunk_minmax(1)+1;
        chunk_ysize=current_chunk_minmax(4);
        
        % feed the size of each chunk along with pixel index corresponding to
        % the current peak to ind2sub to get the corresponding list of pixels for
        % that peak
        [rows_idx_pixellist,cols_idx_pixellist]=ind2sub([chunk_ysize,chunk_xsize],...
            pixelidxlist{i,1});
        pixellist{i,1}=[cols_idx_pixellist,rows_idx_pixellist];
    else
        pixellist{i,1}=nan;
    end
end

end

function [max_power] = compute_max_power_from_pixels(pixelidxlist,sspect,chunks_minmax,chunk_nums)
%function to compute max power for each peak

max_power = zeros(size(chunk_nums));
for ii = 1:size(chunks_minmax,1)
    peaks_in_chunk = find(chunk_nums==ii);
    chunk_spect = sspect(chunks_minmax(ii,2):chunks_minmax(ii,4),chunks_minmax(ii,1):chunks_minmax(ii,3));
    
    for jj = 1:length(peaks_in_chunk)
        max_power(peaks_in_chunk(jj)) = max(chunk_spect(pixelidxlist{peaks_in_chunk(jj)}));
    end    
end

end
