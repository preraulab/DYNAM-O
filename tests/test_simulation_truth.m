function test_simulation_truth(varargin)
%TEST_SIMULATION_TRUTH  Unit test: detected peaks vs ground truth.
%
%   Loads example_data/simulation_truth_data.mat (data + Fs + a 735-row
%   true_values table with Time, Frequency, Amplitude, Duration, Phase),
%   runs runDYNAMO on both backends, Hungarian-matches each backend's
%   stats_table to true_values, and asserts that:
%
%     * recall:         all true peaks matched
%     * |median(dt)|    < spect_step / 2  (peak time bias < half a bin)
%     * |median(df)|    < freq_step / 2   (peak freq bias < half a bin)
%     * |median(dphase)| < 5 degrees      (SO-phase bias near noise floor)
%     * MATLAB ↔ Rust per-peak |median dt| < 1 ms
%
%   The phase assertion is the regression-guard for commit b59fa85
%   (2022-09-28), which silently dropped a `-1` from the WeightedCentroid
%   conversion in computePeakStatsTable.m and biased every PeakTime by
%   one spectrogram bin (~+13 deg of SOphase). Restoring that `-1`
%   collapses the bias from +12.6 deg to -2.1 deg.
%
%   Usage:
%       test_simulation_truth()
%       test_simulation_truth('backends', {'matlab','rust'})
%       test_simulation_truth('backends', {'rust'})  % skip MATLAB if MEX-only
%
%   Returns a non-zero exit when run via `matlab -batch` and any assertion
%   fails, suitable for CI.

p = inputParser;
addParameter(p, 'backends', {'matlab','rust'});
addParameter(p, 'verbose', false);
parse(p, varargin{:});
backends = p.Results.backends;
verbose  = p.Results.verbose;

% --- Locate inputs ---
% tests/simulation_test.mat schema: data (1xN numeric), Fs (scalar),
% true_values (table with at least Time, Frequency, Phase columns).
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
data_path = fullfile(this_dir, 'simulation_test.mat');
assert(exist(data_path, 'file') == 2, ...
    'test_simulation_truth: data file not found at %s', data_path);

if isempty(which('runDYNAMO'))
    addpath(repo_root);
    DYNAMO_addpath();
end

S = load(data_path);
data = double(S.data(:));
Fs   = double(S.Fs);
TV   = S.true_values;
fprintf('Simulation: Fs=%.2f Hz, %d samples (%.1fs), %d true peaks\n', ...
    Fs, numel(data), numel(data)/Fs, height(TV));

% Synthetic single-stage covering the whole recording (entire night = N2).
total_dur = (numel(data)-1)/Fs;
stage_times = [0, total_dur];
stage_vals  = [2, 2];

common = {'plot_on', false, 'fit_param_basis', false, ...
    'fit_spline_basis', false, 'verbose', verbose, ...
    'save_output_image', false};

results = struct();
for k = 1:numel(backends)
    bk = backends{k};
    fprintf('\n--- Running %s backend ---\n', bk);
    t0 = tic;
    [st, ~, ~, ~, ~, ~, ~, ~, ~] = runDYNAMO(data, Fs, stage_times, stage_vals, ...
        common{:}, 'backend', bk);
    t_elapsed = toc(t0);
    fprintf('  done in %.1fs, %d peaks\n', t_elapsed, height(st));
    results.(bk) = st;
end

% --- Hungarian-match each backend to ground truth ---
% Cost = sqrt((dt/0.5s)^2 + (df/0.5Hz)^2). Unmatched cost = 1.0. Block by
% time-chunks so matchpairs's dense (m+n)^2 internal allocation stays small.
dt_scale = 0.5;  df_scale = 2.0;  unmatch = 1.0;
chunk_dur = 30.0; overlap = 1.0;

