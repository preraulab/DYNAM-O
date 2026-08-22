function stats_table = computePeakStatsTable(regions,boundaries,data,xvalues,yvalues,segment_num, features)
%COMPUTEPEAKSTATSTABLE  Create a table of region properties for detected peaks
%
%   Usage:
%       stats_table = computePeakStatsTable(regions, boundaries, data, xvalues, yvalues, segment_num, features)
%
%   Required Inputs:
%       regions:     [1 x K] cell - linear indices of pixels per region
%       boundaries:  [1 x K] cell - linear indices of border pixels per region
%       data:        [M x N] double - 2D image data
%
%   Optional Inputs:
%       xvalues:     [1 x N] double - x axis of image data (default: 1:size(data,2))
%       yvalues:     [1 x M] double - y axis of image data (default: 1:size(data,1))
%       segment_num: integer - segment index when data is a sub-segment (default: 1)
%       features:    cell or char - any subset of {'Area', 'Bandwidth', 'Boundaries',
%                    'BoundingBox', 'Duration', 'Height', 'HeightData', 'PeakFrequency',
%                    'Peakiness', 'PeakTime', 'SegmentNum', 'Volume'} or 'all' (default: 'all')
%
%   Outputs:
%       stats_table: table - one row per peak, columns determined by features
%
%   See Also: extractTFPeaks, runSegmentedData, computeTFPeaks
%
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
    features = {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height', 'HeightData', 'PeakFrequency', 'Peakiness', 'PeakTime', 'SegmentNum', 'Volume'};
end

assert(iscell(regions) && ~isempty(regions),'Regions must be a cell array');
assert(iscell(boundaries) && ~isempty(boundaries),'Boundaries must be a cell array');
assert(isnumeric(data) && ismatrix(data) && min(size(data))>1,'Data must be an MxN numeric matrix');

%% Convert data to labeled data
Ldata = zeros(size(data));
for ii = 1:length(regions)
    Ldata(regions{ii}(~isnan(data(regions{ii})))) = ii;
end

%Compute the stats table
r_props = {'Area'};

if any(strcmpi(features,'BoundingBox')) || any(strcmpi(features,'Bandwidth')) || any(strcmpi(features,'Duration'))
    r_props = cat(2,r_props,'BoundingBox');
end

if any(strcmpi(features,'PeakTime')) || any(strcmpi(features,'PeakFrequency'))
    r_props = cat(2,r_props,'WeightedCentroid');
end

if any(strcmpi(features,'Height')) || any(strcmpi(features,'HeightData')) || any(strcmpi(features,'Volume')) || any(strcmpi(features,'Peakiness'))
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
good_indices = stats_table.Area > 0;
stats_table = stats_table(good_indices,:);
boundaries = boundaries(good_indices);
% regions = regions(good_indices);

%% Compute statistics
%Bounding Box
if any(strcmpi(features,'BoundingBox')) || any(strcmpi(features,'Duration')) || any(strcmpi(features,'Bandwidth'))
    stats_table.BoundingBox(:,1) = stats_table.BoundingBox(:,1)*dx + seg_startx;
    stats_table.BoundingBox(:,2) = stats_table.BoundingBox(:,2)*dy + seg_starty;
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
else
    stats_table.Area = [];
end

%Volume
if any(strcmpi(features,'Volume'))
    stats_table.Volume = cellfun(@(x)sum(x)*dx*dy, stats_table.PixelValues);
    stats_table.Properties.VariableDescriptions{'Volume'} = 'Time-frequency volume of peak in s*μV^2';
    stats_table.Properties.VariableUnits{'Volume'} = 'sec*μV^2';
end

%Boundaries
if any(strcmpi(features,'Boundaries'))
    [a,b] = cellfun(@(x)ind2sub(size(data),x),boundaries','UniformOutput',false);
    stats_table.Boundaries = cellfun(@(a,b)[(b-1)*dx+seg_startx, (a-1)*dy+seg_starty], a, b, 'Uniform', 0); % a,b in pixel indices
    stats_table.Properties.VariableDescriptions{'Boundaries'} = '(time, frequency) of peak region boundary pixels';
    stats_table.Properties.VariableUnits{'Boundaries'} = '(seconds, Hz)';
end

% regionprops returns WeightedCentroid in 1-based pixel-center coords:
% the center of the upper-left pixel is at (1.0, 1.0). The (-1) shifts to
% 0-based so a peak at column 1 maps to xvalues(1), not xvalues(2). The
% legacy toolbox/watershed_functions/ version had this; the (-1) was
% dropped in the 2022-09-28 camelCase rename (b59fa85), silently biasing
% PeakTime/PeakFrequency by +1 spectrogram bin until restored here.
%
%Peak Time
if any(strcmpi(features,'PeakTime'))
    stats_table.PeakTime = (stats_table.WeightedCentroid(:,1)-1)*dx+seg_startx;
    stats_table.Properties.VariableDescriptions{'PeakTime'} = 'Peak time based on weighted centroid';
    stats_table.Properties.VariableUnits{'PeakTime'} = 'sec';
end

%Peak Frequency
if any(strcmpi(features,'PeakFrequency'))
    stats_table.PeakFrequency = (stats_table.WeightedCentroid(:,2)-1)*dy+seg_starty;
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

%Peakiness = N/(N-1) * (max - mean) / (max - min) of the region's N pixel
% values, in [0, 1]. The N/(N-1) factor is a small-sample correction
% (cf. Bessel): a single-pixel spike has mean = min + (max-min)/N, so the
% raw ratio caps at 1 - 1/N; the correction makes a spike score exactly 1
% for every region size. Plateau -> 0 (asymptotically; floor 1/(N-1)).
% Affine-invariant: amplifier gain and any additive pedestal both cancel
% -- which requires artifact masking to write NaN, never 0 (a zeroed
% pixel would pin the region min and masquerade as spikiness; NaN pixels
% are excluded from regions above). NaN for degenerate regions where
% max == min (0/0), e.g. single-pixel or perfectly flat.
% Recomputed from PixelValues so this block is order-independent:
% stats_table.PixelValues is renamed/dropped below depending on 'HeightData'.
if any(strcmpi(features,'Peakiness'))
    pk_max  = cellfun(@max,   stats_table.PixelValues);
    pk_min  = cellfun(@min,   stats_table.PixelValues);
    pk_mean = cellfun(@mean,  stats_table.PixelValues);
    pk_n    = cellfun(@numel, stats_table.PixelValues);
    stats_table.Peakiness = (pk_n ./ max(pk_n - 1, 1)) .* ...
        (pk_max - pk_mean) ./ (pk_max - pk_min);
    stats_table.Properties.VariableDescriptions{'Peakiness'} = 'Peakiness: N/(N-1) * (max - mean) / (max - min) of region pixels; 0 = flat plateau, 1 = spike';
    stats_table.Properties.VariableUnits{'Peakiness'} = 'unitless';
end

%Region data
if any(strcmpi(features,'HeightData'))
    stats_table.Properties.VariableNames{'PixelValues'} = 'HeightData';
    stats_table.Properties.VariableDescriptions{'HeightData'} = 'Height of all pixels within peak region';
    stats_table.Properties.VariableUnits{'HeightData'} = 'μV^2/Hz';
elseif any(cellfun(@(prop) strcmp(prop, 'PixelValues'), r_props))
    stats_table.PixelValues = [];
end

%Remove bounding box if not used
if ~any(strcmpi(features,'BoundingBox')) && any(cellfun(@(prop) strcmp(prop, 'BoundingBox'), r_props))
    stats_table.BoundingBox = [];
end

%Remove weighted centroid, since it is embedded in time and frequency columns
if any(cellfun(@(prop) strcmp(prop, 'WeightedCentroid'), r_props))
    stats_table.WeightedCentroid = [];
end

%% Additional features can be added here
% stats_table.MyFeature = MyValue;

end
