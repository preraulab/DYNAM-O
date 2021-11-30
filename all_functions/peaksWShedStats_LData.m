function [ peaks_matr, matr_names, matr_fields, PixelIdxList, PixelList, PixelValues, rgn, bndry] = peaksWShedStats_LData(regions,boundaries,data,xaxis,yaxis,chunk_num,conn,f_verb,verb_pref)
% peaksWShedStats_LData gets the region properties for the peaks obtained 
% from peaksWShed, regionsMergeByWeight, and trimRegionsWShed.
%
% INPUTS:
%   regions    -- 1D cell array of vector lists of linear idx of all pixels for each region.
%   boundaries -- 1D cell array of vector lists of linear idx of border pixels for each region.
%   data       -- 2D matrix of image data. defaults to peaks(100).
%   xaxis      -- x axis of image data. default 1:size(data,2).
%   yaxis      -- y axis of image data. default 1:size(data,1).
%   chunk_num  -- segment number if data comes from larger image. default 1.
%   conn       -- pixel connection to be used by peaksWShedStats_LData. default 8.
%   f_verb     -- number indicating depth of output text statements of progress.
%                 0 - no output. 1 - output current function level.
%                 >1 - output at subfunction levels. defaults to 0.
%   verb_pref  -- prefix string for verbose output. defaults to ''.
%
% OUTPUTS:
%   peaks_matr   -- matrix of peak features. each row is a peak.
%   matr_names   -- 1D cell array of names for each feature.
%   matr_fields  -- vector indicating number of matrix columns occupied by each feature.
%   PixelIdxList -- 1D cell array of vector lists of linear idx of all pixels for each region.
%   PixelList    -- 1D cell array of vector lists of row-col idx of all pixels for each region.
%   PixelValues  -- 1D cell array of vector lists of all pixel values for each region.
%   rgn          -- same as PixelIdxList.
%   bndry        -- 1D cell array of vector lists of linear idx of border pixels for each region.
%
% Created by: Patrick Stokes
% Created on: 2017-05-19
% Modified: 20190422 -- improved speed based on profiler: 
%                         -avoids find of MaxIntensity using index in PixelValues 
%                         -removes solidity from call to regionprops
%           20190301 -- input order changed. boundaries now 2nd.
%
%

%*************************
% Handle variable inputs *
%*************************
if nargin < 9
    verb_pref = [];
end
if nargin < 8
    f_verb = [];
end
if nargin < 7
    conn = [];
end
if nargin < 6
    chunk_num = [];
end
if nargin < 5
    yaxis = [];
end
if nargin < 4
    xaxis = [];
end
if nargin < 3
    data = [];
end
if nargin < 2
    boundaries = [];
end
if nargin < 1
    regions = [];
end

% Check required inputs
% Region pixel lists, boundary pixel lists, and original 2D image data
if ~isempty(regions) && ~isempty(boundaries) && ~isempty(data)
    f_valid_inputs = true;
elseif isempty(regions) && isempty(boundaries) && isempty(data)
    data = abs(peaks(100))+randn(100)*.5;
    [regions, rgn_lbls, Lborders, amatr] = peaksWShed(data);
    [regions, ~] = regionMergeByWeight(data,regions,rgn_lbls,Lborders,amatr);
    [regions, boundaries] = trimRegionsWShed(data,regions);
    f_valid_inputs = true;
else
    f_valid_inputs = false;
    disp(['Warning: Inappropriate inputs provided to peakWShedStats_LData.\n'...
        '         Regions, boundaries, or image data not provided.']);
end

