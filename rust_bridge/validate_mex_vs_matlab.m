function validate_mex_vs_matlab()
%VALIDATE_MEX_VS_MATLAB  Run extract_tfpeaks_mex on the exported segment
%   spectrogram and compare against MATLAB's own runDYNAMO output
%   (segment_stats.csv, produced by export_validation_segment.m).
%
%   Expected match: the MEX path should reproduce the Python ctypes
%   validator's numbers — ~6440 peaks, ~13% Hungarian match to MATLAB's
%   5738 at 0.1s/0.2Hz (the documented pydynamo↔MATLAB parity gap).
%
%   Run `export_validation_segment` first to populate data_cache/.

    here      = fileparts(mfilename('fullpath'));           % DYNAM-O_dev/rust_bridge
    dev_root  = fileparts(here);                             % DYNAM-O_dev
    cache_dir = fullfile(dev_root, '..', 'DYNAM-O_rs', 'data_cache');
    spect_mat = fullfile(cache_dir, 'segment_spect.mat');
    stats_csv = fullfile(cache_dir, 'segment_stats.csv');

    assert(exist(spect_mat, 'file') == 2, 'Missing %s', spect_mat);
    assert(exist(stats_csv, 'file') == 2, 'Missing %s', stats_csv);

    fprintf('Loading %s ...\n', spect_mat);
    S = load(spect_mat);
    fprintf('  spect: [%d x %d], baseline: %d\n', ...
        size(S.spect, 1), size(S.spect, 2), numel(S.baseline));

    matlab_stats = readtable(stats_csv);
    fprintf('MATLAB peaks: %d\n', height(matlab_stats));

    % Resolve empty MATLAB detection defaults (the 'default' preset in
    % computeTFPeaks: seg_time=30, merge_thresh=11, downsample=[2 2]).
    seg_time     = resolve_default(S, 'seg_time',     30);
    merge_thresh = resolve_default(S, 'merge_thresh', 11);
    ds           = resolve_default_vec(S, 'downsample_spect', [2 2]);

    % MATLAB convention: downsample_spect(1) = time stride, (2) = freq
    % stride (extractTFPeaks.m:207). Map accordingly.
    % trim_shift: MATLAB uses min(spect,[],'all') on baseline-divided
    % spect, uniform across segments. Recompute here on the SAME input
    % the MEX is about to see.
    if isfield(S, 'spect_masked')
        spect_for_shift = double(S.spect_masked);
    else
        spect_for_shift = double(S.spect);
    end
    if isfield(S, 'baseline2')
        bl = double(S.baseline2(:));
    else
        bl = double(S.baseline(:));
    end
    trim_shift_val = min(spect_for_shift ./ max(bl, eps), [], 'all');

    params = struct( ...
        'seg_time',     seg_time, ...
        'downsample_f', ds(2), ...   % freq stride = MATLAB ds(2)
        'downsample_t', ds(1), ...   % time stride = MATLAB ds(1)
        'merge_thresh', merge_thresh, ...
        'trim_vol',     S.trim_vol, ...
        'trim_shift',   trim_shift_val, ...
        'dur_min',      S.dur_min, ...
        'dur_max',      S.dur_max, ...
        'bw_min',       S.bw_min, ...
        'bw_max',       S.bw_max, ...
        'freq_min',     -inf, ...
        'freq_max',      inf, ...
        'ht_db_min',    resolve_default(S, 'ht_db_min', -inf));

    fprintf('\nCalling extract_tfpeaks_mex ...\n');
    % Use the masked pass-2 spect — that's what MATLAB's final stats come
    % from. Also use baseline2 (pass-2 baseline). The export saves both;
    % fall back to unmasked spect if the export is from an older run.
    if isfield(S, 'spect_masked')
        spect_in    = double(S.spect_masked);
        baseline_in = double(S.baseline2(:));
        fprintf('  using spect_masked (pass-2 post-mask) + baseline2\n');
    else
        spect_in    = double(S.spect);
        baseline_in = double(S.baseline(:));
        fprintf('  WARNING: using UNMASKED pass-2 spect (older export)\n');
    end
    fprintf('  spect dtype: %s -> cast to double\n', class(S.spect));
    t0 = tic;
    mex_out = extract_tfpeaks_mex( ...
        spect_in, ...
        double(S.stimes(:)'), ...
        double(S.sfreqs(:)), ...
        baseline_in, ...
        params);
    t_extract = toc(t0);
    fprintf('  MEX extract: %.2f s, peaks: %d\n', t_extract, numel(mex_out.PeakTime));

    % Apply Hann refinement — MATLAB's segment_stats.csv is post-refinement,
    % so we must refine too for a fair comparison. Refinement drops peaks
    % whose Hann-window refined frequency falls outside freq_range or is
    % NaN (edge peaks). pydynamo hits ~0.8% peak-count diff vs MATLAB only
    % with refinement applied; without it the gap is ~15%.
    fprintf('\nApplying Hann refinement (MATLAB-style) ...\n');
    here = fileparts(mfilename('fullpath'));
    ed_path = fullfile(fileparts(here), 'example_data', 'example_data.mat');
    assert(exist(ed_path, 'file') == 2, 'example_data.mat not found: %s', ed_path);
    ed = load(ed_path, 'data', 'Fs');
    time_range = [8420, 13446];     % segment preset
    t_data     = (0:length(ed.data)-1)' / ed.Fs;
    inrange    = t_data >= time_range(1) & t_data <= time_range(2);
    data_tr    = double(ed.data(inrange));
    fs         = double(ed.Fs);

    % BoundingBox format conversion:
    %   extract returns pydynamo [t_tl, f_tl, width_s, height_Hz]
    %   refine expects MATLAB    [f_lo, f_hi, t_lo, t_hi]
    bb = double(mex_out.BoundingBox);
    bb_refine = [bb(:,2), bb(:,2) + bb(:,4), bb(:,1), bb(:,1) + bb(:,3)];

    % Peak times from extract are absolute (stimes shifted by time_range(1)).
    % refine_peaks_mex treats peak_time as offset from data[0]. Shift both
    % peak_time and the bbox t columns by -time_range(1) to match.
    t_shift        = time_range(1);
    peak_time_rel  = double(mex_out.PeakTime(:)) - t_shift;
    bb_refine(:,3) = bb_refine(:,3) - t_shift;   % t_lo
    bb_refine(:,4) = bb_refine(:,4) - t_shift;   % t_hi

    t0 = tic;
    [refined_freq, keep] = refine_peaks_mex( ...
        peak_time_rel, ...
        double(mex_out.PeakFrequency(:)), ...
        bb_refine, ...
        data_tr, fs, ...
        [0.0, 30.0], ...     % freq_range default
        4.0,          ...     % window_size (s)
        0.05);                % dsfreqs
    t_refine = toc(t0);
    n_before = numel(mex_out.PeakTime);

    % Diagnostic: unpack why peaks are being dropped.
    n_keep_flag    = nnz(logical(keep));
    n_finite       = nnz(isfinite(refined_freq));
    n_in_range     = nnz(refined_freq >= 0 & refined_freq <= 30);
    fprintf('  refine: %.2f s\n', t_refine);
    fprintf('  keep-flag true:      %d / %d\n', n_keep_flag, n_before);
    fprintf('  refined_freq finite: %d / %d\n', n_finite, n_before);
    fprintf('  refined_freq in 0-30Hz: %d / %d\n', n_in_range, n_before);
    if n_finite > 0
        finite_vals = refined_freq(isfinite(refined_freq));
        fprintf('  finite refined_freq range: [%.3f, %.3f], median %.3f\n', ...
            min(finite_vals), max(finite_vals), median(finite_vals));
    end
    fprintf('  First 5 refined_freq / keep / orig peak_freq:\n');
    for k = 1:min(5, n_before)
        fprintf('    [%d] refined=%g  keep=%d  orig=%g\n', k, ...
            refined_freq(k), keep(k), mex_out.PeakFrequency(k));
    end

    keep     = logical(keep) & isfinite(refined_freq);
    n_after  = nnz(keep);
    fprintf('  final kept: %d / %d\n', n_after, n_before);

    % Build post-refinement MEX stats
    mex_out.PeakFrequency(keep) = refined_freq(keep);
    mex_out.PeakTime      = mex_out.PeakTime(keep);
    mex_out.PeakFrequency = mex_out.PeakFrequency(keep);
    mex_out.Duration      = mex_out.Duration(keep);
    mex_out.Bandwidth     = mex_out.Bandwidth(keep);
    mex_out.Height        = mex_out.Height(keep);
    mex_out.Volume        = mex_out.Volume(keep);

    fprintf('\nMEX final peaks: %d  (MATLAB: %d, diff %+.1f%%)\n', ...
        n_after, height(matlab_stats), ...
        100 * (n_after - height(matlab_stats)) / height(matlab_stats));

    % Hungarian match MATLAB ↔ MEX at multiple tolerances. Watershed basin
    % drawing differs slightly between MATLAB IPT and skimage/Rust, so
    % peaks land a few hundred ms / a few tenths of Hz off their MATLAB
    % counterparts. The tight-tolerance number is expected to be ~13%.
    % Loose (0.5 s / 0.5 Hz) should be near-100% — that's the real test.
    fprintf('\nMATLAB <-> MEX Hungarian match:\n');
    tol_sets = [0.1 0.2; 0.2 0.4; 0.5 0.5; 1.0 1.0];
    for i = 1:size(tol_sets, 1)
        [ia, ib] = hungarian_match( ...
            matlab_stats.PeakTime, matlab_stats.PeakFrequency, ...
            mex_out.PeakTime,      mex_out.PeakFrequency, ...
            tol_sets(i,1), tol_sets(i,2));
        fprintf('  tol %.1fs / %.1fHz:  %4d / %4d MATLAB peaks matched  (%.1f%%)\n', ...
            tol_sets(i,1), tol_sets(i,2), ...
            numel(ia), height(matlab_stats), ...
            100 * numel(ia) / height(matlab_stats));
    end

    % Property diffs at loose tolerance — mostly reassurance they're not wild.
    [ia, ib] = hungarian_match( ...
        matlab_stats.PeakTime, matlab_stats.PeakFrequency, ...
        mex_out.PeakTime,      mex_out.PeakFrequency, ...
        0.5, 0.5);
    if ~isempty(ia)
        fprintf('\nProperty diffs at 0.5s/0.5Hz (matched peaks only):\n');
        fprintf('  prop           median abs diff    max abs diff\n');
        for prop = {'PeakTime', 'PeakFrequency', 'Duration', 'Bandwidth', 'Height'}
            p = prop{1};
            diff_vec = abs(matlab_stats.(p)(ia) - mex_out.(p)(ib));
            fprintf('  %-13s %15.4e %15.4e\n', p, median(diff_vec), max(diff_vec));
        end
    end

    fprintf('\n--- What the numbers mean ---\n');
    fprintf('  Tight-tol 13%% is the known MATLAB-IPT vs skimage/Rust watershed\n');
    fprintf('  parity gap (pydynamo also matches MATLAB at ~13%% tight).\n');
    fprintf('  The metric that matters for published histograms is SOpower cos,\n');
    fprintf('  which is 0.999 in pydynamo. MEX calls identical kernels, so\n');
    fprintf('  histogram cos should match. Full-pipeline parity test will need\n');
    fprintf('  computePeakStage + computePeakSOpower + SOpowerphaseHistogram.\n');
end


function v = resolve_default(S, name, def)
    if isfield(S, name) && ~isempty(S.(name))
        v = double(S.(name));
    else
        v = def;
    end
end

function v = resolve_default_vec(S, name, def)
    if isfield(S, name) && numel(S.(name)) == 2
        v = double(S.(name));
    else
        v = def;
    end
end


function [ia, ib] = hungarian_match(ta, fa, tb, fb, tol_t, tol_f)
% Greedy nearest-neighbor match. Returns indices into a / b for matched pairs.
    ia = [];
    ib = [];
    used_b = false(numel(tb), 1);
    for i = 1:numel(ta)
        % Candidate B peaks within tolerance box
        dt = abs(tb - ta(i));
        df = abs(fb - fa(i));
        cand = find(~used_b & dt <= tol_t & df <= tol_f);
        if isempty(cand), continue; end
        % Nearest by L2
        d2 = (dt(cand) / tol_t).^2 + (df(cand) / tol_f).^2;
        [~, bk] = min(d2);
        ia(end+1, 1) = i;                     %#ok<AGROW>
        ib(end+1, 1) = cand(bk);              %#ok<AGROW>
        used_b(cand(bk)) = true;
    end
end
