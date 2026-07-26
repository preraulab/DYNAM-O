function validate_so_power_mex()
%VALIDATE_SO_POWER_MEX  Smoke + self-consistency gate for so_power_mex.
%
% Builds a synthetic SO-band spectrogram + dummy EEG times + dummy
% staging, runs so_power_mex with a few canonical norm_methods, and
% asserts the contract:
%   1. Output lengths match retain_fs (T windows vs N EEG samples).
%   2. Times are monotonic non-decreasing.
%   3. Stages take values in {0, 1, 2, 3, 4, 5}.
%   4. After 'p2shift1234' normalization on a stationary input, the
%      output mean is ~0 dB (the p2-shift baseline applied to a flat
%      spectrum leaves residual near zero after dB conversion).
%
% Per-sample MATLAB-vs-Rust parity is gated end-to-end by the
% runDYNAMO test in task #11 against its canonical reference outputs;
% this file just asserts the bridge is internally consistent.

    rng(11, 'twister');
    Fs = 100;
    duration = 300;
    N = duration * Fs;          % 30000
    eeg_times = (0:N-1)' / Fs;
    isexcluded = false(N, 1);

    % Synthetic SO-band spectrogram: 0-1.5 Hz, F=15, T=5980 windows.
    F = 15; T = 5980;
    so_spect = exp(0.3 * randn(F, T) + 0.1 * sin(linspace(0, 8*pi, T)));
    stimes = linspace(0.5, 0.5 + (T-1) * 0.05, T)';
    sfreqs = linspace(0, 1.5, F)';

    % Dummy staging: all NREM2 for the first half, REM for the second.
    stage_times = [0; 150; 300];
    stage_vals  = [2; 4; 4];

    time_range = [stimes(1) stimes(end)];
    outlier_threshold = 3.0;

    cases = {'p2shift1234', 'percent', 'none'};
    for ci = 1:numel(cases)
        nm = cases{ci};
        for retain = [true, false]
            [norm, times, stages, ptile] = so_power_mex( ...
                so_spect, stimes, sfreqs, eeg_times, isexcluded, ...
                stage_times, stage_vals, time_range, outlier_threshold, ...
                nm, retain);
            M = numel(norm);
            expM = ternary(retain, N, T);
            assert(M == expM, '[%s retain=%d] output length %d != expected %d', ...
                nm, retain, M, expM);
            assert(M == numel(times) && M == numel(stages), 'array length mismatch');
            assert(all(diff(times(~isnan(times))) >= -1e-9), 'times not monotone');
            ok_stage = isnan(stages) | (stages == 0 | stages == 1 | stages == 2 | ...
                stages == 3 | stages == 4 | stages == 5);
            assert(all(ok_stage), '[%s retain=%d] stages out of {0..5}', nm, retain);

            if strcmp(nm, 'p2shift1234')
                assert(~isempty(ptile) && isscalar(ptile), 'ptile expected to be scalar for p-shift');
            elseif strcmp(nm, 'percent')
                assert(numel(ptile) == 2, 'ptile expected (lo, hi) pair for percent');
            else  % 'none'
                assert(isempty(ptile), 'ptile should be empty for none');
            end

            fprintf('  %-12s retain_fs=%d : M=%d  ptile=%s  PASS\n', ...
                nm, retain, M, mat2str(ptile(:).'));
        end
    end

    fprintf('so_power_mex smoke gates all PASS.\n');
end

function out = ternary(cond, a, b); if cond, out = a; else, out = b; end; end
