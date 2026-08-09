function tests = test_paramfit_model_recovery
%TEST_PARAMFIT_MODEL_RECOVERY  Recover known mode params from a model SOPH.
%
%   Self-contained (no golden snapshot). Synthesize a SOPH surface from
%   KNOWN rotGauss / vmGauss parameters, fit with param_basis_power /
%   param_basis_phase, and verify the planted parameters are recovered.
%   The power values mirror the Rust paramfit_model_recovery test. All
%   Gaussian widths are true standard deviations (the kernels carry the factor
%   of one half); the companion Rust implementation must use the same contract
%   for cross-language fidelity. Phase recikappa is a reciprocal-square-root
%   concentration/local small-angle scale whose kernel never changed.
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

% One standard deviation out, a genuine Gaussian falls to exp(-0.5) of its
% peak. exp(-1) here would mean the kernel is missing its factor of one half
% and ystd is really sqrt(2) times the standard deviation it is named after.
testCase.verifyEqual(z_one_std / z_center, exp(-0.5), 'AbsTol', 1e-12);
end

function test_rotgauss_uses_standard_deviations_on_both_axes(testCase)
amp = 3;
ymean = 10; ystd = 1.5;
xmean = 4;  xstd = 6;
z_center = rotGauss(xmean, ymean, amp, ymean, ystd, xmean, xstd, 0);
z_freq_std = rotGauss(xmean, ymean + ystd, amp, ymean, ystd, xmean, xstd, 0);
z_power_std = rotGauss(xmean + xstd, ymean, amp, ymean, ystd, xmean, xstd, 0);

testCase.verifyEqual(z_freq_std / z_center, exp(-0.5), 'AbsTol', 1e-12);
testCase.verifyEqual(z_power_std / z_center, exp(-0.5), 'AbsTol', 1e-12);
end

function test_phase_width_defaults_preserve_historical_range(testCase)
opts = param_basis_opts('phase');
% The historical bounds were 1 and sqrt(15) in the pre-half convention, so
% the standard-deviation equivalents divide by sqrt(2). The physical window
% each bound describes is unchanged.
testCase.verifyEqual(opts.LB_default(3), 1/sqrt(2), 'AbsTol', eps);
testCase.verifyEqual(opts.UB_default(3), sqrt(7.5), 'AbsTol', eps);
end

function test_phase_recikappa_defaults_are_not_rescaled(testCase)
% recikappa (slot 5) is a reciprocal-square-root concentration/local
% small-angle scale whose von Mises kernel did not change. It must NOT move
% with the Gaussian widths -- rescaling by column index rather than by kernel
% would corrupt every phase fit with no error raised.
opts = param_basis_opts('phase');
testCase.verifyEqual(opts.LB_default(5), pi/5, 'AbsTol', eps);
testCase.verifyEqual(opts.UB_default(5), 2*pi, 'AbsTol', eps);
end

function test_power_width_defaults_preserve_historical_range(testCase)
opts = param_basis_opts('power');
testCase.verifyEqual(opts.LB_default(3), 0.1/sqrt(2), 'AbsTol', eps);
testCase.verifyEqual(opts.UB_default(3), 2.5/sqrt(2), 'AbsTol', eps);
testCase.verifyEqual(opts.LB_default(5), 2.5/sqrt(2), 'AbsTol', eps);
testCase.verifyEqual(opts.UB_default(5), 30/sqrt(2), 'AbsTol', eps);
end

function test_phase_center_defaults_span_two_periods(testCase)
opts = param_basis_opts('phase');
testCase.verifyEqual(opts.LB_default(4), -2*pi, 'AbsTol', eps);
testCase.verifyEqual(opts.UB_default(4), 2*pi, 'AbsTol', eps);
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

function test_center_constraint_flags_apply_independently(testCase)
freq_bins = linspace(2, 18, 65).';

power_bins = linspace(-5, 25, 61);
[Pg, Fg] = meshgrid(power_bins, freq_bins);
% Widths are standard deviations, so the historical [1, 4] shape is written
% as [1, 4]/sqrt(2) and the synthesized surface is unchanged.
power_mode = [8, 10, 1/sqrt(2), 5, 4/sqrt(2), 0];
SOPH = rotGauss(Pg, Fg, power_mode(1), power_mode(2), ...
    power_mode(3), power_mode(4), power_mode(5), power_mode(6)) + 0.2;
