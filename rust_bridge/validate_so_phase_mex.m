function validate_so_phase_mex()
%VALIDATE_SO_PHASE_MEX  Smoke + self-consistency gate for so_phase_mex.
%
% Builds a 300 s synthetic EEG with a known 1 Hz slow oscillation,
% designs a band-pass SOS via butter, runs the Rust bridge, and asserts:
%   1. Output lengths equal length(eeg).
%   2. NaN appears exactly at excluded samples in SOphase + filtdata.
%   3. The unwrapped phase advances by ~2*pi per second on the 1 Hz
%      portion of the signal (slope ~ 2*pi).
%   4. Stage values are 0 outside staging range, else interpolated.

    Fs = 100;
    duration = 300;
    N = duration * Fs;
    t = (0:N-1)' / Fs;

    eeg = 50 * sin(2*pi*1.0*t) + 5 * randn(N, 1);
    eeg_times = t;
    isexcluded = false(N, 1);
    isexcluded(1000:1500) = true;   % carve out a known excluded segment

    % Slow-osc band-pass: [0.3, 1.5] Hz, order 4, IIR -> SOS.
    [z, p, k] = butter(4, [0.3 1.5] / (Fs/2), 'bandpass');
    sos = zp2sos(z, p, k);

    stage_times = [0; 100; 200];
    stage_vals  = [2; 3; 2];

    [phase, times, stages, filtdata] = so_phase_mex( ...
        eeg, eeg_times, isexcluded, sos, stage_times, stage_vals);

    assert(numel(phase) == N, 'phase length mismatch');
    assert(numel(times) == N, 'times length mismatch');
    assert(numel(stages) == N, 'stages length mismatch');
    assert(numel(filtdata) == N, 'filtdata length mismatch');

    % NaN at excluded samples exactly.
    nan_phase = isnan(phase);
    nan_filt = isnan(filtdata);
    if ~isequal(nan_phase(:), isexcluded(:))
        n_diff = sum(nan_phase(:) ~= isexcluded(:));
        error('SOphase NaN mask differs from isexcluded in %d samples.', n_diff);
    end
    if ~isequal(nan_filt(:), isexcluded(:))
        error('filtdata NaN mask differs from isexcluded.');
    end

    % Unwrapped phase slope ~ 2*pi rad/s on the 1-Hz signal. Measure on a
    % non-excluded stretch.
    seg = 5000:25000;       % avoid edges + the excluded carve-out
    seg = seg(~isexcluded(seg));
    slope = polyfit(t(seg), phase(seg), 1);
    rad_per_s = slope(1);
    expected = 2*pi;        % 1 Hz oscillation
    assert(abs(rad_per_s - expected) < 0.5, ...
        'unwrapped-phase slope %.3f rad/s deviates from 2*pi (=%.3f) by %.3f', ...
        rad_per_s, expected, abs(rad_per_s - expected));

    % Stage assignment: previous-neighbor interpolation, fill=0 outside
    % [stage_times(1), stage_times(end)] = [0, 200].
    %   t = 50  -> stage 2 (from t=0)
    %   t = 150 -> stage 3 (from t=100)
    %   t = 250 -> 0 (past last stage marker -> fill)
    s_at_50  = stages(round(50  * Fs) + 1);
    s_at_150 = stages(round(150 * Fs) + 1);
    s_at_250 = stages(round(250 * Fs) + 1);
    assert(s_at_50  == 2, 'expected stage 2 at t=50s, got %g', s_at_50);
    assert(s_at_150 == 3, 'expected stage 3 at t=150s, got %g', s_at_150);
    assert(s_at_250 == 0, 'expected stage 0 (fill) at t=250s (past last marker), got %g', s_at_250);

    fprintf('  N=%d  phase slope = %.4f rad/s (expected 2*pi = %.4f)  PASS\n', N, rad_per_s, expected);
    fprintf('so_phase_mex smoke gates all PASS.\n');
end
