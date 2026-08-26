function tests = test_display_tfpeaks
%TEST_DISPLAY_TFPEAKS  Regression tests for TF-peak boundary rendering.
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
addpath(repo_root, '-begin');
addpath(genpath(fullfile(repo_root, 'toolbox')), '-begin');
end

function test_boundaries_are_drawn_as_disconnected_edge_segments(testCase)
old_visibility = get(groot, 'DefaultFigureVisible');
set(groot, 'DefaultFigureVisible', 'off');
visibility_cleanup = onCleanup( ...
    @() set(groot, 'DefaultFigureVisible', old_visibility));

boundary = [0 1; 0 2; 1 2; 1 1; 0 1];
stats_table = table({boundary}, 'VariableNames', {'Boundaries'});
spect = reshape(1:9, 3, 3);
stimes = [0 0.5 1];
sfreqs = [1 2 3];

fh = displayTFPeaks(stats_table, spect, stimes, sfreqs);
figure_cleanup = onCleanup(@() close(fh));

image_handle = findall(fh, 'Type', 'Image');
testCase.assertNumElements(image_handle, 1);
spect_ax = ancestor(image_handle, 'axes');
boundary_line = findall(spect_ax, 'Type', 'Line');
testCase.assertNumElements(boundary_line, 1);

x = boundary_line.XData(:);
y = boundary_line.YData(:);
testCase.verifyNumElements(x, 3*(size(boundary, 1)-1));
testCase.verifyTrue(all(isnan(x(3:3:end))));
testCase.verifyTrue(all(isnan(y(3:3:end))));
testCase.verifyEqual(x(1:3:end), boundary(1:end-1, 1)/3600, ...
    'AbsTol', eps);
testCase.verifyEqual(x(2:3:end), boundary(2:end, 1)/3600, ...
    'AbsTol', eps);
testCase.verifyEqual(y(1:3:end), boundary(1:end-1, 2));
testCase.verifyEqual(y(2:3:end), boundary(2:end, 2));
end