power_common = { ...
    'prefix_modes', power_mode, 'prefix_modes_order', 0, ...
    'max_peaks', 1, 'criterion', 'max', 'min_amp', 0, ...
    'min_freq_diff', 0, 'verbose', false, 'plot_on', false};

power_freq_params = param_basis_power(SOPH, power_bins, freq_bins, ...
    power_common{:}, ...
    'LB_default', [0.001, 11, 0.1/sqrt(2), -5, 2.5/sqrt(2), -0.03], ...
    'UB_default', [20, 12, 2.5/sqrt(2), 25, 30/sqrt(2), 0.03], ...
    'constrain_freq_center', false, 'constrain_power_center', true);
power_axis_params = param_basis_power(SOPH, power_bins, freq_bins, ...
    power_common{:}, ...
    'LB_default', [0.001, 2, 0.1/sqrt(2), 6, 2.5/sqrt(2), -0.03], ...
    'UB_default', [20, 18, 2.5/sqrt(2), 7, 30/sqrt(2), 0.03], ...
    'constrain_freq_center', true, 'constrain_power_center', false);

testCase.assertSize(power_freq_params, [1, 6]);
testCase.assertSize(power_axis_params, [1, 6]);
testCase.verifyLessThan(abs(power_freq_params(1, 2) - power_mode(2)), 0.1);
testCase.verifyLessThan(abs(power_axis_params(1, 4) - power_mode(4)), 0.1);

phase_bins = linspace(-pi, pi, 41);
[PHg, Fg] = meshgrid(phase_bins, freq_bins);
% Only fstd (col 3) rescales -- col 5 is recikappa and its kernel is unchanged.
phase_mode = [0.05, 10, 1.5/sqrt(2), 0, 1, 0];
SOPhH = normalized_vmGauss(PHg, Fg, true, 0, 0, 0.001, ...
    phase_mode(1), phase_mode(2), phase_mode(3), ...
    phase_mode(4), phase_mode(5), phase_mode(6));
phase_common = { ...
    'prefix_modes', phase_mode, 'prefix_modes_order', 0, ...
    'max_peaks', 1, 'criterion', 'max', 'min_amp', 0, ...
    'verbose', false, 'plot_on', false};

phase_freq_params = param_basis_phase(SOPhH, phase_bins, freq_bins, ...
    phase_common{:}, ...
    'LB_default', [0.001, 11, 1/sqrt(2), -pi, 0.2, -0.2], ...
    'UB_default', [1, 12, 3/sqrt(2), pi, 2, 0.2], ...
    'constrain_freq_center', false, 'constrain_phase_center', true);
phase_axis_params = param_basis_phase(SOPhH, phase_bins, freq_bins, ...
    phase_common{:}, ...
    'LB_default', [0.001, 2, 1/sqrt(2), 1, 0.2, -0.2], ...
    'UB_default', [1, 18, 3/sqrt(2), 2, 2, 0.2], ...
    'constrain_freq_center', true, 'constrain_phase_center', false);

testCase.assertSize(phase_freq_params, [1, 6]);
testCase.assertSize(phase_axis_params, [1, 6]);
testCase.verifyLessThan(abs(phase_freq_params(1, 2) - phase_mode(2)), 0.1);
testCase.verifyLessThan(abs(wrapToPi(phase_axis_params(1, 4) - phase_mode(4))), 0.1);
end

function test_default_phase_bounds_allow_crossing_pi_seam(testCase)
phase_bins = linspace(-pi, pi, 81);
freq_bins = linspace(2, 18, 65).';
[PHg, Fg] = meshgrid(phase_bins, freq_bins);
planted = [0.07, 10.5, 1.4/sqrt(2), -pi + 0.12, 0.9, 0.42];
SOPhH = normalized_vmGauss(PHg, Fg, true, 0.012, 0.35, 0.003, ...
    planted(1), planted(2), planted(3), ...
    planted(4), planted(5), planted(6));
seed = [0.06, 10.2, 1.2/sqrt(2), pi - 0.04, 1, 0.30];

[params, fitobj, gof] = param_basis_phase(SOPhH, phase_bins, freq_bins, ...
    'prefix_modes', seed, 'prefix_modes_order', 0, ...
    'max_peaks', 1, 'criterion', 'max', 'min_amp', 0, ...
    'verbose', false, 'plot_on', false);

raw_params = get_mode_params(fitobj);
testCase.assertSize(params, [1, 6]);
testCase.verifyGreaterThan(raw_params(1, 4), pi, ...
    'The optimizer must be able to cross the +pi seam from this seed.');
