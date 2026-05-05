function tests = test_simulation_truth
%TEST_SIMULATION_TRUTH  Function-based unit tests against ground truth.
%
%   Loads tests/simulation_test.mat (data, Fs, true_values table with
%   Time, Frequency, Phase columns), runs runDYNAMO on both backends
%   ONCE in setupOnce, Hungarian-matches each backend's stats_table to
%   true_values, and exposes the matched per-peak deltas to a battery
%   of sub-tests via testCase.TestData.
%
%   The phase-bias sub-tests are the regression-guard for commit b59fa85
%   (2022-09-28), which silently dropped the `-1` from the
%   WeightedCentroid conversion in computePeakStatsTable.m and biased
%   every PeakTime by one spectrogram bin (~+13 deg of SOphase).
%
%   Run individually:
%       runtests('tests/test_simulation_truth')
%   Or via the bundle runner:
%       run_all_tests
tests = functiontests(localfunctions);
end

% =====================================================================
% Setup — run both backends once, build matched pairs for every test.
% =====================================================================

function setupOnce(testCase)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
data_path = fullfile(this_dir, 'simulation_test.mat');
testCase.assertEqual(exist(data_path, 'file'), 2, ...
    sprintf('simulation_test.mat not found at %s', data_path));

if isempty(which('runDYNAMO'))
    addpath(repo_root);
    DYNAMO_addpath();
end

S = load(data_path);
data = double(S.data(:));
Fs   = double(S.Fs);
TV   = S.true_values;
testCase.TestData.TV = TV;
testCase.TestData.Fs = Fs;

stage_times = [0, (numel(data)-1)/Fs];
stage_vals  = [2, 2];
common = {'plot_on', false, 'fit_param_basis', false, ...
    'fit_spline_basis', false, 'verbose', false, ...
    'save_output_image', false};

backends = {'matlab', 'rust'};
results = struct();
for k = 1:numel(backends)
    bk = backends{k};
    fprintf('  [setupOnce] running %s backend...\n', bk);
    t0 = tic;
    [st, ~, ~, ~, ~, ~, ~, ~, ~] = runDYNAMO(data, Fs, stage_times, ...
        stage_vals, common{:}, 'backend', bk);
    fprintf('    done in %.1fs, %d peaks\n', toc(t0), height(st));
    results.(bk) = st;
end
testCase.TestData.results = results;

% Hungarian-match each backend to ground truth (block-decomposed by time).
for k = 1:numel(backends)
    bk = backends{k};
    P = match_to_truth(results.(bk), TV);
    testCase.TestData.match.(bk) = P;
end

% Cross-backend pairing (greedy NN within tight (t, f) window).
[idx, dist] = knnsearch( ...
    [results.matlab.PeakTime/0.5, results.matlab.PeakFrequency/0.5], ...
    [results.rust.PeakTime/0.5,   results.rust.PeakFrequency/0.5]);
tight = dist < 0.1;
testCase.TestData.cross_dt = ...
    results.rust.PeakTime(tight) - results.matlab.PeakTime(idx(tight));

