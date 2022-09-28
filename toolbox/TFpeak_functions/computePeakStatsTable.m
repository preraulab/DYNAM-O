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

%**********************************************
% Set defaults for additional input arguments *
%**********************************************
if nargin<3
    error('Regions, boundaries, and data are required')
end

if nargin<4 || isempty(xvalues)
    xvalues = 1:size(data,2);
end

if nargin<5 || isempty(yvalues)
    yvalues = 1:size(data,1);
end

if nargin<6 || isempty(segment_num)
    segment_num = 1;
end

assert(iscell(regions) && ~isempty(regions),'Regions must be a cell array');
assert(iscell(boundaries) && ~isempty(boundaries),'Boundaries must be a cell array');
assert(isnumeric(data) && ismatrix(data) && min(size(data))>1,'Data must be an MxN numeric matrix');

%% Convert data to labeled data
Ldata = cell2Ldata(regions,size(data),boundaries);

%Compute the stats table
statsTable = regionprops('table',Ldata,data,'Area',...
        'BoundingBox','WeightedCentroid','PixelValues');

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

%% Compute statistics

%Area
statsTable.Area = statsTable.Area*dx*dy;

%Volume
statsTable.Volume = cellfun(@(x)sum(x)*dx*dy, statsTable.PixelValues);

%Boundaries 
[a,b] = cellfun(@(x)ind2sub(size(data),x),boundaries,'UniformOutput',false); % a,b in pixel indices
statsTable.Boundaries = cellfun(@(a,b)[(b-1)*dx+seg_startx, (a-1)*dy+seg_starty], a, b, 'Uniform', 0);

%Peak Time
statsTable.PeakTime = statsTable.WeightedCentroid(:,1)*dx+seg_startx; % WeightedCentroid in spatial coordinates

%Peak Frequency
statsTable.PeakFrequency = statsTable.WeightedCentroid(:,2)*dy+seg_starty; % WeightedCentroid in spatial coordinates

%Height
statsTable.Height = cellfun(@max,statsTable.PixelValues) - cellfun(@min, statsTable.PixelValues);

%Segment Number
statsTable.SegmentNum(:,1) = segment_num;

%Duration
statsTable.Duration = statsTable.BoundingBox(:,3)*dx; % Bounding box in spatial coordinates

%Bandwidth
statsTable.Bandwidth = statsTable.BoundingBox(:,4)*dy; % Bounding box in spatial coordinates

end