testCase.verifyLessThan(abs(wrapToPi(raw_params(1, 4) - planted(4))), 1e-4);
testCase.verifyGreaterThan(gof.adjrsquare, 0.9999);
end

function test_phase_volume_uses_frequency_standard_deviation(testCase)
params = [0.05, 11, 2, 0, 1.2, 0];
out = createSOPHparamfitStruct('phase', params, [], [], [], []);
out_class = DYNAMO.createSOPHparamfitStruct('phase', params, [], [], [], []);
k = 1 / params(5)^2;
expected = params(1) * (2*pi) * besseli(0, k, 1) * sqrt(2*pi) * params(3);

testCase.verifyEqual(out.params.FreqStd, params(3));
testCase.verifyEqual(out.params.Volume, expected, 'RelTol', 1e-12);
testCase.verifyEqual(out_class.params.FreqStd, params(3));
testCase.verifyEqual(out_class.params.Volume, expected, 'RelTol', 1e-12);
end

function test_phase_peak_assignment_uses_frequency_standard_deviation(testCase)
prob = 0.95;
fmean = 10;
fstd = 2;
% Q = 0.5*(dF/fstd)^2 on the freq axis (the von Mises term is zero there), so
% the Q = -log(1-prob) boundary sits at dF/fstd = sqrt(-2*log(1-prob)).
freq_radius = fstd * sqrt(-2*log(1 - prob));
stats_table = table( ...
    [fmean + 0.99*freq_radius; fmean + 1.01*freq_radius], ...
    [0; 0], 'VariableNames', {'PeakFrequency', 'SOphase'});

idx = get_mode_peaks([1, fmean, fstd, 0, 0.5, 0], ...
    'phase', stats_table, prob);
testCase.verifyEqual(idx, [true; false]);
end

function test_power_containment_encloses_the_requested_probability(testCase)
% The pairing of get_mode_peaks' Q with its -log(1-prob) threshold must
% actually enclose `prob` of the fitted Gaussian's mass. This is the guard
% the standard-deviation reparameterization needed and did not have: adding
% the factor of one half to rotGauss.m without adding it to Q leaves every
% other test green while silently dropping containment from 95% to ~77.7%,
% which would shift every Pk* column with no error raised anywhere.
%
% Deterministic midpoint integration of the true bivariate normal the kernel
% represents (sigma_freq = fstd, sigma_power = pstd), no RNG.
fmean = 13; fstd = 1.3;
pmean = 5;  pstd = 7;
mode_params = [0, fmean, fstd, pmean, pstd, 0];

n = 1201;
span = 8;                                        % integrate to +/-8 sigma
edges = linspace(-span, span, n + 1);
z = (edges(1:end-1) + edges(2:end)) / 2;         % midpoints, in sigma units
[ZP, ZF] = meshgrid(z, z);
stats_table = table(fmean + ZF(:).*fstd, pmean + ZP(:).*pstd, ...
    'VariableNames', {'PeakFrequency', 'SOpower'});
dens = exp(-0.5 .* (ZF(:).^2 + ZP(:).^2));
total = sum(dens);

for prob = [0.5, 0.8, 0.95, 0.99]
    idx = get_mode_peaks(mode_params, 'power', stats_table, prob);
    captured = sum(dens(idx)) / total;
    testCase.verifyEqual(captured, prob, 'AbsTol', 2e-3, ...
        sprintf(['prob=%.2f: captured %.5f. A value near 0.777 at ' ...
                 'prob=0.95 means Q lost its factor of one half.'], ...
                 prob, captured));
end
end

function test_phase_empirical_amplitude_uses_circular_distance(testCase)
phase_bins = linspace(-pi, pi, 41);
freq_bins = linspace(2, 18, 65).';
[PHg, Fg] = meshgrid(phase_bins, freq_bins);

% Fit the phase-zero mode through its equivalent 2*pi representation. Both
% the iteration-time min_amp check and final Density lookup must use the
% shortest angular distance to the phase bins. Rust implementations should
% apply the same circular-distance contract before selecting a phase bin.
planted = [0.05, 10, 1.5/sqrt(2), 0, 1, 0];
SOPhH = normalized_vmGauss(PHg, Fg, true, 0, 0, 0.001, ...
    planted(1), planted(2), planted(3), planted(4), planted(5), planted(6));