%**********************************************
% Set defaults for additional input arguments *
%**********************************************
if f_valid_inputs
    % x-axis
    if isempty(xaxis)
        xaxis = 1:size(data,2);
    end
    % y-axis
    if isempty(yaxis)
        yaxis = 1:size(data,1);
    end
    % id number of chunk in larger dataset
    if isempty(chunk_num)
        chunk_num = 1;
    end
    % connection parameter to be used in regionprops
    if isempty(conn)
        conn = 8;
    end
    % flag indicating degree of verbosity in screen output
    if isempty(f_verb)
        f_verb = 0;
    end
    % string prefix for screen output
    if f_verb > 0 && isempty(verb_pref)
        verb_pref = '';
    end
end

%****************************
% Get regionprops for peaks *
%****************************
if f_valid_inputs
    % Convert pixel lists back to labeled image
    if f_verb > 0
        disp([verb_pref 'Converting pixel lists to labeled image...']);
    end
    Ldata = cell2Ldata(regions,size(data),boundaries);
    
    % Get regionprops
    if f_verb > 0
        disp([verb_pref 'Computing regionprops...']);
    end
    cc_props = regionprops(Ldata,data,'Area','Centroid','BoundingBox','MajorAxisLength',...
        'MinorAxisLength','Eccentricity','Orientation',... %'ConvexArea','FilledArea',
        'EulerNumber','Extrema','EquivDiameter',... % 'Solidity',
        'Extent','Perimeter','PerimeterOld','WeightedCentroid',...
        'MeanIntensity','MinIntensity','MaxIntensity','PixelIdxList','PixelList','PixelValues');
    
    %***** THIS CONDITION (AND THE REPEAT OF THE f_boundaries EVALUATION IS
    %      TO HANDLE THE CASE OF CHUNKS THAT ARE ZERO EXCEPT FOR THE FIRST
    %      OR LAST ONE OR TWO COLUMNS FOR WHICH THE CONVERSION TO LDATA AND
    %      SUBSEQUENT REGIONPROPS IS EMPTY.
    if isempty(cc_props)
        f_valid_inputs = false;
        disp(['Warning: Regionprops returned empty.\n'...
            '         Likely chunk of data is nearly constant.']);
    end
end

%***********************************************
% Compute additional stats and assemble output *
%***********************************************
if f_valid_inputs
    
    cc_props(end).ConvexArea = [];
    cc_props(end).FilledArea = [];
    cc_props(end).Solidity = [];
    
    % Determine which regions are not empty
    %     tic
    %     num_peaks = 0;
    %     pick_nonempty = false(length(regions),1);
    %     for ii = 1:length(regions)
    %         if ~isempty(find(Ldata==ii,1))
    %             num_peaks = num_peaks + 1;
    %             pick_nonempty(ii) = true;
    %         end
    %     end
    %     num_regions = find(pick_nonempty,1,'last');
    % toc
    % disp(num_regions)
    % disp(num_peaks);   
    pick_nonempty = ismember(1:length(regions),Ldata);
    num_peaks = sum(pick_nonempty);
    num_regions = find(pick_nonempty,1,'last');
    
    
    
    % Preallocate storage
    peaks_matr = zeros(num_peaks,79);
    island_boundaries = cell(num_regions,1);
    matr_names = {'Area','Centroid','BoundingBox','MajorAxisLength',...
        'MinorAxisLength','Eccentricity','Orientation','ConvexArea',...
        'FilledArea','EulerNumber','Extrema','EquivDiameter','Solidity',...
        'Extent','Perimeter','PerimeterOld','WeightedCentroid',...
        'MeanIntensity','MinIntensity','MaxIntensity','idx_loc','loc',...
        'height','parent','dx','dy','xlim','ylim','xy_area','xy_bndbox',...
        'xy_centrd','xy_extrema','xy_wcentrd','n_children','chunk_num'};
    matr_fields = [1 2 4 1 1 1 1 1 1 1 16 1 1 1 1 1 2 1 1 1 2 2 1 1 1 1 2 2 1 4 2 16 2 1 1];
    PixelIdxList = cell(num_peaks,1);
    PixelList = cell(num_peaks,1);
    PixelValues = cell(num_peaks,1);
    rgn = cell(num_peaks,1);
    bndry = cell(num_peaks,1);
    
    % Unpack, compute, and store stats for each peak
    if f_verb > 0
        disp([verb_pref 'Unpacking and storing regionprops...']);
    end
    cnt = 0;
    for ii = 1:num_regions
        if pick_nonempty(ii)
            cnt = cnt + 1;
            
            % Convert linear pixel indices of boundaries to row-col
            island_boundaries{ii} = zeros(length(boundaries{ii}),2);
            [island_boundaries{ii}(:,1),island_boundaries{ii}(:,2)] = ind2sub(size(data),boundaries{ii});
            
            % Extract regionprops to be stored in peaks_matr
            for kk = 1:20 % length(matr_names)
                tmp = cc_props(ii).(matr_names{kk});
                if numel(tmp)==matr_fields(kk)
                    peaks_matr(cnt,(sum(matr_fields(1:(kk-1)))+1):sum(matr_fields(1:kk))) = reshape(tmp,[1 matr_fields(kk)]);
                else
                    % disp(['*something wrong: peak ' num2str(ii) ' ' matr_names{kk} ' has dim ' num2str(size(tmp))]);
                end
            end
            
            % Compute relative height of peak
            tmp_height = cc_props(ii).MaxIntensity-cc_props(ii).MinIntensity;
            
            % Find location of MaxIntensity
            if tmp_height==0
                % If the height is zero, the region is constant.
                % The location is placed at the Centroid.
                tmp_cntrd = round(cc_props(ii).Centroid);
                idx_x = tmp_cntrd(1);
                idx_y = tmp_cntrd(2);
            else
                [~,tmp_max_val_idx] = max(cc_props(ii).PixelValues);
                tmp_max_loc = cc_props(ii).PixelList(tmp_max_val_idx,:);
                idx_x = tmp_max_loc(1);
                idx_y = tmp_max_loc(2);
                
                % If there are multiple pixels with the max value,
                % the location is placed at the centroid of those pixels.
                if length(idx_y)>1
                    %                     tmp_props = regionprops(data.*(Ldata==ii)==cc_props(ii).MaxIntensity,'Centroid');
                    %                     tmp_cntrd = round(tmp_props.Centroid);
                    %                     idx_x = tmp_cntrd(1);
                    %                     idx_y = tmp_cntrd(2);
                    error([num2str(ii) ' : multiple pixels with max intensity']);
                end
            end
            
            % Store pixel location of MaxIntensity
            peaks_matr(cnt,(sum(matr_fields(1:(21-1)))+1):sum(matr_fields(1:21))) = [idx_y idx_x];
            % Store x-y location of MaxIntensity
            peaks_matr(cnt,(sum(matr_fields(1:(22-1)))+1):sum(matr_fields(1:22))) = [yaxis(idx_y) xaxis(idx_x)];
            % Store relative height
            peaks_matr(cnt,(sum(matr_fields(1:(23-1)))+1):sum(matr_fields(1:23))) = tmp_height;
            % Parent peak. Field not currently used.
            peaks_matr(cnt,(sum(matr_fields(1:(24-1)))+1):sum(matr_fields(1:24))) = 0;
            
            % Extract additional regionprops to peak_matr.
            peaks_matr(cnt,(sum(matr_fields(1:24))+1):(end-2)) = getXYPeakProps(cc_props(ii),xaxis,yaxis);
            
            % Number of child peaks. Field not currently used.
            peaks_matr(cnt,end-1) = 0;
            % Store number of data chunk to which peak belongs
            peaks_matr(cnt,end) = chunk_num;
            
            % Orginal region linear pixel indices
            rgn{cnt} = regions{ii};
            % Boundary pixels in y-x coordinates of row-col
            bndry{cnt} = [yaxis(island_boundaries{ii}(:,1))' xaxis(island_boundaries{ii}(:,2))'] ;
            % Region linear pixel indices
            PixelIdxList{cnt} = cc_props(ii).PixelIdxList;
            % Region row-col pixel list
            PixelList{cnt} = cc_props(ii).PixelList;
            % Region pixel values
            PixelValues{cnt} = cc_props(ii).PixelValues;
            
        end
    end
else
    disp(['         Returning empty matrix and cell arrays.']);
    num_peaks = 0;
    peaks_matr = zeros(0,79);
    matr_names = {'Area','Centroid','BoundingBox','MajorAxisLength',...
        'MinorAxisLength','Eccentricity','Orientation','ConvexArea',...
        'FilledArea','EulerNumber','Extrema','EquivDiameter','Solidity',...
        'Extent','Perimeter','PerimeterOld','WeightedCentroid',...
        'MeanIntensity','MinIntensity','MaxIntensity','idx_loc','loc',...
        'height','parent','dx','dy','xlim','ylim','xy_area','xy_bndbox',...
        'xy_centrd','xy_extrema','xy_wcentrd','n_children','chunk_num'};
    matr_fields = [1 2 4 1 1 1 1 1 1 1 16 1 1 1 1 1 2 1 1 1 2 2 1 1 1 1 2 2 1 4 2 16 2 1 1];
    PixelIdxList = {}; % cell(num_peaks,1);
    PixelList = {}; % cell(num_peaks,1);
    PixelValues = {}; % cell(num_peaks,1);
    rgn = {}; % cell(num_peaks,1);
    bndry = {}; % cell(num_peaks,1);
end

end

function peak_matr = getXYPeakProps(peak,x,y)
% getXYPeakProps converts chunk- and pixel- specific regionprops
% to the dimensions of the x-y axes.
%
% INPUTS:
%   peak -- output of regionprops for data of labeled regions
%   x    -- x-axis of current region
%   y    -- y-axis of current region
%
% OUTPUTS:
%   peak_matr -- matrix of size (num_peaks x 24) storing
%                'dx'         -- col 1
%                'dy'         -- col 2
%                'xlim'       -- cols 3 and 4
%                'ylim'       -- cols 5 and 6
%                'xy_area'    -- col 7
%                'xy_bndbox'  -- cols 8-11
%                'xy_centrd'  -- cols 12 and 13
%                'xy_extrema' -- cols 14-29
%                'xy_wcentrd' -- cols 30 and 31
%

n_peaks = size(peak,1);
peak_matr = zeros(n_peaks,24);
% x-axis bin width
diff_x = diff(x);
dx = diff_x(1);
peak_matr(:,1) = dx;
% y-axis bin width
diff_y = diff(y);
dy = diff_y(1);
peak_matr(:,2) = dy;
% Chunk bounds
peak_matr(:,3) = min(x);
peak_matr(:,4) = max(x);
peak_matr(:,5) = min(y);
peak_matr(:,6) = max(y);
% Area
peak_matr(:,7) = peak.Area * dx * dy;
% Bounding box
xy_bndbox = peak.BoundingBox;
peak_matr(:,8:9) = xy_bndbox(:,[1 2]).*repmat([dx dy],[n_peaks 1]) + repmat([min(x) min(y)],[n_peaks 1]);
peak_matr(:,10:11) = xy_bndbox(:,[3 4]).*repmat([dx dy],[n_peaks 1]);
% Centroid
peak_matr(:,12:13) = peak.Centroid.*repmat([dx dy],[n_peaks 1]) + repmat([min(x) min(y)],[n_peaks 1]);
% Extrema
for ii = 1:n_peaks
    peak_matr(ii,14:29) = reshape(peak(ii).Extrema.*repmat([dx dy],[8 1]) + repmat([min(x) min(y)],[8 1]),[1 16]);
end
% Weighted centroid
peak_matr(:,30:31) = peak.WeightedCentroid.*repmat([dx dy],[n_peaks 1]) + repmat([min(x) min(y)],[n_peaks 1]);

end