% MTS equivalence: compute the same multitaper spectrogram via the
% MATLAB-Coder MEX and the Rust MEX, expose the per-element diff
% statistics for assertion sub-tests below. Only run if both binaries
% are on the path; otherwise leave testCase.TestData.mts empty so
% downstream sub-tests can skip cleanly.
testCase.TestData.mts = [];
have_coder = exist(['multitaper_spectrogram_coder_mex.' mexext], 'file') == 3;
have_rust  = exist(['multitaper_spectrogram_rust_mex.' mexext],  'file') == 3;
if have_coder && have_rust
    freq_range    = [0 30];
    taper_params  = [2 3];
    window_params = [1 0.05];
    nfft = 2^nextpow2(round(window_params(1)*Fs)/0.1);
    detrend_opt = 'linear'; weighting = 'unity';
    NW = taper_params(1); K = taper_params(2);
    winN = round(window_params(1)*Fs);
    [tapers, ~] = dpss(winN, NW, K);

    [s_m, t_m, f_m] = multitaper_spectrogram_mex(data, Fs, freq_range, ...
        taper_params, window_params, nfft, detrend_opt, weighting, false, false);
    [s_r, t_r, f_r] = multitaper_spectrogram_rust_mex(data, Fs, freq_range, ...
        taper_params, window_params, tapers, [], nfft, detrend_opt, weighting);

    M = struct();
    M.size_match   = isequal(size(s_m), size(s_r));
    M.stimes_diff  = max(abs(double(t_m(:)) - double(t_r(:))));
    M.sfreqs_diff  = max(abs(double(f_m(:)) - double(f_r(:))));
    if M.size_match
        sm = double(s_m(:)); sr = double(s_r(:));
        M.cosine_sim    = sum(sm .* sr) / (norm(sm) * norm(sr));
        M.mean_rel_diff = mean(abs(sm - sr) ./ max(abs(sm), 1e-30));
    else
        M.cosine_sim = NaN; M.mean_rel_diff = NaN;
    end
    testCase.TestData.mts = M;
end
end

% =====================================================================
% Per-backend recall: every true peak must be matched.
% =====================================================================

function test_recall_matlab(testCase)
P = testCase.TestData.match.matlab;
testCase.verifyEqual(size(P.pairs, 1), height(testCase.TestData.TV), ...
    'MATLAB recall is below 100% — some true peaks unmatched.');
end

function test_recall_rust(testCase)
P = testCase.TestData.match.rust;
testCase.verifyEqual(size(P.pairs, 1), height(testCase.TestData.TV), ...
    'Rust recall is below 100% — some true peaks unmatched.');
end

% =====================================================================
% Per-backend bias against ground truth.
% spect_step = 0.05 s by default; bias must be under half a bin in time.
% =====================================================================

function test_time_bias_matlab(testCase)
md = abs(median(testCase.TestData.match.matlab.dt));
testCase.verifyLessThan(md, 0.025, ...
    sprintf('MATLAB |median dt| = %.4fs >= 0.025 (half a spect bin)', md));
end

function test_time_bias_rust(testCase)
md = abs(median(testCase.TestData.match.rust.dt));
testCase.verifyLessThan(md, 0.025, ...
    sprintf('Rust |median dt| = %.4fs >= 0.025 (half a spect bin)', md));
end

function test_freq_bias_matlab(testCase)
md = abs(median(testCase.TestData.match.matlab.df));
testCase.verifyLessThan(md, 0.5, ...
    sprintf('MATLAB |median df| = %.4fHz >= 0.5', md));
end

function test_freq_bias_rust(testCase)
md = abs(median(testCase.TestData.match.rust.df));
testCase.verifyLessThan(md, 0.5, ...
    sprintf('Rust |median df| = %.4fHz >= 0.5', md));
end

function test_phase_bias_matlab(testCase)
% Regression guard for b59fa85 (PeakTime +1-bin bias). Pre-fix: +12.6deg.
% Post-fix: ~-1deg. Threshold of 5deg leaves comfortable headroom.
md_deg = abs(rad2deg(median(testCase.TestData.match.matlab.dphase, 'omitnan')));
testCase.verifyLessThan(md_deg, 5.0, ...
    sprintf('MATLAB |median dphase| = %.2fdeg >= 5deg', md_deg));
end

function test_phase_bias_rust(testCase)
md_deg = abs(rad2deg(median(testCase.TestData.match.rust.dphase, 'omitnan')));
testCase.verifyLessThan(md_deg, 5.0, ...
    sprintf('Rust |median dphase| = %.2fdeg >= 5deg', md_deg));
end

% =====================================================================
% Cross-backend agreement.
% =====================================================================

function test_cross_backend_dt(testCase)
cross = testCase.TestData.cross_dt;
testCase.assertNotEmpty(cross, 'No matched MATLAB-Rust peak pairs found.');
md = abs(median(cross));
testCase.verifyLessThan(md, 0.001, ...
    sprintf('MATLAB-Rust |median dt| = %.5fs >= 0.001s', md));