per = struct();
for k = 1:numel(backends)
    bk = backends{k};
    st = results.(bk);
    t_det = st.PeakTime; f_det = st.PeakFrequency;
    if ismember('SOphase', st.Properties.VariableNames)
        ph_det = st.SOphase;
    else
        ph_det = nan(size(t_det));
    end

    pairs = zeros(0, 2);
    t_lo = min(min(TV.Time), min(t_det));
    t_hi = max(max(TV.Time), max(t_det));
    edges = t_lo:chunk_dur:(t_hi+chunk_dur);
    for c = 1:numel(edges)-1
        a = edges(c) - overlap; b = edges(c+1) + overlap;
        ti = find(TV.Time >= a & TV.Time < b);
        di = find(t_det >= a & t_det < b);
        if isempty(ti) || isempty(di), continue; end
        DT = TV.Time(ti) - reshape(t_det(di),1,[]);
        DF = TV.Frequency(ti) - reshape(f_det(di),1,[]);
        cost = sqrt((DT/dt_scale).^2 + (DF/df_scale).^2);
        cost(cost >= unmatch) = unmatch;
        M = matchpairs(cost, unmatch);
        if isempty(M), continue; end
        own = TV.Time(ti(M(:,1))) >= edges(c) & TV.Time(ti(M(:,1))) < edges(c+1);
        pairs = [pairs; ti(M(own,1)), di(M(own,2))]; %#ok<AGROW>
    end

    dt = t_det(pairs(:,2)) - TV.Time(pairs(:,1));
    df = f_det(pairs(:,2)) - TV.Frequency(pairs(:,1));
    dphase = wrapToPi(ph_det(pairs(:,2)) - TV.Phase(pairs(:,1)));

    per.(bk).pairs   = pairs;
    per.(bk).dt      = dt;
    per.(bk).df      = df;
    per.(bk).dphase  = dphase;

    fprintf('\n=== %s vs ground truth ===\n', bk);
    fprintf('  matched: %d/%d true peaks (%d unmatched detections)\n', ...
        size(pairs,1), height(TV), height(st)-size(pairs,1));
    fprintf('  median dt     = %+.5fs   (mean %+.5f, std %.5f)\n', ...
        median(dt), mean(dt), std(dt));
    fprintf('  median df     = %+.5fHz  (mean %+.5f, std %.5f)\n', ...
        median(df), mean(df), std(df));
    fprintf('  median dphase = %+.5frad (%+.2fdeg)  (mean %+.4f, std %.4f)\n', ...
        median(dphase,'omitnan'), rad2deg(median(dphase,'omitnan')), ...
        mean(dphase,'omitnan'), std(dphase,'omitnan'));
end

% --- Assertions ---
spect_step = 0.05;     % default detection_options spect step
freq_step_assert = 0.5; % Hz; spectrogram freq grid is dense, peak detection adds variance
phase_tol_deg = 5.0;

n_fail = 0;
for k = 1:numel(backends)
    bk = backends{k};
    P = per.(bk);
    if size(P.pairs, 1) ~= height(TV)
        fprintf('FAIL [%s]: matched %d/%d (expected %d)\n', ...
            bk, size(P.pairs,1), height(TV), height(TV));
        n_fail = n_fail + 1;
    end
    if abs(median(P.dt)) >= spect_step / 2
        fprintf('FAIL [%s]: |median dt| = %.4fs >= %.4f (half a spect bin)\n', ...
            bk, abs(median(P.dt)), spect_step/2);
        n_fail = n_fail + 1;
    end
    if abs(median(P.df)) >= freq_step_assert
        fprintf('FAIL [%s]: |median df| = %.4fHz >= %.4f\n', ...
            bk, abs(median(P.df)), freq_step_assert);
        n_fail = n_fail + 1;
    end
    md_phase_deg = abs(rad2deg(median(P.dphase, 'omitnan')));
    if md_phase_deg >= phase_tol_deg
        fprintf('FAIL [%s]: |median dphase| = %.2fdeg >= %.2f\n', ...
            bk, md_phase_deg, phase_tol_deg);
        n_fail = n_fail + 1;
    end
end

% Cross-backend agreement (only if both ran).
if all(ismember({'matlab','rust'}, backends))
    % Match by PeakTime within ±0.5s, ±0.5Hz, then check |median dt|.
    tm = results.matlab.PeakTime; fm = results.matlab.PeakFrequency;
    tr = results.rust.PeakTime;   fr = results.rust.PeakFrequency;
    [idx, dist] = knnsearch([tm/0.5, fm/0.5], [tr/0.5, fr/0.5]);
    tight = dist < 0.1;
    if any(tight)
        cross_dt = tr(tight) - tm(idx(tight));
        med_cross = abs(median(cross_dt));
        fprintf('\n=== MATLAB vs Rust per-peak ===\n');
        fprintf('  |median dt| = %.5fs (n=%d pairs)\n', med_cross, sum(tight));
        if med_cross >= 0.001
            fprintf('FAIL: MATLAB-Rust |median dt| = %.5fs >= 0.001s\n', med_cross);
            n_fail = n_fail + 1;
        end
    end
end

fprintf('\n');
if n_fail == 0
    fprintf('test_simulation_truth: PASS\n');
else
    fprintf('test_simulation_truth: %d ASSERTION(S) FAILED\n', n_fail);
    error('test_simulation_truth:failed', '%d assertion(s) failed', n_fail);
end
end
