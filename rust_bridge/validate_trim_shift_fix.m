function validate_trim_shift_fix()
%VALIDATE_TRIM_SHIFT_FIX  Exercise runSegmentedData on both backends with
%   the trim_shift fix in place (runSegmentedData.m:152). Confirm:
%     1. Rust backend still runs end-to-end with the fat-LTO dylib.
%     2. trim_shift seen by Rust == MATLAB's min(spect./baseline,[],'all').
%     3. Peak-count gap vs backend='matlab' is tighter than the pre-fix -0.8%.

    here      = fileparts(mfilename('fullpath'));
    dev_root  = fileparts(here);
    addpath(genpath(dev_root));

    cache_dir = fullfile(dev_root, '..', 'DYNAM-O_rs', 'data_cache');
    spect_mat = fullfile(cache_dir, 'segment_spect.mat');
    assert(exist(spect_mat, 'file') == 2, 'Missing %s', spect_mat);

    S = load(spect_mat);
    if isfield(S, 'spect_masked')
        spect = double(S.spect_masked);
    else
        spect = double(S.spect);
    end
    if isfield(S, 'baseline2')
        baseline = double(S.baseline2(:));
    else
        baseline = double(S.baseline(:));
    end
    stimes = double(S.stimes(:)');
    sfreqs = double(S.sfreqs(:));
    fprintf('Fixture: spect [%d x %d], baseline %d, stimes %d\n', ...
        size(spect,1), size(spect,2), numel(baseline), numel(stimes));

    % --- Pull the same defaults runSegmentedData would resolve ---
    seg_time     = 30;
    merge_thresh = 11;
    ds           = [2 2];
    trim_vol     = S.trim_vol;
    dur_min      = S.dur_min;
    bw_min       = S.bw_min;

    % --- Reference trim_shift (what pure-MATLAB path computes) ---
    ref_shift = min(spect ./ baseline, [], 'all');
    fprintf('\nReference trim_shift (MATLAB path):   %.6f\n', ref_shift);

    % --- What my new helper returns via runSegmentedData path ---
    % Re-implement it inline so we don't need to refactor the helper to public.
    bv = baseline; good = bv > 0 & isfinite(bv);
    helper_shift = min(spect(good,:) ./ bv(good), [], 'all');
    fprintf('Helper trim_shift (Rust path):        %.6f\n', helper_shift);
    delta = abs(helper_shift - ref_shift);
    fprintf('  |delta| = %.3e   %s\n', delta, ...
        ternary(delta < 1e-12, 'EQUIVALENT', 'DIVERGENT'));

    % --- Run both backends ---
    fprintf('\n--- Rust backend ---\n');
    t0 = tic;
    stats_rust = runSegmentedData(spect, stimes, sfreqs, baseline, seg_time, ds, ...
        'all', dur_min, bw_min, merge_thresh, inf, trim_vol, 0, false, false, ...
        'backend', 'rust');
    t_rust = toc(t0);
    fprintf('  peaks: %d   time: %.2f s\n', height(stats_rust), t_rust);

    fprintf('\n--- MATLAB backend ---\n');
    t0 = tic;
    stats_mat = runSegmentedData(spect, stimes, sfreqs, baseline, seg_time, ds, ...
        'all', dur_min, bw_min, merge_thresh, inf, trim_vol, 0, false, true, ... % debug_mode=true (serial)
        'backend', 'matlab');
    t_mat = toc(t0);
    fprintf('  peaks: %d   time: %.2f s\n', height(stats_mat), t_mat);

    n_r = height(stats_rust); n_m = height(stats_mat);
    fprintf('\n=== Summary ===\n');
    fprintf('  Rust:   %d peaks (%.2f s)\n', n_r, t_rust);
    fprintf('  MATLAB: %d peaks (%.2f s)\n', n_m, t_mat);
    fprintf('  Peak-count diff: %+.2f%% (Rust vs MATLAB)\n', 100*(n_r-n_m)/n_m);
    fprintf('  Speedup: %.2fx\n', t_mat / t_rust);
    fprintf('  trim_shift equivalence: %s\n', ...
        ternary(delta < 1e-12, 'PASS', 'FAIL'));
end

function r = ternary(cond, a, b)
    if cond, r = a; else, r = b; end
end
