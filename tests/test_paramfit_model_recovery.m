function tests = test_paramfit_model_recovery
%TEST_PARAMFIT_MODEL_RECOVERY  Recover known mode params from a model SOPH.
%
%   Self-contained (no golden snapshot). Synthesize a SOPH surface from
%   KNOWN rotGauss / vmGauss parameters, fit with param_basis_power /
%   param_basis_phase, and verify the planted parameters are recovered.
%   The power values mirror the Rust paramfit_model_recovery test. Phase
%   frequency widths use the standard-deviation contract; the companion Rust
%   implementation must use the same contract for cross-language fidelity.
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<*INUSD>
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('runDYNAMO'))
    addpath(repo_root); init_DYNAMO();
end
end

function test_vmgauss_uses_frequency_standard_deviation(testCase)
amp = 2;
ymean = 10;
ystd = 2.5;
z_center = vmGauss(0, ymean, amp, ymean, ystd, 0, 1, 0);
z_one_std = vmGauss(0, ymean + ystd, amp, ymean, ystd, 0, 1, 0);

testCase.verifyEqual(z_one_std / z_center, exp(-1), 'AbsTol', 1e-12);
end

function test_phase_width_defaults_preserve_historical_range(testCase)
opts = param_basis_opts('phase');
testCase.verifyEqual(opts.LB_default(3), 1);
testCase.verifyEqual(opts.UB_default(3), sqrt(15), 'AbsTol', eps);
end

function test_center_constraint_options_parse(testCase)
power_defaults = param_basis_opts('power');
phase_defaults = param_basis_opts('phase');
power_opts = param_basis_opts('power', ...
    'constrain_freq_center', false, 'constrain_power_center', false);
phase_opts = param_basis_opts('phase', ...
    'constrain_freq_center', false, 'constrain_phase_center', false);

testCase.verifyTrue(power_defaults.constrain_freq_center);
testCase.verifyTrue(power_defaults.constrain_power_center);
testCase.verifyTrue(phase_defaults.constrain_freq_center);
testCase.verifyTrue(phase_defaults.constrain_phase_center);
testCase.verifyFalse(isfield(power_defaults, 'constrain_phase_center'));
testCase.verifyFalse(isfield(phase_defaults, 'constrain_power_center'));
testCase.verifyFalse(power_opts.constrain_freq_center);
testCase.verifyFalse(power_opts.constrain_power_center);
testCase.verifyFalse(phase_opts.constrain_freq_center);
testCase.verifyFalse(phase_opts.constrain_phase_center);
testCase.verifyError(@() param_basis_opts('power', ...
    'constrain_freq_center', 2), 'MATLAB:expectedBinary');
testCase.verifyError(@() param_basis_opts('phase', ...
    'constrain_phase_center', [true, false]), 'MATLAB:expectedScalar');
end

function test_phase_volume_uses_frequency_standard_deviation(testCase)
params = [0.05, 11, 2, 0, 1.2, 0];
out = createSOPHparamfitStruct('phase', params, [], [], [], []);
out_class = DYNAMO.createSOPHparamfitStruct('phase', params, [], [], [], []);
k = 1 / params(5)^2;
expected = params(1) * (2*pi) * besseli(0, k, 1) * sqrt(pi) * params(3);

testCase.verifyEqual(out.params.FreqStd, params(3));
testCase.verifyEqual(out.params.Volume, expected, 'RelTol', 1e-12);
testCase.verifyEqual(out_class.params.FreqStd, params(3));
testCase.verifyEqual(out_class.params.Volume, expected, 'RelTol', 1e-12);
end

function test_phase_peak_assignment_uses_frequency_standard_deviation(testCase)
prob = 0.95;
fmean = 10;
fstd = 2;
freq_radius = fstd * sqrt(-log(1 - prob));
stats_table = table( ...
    [fmean + 0.99*freq_radius; fmean + 1.01*freq_radius], ...
    [0; 0], 'VariableNames', {'PeakFrequency', 'SOphase'});

idx = get_mode_peaks([1, fmean, fstd, 0, 0.5, 0], ...
    'phase', stats_table, prob);
testCase.verifyEqual(idx, [true; false]);
end

function test_phase_empirical_amplitude_uses_circular_distance(testCase)
phase_bins = linspace(-pi, pi, 41);
freq_bins = linspace(2, 18, 65).';
[PHg, Fg] = meshgrid(phase_bins, freq_bins);

% Fit the phase-zero mode through its equivalent 2*pi representation. Both
% the iteration-time min_amp check and final Density lookup must use the
% shortest angular distance to the phase bins. Rust implementations should
% apply the same circular-distance contract before selecting a phase bin.
planted = [0.05, 10, 1.5, 0, 1, 0];
SOPhH = normalized_vmGauss(PHg, Fg, true, 0, 0, 0.001, ...
    planted(1), planted(2), planted(3), planted(4), planted(5), planted(6));
prefix_mode = planted;
prefix_mode(4) = 2*pi;
LB = [0.001, 9, 0.5, 2*pi - 0.2, 0.2, -0.2];
UB = [1, 11, 3, 2*pi + 0.2, 2, 0.2];

[params, fitobj] = param_basis_phase(SOPhH, phase_bins, freq_bins, ...
    'prefix_modes', prefix_mode, 'prefix_modes_order', 0, ...
    'max_peaks', 1, 'criterion', 'max', 'min_amp', 0.02, ...
    'LB_default', LB, 'UB_default', UB, ...
    'verbose', false, 'plot_on', false);

