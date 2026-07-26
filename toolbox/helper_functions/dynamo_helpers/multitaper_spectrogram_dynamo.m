function [spect, stimes, sfreqs] = multitaper_spectrogram_dynamo( ...
    data, Fs, freq_range, taper_params, window_params, ...
    nfft, detrend_opt, weighting, ploton, verbose)
%MULTITAPER_SPECTROGRAM_DYNAMO  Backend-dispatched multitaper spectrogram.
%
%   Drop-in replacement for multitaper_spectrogram_mex. Same arguments,
%   same outputs. Routes the actual computation to either:
%     - Rust path: dynamo_rs::dynamo_multitaper_spectrogram via the
%       multitaper_spectrogram_rust_mex MEX (f64 throughout).
%     - MATLAB path: multitaper_spectrogram_mex (Coder-generated f32 MEX,
%       fallback to pure-MATLAB multitaper_spectrogram).
%
%   Backend selection comes from setappdata(0, 'dynamo_backend', '<name>')
%   set once by runDYNAMO per pipeline run. If unset, defaults to 'matlab'
%   for safety (= preserves pre-Rust-MTS behavior for callers outside
%   runDYNAMO, e.g. notebook scripts that call detect_artifacts directly).
%
%   Selection precedence:
%     dynamo_backend == 'rust' AND multitaper_spectrogram_rust_mex on path
%                              → Rust path.
%     otherwise                → MATLAB path.
%
%   Bit-equivalence: f32 vs f64 produces ~1e-7 mean relative diff. Cosine
%   similarity > 0.99999 verified against the simulation_test fixture
%   (test_mts_cosine_similarity / test_mts_mean_relative_diff).

    if nargin < 10, verbose = false;     end
    if nargin <  9, ploton = false;      end
    if nargin <  8, weighting = 'unity'; end
    if nargin <  7, detrend_opt = 'linear'; end
    if nargin <  6, nfft = []; end
    % Some legacy call sites pass [] for weighting / detrend (the Coder
    % MEX accepts these as "use default"). Normalize so the Rust path
    % gets concrete strings.
    if isempty(weighting),   weighting = 'unity';   end
    if isempty(detrend_opt), detrend_opt = 'linear'; end

    % Pull backend choice from the per-run state set by runDYNAMO.
    bk = getappdata(0, 'dynamo_backend');
    if isempty(bk), bk = 'matlab'; end

    rust_mex_present = exist(['multitaper_spectrogram_rust_mex.' mexext], 'file') == 3;
    if strcmpi(bk, 'rust') && ~rust_mex_present
        % Build the rust MTS MEX for this platform — the silent fall-through
        % to the Coder MEX runs at single precision and (for the heavy
        % artifact-detection MTS config) is several × slower than the rust
        % path, which is what users typically hit when they ask "why is
        % rust slow on Linux?". Fail loud so the platform mismatch is
        % obvious instead of degrading silently.
        error('multitaper_spectrogram_dynamo:missingRustMEX', ...
            ['backend=''rust'' selected but multitaper_spectrogram_rust_mex.%s is not on the MATLAB path.\n' ...
             'Build it with:  cd <DYNAM-O_dev>/rust_bridge && build_rust_mex'], mexext);
    end
    use_rust = strcmpi(bk, 'rust') && rust_mex_present;

    if verbose
        if use_rust
            fprintf('  Multitaper spectrogram: rust (f64)\n');
        else
            fprintf('  Multitaper spectrogram: matlab (Coder MEX)\n');
        end
    end

    if use_rust
        % Rust path needs DPSS tapers explicitly. Mirror the Coder MEX's
        % default-nfft policy: 2^nextpow2(winsize) when caller passed [].
        winN = round(window_params(1) * Fs);
        if isempty(nfft) || nfft <= 0
            nfft = max(2^nextpow2(winN), 256);
        end
        NW = taper_params(1);
        K  = taper_params(2);
        % Prefer the Rust DPSS solver when its MEX is on path — drops the
        % Signal Processing Toolbox dependency for taper generation, and
        % the underlying multitaper_rs::dpss matches MATLAB's dpss(N,NW,K)
        % to <=1e-8 elementwise on every config in our test battery (see
        % rust_bridge/validate_dpss_mex.m).
        if exist('dpss_rust_mex', 'file') == 3
            [tapers, eigen] = dpss_rust_mex(winN, NW, K);
        else
            [tapers, eigen] = dpss(winN, NW, K);
        end
        eigen_arg = [];
        if strcmpi(weighting, 'eigen')
            eigen_arg = eigen;
        end
        if ~isa(data, 'double'), data = double(data); end
        data = data(:);
        [spect, stimes, sfreqs] = multitaper_spectrogram_rust_mex( ...
            data, Fs, freq_range, taper_params, window_params, ...
            tapers, eigen_arg, nfft, detrend_opt, weighting);
    else
        % MATLAB path — existing dispatcher (Coder MEX → pure-MATLAB).
        [spect, stimes, sfreqs] = multitaper_spectrogram_mex( ...
            data, Fs, freq_range, taper_params, window_params, ...
            nfft, detrend_opt, weighting, ploton, verbose);
    end
end
