function tests = test_paramfit_model_recovery
%TEST_PARAMFIT_MODEL_RECOVERY  Recover known mode params from a model SOPH.
%
%   Self-contained (no golden snapshot). Synthesize a SOPH surface from
%   KNOWN rotGauss / vmGauss parameters, fit with param_basis_power /
%   param_basis_phase, and verify the planted parameters are recovered.
%   Mirrors the Rust paramfit_model_recovery test with the SAME planted
%   values, so both languages must recover the same ground truth -> a
%   cross-language fidelity check that needs no committed snapshot.
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<*INUSD>
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('runDYNAMO'))
    addpath(repo_root); init_DYNAMO();
end
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
% [amp, fmean, fstd(VARIANCE-form), phasepref, recikappa, theta].
planted = [0.05 11 2.0 1.0 1.2 0.05; ...
           0.04 15 2.5 -1.5 1.5 -0.05];
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