testCase.assertSize(params, [1, 6], ...
    'A 2*pi phase alias must not fail the min_amp check.');
raw_params = get_mode_params(fitobj);
fitobj_nosin = fitobj;
fitobj_nosin.xxx = 0;
model_nosin = feval(fitobj_nosin, PHg, Fg);
[~, freq_idx] = min(abs(freq_bins - raw_params(1, 2)));
[~, phase_idx] = min(abs(wrapToPi(phase_bins - raw_params(1, 4))));
expected_amp = model_nosin(freq_idx, phase_idx);

testCase.verifyEqual(params(1, 1), expected_amp, 'AbsTol', 1e-12, ...
    'Density must be sampled at the circularly nearest phase bin.');
end

function test_power_recovers_planted_modes_with_column_bins(testCase)
power_bins = linspace(-5, 25, 61).';
freq_bins  = linspace(2, 18, 65).';
% [amp, fmean, fstd, pmean, pstd, theta] -- same as the Rust test.
planted = [8 11 1.0 5 10 0.01; ...
           5 15 0.8 12 8 -0.01];
[Fg, Pg] = meshgrid(freq_bins, power_bins);          % [nPower x nFreq]
SOPH = 0.001*Pg + 0.001*Fg + 0.2;                    % background plane
for m = 1:size(planted, 1)
    p = planted(m, :);
    SOPH = SOPH + rotGauss(Pg, Fg, p(1), p(2), p(3), p(4), p(5), p(6));
end

[params, ~, gof] = param_basis_power(SOPH, power_bins, freq_bins, ...
    'verbose', false, 'plot_on', false);

testCase.verifyEqual(size(params, 1), size(planted, 1), 'power mode count');
testCase.verifyGreaterThan(gof.adjrsquare, 0.99);

pairs = match_by_freq(planted, params);
for k = 1:size(pairs, 1)
    p = planted(pairs(k, 1), :);
    r = params(pairs(k, 2), :);
    testCase.verifyLessThan(abs(r(2) - p(2)), 0.1,  'FreqMean');
    testCase.verifyLessThan(abs(r(4) - p(4)), 0.5,  'SOpowerMean');
    testCase.verifyLessThan(abs(r(6) - p(6)), 0.01, 'Theta');
    testCase.verifyLessThan(abs(r(1) - p(1)) / p(1), 0.10, 'amp');
    testCase.verifyLessThan(abs(r(3) - p(3)) / p(3), 0.12, 'FreqStd');
    testCase.verifyLessThan(abs(r(5) - p(5)) / p(5), 0.12, 'SOpowerStd');
end
end

function test_phase_recovers_planted_modes_with_column_bins(testCase)
phase_bins = linspace(-pi, pi, 41).';
freq_bins  = linspace(2, 18, 65).';
% [amp, fmean, fstd, phasepref, recikappa, theta], with fstd in Hz.
% Square roots preserve the modeled widths of the historical test modes.
planted = [0.05 11 sqrt(2.0) 1.0 1.2 0.05; ...
           0.04 15 sqrt(2.5) -1.5 1.5 -0.05];
[Fg, PHg] = meshgrid(freq_bins, phase_bins);         % [nPhase x nFreq]
SOPhH = zeros(size(Fg));
for m = 1:size(planted, 1)
    p = planted(m, :);
    SOPhH = SOPhH + vmGauss(PHg, Fg, p(1), p(2), p(3), p(4), p(5), p(6));
end
SOPhH = SOPhH + 0.001;                               % constant background (matches Rust zzz)
SOPhH = SOPhH ./ sum(SOPhH, 1);                      % phase-normalize, as in production

[params, ~, gof] = param_basis_phase(SOPhH, phase_bins, freq_bins, ...
    'verbose', false, 'plot_on', false);

testCase.verifyEqual(size(params, 1), size(planted, 1), 'phase mode count');
testCase.verifyGreaterThan(gof.adjrsquare, 0.95);

% Phase amp (Density) is overwritten by the empirical no-sin amplitude, so
% it is not asserted; centers + freq width are the recoverable params.
pairs = match_by_freq(planted, params);
for k = 1:size(pairs, 1)
    p = planted(pairs(k, 1), :);
    r = params(pairs(k, 2), :);
    testCase.verifyLessThan(abs(r(2) - p(2)), 0.3, 'FreqMean');
    testCase.verifyLessThan(abs(r(3) - p(3)) / p(3), 0.12, 'FreqStd');
    testCase.verifyLessThan(abs(sin(r(4) - p(4))), 0.15, 'phasepref');  % circular
end
end

function pairs = match_by_freq(planted, recovered)
% Greedy nearest-FreqMean (column 2) match of recovered rows to planted.
nr = size(recovered, 1);
used = false(nr, 1);
pairs = zeros(0, 2);
for pidx = 1:size(planted, 1)
    bd = inf; best = 0;
    for r = 1:nr
        if used(r), continue; end
        d = abs(recovered(r, 2) - planted(pidx, 2));
        if d < bd, bd = d; best = r; end
    end
    if best > 0
        used(best) = true;
        pairs(end + 1, :) = [pidx best]; %#ok<AGROW>
    end
end
end
