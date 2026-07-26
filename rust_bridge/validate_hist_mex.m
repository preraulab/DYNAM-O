function validate_hist_mex()
%VALIDATE_HIST_MEX  Call tfpeak_histogram_mex and the pure-MATLAB path on
%   identical inputs, diff the outputs. After the c_mat layout fix in
%   c_api.rs (2026-04-24), max |Δ| should be 0 (bit-identical).

    here = fileparts(mfilename('fullpath'));
    dev_root = fileparts(here);
    addpath(genpath(dev_root));

    rng(42);
    % Synthesize realistic-sized inputs
    n_peaks = 5000;
    peak_freqs  = 1 + 28*rand(n_peaks, 1);      % 1..29 Hz
    peak_C      = rand(n_peaks, 1);             % 0..1 SOpower
    n_times     = 6000;
    Cmetric     = rand(1, n_times);
    Cmetric_stages = randi([1 5], 1, n_times);
    Cmetric_times_step = 0.1;
    Cmetric_valid = true(1, n_times);
    Cmetric_valid_all = true(1, n_times);

    freq_range        = [0, 30];
    freq_binsizestep  = [1, 0.2];
    C_range           = [0, 1];
    C_binsizestep     = [0.2, 0.01];

    [freq_edges, ~] = create_bins(freq_range, freq_binsizestep(1), freq_binsizestep(2), 'partial');
    [C_edges, ~]    = create_bins(C_range, C_binsizestep(1), C_binsizestep(2), 'partial');

    fprintf('N peaks: %d   freq bins: %d   C bins: %d   times: %d\n', ...
        n_peaks, size(freq_edges, 2), size(C_edges, 2), n_times);

    % Match production defaults so MEX and MATLAB see the same options.
    compute_rate    = true;
    norm_dim        = 0;
    min_time_in_bin = 0;   % disable time-gating so outputs aren't nan'd
    min_peak_at_freq = 0;

    % --- MEX path (warm-up run + 3 timed runs to amortize dylib map-in
    % + rayon thread-pool spin-up; first call in a fresh process is
    % 10-20× the steady-state cost) ---
    mex_opts = struct('circular', false, 'circular_lo', 0, 'circular_hi', 2*pi, ...
                      'norm_dim', int32(norm_dim), 'compute_rate', logical(compute_rate), ...
                      'min_time_in_bin', double(min_time_in_bin), ...
                      'min_peak_at_freq', int32(min_peak_at_freq));
    % warm
    [~, ~, ~, ~] = tfpeak_histogram_mex( ...
        Cmetric, double(Cmetric_stages), Cmetric_times_step, ...
        Cmetric_valid, Cmetric_valid_all, ...
        peak_freqs, peak_C, freq_edges, C_edges, mex_opts);
    mex_trials = zeros(1, 3);
    for i = 1:3
        t0 = tic;
        [C_mex, tib_mex, pib_mex, paf_mex] = tfpeak_histogram_mex( ...
            Cmetric, double(Cmetric_stages), Cmetric_times_step, ...
            Cmetric_valid, Cmetric_valid_all, ...
            peak_freqs, peak_C, freq_edges, C_edges, mex_opts);
        mex_trials(i) = toc(t0);
    end
    t_mex = median(mex_trials);

    % --- MATLAB path (force fallback via env var) ---
    setenv('DYNAMO_HIST_MATLAB', '1');
    cleanupEnv = onCleanup(@() setenv('DYNAMO_HIST_MATLAB', ''));
    % warm
    [~, ~, ~, ~, ~, ~] = TFPeakHistogram(Cmetric, ...
        double(Cmetric_stages), Cmetric_times_step, Cmetric_valid, ...
        Cmetric_valid_all, peak_freqs, peak_C, ...
        'C_range', C_range, 'C_binsizestep', C_binsizestep, ...
        'freq_range', freq_range, 'freq_binsizestep', freq_binsizestep, ...
        'compute_rate', compute_rate, 'norm_dim', norm_dim, ...
        'min_time_in_bin', min_time_in_bin, 'min_peak_at_freq', min_peak_at_freq, ...
        'verbose', false);
    mat_trials = zeros(1, 3);
    for i = 1:3
        t0 = tic;
        [C_mat, ~, ~, tib_mat, pib_mat, paf_mat] = TFPeakHistogram(Cmetric, ...
            double(Cmetric_stages), Cmetric_times_step, Cmetric_valid, ...
            Cmetric_valid_all, peak_freqs, peak_C, ...
            'C_range', C_range, 'C_binsizestep', C_binsizestep, ...
            'freq_range', freq_range, 'freq_binsizestep', freq_binsizestep, ...
            'compute_rate', compute_rate, 'norm_dim', norm_dim, ...
            'min_time_in_bin', min_time_in_bin, 'min_peak_at_freq', min_peak_at_freq, ...
            'verbose', false);
        mat_trials(i) = toc(t0);
    end
    t_mat = median(mat_trials);
    clear cleanupEnv

    fprintf('\nShapes:\n');
    fprintf('  C_mex  %s   C_mat %s\n', mat2str(size(C_mex)), mat2str(size(C_mat)));
    fprintf('  tib_mex %s  tib_mat %s\n', mat2str(size(tib_mex)), mat2str(size(tib_mat)));

    d_c   = max(abs(C_mex(:)  - C_mat(:)));
    d_tib = max(abs(tib_mex(:) - tib_mat(:)));
    d_pib = max(abs(pib_mex(:) - pib_mat(:)));
    d_paf = max(abs(paf_mex(:) - paf_mat(:)));

    fprintf('\nMax |Δ|:\n');
    fprintf('  C_mat        : %.3e\n', d_c);
    fprintf('  time_in_bin  : %.3e\n', d_tib);
    fprintf('  prop_in_bin  : %.3e\n', d_pib);
    fprintf('  peak_at_freq : %.3e\n', d_paf);

    fprintf('\nTime (warm, median of 3):  MEX %.4f s   MATLAB %.4f s   speedup %.2fx\n', ...
        t_mex, t_mat, t_mat/t_mex);
    fprintf('  MEX    trials: %s\n', mat2str(mex_trials, 4));
    fprintf('  MATLAB trials: %s\n', mat2str(mat_trials, 4));

    tol = 1e-12;
    if d_c < tol && d_tib < tol && d_pib < tol && d_paf < tol
        fprintf('\nEQUIVALENCE: PASS\n');
    else
        fprintf('\nEQUIVALENCE: FAIL — investigate\n');
        % Show stripe pattern if any
        col_var = var(C_mex, 0, 1);
        fprintf('  C_mex column variance per freq bin (first 20): %s\n', ...
            mat2str(col_var(1:min(20,end)), 3));
    end
end
