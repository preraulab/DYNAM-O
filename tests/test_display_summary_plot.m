function tests = test_display_summary_plot
%TEST_DISPLAY_SUMMARY_PLOT  TF-peak scatter inclusion and SOPH masking.
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('runDYNAMO'))
    addpath(repo_root); init_DYNAMO();
end
end

function test_scatter_shows_all_peaks_and_shades_excluded_times(testCase)
old_visibility = get(groot, 'DefaultFigureVisible');
set(groot, 'DefaultFigureVisible', 'off');
visibility_cleanup = onCleanup(@() set(groot, 'DefaultFigureVisible', old_visibility));

stats_table = table( ...
    [0.25; 1; 2; 4; 6.5; 8], ...
    [6; 8; 10; 12; 14; 16], ...
    [1; 2; 4; 8; 16; 32], ...
    [-pi/2; NaN; 0; pi/2; pi/4; NaN], ...
    'VariableNames', {'PeakTime', 'PeakFrequency', 'Volume', 'SOphase'});
stats_table_before = stats_table;
hist_peakidx = logical([0; 0; 1; 0; 1; 0]);
stage_times = [-1.5 3 6 10.5];
stage_vals = [2 5 2 2];
time_range = [-1.5 10.5];
SOpower_times = 0:9;
SOpower_norm = [0 NaN 2 3 NaN 5 6 7 NaN 9];

SOpower_times_step = SOpower_times(2) - SOpower_times(1);
peak_SOpower = interp1( ...
    [SOpower_times(1)-SOpower_times_step, SOpower_times, SOpower_times(end)+SOpower_times_step], ...
    [SOpower_norm(1), SOpower_norm, SOpower_norm(end)], stats_table.PeakTime);
peak_stages = interp1(stage_times, stage_vals, stats_table.PeakTime, 'previous');
peak_stages(isnan(peak_stages)) = 0;
expected_hist_peakidx = ismember(peak_stages, 2) & ~isnan(peak_SOpower) & ...
    stats_table.PeakTime >= time_range(1) & stats_table.PeakTime <= time_range(2);
testCase.verifyEqual(hist_peakidx, expected_hist_peakidx);

fh = displaySummaryPlot( ...
    'stage_times', stage_times, ...
    'stage_vals', stage_vals, ...
    'time_range', time_range, ...
    'SOpower_norm', SOpower_norm, ...
    'SOpower_times', SOpower_times, ...
    'stats_table', stats_table, ...
    'hist_peakidx', hist_peakidx, ...
    'SOPH_stages', 2, ...
    'peak_size_prctiles', [50 100]);
figure_cleanup = onCleanup(@() close(fh));

axes_handles = findall(fh, 'Type', 'Axes');
scatter_ax = gobjects(0);
for k = 1:numel(axes_handles)
    if strcmp(axes_handles(k).Title.String, 'Extracted Time-Frequency Peaks')
        scatter_ax = axes_handles(k);
        break
    end
end
testCase.assertNotEmpty(scatter_ax);

scatters = findall(scatter_ax, 'Type', 'Scatter');
testCase.verifyNumElements(scatters, 2);

observed_x = [];
observed_y = [];
observed_size = [];
for k = 1:numel(scatters)
    observed_x = [observed_x; scatters(k).XData(:)]; %#ok<AGROW>
    observed_y = [observed_y; scatters(k).YData(:)]; %#ok<AGROW>
    observed_size = [observed_size; scatters(k).SizeData(:)]; %#ok<AGROW>
end
[observed_x, order] = sort(observed_x);
observed_y = observed_y(order);
observed_size = observed_size(order);

pmin = prctile(stats_table.Volume(hist_peakidx), 50);
pmax = prctile(stats_table.Volume(hist_peakidx), 100);
expected_size = min(stats_table.Volume, pmax) / pmin * 0.5;
[expected_x, order] = sort(stats_table.PeakTime/3600);
testCase.verifyEqual(observed_x, expected_x, 'AbsTol', eps);
testCase.verifyEqual(observed_y, stats_table.PeakFrequency(order));
testCase.verifyEqual(observed_size, expected_size(order), 'AbsTol', eps);
testCase.verifyTrue(all(isfinite(observed_size) & observed_size > 0));

phase_scatter = scatters(arrayfun(@(h) numel(h.XData) == sum(~isnan(stats_table.SOphase)), scatters));
neutral_scatter = scatters(arrayfun(@(h) numel(h.XData) == sum(isnan(stats_table.SOphase)), scatters));
testCase.verifyEqual(phase_scatter.CData(:), stats_table.SOphase(~isnan(stats_table.SOphase)));
testCase.verifyEqual(neutral_scatter.MarkerFaceColor, [0.35 0.35 0.35]);

patches = findall(scatter_ax, 'Type', 'Patch');
testCase.verifyNumElements(patches, 5);
observed_spans = zeros(numel(patches), 2);
for k = 1:numel(patches)
    observed_spans(k, :) = [min(patches(k).XData), max(patches(k).XData)];
    testCase.verifyEqual(patches(k).YData(:), [2; 2; 25; 25]);
    testCase.verifyEqual(patches(k).FaceColor, [0.8 0.8 0.8]);
    testCase.verifyEqual(patches(k).FaceAlpha, 0.35);
end
observed_spans = sortrows(observed_spans);
expected_spans = [-1.5 -1; 0 2; 3 6; 7 9; 10 10.5] / 3600;
testCase.verifyEqual(observed_spans, expected_spans, 'AbsTol', eps);

children = allchild(scatter_ax);
scatter_positions = zeros(numel(scatters), 1);
patch_positions = zeros(numel(patches), 1);
for k = 1:numel(scatters)
    scatter_positions(k) = find(children == scatters(k), 1);
end
for k = 1:numel(patches)
    patch_positions(k) = find(children == patches(k), 1);
end
testCase.verifyLessThan(max(scatter_positions), min(patch_positions));
testCase.verifyEqual(stats_table, stats_table_before);
end
