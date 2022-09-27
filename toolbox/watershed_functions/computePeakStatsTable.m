function statsTable = computePeakStatsTable(regions,boundaries,data,xvalues,yvalues,segment_num)
% COMPUTEPEAKSTATSTABLE Creates a table of the region properties for the peaks 
%
% USAGE:
%   statsTable = computePeakStatsTable(regions, boundaries, data, xvalues, yvalues, segment_num)
%
% INPUTS:
%   regions    -- 1D cell array of vector lists of linear idx of all pixels for each region.
%   boundaries -- 1D cell array of vector lists of linear idx of border pixels for each region.
%   data       -- 2D matrix of image data. defaults to peaks(100).
%   xvalues      -- x axis of image data. default 1:size(data,2).
%   yvalues      -- y axis of image data. default 1:size(data,1).
%   segment_num  -- segment number if data comes from larger image. default 1.
%
% OUTPUTS:
%   statsTable   -- Table of peak statistics
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
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
    if isempty(xvalues)
        xvalues = 1:size(data,2);
    end
    % y-axis
    if isempty(yvalues)
        yvalues = 1:size(data,1);
    end
    % id number of chunk in larger dataset
    if isempty(segment_num)
        segment_num = 1;
    end
end

%Convert data to labeled data
Ldata = cell2Ldata(regions,size(data),boundaries);

%Compute the stats table
statsTable = regionprops('table',Ldata,data,'Area',...
        'WeightedCentroid','PixelIdxList','PixelList','PixelValues');

%Get the dx and dy
dx = diff(xvalues(1:2));
dy = diff(yvalues(1:2));

%Get the segment bounds
seg_startx = xvalues(1);
seg_starty = yvalues(1);

%Remove Dead Rows
good_indices = statsTable.Area  > 0;
statsTable = statsTable(good_indices,:);
boundaries = boundaries(good_indices);
regions = regions(good_indices);

%Area
statsTable.Area = statsTable.Area * dx * dy;

%Volume
statsTable.Volume = cellfun(@(x)pow2db(sum(x))*dx*dy,statsTable.PixelValues);

%Boundaries 
[a,b] = cellfun(@(x)ind2sub(size(data),x),boundaries,'UniformOutput',false);
statsTable.Boundaries = cellfun(@(a,b)[(b-1)*dx+seg_startx,  (a-1)*dy+seg_starty ], a, b, 'Uniform', 0);

%Weighted Centroid 
% statsTable.WeightedCentroidxy = [(statsTable.WeightedCentroid(:,1)-1)*dx+seg_startx  (statsTable.WeightedCentroid(:,2)-1)*dy+seg_starty ];

%Peak Time
statsTable.PeakTime = (statsTable.WeightedCentroid(:,1)-1)*dx+seg_startx;

%Peak Frequency
statsTable.PeakFrequency = (statsTable.WeightedCentroid(:,2)-1)*dy+seg_starty;

%Height
statsTable.Height = cellfun(@max,statsTable.PixelValues) - cellfun(@min, statsTable.PixelValues);

%Segment Number
statsTable.SegmentNum(:,1) = segment_num;

%Bandwidth
statsTable.Bandwidth = cellfun(@(x)max(x)-min(x),a)*dy;

%Duration
statsTable.Duration = cellfun(@(x)max(x)-min(x),b)*dx;