prefix_mode = planted;
prefix_mode(4) = 2*pi;
LB = [0.001, 9, 0.5/sqrt(2), 2*pi - 0.2, 0.2, -0.2];
UB = [1, 11, 3/sqrt(2), 2*pi + 0.2, 2, 0.2];

warning_id = 'curvefit:sfit:subsasgn:coeffsClearingConfBounds';
warning_state = warning('error', warning_id);
warning_cleanup = onCleanup(@() warning(warning_state));

[params, fitobj] = param_basis_phase(SOPhH, phase_bins, freq_bins, ...
    'prefix_modes', prefix_mode, 'prefix_modes_order', 0, ...
    'max_peaks', 1, 'criterion', 'max', 'min_amp', 0.02, ...
    'LB_default', LB, 'UB_default', UB, ...
    'verbose', false, 'plot_on', false);

warning_state_after_fit = warning('query', warning_id);
testCase.verifyEqual(warning_state_after_fit.state, 'error', ...
    'param_basis_phase must restore the caller warning state.');
testCase.assertSize(params, [1, 6], ...
    'A 2*pi phase alias must not fail the min_amp check.');
raw_params = get_mode_params(fitobj);
coeff_values = coeffvalues(fitobj);
coeff_values(strcmpi(coeffnames(fitobj), 'xxx')) = 0;
fit_values = [num2cell(coeff_values), num2cell(probvalues(fitobj))];
fitobj_nosin = sfit(fittype(fitobj), fit_values{:});
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
% [amp, fmean, fstd, pmean, pstd, theta] -- same as the Rust test. Both
% widths are standard deviations, so the historical shapes are written with
% the sqrt(2) divisor and the synthesized surface is unchanged.
planted = [8 11 1.0/sqrt(2) 5 10/sqrt(2) 0.01; ...
           5 15 0.8/sqrt(2) 12 8/sqrt(2) -0.01];
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

function test_power_revert_returns_selected_gof(testCase)
power_bins = linspace(-2, 20, 41);
freq_bins = linspace(2, 18, 33).';
[Pg, Fg] = meshgrid(power_bins, freq_bins);
modes = [6, 8, 1/sqrt(2), 3, 6/sqrt(2), 0; ...
         4, 12, 1/sqrt(2), 10, 6/sqrt(2), 0];
SOPH = 0.2 + 0.001*Pg + 0.001*Fg;
for m = 1:size(modes, 1)
    p = modes(m, :);
    SOPH = SOPH + rotGauss(Pg, Fg, p(1), p(2), p(3), p(4), p(5), p(6));
end

[params, fitobj, gof, model_SOPH] = param_basis_power( ...
    SOPH, power_bins, freq_bins, ...
    'prefix_modes', modes, 'prefix_modes_order', 0, ...
    'max_peaks', 2, 'criterion', 'max', 'max_overlap', 0, ...
    'min_amp', 0, 'min_freq_diff', 0, ...
    'verbose', false, 'plot_on', false);

testCase.verifyEqual(size(params, 1), 1);
testCase.verifyEqual(num_modes(fitobj), 1);
selected_sse = sum((SOPH - model_SOPH).^2, 'all');
testCase.verifyEqual(gof.sse, selected_sse, 'RelTol', 1e-12, ...
    'gof must describe the selected model after iteration 2 is rejected.');
end

function test_phase_recovers_planted_modes_with_column_bins(testCase)
phase_bins = linspace(-pi, pi, 41).';
freq_bins  = linspace(2, 18, 65).';
% [amp, fmean, fstd, phasepref, recikappa, theta], with fstd a true frequency
% standard deviation in Hz. These values preserve the modeled widths of the
% historical test modes: the original variance-form entries 2.0 and 2.5 become
% sqrt(2.0/2) = 1 and sqrt(2.5/2) = sqrt(1.25). recikappa (col 5) never
% rescales because its von Mises parameterization is unchanged.
planted = [0.05 11 1           1.0 1.2 0.05; ...
           0.04 15 sqrt(1.25) -1.5 1.5 -0.05];
[Fg, PHg] = meshgrid(freq_bins, phase_bins);         % [nPhase x nFreq]
SOPhH = zeros(size(Fg));
for m = 1:size(planted, 1)
    p = planted(m, :);
    SOPhH = SOPhH + vmGauss(PHg, Fg, p(1), p(2), p(3), p(4), p(5), p(6));
end
SOPhH = SOPhH + 0.001;                               % constant background (matches Rust zzz)
SOPhH = SOPhH ./ sum(SOPhH, 1);                      % phase-normalize, as in production

