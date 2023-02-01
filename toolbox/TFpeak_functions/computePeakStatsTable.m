function stats_table = computePeakStatsTable(regions,boundaries,data,xvalues,yvalues,segment_num, features)
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
%   features   -- cell array of features to include, can be any subset of
%                 {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height', 'HeightData', 
%                  'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume'} or 'all'. default 'all'
%
% OUTPUTS:
%   stats_table   -- Table of peak statistics
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

if nargin<7 || isempty(features) || any(strcmpi(features,'all'))
    features = {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height', 'HeightData', 'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume'};
end

assert(iscell(regions) && ~isempty(regions),'Regions must be a cell array');
assert(iscell(boundaries) && ~isempty(boundaries),'Boundaries must be a cell array');
assert(isnumeric(data) && ismatrix(data) && min(size(data))>1,'Data must be an MxN numeric matrix');

%% Convert data to labeled data
Ldata = zeros(size(data));
for ii = 1:length(regions)
    Ldata(regions{ii}) = ii;
end

%Compute the stats table
r_props = {};
if any(strcmpi(features,'Area'))
    r_props = cat(2,r_props,'Area');
end

if any(strcmpi(features,'BoundingBox')) || any(strcmpi(features,'Bandwidth')) || any(strcmpi(features,'Duration'))
    r_props = cat(2,r_props,'BoundingBox');
end

if any(strcmpi(features,'PeakTime')) || any(strcmpi(features,'PeakFrequency')) 
    r_props = cat(2,r_props,'WeightedCentroid');
end

if any(strcmpi(features,'Height')) || any(strcmpi(features,'HeightData')) || any(strcmpi(features,'Volume')) 
    r_props = cat(2,r_props,'PixelValues');
end

stats_table = regionprops('table',Ldata,data,r_props{:});

%Get the dx and dy
dx = diff(xvalues(1:2));
dy = diff(yvalues(1:2));

%Get the segment bounds
seg_startx = xvalues(1);
seg_starty = yvalues(1);

%Remove dead rows
if any(strcmpi(features,'Area'))
    good_indices = stats_table.Area > 0;
end

stats_table = stats_table(good_indices,:);
boundaries = boundaries(good_indices);
% regions = regions(good_indices);

%% Compute statistics
%Bounding Box
if any(strcmpi(features,'BoundingBox')) || any(strcmpi(features,'Duration')) || any(strcmpi(features,'Bandwidth'))
    stats_table.BoundingBox(:,1) = stats_table.BoundingBox(:,3)*dx + seg_startx;
    stats_table.BoundingBox(:,2) = stats_table.BoundingBox(:,4)*dy + seg_starty;
    stats_table.BoundingBox(:,3) = stats_table.BoundingBox(:,3)*dx;
    stats_table.BoundingBox(:,4) = stats_table.BoundingBox(:,4)*dy;
    stats_table.Properties.VariableDescriptions{'BoundingBox'} = 'Bounding Box: (top left time, top left freq, width, height)';
    stats_table.Properties.VariableUnits{'BoundingBox'} = '(sec, Hz, sec, Hz)';
end

%Area
if any(strcmpi(features,'Area'))
    stats_table.Area = stats_table.Area*dx*dy;
    stats_table.Properties.VariableDescriptions{'Area'} = 'Time-frequency area of peak';
    stats_table.Properties.VariableUnits{'Area'} = 'sec*Hz';
end

%Volume
if any(strcmpi(features,'Volume'))
    stats_table.Volume = cellfun(@(x)sum(x)*dx*dy, stats_table.PixelValues);
    stats_table.Properties.VariableDescriptions{'Volume'} = 'Time-frequency volume of peak in s*μV^2';
    stats_table.Properties.VariableUnits{'Volume'} = 'sec*μV^2';
end

%Boundaries
if any(strcmpi(features,'Boundaries'))
    [a,b] = cellfun(@(x)ind2sub(size(data),x),boundaries,'UniformOutput',false);
    stats_table.Boundaries = cellfun(@(a,b)[(b-1)*dx+seg_startx, (a-1)*dy+seg_starty], a, b, 'Uniform', 0); % a,b in pixel indices
    stats_table.Properties.VariableDescriptions{'Boundaries'} = '(time, frequency) of peak region boundary pixels';
    stats_table.Properties.VariableUnits{'Boundaries'} = '(seconds, Hz)';
end

%Peak Time
if any(strcmpi(features,'PeakTime'))
    stats_table.PeakTime = stats_table.WeightedCentroid(:,1)*dx+seg_startx; % WeightedCentroid in spatial coordinates
    stats_table.Properties.VariableDescriptions{'PeakTime'} = 'Peak time based on weighted centroid';
    stats_table.Properties.VariableUnits{'PeakTime'} = 'sec';
end

%Peak Frequency
if any(strcmpi(features,'PeakFrequency'))
    stats_table.PeakFrequency = stats_table.WeightedCentroid(:,2)*dy+seg_starty; % WeightedCentroid in spatial coordinates
    stats_table.Properties.VariableDescriptions{'PeakFrequency'} = 'Peak frequency based on weighted centroid';
    stats_table.Properties.VariableUnits{'PeakFrequency'} = 'Hz';
end

%Height
if any(strcmpi(features,'Height'))
    stats_table.Height = cellfun(@max,stats_table.PixelValues) - cellfun(@min,stats_table.PixelValues);
    stats_table.Properties.VariableDescriptions{'Height'} = 'Peak height above baseline';
    stats_table.Properties.VariableUnits{'Height'} = 'μV^2/Hz';
end

%Duration
if any(strcmpi(features,'Duration'))
    stats_table.Duration = stats_table.BoundingBox(:,3); % BoundingBox in spatial coordinates
    stats_table.Properties.VariableDescriptions{'Duration'} = 'Peak duration in seconds';
    stats_table.Properties.VariableUnits{'Duration'} = 'sec';
end

%Bandwidth
if any(strcmpi(features,'Bandwidth'))
    stats_table.Bandwidth = stats_table.BoundingBox(:,4); % BoundingBox in spatial coordinates
    stats_table.Properties.VariableDescriptions{'Bandwidth'} = 'Peak bandwidth in Hz';
    stats_table.Properties.VariableUnits{'Bandwidth'} = 'Hz';
end

%Segment Number
if any(strcmpi(features,'SegmentNum'))
    stats_table.SegmentNum(:,1) = segment_num;
    stats_table.Properties.VariableDescriptions{'SegmentNum'} = 'Data segment number';
    stats_table.Properties.VariableUnits{'SegmentNum'} = '#';
end

%Region data
if any(strcmpi(features,'HeightData'))
    stats_table.Properties.VariableNames{'PixelValues'} = 'HeightData';
    stats_table.Properties.VariableDescriptions{'HeightData'} = 'Height of all pixels within peak region';
    stats_table.Properties.VariableUnits{'HeightData'} = 'μV^2/Hz';
else
    stats_table.PixelValues = [];
end

%Remove bounding box if not used
if ~any(strcmpi(features,'BoundingBox'))
    stats_table.BoundingBox = [];
end

%Remove weighted centroid, since it is embedded in time and frequency columns
stats_table.WeightedCentroid = [];
end