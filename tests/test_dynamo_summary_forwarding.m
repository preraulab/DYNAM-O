function tests = test_dynamo_summary_forwarding
%TEST_DYNAMO_SUMMARY_FORWARDING  DYNAMO stores and forwards SOPH selection.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
addpath(repo_root);
init_DYNAMO();

import matlab.unittest.fixtures.CurrentFolderFixture
import matlab.unittest.fixtures.PathFixture
import matlab.unittest.fixtures.TemporaryFolderFixture

stub_folder = testCase.applyFixture(TemporaryFolderFixture);
writeRunStub(fullfile(stub_folder.Folder, 'runDYNAMO.m'));
writeDisplayStub(fullfile(stub_folder.Folder, 'displaySummaryPlot.m'));
testCase.applyFixture(PathFixture(stub_folder.Folder, 'Position', 'begin'));
testCase.applyFixture(CurrentFolderFixture(stub_folder.Folder));

clear runDYNAMO displaySummaryPlot
testCase.assertEqual(which('runDYNAMO'), ...
    fullfile(stub_folder.Folder, 'runDYNAMO.m'));
end

function teardownOnce(~)
clear runDYNAMO displaySummaryPlot
removeRootAppData({'DYNAMOTestRunCalled', 'DYNAMOTestDisplayArgs'});
end

function test_stores_and_forwards_histogram_selection(testCase)
removeRootAppData({'DYNAMOTestRunCalled', 'DYNAMOTestDisplayArgs'});

soph_options = SOpowerphasehist_opts();
soph_options.SOPH_stages = [2 4];
obj = DYNAMO([0; 0], 1, [0 0.5 1], [2 5 5], [], ...
    baseline_opts(), detection_opts(), soph_options);

expected_hist_peakidx = logical([true; false; false]);
obj.runDYNAMO();
testCase.verifyTrue(getappdata(groot, 'DYNAMOTestRunCalled'));
testCase.verifyEqual(obj.hist_peakidx, expected_hist_peakidx);

fh = obj.displaySummaryPlot();
testCase.verifyEmpty(fh);
captured_args = getappdata(groot, 'DYNAMOTestDisplayArgs');
testCase.verifyEqual(getNameValue(captured_args, 'hist_peakidx'), ...
    expected_hist_peakidx);
testCase.verifyEqual(getNameValue(captured_args, 'SOPH_stages'), ...
    soph_options.SOPH_stages);

% Cached app results do not retain transient object state. The class must
% reconstruct the same mask before forwarding the plotting arguments.
obj.hist_peakidx = logical([]);
rmappdata(groot, 'DYNAMOTestDisplayArgs');
obj.displaySummaryPlot();
captured_args = getappdata(groot, 'DYNAMOTestDisplayArgs');
testCase.verifyEqual(obj.hist_peakidx, expected_hist_peakidx);
testCase.verifyEqual(getNameValue(captured_args, 'hist_peakidx'), ...
    expected_hist_peakidx);
end

function test_reconstruction_matches_histogram_selection(testCase)
removeRootAppData({'DYNAMOTestDisplayArgs'});

sopower_times = 0:10;
sopower = [1 2 nan 4 5 6 7 8 9 10 11];
peak_times = [1.5; 2.5; 4.5; 6.5; 9.5];
peak_freqs = (10:14)';
stage_times = [0 5 10];
stage_vals = [2 5 5];
soph_stages = 2;

[~, ~, ~, ~, ~, ~, peak_sopower, expected_hist_peakidx] = ...
    SOpowerHistogram(sopower, sopower_times, peak_freqs, peak_times, ...
    'stage_times', stage_times, 'stage_vals', stage_vals, ...
    'SOPH_stages', soph_stages, 'compute_rate', false, ...
    'min_time_in_bin', 0, 'freq_range', [9 15], ...
    'freq_binsizestep', [1 1], 'SO_range', [0 12], ...
    'SO_binsizestep', [1 1], 'backend', 'matlab', 'verbose', false);

soph_options = SOpowerphasehist_opts();
soph_options.SOPH_stages = soph_stages;
obj = DYNAMO(zeros(11, 1), 1, stage_times, stage_vals, [], ...
    baseline_opts(), detection_opts(), soph_options);
obj.stats_table = table(peak_times, peak_sopower, ...
    'VariableNames', {'PeakTime', 'SOpower'});
obj.SOPHs = minimalSOPHs();

obj.displaySummaryPlot();
captured_args = getappdata(groot, 'DYNAMOTestDisplayArgs');
testCase.verifyEqual(getNameValue(captured_args, 'hist_peakidx'), ...
    logical(expected_hist_peakidx));
end

function writeRunStub(filename)
writeStub(filename, {
    'function [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, SOPHs] = runDYNAMO(varargin)'
    'setappdata(groot, ''DYNAMOTestRunCalled'', true);'
    'stats_table = table([0.1; 0.3; 0.75], [1; nan; 2], ...'
    '    ''VariableNames'', {''PeakTime'', ''SOpower''});'
    'spect = 1;'
    'stimes = 0.5;'
    'sfreqs = 8;'
    'data_time_range = varargin{1};'
    't_time_range = (0:numel(data_time_range)-1) / varargin{2};'
    'artifacts = false(size(data_time_range));'
    'SOPHs = struct( ...'
    '    ''SOpower_norm'', [1 2], ...'
    '    ''SOpower_times'', [0 1], ...'
    '    ''freq_bins'', 8, ...'
    '    ''SOpower_mat'', 1, ...'
    '    ''SOpower_bins'', 1, ...'
    '    ''SOphase_mat'', 1, ...'
    '    ''SOphase_bins'', 0);'
    'end'
    });
end

function writeDisplayStub(filename)
writeStub(filename, {
    'function fh = displaySummaryPlot(varargin)'
    'setappdata(groot, ''DYNAMOTestDisplayArgs'', varargin);'
    'fh = [];'
    'end'
    });
end

function writeStub(filename, lines)
fid = fopen(filename, 'w');
assert(fid >= 0, 'Could not create test double: %s', filename);
file_cleanup = onCleanup(@() fclose(fid));
for k = 1:numel(lines)
    fprintf(fid, '%s\n', lines{k});
end
end

function value = getNameValue(args, name)
names = args(1:2:end);
idx = find(strcmp(names, name), 1);
assert(~isempty(idx), 'Missing name-value argument: %s', name);
value = args{2*idx};
end

function SOPHs = minimalSOPHs()
SOPHs = struct( ...
    'SOpower_norm', [1 2], ...
    'SOpower_times', [0 1], ...
    'freq_bins', 8, ...
    'SOpower_mat', 1, ...
    'SOpower_bins', 1, ...
    'SOphase_mat', 1, ...
    'SOphase_bins', 0);
end

function removeRootAppData(keys)
for k = 1:numel(keys)
    if isappdata(groot, keys{k})
        rmappdata(groot, keys{k});
    end
end
end
