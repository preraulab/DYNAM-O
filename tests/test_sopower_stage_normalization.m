function tests = test_sopower_stage_normalization
%TEST_SOPOWER_STAGE_NORMALIZATION  Stage-aware p2shift1234 normalization.
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('runDYNAMO'))
    addpath(repo_root);
    init_DYNAMO();
end
end

function test_p2shift1234_excludes_wake(testCase)
verifyExcludedStage(testCase, 5);
end

function test_p2shift1234_excludes_undefined(testCase)
verifyExcludedStage(testCase, 0);
end

function verifyExcludedStage(testCase, excluded_stage)
Fs = 20;
EEG_times = 0:1/Fs:39.95;

% Keep Wake/Undefined 40 dB below N2. The five-second amplitude lead-in
% ensures every stage-2 multitaper window contains only high-amplitude data.
amplitude = 0.01 * ones(size(EEG_times));
amplitude(EEG_times >= 15) = 1;
data = amplitude .* sin(2*pi*EEG_times);

stage_times = [0 20 40];
stage_vals = [excluded_stage 2 2];
direct_args = { ...
    'EEG_times', EEG_times, ...
    'time_range', [EEG_times(1) EEG_times(end)], ...
    'SO_freqrange', [0.3 1.5], ...
    'tapers', [5 9], ...
    'window_params', [5 0.5], ...
    'SOpower_outlier_threshold', 1e6, ...
    'norm_method', 'p2shift1234', ...
    'retain_Fs', false};

[stage_aware, expected_times, ~, expected_method, stage_ptile] = ...
    computeSOpower(data, Fs, ...
    'stage_times', stage_times, 'stage_vals', stage_vals, direct_args{:});
[stage_blind, blind_times, ~, ~, blind_ptile] = ...
    computeSOpower(data, Fs, direct_args{:});

stats_table = table(25, 'VariableNames', {'PeakTime'});
[~, observed_power, observed_times, observed_method] = ...
    computePeakSOpower(stats_table, data, Fs, ...
    'stage_times', stage_times, 'stage_vals', stage_vals, ...
    'EEG_times', EEG_times, ...
    'time_range', [EEG_times(1) EEG_times(end)], ...
    'SO_freqrange', [0.3 1.5], ...
    'SOpower_tapers', [5 9], ...
    'SOpower_window_params', [5 0.5], ...
    'SOpower_outlier_threshold', 1e6, ...
    'SOpower_norm_method', 'p2shift1234', ...
    'SOpower_retain_Fs', false);

testCase.verifyEqual(blind_times, expected_times);
testCase.verifyGreaterThan(stage_ptile - blind_ptile, 30);
testCase.verifyGreaterThan(max(abs(stage_aware - stage_blind)), 30);
testCase.verifyEqual(observed_times, expected_times);
testCase.verifyEqual(observed_method, expected_method);
testCase.verifyEqual(observed_power, stage_aware, 'AbsTol', 1e-9);
end