[params, ~, gof, model_SOPhH] = param_basis_phase(SOPhH, phase_bins, freq_bins, ...
    'verbose', false, 'plot_on', false);

testCase.verifyEqual(size(params, 1), size(planted, 1), 'phase mode count');
testCase.verifyGreaterThan(gof.adjrsquare, 0.95);

opts = param_basis_opts('phase');
valid_phase = phase_bins >= opts.phase_limits(1) & phase_bins <= opts.phase_limits(2);
valid_freq = freq_bins >= opts.freq_limits(1) & freq_bins <= opts.freq_limits(2);
fit_data = SOPhH.';
selected_sse = sum((fit_data(valid_freq, valid_phase) - ...
    model_SOPhH(valid_freq, valid_phase)).^2, 'all');
testCase.verifyEqual(gof.sse, selected_sse, 'AbsTol', 1e-10, ...
    'gof must describe the selected model after a rejected iteration.');

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

function test_power_baseline_fallback_returns_matching_gof(testCase)
power_bins = linspace(-5, 25, 41);
freq_bins = linspace(2, 18, 33).';
[Pg, Fg] = meshgrid(power_bins, freq_bins);
mode = [2, 10, 1/sqrt(2), 5, 4/sqrt(2), 0];
SOPH = rotGauss(Pg, Fg, mode(1), mode(2), mode(3), ...
    mode(4), mode(5), mode(6)) + 0.2;

warning_id = 'param_basis_power:noModesFound';
warning_state = warning('off', warning_id);
warning_cleanup = onCleanup(@() warning(warning_state));
[params, fitobj, gof, model_SOPH] = param_basis_power( ...
    SOPH, power_bins, freq_bins, ...
    'prefix_modes', mode, 'prefix_modes_order', 0, ...
    'max_peaks', 1, 'criterion', 'max', 'min_amp', Inf, ...
    'min_freq_diff', 0, 'verbose', false, 'plot_on', false);
clear warning_cleanup

testCase.verifyEmpty(params);
testCase.verifyEqual(num_modes(fitobj), 0);
opts = param_basis_opts('power');
valid_power = power_bins >= opts.power_limits(1) & power_bins <= opts.power_limits(2);
valid_freq = freq_bins >= opts.freq_limits(1) & freq_bins <= opts.freq_limits(2);
selected_sse = sum((SOPH(valid_freq, valid_power) - ...
    model_SOPH(valid_freq, valid_power)).^2, 'all');
testCase.verifyEqual(gof.sse, selected_sse, 'AbsTol', 1e-10, ...
    'gof must describe the background fit returned after iteration 1 is rejected.');
end

function test_phase_baseline_fallback_returns_matching_gof(testCase)
phase_bins = linspace(-pi, pi, 31);
freq_bins = linspace(2, 18, 33).';
[PHg, Fg] = meshgrid(phase_bins, freq_bins);
mode = [0.05, 10, 1.5/sqrt(2), 0, 1, 0];
SOPhH = normalized_vmGauss(PHg, Fg, true, 0, 0, 0.001, ...
    mode(1), mode(2), mode(3), mode(4), mode(5), mode(6));

warning_id = 'param_basis_phase:noModesFound';
warning_state = warning('off', warning_id);
warning_cleanup = onCleanup(@() warning(warning_state));
[params, fitobj, gof, model_SOPhH] = param_basis_phase( ...
    SOPhH, phase_bins, freq_bins, ...
    'prefix_modes', mode, 'prefix_modes_order', 0, ...
    'max_peaks', 1, 'criterion', 'max', 'min_amp', Inf, ...
    'verbose', false, 'plot_on', false);
clear warning_cleanup

testCase.verifyEmpty(params);
testCase.verifyEqual(num_modes(fitobj), 0);
opts = param_basis_opts('phase');
valid_phase = phase_bins >= opts.phase_limits(1) & phase_bins <= opts.phase_limits(2);
valid_freq = freq_bins >= opts.freq_limits(1) & freq_bins <= opts.freq_limits(2);
selected_sse = sum((SOPhH(valid_freq, valid_phase) - ...
    model_SOPhH(valid_freq, valid_phase)).^2, 'all');
testCase.verifyEqual(gof.sse, selected_sse, 'AbsTol', 1e-10, ...
    'gof must describe the background fit returned after iteration 1 is rejected.');
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
