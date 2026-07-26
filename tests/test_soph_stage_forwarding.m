function tests = test_soph_stage_forwarding
%TEST_SOPH_STAGE_FORWARDING  Stage arguments reach low-level SO functions.
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
writeComputeSOpowerStub(fullfile(stub_folder.Folder, 'computeSOpower.m'));
writeComputeSOphaseStub(fullfile(stub_folder.Folder, 'computeSOphase.m'));
testCase.applyFixture(PathFixture(stub_folder.Folder, 'Position', 'begin'));

clear computeSOpower computeSOphase computePeakSOphase SOpowerphaseHistogram
testCase.assertEqual(which('computeSOpower'), ...
    fullfile(stub_folder.Folder, 'computeSOpower.m'));
testCase.assertEqual(which('computeSOphase'), ...
    fullfile(stub_folder.Folder, 'computeSOphase.m'));
end

function teardownOnce(~)
clear computeSOpower computeSOphase computePeakSOphase SOpowerphaseHistogram
removeRootAppData({'DYNAMOTestComputeSOpowerArgs', ...
    'DYNAMOTestComputeSOphaseArgs'});
end

function test_computePeakSOphase_forwards_stages(testCase)
removeRootAppData({'DYNAMOTestComputeSOphaseArgs'});

stage_times = single([0 2 5]);
stage_vals = single([2 5 5]);
stats_table = table(0.5, 'VariableNames', {'PeakTime'});

computePeakSOphase(stats_table, zeros(5, 1), 1, ...
    'stage_times', stage_times, 'stage_vals', stage_vals);

captured_args = getappdata(groot, 'DYNAMOTestComputeSOphaseArgs');
verifyNameValue(testCase, captured_args, 'stage_times', stage_times);
verifyNameValue(testCase, captured_args, 'stage_vals', stage_vals);
end

function test_SOpowerphaseHistogram_forwards_stages(testCase)
removeRootAppData({'DYNAMOTestComputeSOpowerArgs', ...
    'DYNAMOTestComputeSOphaseArgs'});

stage_times = single([0 2 5]);
stage_vals = single([2 5 5]);
[~, ~, ~, ~, ~, ~, ~, ~, ~, ~, peak_selection_inds] = ...
    SOpowerphaseHistogram(zeros(5, 1), 1, [10 11], [0.5 2.5], ...
    'stage_times', stage_times, 'stage_vals', stage_vals, ...
    'SOPH_stages', [2 5], ...
    'freq_range', [9 12], 'freq_binsizestep', [1 1], ...
    'compute_rate', false, ...
    'SOpower_min_time_in_bin', 0, ...
    'SOpower_range', [0 2], 'SOpower_binsizestep', [1 1], ...
    'SOphase_min_peak_at_freq', 0, 'SOphase_norm_dim', 0, ...
    'SOphase_range', [-pi pi], ...
    'SOphase_binsizestep', [pi/2 pi/2], ...
    'backend', 'matlab', 'verbose', false);

power_args = getappdata(groot, 'DYNAMOTestComputeSOpowerArgs');
phase_args = getappdata(groot, 'DYNAMOTestComputeSOphaseArgs');
verifyNameValue(testCase, power_args, 'stage_times', stage_times);
verifyNameValue(testCase, power_args, 'stage_vals', stage_vals);
verifyNameValue(testCase, phase_args, 'stage_times', stage_times);
verifyNameValue(testCase, phase_args, 'stage_vals', stage_vals);
testCase.verifyEqual(peak_selection_inds, logical([true true]));
end

function writeComputeSOpowerStub(filename)
writeStub(filename, {
    'function [SOpower, SOpower_times, SOpower_stages, norm_method, ptile] = computeSOpower(data, Fs, varargin)'
    'setappdata(groot, ''DYNAMOTestComputeSOpowerArgs'', varargin);'
    'SOpower_times = (0:numel(data)-1)/Fs;'
    'SOpower = ones(size(SOpower_times));'
    'SOpower_stages = true(size(SOpower_times));'
    'norm_method = ''shift'';'
    'ptile = 0;'
    'end'
    });
end

function writeComputeSOphaseStub(filename)
writeStub(filename, {
    'function [SOphase, SOphase_times, SOphase_stages, SOdata] = computeSOphase(data, Fs, varargin)'
    'setappdata(groot, ''DYNAMOTestComputeSOphaseArgs'', varargin);'
    'SOphase_times = (0:numel(data)-1)/Fs;'
    'SOphase = zeros(size(SOphase_times));'
    'SOphase_stages = true(size(SOphase_times));'
    'SOdata = zeros(size(SOphase_times));'
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
