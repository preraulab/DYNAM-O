function validate_baseline_mex()
%VALIDATE_BASELINE_MEX  Parity gate: baseline_mex vs MATLAB
% computeBaseline (in TFpeak_functions/computeTFPeaks.m). Builds a
% synthetic-EEG spectrogram via multitaper_spectrogram_dynamo, then
% computes the per-frequency 2nd-percentile baseline both ways and
% asserts the F-vector matches within 1e-9 absolute.

    addpath(genpath('<private-path>'));
    addpath('<private-path>');

    % Synthetic spectrogram: F=128 freqs x T=600 windows of strictly
    % positive doubles drawn from log-normal (so zeros are zero zeros
    % only by construction, mirroring real multitaper output). Inject
    % a handful of zeros and an excluded region to exercise the
    % NaN-zero replacement and the exclude-stimes interp path.
    rng(7, 'twister');
    F = 128; T = 600;
    spect = exp(0.5 * randn(F, T));        % strictly positive
    spect(1:5, 100:200) = 0;                % some zero pixels (-> NaN in compute)
    Fs = 100;
    stimes = linspace(0.5, 0.5 + (T-1) * 0.05, T);  % 50 ms step
    % Extend t_data past stimes(end) so MATLAB's interp1 doesn't NaN at
    % the edge sample (the production caller always has data beyond the
    % last spectrogram window).
    n_data = round((stimes(end) + 1.0) * Fs);
    t_data = (0:n_data-1) / Fs;
    baseline_exclude = false(size(t_data));
    baseline_exclude(round(20*Fs):round(30*Fs)) = true; % exclude 10 s of "artifact"

    baseline_range = [stimes(1) stimes(end)];
    baseline_ptile = 2.0;
    sfreqs = (0:F-1) * 0.25; %#ok<NASGU>

    % 3. Rust path.
    baseline_rs  = baseline_mex(spect, stimes, t_data, baseline_exclude, baseline_range, baseline_ptile);

    % 4. MATLAB path — re-implement computeBaseline locally.
    baseline_mat = local_computeBaseline(spect, stimes, t_data, baseline_exclude, baseline_range, baseline_ptile);

    if ~isequal(size(baseline_rs), size(baseline_mat))
        error('size mismatch: rs=[%s] mat=[%s]', num2str(size(baseline_rs)), num2str(size(baseline_mat)));
    end
    drift = max(abs(baseline_rs(:) - baseline_mat(:)));
    fprintf('  baseline F=%d : max abs drift = %.3e  (budget 1e-9)  %s\n', ...
        size(spect, 1), drift, ternary(drift < 1e-9, 'PASS', 'FAIL'));
    if drift >= 1e-9
        % Show top 5 worst rows.
        [~, ord] = sort(abs(baseline_rs(:) - baseline_mat(:)), 'descend');
        for i = 1:min(5, numel(ord))
            k = ord(i);
            fprintf('    row %d (freq %.3f Hz): rs=%.6e  mat=%.6e  diff=%.3e\n', ...
                k, sfreqs(k), baseline_rs(k), baseline_mat(k), baseline_rs(k) - baseline_mat(k));
        end
        error('validate_baseline_mex:fail', 'drift %.3e >= 1e-9', drift);
    end
end

function baseline = local_computeBaseline(spect, stimes, t_data, baseline_exclude, baseline_range, baseline_ptile)
% Mirror of computeBaseline at TFpeak_functions/computeTFPeaks.m:485.
    baseline_exclude_stimes = logical(interp1(t_data, single(baseline_exclude), stimes, 'nearest'));
    baseline_range_inds = stimes >= baseline_range(1) & stimes <= baseline_range(2);
    valid = ~baseline_exclude_stimes & baseline_range_inds;
    if ~any(valid)
        error('No valid baseline time bins.');
    end
    spect_bl = spect(:, valid);
    spect_bl(spect_bl == 0) = NaN;
    baseline = prctile(spect_bl, baseline_ptile, 2);
end

function arr = read_npy_double(path)
    fid = fopen(path, 'r'); raw = fread(fid, inf, '*uint8'); fclose(fid);
    hdr_len = double(typecast(raw(9:10), 'uint16'));
    arr = typecast(raw(11 + hdr_len:end), 'double');
end

function out = ternary(cond, a, b); if cond, out = a; else, out = b; end; end
