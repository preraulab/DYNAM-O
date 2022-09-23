function statsTable = computePeakStatsTable(regions,boundaries,data,xaxis,yaxis,segment_num)
% gets the region properties for the peaks 
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
    segment_num = [];
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
    if isempty(segment_num)
        segment_num = 1;
    end
end

%Convert data to labeled data
Ldata = cell2Ldata(regions,size(data),boundaries);

statsTable = regionprops('table',Ldata,data,'Area','BoundingBox',...
        'WeightedCentroid','Extrema','MinIntensity','MaxIntensity',...
        'PixelIdxList','PixelList','PixelValues');

%Get the dx and dy
dx = diff(xaxis(1:2));
dy = diff(yaxis(1:2));

%Get the segment bounds
seg_startx = xaxis(1);
seg_starty = yaxis(1);

%Area
statsTable.Area = statsTable.Area * dx * dy;

%Volume
statsTable.Volume = cellfun(@(x)sum(x)*dx*dy,statsTable.PixelValues);

%Boundaries 
[a,b] = cellfun(@(x)ind2sub(size(data),x),boundaries,'UniformOutput',false);
statsTable.Boundaries = cellfun(@(a,b)[(b-1)*dx+seg_startx  (a-1)*dy+seg_starty ], a, b, 'Uniform', 0);

%Weighted Centroid 
% statsTable.WeightedCentroidxy = [(statsTable.WeightedCentroid(:,1)-1)*dx+seg_startx  (statsTable.WeightedCentroid(:,2)-1)*dy+seg_starty ];

%Peak Time
statsTable.PeakTime = (statsTable.WeightedCentroid(:,1)-1)*dx+seg_startx;

%Peak Frequency
statsTable.PeakFrequency = (statsTable.WeightedCentroid(:,2)-1)*dy+seg_starty;

%Height
statsTable.Height = statsTable.MaxIntensity-statsTable.MinIntensity;

%Segment Number
statsTable.SegmentNum(:,1) = segment_num;

%Bandwidth
statsTable.Bandwidth = cellfun(@(x)max(x)-min(x),a)*dy;

%Duration
statsTable.Duration = cellfun(@(x)max(x)-min(x),b)*dx;