end

% =====================================================================
% MTS equivalence — Coder MEX (f32) vs Rust MEX (f64) on the same data.
% Outputs should agree up to f32 roundoff (~1e-7 relative).
% =====================================================================

function test_mts_size_match(testCase)
M = testCase.TestData.mts;
testCase.assumeNotEmpty(M, ...
    'multitaper_spectrogram_(coder|rust)_mex not both on path; skipping MTS equivalence.');
testCase.verifyTrue(M.size_match, ...
    'MATLAB and Rust MTS produced different output sizes.');
testCase.verifyLessThan(M.stimes_diff, 1e-9, ...
    sprintf('stimes mismatch: max|diff| = %.3g', M.stimes_diff));
testCase.verifyLessThan(M.sfreqs_diff, 1e-9, ...
    sprintf('sfreqs mismatch: max|diff| = %.3g', M.sfreqs_diff));
end

function test_mts_cosine_similarity(testCase)
M = testCase.TestData.mts;
testCase.assumeNotEmpty(M, 'MTS test pair not built; skipping.');
testCase.verifyGreaterThan(M.cosine_sim, 0.99999, ...
    sprintf('Coder vs Rust MTS cosine sim = %.6f < 0.99999', M.cosine_sim));
end

function test_mts_mean_relative_diff(testCase)
M = testCase.TestData.mts;
testCase.assumeNotEmpty(M, 'MTS test pair not built; skipping.');
% f32 roundoff is ~1.2e-7. Allow 1e-5 to absorb summed roundoff over
% many windows + the slight detrend-numerical-stability differences
% between scipy.signal.detrend (Rust path) and the Coder MEX.
testCase.verifyLessThan(M.mean_rel_diff, 1e-5, ...
    sprintf('Coder vs Rust MTS mean|rel diff| = %.3g >= 1e-5', M.mean_rel_diff));
end

% =====================================================================
% Hungarian matching helper (local, not a test).
% Returns a struct with .pairs (Nx2: [tv_idx, det_idx]), .dt, .df, .dphase.
% =====================================================================

function P = match_to_truth(st, TV)
t_det = st.PeakTime; f_det = st.PeakFrequency;
if ismember('SOphase', st.Properties.VariableNames)
    ph_det = st.SOphase;
else
    ph_det = nan(size(t_det));
end

dt_scale = 0.5; df_scale = 2.0; unmatch = 1.0;
chunk_dur = 30.0; overlap = 1.0;

t_lo = min(min(TV.Time), min(t_det));
t_hi = max(max(TV.Time), max(t_det));
edges = t_lo:chunk_dur:(t_hi+chunk_dur);

pairs = zeros(0, 2);
for c = 1:numel(edges)-1
    a = edges(c) - overlap; b = edges(c+1) + overlap;
    ti = find(TV.Time >= a & TV.Time < b);
    di = find(t_det >= a & t_det < b);
    if isempty(ti) || isempty(di), continue; end
    DT = TV.Time(ti) - reshape(t_det(di), 1, []);
    DF = TV.Frequency(ti) - reshape(f_det(di), 1, []);
    cost = sqrt((DT/dt_scale).^2 + (DF/df_scale).^2);
    cost(cost >= unmatch) = unmatch;
    M = matchpairs(cost, unmatch);
    if isempty(M), continue; end
    own = TV.Time(ti(M(:,1))) >= edges(c) & TV.Time(ti(M(:,1))) < edges(c+1);
    pairs = [pairs; ti(M(own,1)), di(M(own,2))]; %#ok<AGROW>
end

P.pairs  = pairs;
P.dt     = t_det(pairs(:,2)) - TV.Time(pairs(:,1));
P.df     = f_det(pairs(:,2)) - TV.Frequency(pairs(:,1));
P.dphase = wrapToPi(ph_det(pairs(:,2)) - TV.Phase(pairs(:,1)));
end
