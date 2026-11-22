function tests = test_bounding_box_pixel_extent
%TEST_BOUNDING_BOX_PIXEL_EXTENT  BoundingBox is the exact extent of the region's pixels
%
%   computePeakStatsTable is given regions whose pixels are known, on
%   axes that do not start at zero. A pixel at column c is centered on
%   xvalues(c) and covers half a bin to each side, so the BoundingBox
%   must start half a bin before the center of the region's first pixel
%   and end half a bin after the center of its last one, on both axes.
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<*INUSD>
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('runDYNAMO'))
    addpath(repo_root); init_DYNAMO();
end
end

function test_box_spans_pixel_edges(testCase)
% Image axes: time starts at 100 s in 0.05 s bins, frequency at 4 Hz in
% 0.1 Hz bins.
dx = 0.05;
dy = 0.1;
xvalues = 100 + (0:19) * dx;
yvalues = 4 + (0:11) * dy;
data = ones(numel(yvalues), numel(xvalues));

% Region 1: rows 3 to 6, columns 5 to 9. Region 2: the single pixel at
% row 1, column 1 plus its neighbor at row 2, column 1.
region_rows = {3:6, 1:2};
region_cols = {5:9, 1};
regions = cell(1, 2);
for k = 1:2
    [cols, rows] = meshgrid(region_cols{k}, region_rows{k});
    regions{k} = sub2ind(size(data), rows(:), cols(:));
end
boundaries = regions;

stats = computePeakStatsTable(regions, boundaries, data, xvalues, yvalues, 1, {'BoundingBox'});

for k = 1:2
    first_col = region_cols{k}(1);
    last_col = region_cols{k}(end);
    first_row = region_rows{k}(1);
    last_row = region_rows{k}(end);
    expected_start_time = xvalues(first_col) - dx / 2;
    expected_end_time = xvalues(last_col) + dx / 2;
    expected_start_freq = yvalues(first_row) - dy / 2;
    expected_end_freq = yvalues(last_row) + dy / 2;

    box = stats.BoundingBox(k, :);
    verifyEqual(testCase, box(1), expected_start_time, 'AbsTol', 1e-12);
    verifyEqual(testCase, box(2), expected_start_freq, 'AbsTol', 1e-12);
    verifyEqual(testCase, box(1) + box(3), expected_end_time, 'AbsTol', 1e-12);
    verifyEqual(testCase, box(2) + box(4), expected_end_freq, 'AbsTol', 1e-12);
end
end

function test_box_contains_weighted_centroid(testCase)
% A uniform region's PeakTime and PeakFrequency are the middle of its
% BoundingBox.
dx = 0.05;
dy = 0.1;
xvalues = 100 + (0:19) * dx;
yvalues = 4 + (0:11) * dy;
data = ones(numel(yvalues), numel(xvalues));
[cols, rows] = meshgrid(5:9, 3:6);
regions = {sub2ind(size(data), rows(:), cols(:))};

stats = computePeakStatsTable(regions, regions, data, xvalues, yvalues, 1, {'BoundingBox', 'PeakTime', 'PeakFrequency'});

box = stats.BoundingBox(1, :);
verifyEqual(testCase, stats.PeakTime, box(1) + box(3) / 2, 'AbsTol', 1e-12);
verifyEqual(testCase, stats.PeakFrequency, box(2) + box(4) / 2, 'AbsTol', 1e-12);
end
