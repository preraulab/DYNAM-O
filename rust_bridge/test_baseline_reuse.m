function test_baseline_reuse(varargin)
%TEST_BASELINE_REUSE  Compute pass-1 and pass-2 spectrograms + baselines on
%   the bundled example data, then plot them overlaid so we can see how
%   different the two baselines really are. Used to evaluate whether
%   reusing pass-1's baseline for pass-2 (skipping the second
%   computeBaseline call) is a viable optimisation — see the analysis
%   thread re: ~5 percent pipeline speedup vs peak-count drift risk.
%
%   Replicates the relevant portions of computeTFPeaks.m without invoking
%   the watershed / merge / extract pipeline, so we can iterate on the
%   baseline question alone.
%
%   Outputs three figures:
%     1. Both baselines (median + 5/95-percentile across time) overlaid
%        on log scale, with the per-freq-bin ratio in a sub-axis.
%     2. The two spectrograms as imagesc (mean-pooled in time for clarity).
%     3. Histogram of the pass-2/pass-1 baseline ratio.
%
%   Usage:
%       test_baseline_reuse           % defaults (bundled night, baseline_ptile=2)
%       test_baseline_reuse('baseline_ptile', 5)
%
%   Optional name-value:
%       'baseline_ptile' - percentile for baseline (default 2; matches
%                          baseline_opts default)
%       'time_range'     - [start_s end_s] (default: bundled-night auto-clip)

    p = inputParser;
    addParameter(p, 'baseline_ptile', 2, @isscalar);
    addParameter(p, 'time_range', [], @(x) isempty(x) || numel(x)==2);
    parse(p, varargin{:});
    S = p.Results;

    % ---- paths ----
    here = fileparts(mfilename('fullpath'));
    dev_root = fileparts(here);
    addpath(genpath(dev_root));

    % ---- load bundled example ----
    fix_path = fullfile(dev_root, 'example_data', 'example_data.mat');
    fprintf('Loading %s ...\n', fix_path);
    L = load(fix_path, 'data', 'stage_times', 'stage_vals', 'Fs');
    data = double(L.data(:));
    Fs = double(L.Fs);
    fprintf('  size(data)=%s  Fs=%g  staged epochs=%d\n', ...
        mat2str(size(data)), Fs, numel(L.stage_vals));

    % ---- pick time_range matching runDYNAMO('night') wake-buffer logic ----
    if isempty(S.time_range)
        wake_buffer = 5*60;
        idx_first = find(L.stage_vals < 5 & L.stage_vals > 0, 1, 'first');
        idx_last  = find(L.stage_vals < 5 & L.stage_vals > 0, 1, 'last');
        time_range = [L.stage_times(idx_first) - wake_buffer, ...
                      L.stage_times(idx_last)  + wake_buffer];
    else
        time_range = S.time_range;
    end
    fprintf('  time_range = [%.1f, %.1f] s  (%.1f h)\n', ...
        time_range(1), time_range(2), diff(time_range)/3600);

    % Trim data + build baseline_exclude (exclude artifacts + wake stages)
    sample_range = round(time_range * Fs) + [1, 0];
    sample_range(1) = max(1, sample_range(1));
    sample_range(2) = min(numel(data), sample_range(2));
    data_trim = data(sample_range(1):sample_range(2));
    n = numel(data_trim);
    t_time_range = (0:n-1) / Fs;

    % Build a per-sample stage vector by interpolating stage_vals at sample times.
    % Cast to double — interp1 rejects uint8 (which is how stage_vals ships
    % in the bundled .mat).
    stage_per_sample = interp1(double(L.stage_times), double(L.stage_vals), ...
        time_range(1) + t_time_range, 'previous', 'extrap');
    % Default baseline_stages: N1, N2, N3, REM (1..4); exclude Wake (5),
    % Artifact (6), Unknown (0).
    baseline_stages = [1 2 3 4];
    exclude_mask = ~ismember(stage_per_sample, baseline_stages);
    baseline_exclude = exclude_mask(:);
    fprintf('  baseline_exclude: %d of %d samples excluded (%.1f%%)\n', ...
        sum(baseline_exclude), n, 100*mean(baseline_exclude));

    % ---- multitaper params (matching detection_opts defaults) ----
    det_opts = detection_opts();
    mtm_taper_params = det_opts.mtm_taper_params;   % [TW, K] — defaults [2,3]
    mtm_freq_range = det_opts.mtm_freq_range;
    mtm_dsfreqs    = det_opts.mtm_dsfreqs;
    win_step       = det_opts.mtm_window_stepsize;
    win1 = det_opts.mtm_window_length_1;   % 1 s
    win2 = det_opts.mtm_window_length_2;   % 2 s
    nfft = 2^nextpow2(Fs / mtm_dsfreqs);
    fprintf('  NFFT = %d  (Fs=%g, dsfreqs=%g, df = %g Hz)\n', ...
        nfft, Fs, mtm_dsfreqs, Fs/nfft);
    fprintf('  Pass 1 window = %g s,  Pass 2 window = %g s,  step = %g s\n', ...
        win1, win2, win_step);

    % ---- compute pass-1 + pass-2 spectrograms ----
    fprintf('\nComputing pass-1 spectrogram (%g s window)...\n', win1);
    t1 = tic;
    [spect1, stimes1, sfreqs1] = multitaper_spectrogram_mex( ...
        data_trim, Fs, mtm_freq_range, mtm_taper_params, ...
        [win1, win_step], nfft, 'constant', 'unity', false, false);
    fprintf('  done in %.2f s.  size = %s\n', toc(t1), mat2str(size(spect1)));

    fprintf('Computing pass-2 spectrogram (%g s window)...\n', win2);
    t2 = tic;
    [spect2, stimes2, sfreqs2] = multitaper_spectrogram_mex( ...
        data_trim, Fs, mtm_freq_range, mtm_taper_params, ...
        [win2, win_step], nfft, 'constant', 'unity', false, false);
    fprintf('  done in %.2f s.  size = %s\n', toc(t2), mat2str(size(spect2)));

    % ---- compute both baselines ----
    fprintf('\nComputing pass-1 baseline (percentile %g, exclude wake/artifact)...\n', S.baseline_ptile);
    bl1 = local_baseline(spect1, stimes1, t_time_range, baseline_exclude, ...
        time_range - time_range(1), S.baseline_ptile);
    fprintf('Computing pass-2 baseline...\n');
    bl2 = local_baseline(spect2, stimes2, t_time_range, baseline_exclude, ...
        time_range - time_range(1), S.baseline_ptile);

    % ---- summary stats: how different are they? ----
    valid = bl1 > 0 & bl2 > 0 & isfinite(bl1) & isfinite(bl2);
    ratio = bl2(valid) ./ bl1(valid);
    fprintf('\n=== Baseline ratio (pass-2 / pass-1) across %d valid freq bins ===\n', sum(valid));
    fprintf('  median = %.4f   mean = %.4f   std = %.4f\n', ...
        median(ratio), mean(ratio), std(ratio));
    fprintf('  range  = [%.4f, %.4f]  (5th/95th: %.4f / %.4f)\n', ...
        min(ratio), max(ratio), prctile(ratio,5), prctile(ratio,95));
    rel_dB = 20*log10(ratio);
    fprintf('  ratio in dB:  median = %+.2f dB   IQR = [%+.2f, %+.2f] dB\n', ...
        median(rel_dB), prctile(rel_dB,25), prctile(rel_dB,75));

    % Localise the heavy tail: report which frequencies have ratio > 1 dB,
    % > 2 dB, > 5 dB. Tells us at a glance whether outliers are at band
    % edges (safe to reuse directly) or in-band (need per-bin correction).
    f_valid = sfreqs1(valid);
    for thr_dB = [1, 2, 5]
        mask = abs(rel_dB) > thr_dB;
        if any(mask)
            f_at = f_valid(mask);
            fprintf('  freqs where |ratio| > %d dB:  n=%d  range = [%.2f, %.2f] Hz', ...
                thr_dB, sum(mask), min(f_at), max(f_at));
            % Indicate whether they cluster at edges or in-band
            in_band   = sum(f_at >= 0.5 & f_at <= 40);
            band_edge = sum(mask) - in_band;
            fprintf('   (in-band 0.5-40Hz: %d, band-edge: %d)\n', in_band, band_edge);
        end
    end

    % Per-band median ratio so we can see if specific oscillation bands shift.
    bands = struct('SO', [0.3 1.5], 'delta', [1 4], 'theta', [4 8], ...
                   'alpha', [8 12], 'sigma', [11 16], 'beta', [13 30]);
    fns = fieldnames(bands);
    fprintf('\n  Per-band ratio summary:\n');
    fprintf('    %-8s %8s %8s %8s\n', 'band', 'median', 'IQR_lo', 'IQR_hi');
    for i = 1:numel(fns)
        b = bands.(fns{i});
        in = f_valid >= b(1) & f_valid <= b(2);
        if any(in)
            r = rel_dB(in);
            fprintf('    %-8s %+7.2fdB %+7.2fdB %+7.2fdB\n', ...
                fns{i}, median(r), prctile(r,25), prctile(r,75));
        end
    end

    % ==================================================================
    % PLOTS
    % ==================================================================

    % ---- Figure 1: baselines overlaid + ratio ----
    f1 = figure('Name', 'Pass-1 vs Pass-2 baselines', 'Position', [100 100 900 700]);
    tl1 = tiledlayout(f1, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile(tl1, [2 1]);
    plot(sfreqs1, 10*log10(bl1), '-', 'LineWidth', 1.5, 'DisplayName', 'Pass 1 (1 s win)'); hold on;
    plot(sfreqs2, 10*log10(bl2), '-', 'LineWidth', 1.5, 'DisplayName', 'Pass 2 (2 s win)');
    grid on; xlim(mtm_freq_range);
    xlabel('Frequency (Hz)'); ylabel('Baseline (dB)');
    title('Baselines (10 log_{10}) — passes use same NFFT so freq grids match exactly');
    legend('Location','southwest');

    nexttile(tl1);
    plot(sfreqs1(valid), 20*log10(ratio), '-', 'LineWidth', 1.5);
    grid on; xlim(mtm_freq_range);
    xlabel('Frequency (Hz)'); ylabel('Pass2/Pass1 (dB)');
    yline(0, '--', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
    title('Per-freq-bin ratio (negative = pass-2 baseline lower)');

    % ---- Figure 2: time-mean spectra ----
    f2 = figure('Name', 'Pass-1 vs Pass-2 spectrograms (time-mean)', 'Position', [200 200 900 500]);
    valid_t1 = ~interp1(t_time_range, single(baseline_exclude), stimes1, 'nearest');
    valid_t2 = ~interp1(t_time_range, single(baseline_exclude), stimes2, 'nearest');
    spect1_mean = mean(double(spect1(:, logical(valid_t1))), 2, 'omitnan');
    spect2_mean = mean(double(spect2(:, logical(valid_t2))), 2, 'omitnan');
    plot(sfreqs1, 10*log10(spect1_mean), '-', 'LineWidth', 1.5, 'DisplayName', 'Pass 1 mean'); hold on;
    plot(sfreqs2, 10*log10(spect2_mean), '-', 'LineWidth', 1.5, 'DisplayName', 'Pass 2 mean');
    plot(sfreqs1, 10*log10(bl1), '--', 'LineWidth', 1.0, 'DisplayName', 'Pass 1 baseline');
    plot(sfreqs2, 10*log10(bl2), '--', 'LineWidth', 1.0, 'DisplayName', 'Pass 2 baseline');
    grid on; xlim(mtm_freq_range);
    xlabel('Frequency (Hz)'); ylabel('Power (dB)');
    title('Time-mean spectra (sleep epochs only) with baselines');
    legend('Location','southwest');

    % ---- Figure 3: ratio histogram ----
    f3 = figure('Name', 'Baseline ratio distribution', 'Position', [300 300 600 400]);
    histogram(rel_dB, 50);
    xline(median(rel_dB), '--', 'Color', 'r', 'LineWidth', 1.5, ...
        'Label', sprintf('median %+.2f dB', median(rel_dB)));
    grid on;
    xlabel('Pass-2/Pass-1 baseline ratio (dB)');
    ylabel('# freq bins');
    title(sprintf('Distribution of per-freq-bin ratios — std = %.2f dB', std(rel_dB)));

    fprintf('\n3 figures opened. Close them when done.\n');
end


% ====================================================================
% Helpers
% ====================================================================
function bl = local_baseline(spect, stimes, t_time_range, baseline_exclude, baseline_range, ptile)
    % Mirrors computeBaseline in computeTFPeaks.m (which is a local
    % function and not callable from outside). Same algorithm so the
    % numbers match what the production pipeline would compute.
    excl_at_stimes = logical(interp1(t_time_range, single(baseline_exclude), ...
        stimes, 'nearest'));
    in_range = stimes >= baseline_range(1) & stimes <= baseline_range(2);
    valid = ~excl_at_stimes & in_range;
    if ~any(valid)
        error('No valid baseline time bins.');
    end
    spect_bl = double(spect(:, valid));
    spect_bl(spect_bl == 0) = NaN;
    bl = prctile(spect_bl, ptile, 2);
end
