function test_baseline_reuse_compare(varargin)
%TEST_BASELINE_REUSE_COMPARE  Run runDYNAMO twice on the bundled night
%   fixture — once with reuse_baseline=false (current behavior) and once
%   with reuse_baseline=true (the optimization). Capture timings, peak
%   counts, and SOPHs; print a comparison table and show four side-by-
%   side figures.
%
%   Decision criteria after running:
%     - Peak count drift > a few percent OR SOPH cosine similarity < 0.999:
%       optimization shifts behavior too much; shelve.
%     - Drift within noise AND consistent ~5% wall-clock saving:
%       optimization is safe to flip on by default.
%
%   Usage:
%       test_baseline_reuse_compare                        % bundled night
%       test_baseline_reuse_compare('backend', 'rust')     % explicit
%       test_baseline_reuse_compare('warmup', false)       % skip warmup
%
%   Optional name-value:
%       'backend' - 'rust' (default) | 'matlab'
%       'warmup'  - logical, do a discarded warmup per condition (default: true)
%       'fixture' - 'segment' (~1 min, fast) | 'night' (~1 min total, default)

    p = inputParser;
    addParameter(p, 'backend', 'rust', @ischar);
    addParameter(p, 'warmup', true, @islogical);
    addParameter(p, 'fixture', 'night', @ischar);
    parse(p, varargin{:});
    S = p.Results;

    % ---- paths ----
    here = fileparts(mfilename('fullpath'));
    dev_root = fileparts(here);
    addpath(genpath(dev_root));

    fprintf('=================================================================\n');
    fprintf(' Baseline-reuse A/B test\n');
    fprintf('   fixture=%s   backend=%s   warmup=%s\n', ...
        S.fixture, S.backend, ternary(S.warmup,'true','false'));
    fprintf('=================================================================\n\n');

    % ---- run BOTH conditions ----
    if S.warmup
        fprintf('Warmup (discarded)...\n');
        run_one(S.fixture, S.backend, false);
    end

    fprintf('\n[A] reuse_baseline = FALSE (current behavior)\n');
    [stats_A, soph_A, t_A] = run_one(S.fixture, S.backend, false);

    fprintf('\n[B] reuse_baseline = TRUE  (optimization)\n');
    [stats_B, soph_B, t_B] = run_one(S.fixture, S.backend, true);

    % ==================================================================
    % NUMERICAL COMPARISON
    % ==================================================================
    fprintf('\n=================================================================\n');
    fprintf(' Numerical comparison\n');
    fprintf('=================================================================\n');

    % Wall-clock per stage
    fprintf('\nTimings (seconds):\n');
    fprintf('  %-22s %10s %10s %10s\n', 'stage', 'A (compute)', 'B (reuse)', 'delta');
    keys = intersect(fieldnames(t_A), fieldnames(t_B));
    keys = sort_keys(keys);
    for i = 1:numel(keys)
        a = getfield_or(t_A, keys{i}, NaN);
        b = getfield_or(t_B, keys{i}, NaN);
        flag = '';
        if abs(a-b) > 0.5, flag = ' *'; end
        fprintf('  %-22s %10.3f %10.3f %+10.3f%s\n', keys{i}, a, b, b-a, flag);
    end
    fprintf('  %-22s %10.3f %10.3f %+10.3f  (%+.1f%%)\n', 'TOTAL', ...
        t_A.total, t_B.total, t_B.total - t_A.total, ...
        100*(t_B.total - t_A.total)/t_A.total);

    % Peak counts
    nA = height(stats_A);
    nB = height(stats_B);
    fprintf('\nPeak counts:\n');
    fprintf('  reuse=false (A):  %d peaks\n', nA);
    fprintf('  reuse=true  (B):  %d peaks\n', nB);
    fprintf('  drift:            %+d peaks  (%+.2f%%)\n', nB - nA, 100*(nB - nA)/nA);

    % Per-band peak count (distribution by frequency)
    fprintf('\nPer-band peak counts (drift relative to A):\n');
    bands = struct('SO', [0.3 1.5], 'delta', [1 4], 'theta', [4 8], ...
                   'alpha', [8 12], 'sigma', [11 16], 'beta', [13 30]);
    fns = fieldnames(bands);
    fprintf('  %-8s %8s %8s %8s\n', 'band', 'A_count', 'B_count', 'drift%');
    for i = 1:numel(fns)
        b = bands.(fns{i});
        ca = sum(stats_A.PeakFrequency >= b(1) & stats_A.PeakFrequency <= b(2));
        cb = sum(stats_B.PeakFrequency >= b(1) & stats_B.PeakFrequency <= b(2));
        if ca > 0
            d = 100*(cb-ca)/ca;
        else
            d = NaN;
        end
        fprintf('  %-8s %8d %8d %+7.2f%%\n', fns{i}, ca, cb, d);
    end

    % SOPH similarity
    if ~isempty(soph_A) && ~isempty(soph_B)
        cs_pow = cosine_sim(soph_A.SOpower_mat, soph_B.SOpower_mat);
        cs_pha = cosine_sim(soph_A.SOphase_mat, soph_B.SOphase_mat);
        fprintf('\nSOPH cosine similarity (A vs B):\n');
        fprintf('  SO-power histogram: %.6f\n', cs_pow);
        fprintf('  SO-phase histogram: %.6f\n', cs_pha);
    end

    % Verdict
    fprintf('\n-----------------------------------------------------------------\n');
    fprintf(' Verdict thresholds:\n');
    fprintf('   peak drift     < 1%%   AND   SOPH cosine > 0.999  -> SAFE to flip on\n');
    fprintf('   peak drift  1-3%%      OR   SOPH cosine 0.99-0.999 -> review per-band\n');
    fprintf('   peak drift     > 3%%   OR   SOPH cosine < 0.99     -> SHELVE\n');
    fprintf('-----------------------------------------------------------------\n');

    % ==================================================================
    % FIGURES (4 panels side-by-side)
    % ==================================================================
    if ~isempty(soph_A) && ~isempty(soph_B)
        f = figure('Name', 'Baseline reuse: A (current) vs B (reuse)', ...
                   'Position', [80 80 1400 900]);
        tl = tiledlayout(f, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

        % SOPH matrices are shape (num_Cbins, num_freqbins) — transpose so
        % imagesc's row-is-Y convention puts frequency on the Y axis.
        % Horizontal line at 2 Hz marks the bw_min (and analysis-band)
        % boundary so we can see at a glance whether the diff lives
        % above or below it.

        % Row 1: SO-power
        ax = nexttile(tl);
        imagesc(ax, soph_A.SOpower_bins, soph_A.freq_bins, soph_A.SOpower_mat');
        axis(ax,'xy'); colorbar(ax);
        yline(ax, 2, '--', '2 Hz', 'Color', [0.85 0.85 0.85], 'LineWidth', 1.0);
        title(ax, 'A: SO-power (compute pass-2)');
        xlabel(ax,'SO-power'); ylabel(ax,'Frequency (Hz)');

        ax = nexttile(tl);
        imagesc(ax, soph_B.SOpower_bins, soph_B.freq_bins, soph_B.SOpower_mat');
        axis(ax,'xy'); colorbar(ax);
        yline(ax, 2, '--', '2 Hz', 'Color', [0.85 0.85 0.85], 'LineWidth', 1.0);
        title(ax, 'B: SO-power (reuse pass-1)');
        xlabel(ax,'SO-power');

        ax = nexttile(tl);
        diff_pow = soph_B.SOpower_mat - soph_A.SOpower_mat;
        imagesc(ax, soph_A.SOpower_bins, soph_A.freq_bins, diff_pow');
        axis(ax,'xy'); colorbar(ax); colormap(ax, redblue());
        clim(ax, [-1 1] * max(abs(diff_pow(:))));
        yline(ax, 2, '--', '2 Hz', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.0);
        title(ax, sprintf('B - A   (max |diff| = %.3f)', max(abs(diff_pow(:)))));
        xlabel(ax,'SO-power');

        % Row 2: SO-phase
        ax = nexttile(tl);
        imagesc(ax, soph_A.SOphase_bins, soph_A.freq_bins, soph_A.SOphase_mat');
        axis(ax,'xy'); colorbar(ax);
        yline(ax, 2, '--', '2 Hz', 'Color', [0.85 0.85 0.85], 'LineWidth', 1.0);
        title(ax, 'A: SO-phase (compute pass-2)');
        xlabel(ax,'SO-phase'); ylabel(ax,'Frequency (Hz)');

        ax = nexttile(tl);
        imagesc(ax, soph_B.SOphase_bins, soph_B.freq_bins, soph_B.SOphase_mat');
        axis(ax,'xy'); colorbar(ax);
        yline(ax, 2, '--', '2 Hz', 'Color', [0.85 0.85 0.85], 'LineWidth', 1.0);
        title(ax, 'B: SO-phase (reuse pass-1)');
        xlabel(ax,'SO-phase');

        ax = nexttile(tl);
        diff_pha = soph_B.SOphase_mat - soph_A.SOphase_mat;
        imagesc(ax, soph_A.SOphase_bins, soph_A.freq_bins, diff_pha');
        axis(ax,'xy'); colorbar(ax); colormap(ax, redblue());
        clim(ax, [-1 1] * max(abs(diff_pha(:))));
        yline(ax, 2, '--', '2 Hz', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.0);
        title(ax, sprintf('B - A   (max |diff| = %.3f)', max(abs(diff_pha(:)))));
        xlabel(ax,'SO-phase');

        sgtitle(f, sprintf('runDYNAMO  fixture=%s  backend=%s   total: A=%.1fs  B=%.1fs  (%+.1f%%)', ...
            S.fixture, S.backend, t_A.total, t_B.total, ...
            100*(t_B.total - t_A.total)/t_A.total));
    end

    % Peak frequency distribution overlay (figure 2)
    f2 = figure('Name', 'Peak frequency distribution: A vs B', ...
                'Position', [200 200 800 400]);
    edges = 0:0.25:30;
    histogram(stats_A.PeakFrequency, edges, 'FaceAlpha', 0.5, ...
        'DisplayName', sprintf('A: compute  (n=%d)', nA));
    hold on;
    histogram(stats_B.PeakFrequency, edges, 'FaceAlpha', 0.5, ...
        'DisplayName', sprintf('B: reuse    (n=%d)', nB));
    grid on;
    xlabel('PeakFrequency (Hz)'); ylabel('# peaks');
    title('Peak frequency distribution');
    legend('Location', 'northeast');
    xline(2, '--', 'bw_min cutoff', 'HandleVisibility', 'off');
end


% ====================================================================
% Helpers
% ====================================================================
function [stats_table, SOPHs, timings] = run_one(fixture, backend, reuse_baseline)
    det_opts = detection_opts();
    det_opts.show_pbar = false;
    det_opts.backend = backend;

    [stats_table, ~, ~, ~, ~, ~, ~, SOPHs, timings] = runDYNAMO(fixture, ...
        'backend', backend, ...
        'plot_on', false, ...
        'detection_options', det_opts, ...
        'fit_param_basis', false, ...
        'fit_spline_basis', false, ...
        'reuse_baseline', logical(reuse_baseline));
end


function v = getfield_or(s, name, dflt)
    if isfield(s, name), v = s.(name); else, v = dflt; end
end


function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end


function k = sort_keys(k)
    % Bring known stages to the top in pipeline order; everything else
    % after. intersect/setdiff on cellstr can return row OR column
    % depending on input shape, so reshape both to row before concat.
    order = {'spect_pass1','baseline_pass1','artifact','extract_pass1', ...
             'spect_pass2','baseline_pass2','extract_pass2','refine', ...
             'peak_stage','peak_sopower','peak_sophase', ...
             'soph_histograms','soph_sopower_compute','soph_sophase_compute', ...
             'soph_sopower_hist','soph_sophase_hist', ...
             'fit_param_basis','fit_spline_basis','plot_summary','total'};
    head = intersect(order, k, 'stable');
    tail = setdiff(k, order, 'stable');
    k = [reshape(head, 1, []), reshape(tail, 1, [])];
end


function cs = cosine_sim(A, B)
    a = double(A(:)); b = double(B(:));
    valid = isfinite(a) & isfinite(b);
    a = a(valid); b = b(valid);
    cs = (a' * b) / (norm(a) * norm(b));
end


function cm = redblue()
    % Simple diverging colormap centered at zero.
    n = 64;
    r = [linspace(0, 1, n), ones(1, n)]';
    g = [linspace(0, 1, n), linspace(1, 0, n)]';
    b = [ones(1, n), linspace(1, 0, n)]';
    cm = [r g b];
end
