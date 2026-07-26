function tests = test_rundynamo_stage_forwarding
%TEST_RUNDYNAMO_STAGE_FORWARDING  runDYNAMO forwards stages to peak helpers.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
addpath(repo_root);
init_DYNAMO();

import matlab.unittest.fixtures.PathFixture
import matlab.unittest.fixtures.TemporaryFolderFixture

stub_folder = testCase.applyFixture(TemporaryFolderFixture);
writeComputePeakSOpowerStub( ...
    fullfile(stub_folder.Folder, 'computePeakSOpower.m'));
writeComputePeakSOphaseStub( ...
    fullfile(stub_folder.Folder, 'computePeakSOphase.m'));
writeSOpowerphaseHistogramStub( ...
    fullfile(stub_folder.Folder, 'SOpowerphaseHistogram.m'));
writeSetupParallelPoolStub( ...
    fullfile(stub_folder.Folder, 'setup_parallel_pool.m'));
testCase.applyFixture(PathFixture(stub_folder.Folder, 'Position', 'begin'));

clear runDYNAMO computePeakSOpower computePeakSOphase SOpowerphaseHistogram setup_parallel_pool
testCase.assertEqual(which('computePeakSOpower'), ...
    fullfile(stub_folder.Folder, 'computePeakSOpower.m'));
testCase.assertEqual(which('computePeakSOphase'), ...
    fullfile(stub_folder.Folder, 'computePeakSOphase.m'));
testCase.assertEqual(which('SOpowerphaseHistogram'), ...
    fullfile(stub_folder.Folder, 'SOpowerphaseHistogram.m'));
testCase.assertEqual(which('setup_parallel_pool'), ...
    fullfile(stub_folder.Folder, 'setup_parallel_pool.m'));
end

function teardownOnce(~)
clear runDYNAMO computePeakSOpower computePeakSOphase SOpowerphaseHistogram setup_parallel_pool
removeRootAppData({'DYNAMOTestComputePeakSOpowerArgs', ...
    'DYNAMOTestComputePeakSOphaseArgs'});
end

function test_runDYNAMO_forwards_stages_to_peak_helpers(testCase)
removeRootAppData({'DYNAMOTestComputePeakSOpowerArgs', ...
    'DYNAMOTestComputePeakSOphaseArgs'});

stage_times = [0 4];
stage_vals = [2 2];
stats_table = table(1, 10, ...
    'VariableNames', {'PeakTime', 'PeakFrequency'});
artifacts = false(1, 5);
detection_options = detection_opts();
detection_options.parallel_mode = '';
detection_options.backend = 'matlab';

[~, ~, ~, ~, ~, ~, ~, ~] = runDYNAMO(zeros(5, 1), 1, ...
    stage_times, stage_vals, ...
    'stats_table', stats_table, ...
    'artifacts', artifacts, ...
    'detection_options', detection_options, ...
    'backend', 'matlab', ...
    'plot_on', false, ...
    'fit_param_basis', false, ...
    'fit_spline_basis', false, ...
    'verbose', false);

power_args = getappdata(groot, 'DYNAMOTestComputePeakSOpowerArgs');
phase_args = getappdata(groot, 'DYNAMOTestComputePeakSOphaseArgs');
verifyNameValue(testCase, power_args, 'stage_times', stage_times);
verifyNameValue(testCase, power_args, 'stage_vals', single(stage_vals));
verifyNameValue(testCase, phase_args, 'stage_times', stage_times);
verifyNameValue(testCase, phase_args, 'stage_vals', single(stage_vals));
end

function writeComputePeakSOpowerStub(filename)
writeStub(filename, {
    'function [stats_table, SOpower, SOpower_times, norm_method] = computePeakSOpower(stats_table, data, Fs, varargin)'
    'setappdata(groot, ''DYNAMOTestComputePeakSOpowerArgs'', varargin);'
    'stats_table.SOpower = ones(height(stats_table), 1);'
    'SOpower = ones(1, numel(data));'
    'SOpower_times = (0:numel(data)-1)/Fs;'
    'norm_method = ''shift'';'
    'end'
    });
end

function writeComputePeakSOphaseStub(filename)
writeStub(filename, {
    'function [stats_table, SOphase, SOphase_times, SOdata] = computePeakSOphase(stats_table, data, Fs, varargin)'
    'setappdata(groot, ''DYNAMOTestComputePeakSOphaseArgs'', varargin);'
    'stats_table.SOphase = zeros(height(stats_table), 1);'
    'SOphase = zeros(1, numel(data));'
    'SOphase_times = (0:numel(data)-1)/Fs;'
    'SOdata = zeros(1, numel(data));'
    'end'
    });
end

function writeSOpowerphaseHistogramStub(filename)
writeStub(filename, {
    'function [SOpower_mat, SOphase_mat, SOpower_bins, SOphase_bins, freq_bins, num_peaks_at_freq, SOpower_TIB, SOphase_TIB, peak_SOpower, peak_SOphase, peak_selection_inds, SOpower, SOpower_times, SOphase, SOphase_times, SOdata, soph_timings] = SOpowerphaseHistogram(~, ~, ~, TFpeak_times, varargin)'
    'SOpower_mat = 1;'
    'SOphase_mat = 1;'
    'SOpower_bins = 1;'
    'SOphase_bins = 0;'
    'freq_bins = 10;'
    'num_peaks_at_freq = numel(TFpeak_times);'
    'SOpower_TIB = 1;'
    'SOphase_TIB = 1;'
    'peak_SOpower = ones(size(TFpeak_times));'
    'peak_SOphase = zeros(size(TFpeak_times));'
    'peak_selection_inds = true(size(TFpeak_times));'
    'SOpower = 1;'
    'SOpower_times = 0;'
    'SOphase = 0;'
    'SOphase_times = 0;'
    'SOdata = 0;'
    'soph_timings = struct(''sopower_compute'', 0, ''sophase_compute'', 0, ''sopower_hist'', 0, ''sophase_hist'', 0);'
    'end'
    });
end

function writeSetupParallelPoolStub(filename)
writeStub(filename, {
    'function setup_parallel_pool(varargin)'
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

function verifyNameValue(testCase, args, name, expected)
is_name = cellfun(@(x) (ischar(x) || (isstring(x) && isscalar(x))) && ...
    strcmp(x, name), args);
testCase.assertTrue(any(is_name), ...
    sprintf('Missing name-value argument: %s', name));
name_idx = find(is_name, 1);
testCase.verifyEqual(args{name_idx + 1}, expected);
end

function removeRootAppData(keys)
for k = 1:numel(keys)
    if isappdata(groot, keys{k})
        rmappdata(groot, keys{k});
    end
end
end
