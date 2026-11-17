function tests = test_prefphase_outside_phase_window
%TEST_PREFPHASE_OUTSIDE_PHASE_WINDOW  PrefPhase and Coupling are NaN where the phase fit has no model
%
%   The phase fit covers its own frequency window. A power mode whose
%   frequency bin lies outside that window has no phase model to read, so
%   annotatePowerWithPreferredPhase reports NaN for it. Modes inside the
%   window keep the argmax of the fitted phase model.
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<*INUSD>
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('runDYNAMO'))
    addpath(repo_root); init_DYNAMO();
end
end

function test_modes_outside_the_window_are_nan(testCase)
[T, freq_bins, phase_bins, model] = example_inputs();
T = annotatePowerWithPreferredPhase(T, [], freq_bins, phase_bins, model, [10 14]);

% Modes at 12.3 Hz and 10.2 Hz read bins 12 and 10, inside the window.
verifyEqual(testCase, T.PrefPhase(1), phase_bins(2));
verifyEqual(testCase, T.Coupling(1), 0.7);
verifyEqual(testCase, T.PrefPhase(2), phase_bins(2));

% Modes at 7.5 Hz and 15.9 Hz read bins 8 and 16, outside the window.
verifyTrue(testCase, all(isnan(T.PrefPhase(3:4))));
verifyTrue(testCase, all(isnan(T.Coupling(3:4))));
end

function test_without_limits_every_mode_is_read(testCase)
[T, freq_bins, phase_bins, model] = example_inputs();
T = annotatePowerWithPreferredPhase(T, [], freq_bins, phase_bins, model);
verifyFalse(testCase, any(isnan(T.PrefPhase)));
verifyEqual(testCase, T.Coupling, 0.7 * ones(4, 1));
end

function test_failed_phase_fit_is_all_nan(testCase)
[T, freq_bins, phase_bins] = example_inputs();
T = annotatePowerWithPreferredPhase(T, [], freq_bins, phase_bins, [], [10 14]);
verifyTrue(testCase, all(isnan(T.PrefPhase)));
verifyTrue(testCase, all(isnan(T.Coupling)));
end

function [T, freq_bins, phase_bins, model] = example_inputs()
% Four modes on a 5-bin frequency axis, with a phase model that peaks at
% the second phase bin for every frequency
freq_bins = [8 10 12 14 16];
phase_bins = [-2 -1 1 2];
model = repmat([0.2; 0.7; 0.4; 0.1], 1, numel(freq_bins));   % [phase x freq]
T = table([12.3; 10.2; 7.5; 15.9], 'VariableNames', {'FreqMean'});
end
