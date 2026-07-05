# dynamo_rs improvements — bridge expansion ledger

Tracks additions to the MATLAB↔Rust MEX bridge in `DYNAM-O_rs/rust/src/c_api.rs`
and its companion shims in `DYNAM-O_dev/rust_bridge/`. One entry per kernel
brought across as we add MATLAB-callable paths to the existing Rust code.

Pre-existing bridge surface (carried forward from prior work):
`dynamo_extract_tfpeaks`, `dynamo_refine_peaks`, `dynamo_tfpeak_histogram`,
`dynamo_mask_spectrogram`, `dynamo_multitaper_spectrogram`.

---

## 2026-05-12  `dynamo_dpss`

- **Rust source:** `multitaper_rs::dpss(n, nw, k)` (vendored copy under
  `DYNAM-O_dev/toolbox/helper_functions/multitaper_toolbox/rust/`,
  synced to the upstream `preraulab/multitaper_toolbox` PR #9 dpss.rs
  + faer 0.24 / dyn-stack 0.13 deps).
- **C ABI:** `int dynamo_dpss(uintptr_t n, double nw, uintptr_t k,
  double *tapers_out, double *ratios_out)` — caller-allocated outputs;
  tapers row-major (K, N) which equals MATLAB column-major (N, K) bytewise.
- **MEX shim:** `dpss_rust_mex.c` → `[tapers, ratios] = dpss_rust_mex(n, nw, k)`.
- **MATLAB wiring:** `multitaper_spectrogram_dynamo.m` (line ~73) — calls
  `dpss_rust_mex(winN, NW, K)` when the MEX is on path, else MATLAB
  built-in `dpss(...)`.
- **Parity vs MATLAB R2025a `dpss(N, NW, K)`** (`validate_dpss_mex.m`):

  | Config              | Tapers max abs diff | Ratios max abs diff | Budget    | Result |
  |---|---|---|---|---|
  | n=128, NW=2.0, K=3  | 2.61e-13            | 6.88e-15            | 1e-9      | PASS |
  | n=1024, NW=4.0, K=7 | 3.25e-09            | 4.26e-14            | 1e-8      | PASS |

  (Larger config sits at the budget because faer's
  divide-and-conquer tridiagonal eigensolver orders Givens rotations
  differently from MATLAB's DSTEBZ+DSTEIN; same drift the upstream
  multitaper_rs tests document.)

- **Side benefit:** callers without a Signal Processing Toolbox
  license (every cluster node) now get DPSS for free.

---

## 2026-05-12  `dynamo_detect_artifacts`

- **Rust source:** `dynamo_rs::artifacts::detect_artifacts(data, fs, opts)` —
  band-detection iter-zscore (high-freq + broadband envelopes), flat-run
  mask, ±10σ outlier-noise backstop. Slope-test branch deliberately not
  bridged (stays on MATLAB; would need to pull `multitaper_rs` into the
  C ABI surface).
- **C ABI:** `int dynamo_detect_artifacts(const double *data, uintptr_t n,
  double fs, const struct ArtifactOptsFFI *opts, uint8_t *mask_out)` —
  caller-allocated u8 mask; 1 = artifact.
- **`ArtifactOptsFFI`:** `repr(C)` mirror of `ArtifactOpts`. Field order
  matches the Rust struct so cbindgen emits identical layout. Booleans
  as `u8`; zscore_method as `u32` (0=Robust, 1=Standard).
- **MEX shim:** `detect_artifacts_mex.c` → `mask = detect_artifacts_mex(data, Fs[, opts])`.
- **MATLAB wiring:** `detect_artifacts.m` early-return fast path when
  MEX is present AND `slope_test=false` AND no user exclusions AND no
  diagnostic plots. Slope-test path stays MATLAB.
- **Parity vs MATLAB R2025a `detect_artifacts(..., 'slope_test', false)`**
  on the synthetic-EEG battery (`validate_detect_artifacts_mex.m`):

  | Variant     | Disagreements | Budget | Result |
  |---|---|---|---|
  | sim_clean   | 0             | 5      | PASS |
  | sim_motion  | 4             | 30     | PASS |
  | sim_flat    | 3             | 5      | PASS |
  | sim_full    | 4             | 30     | PASS |
  | sim_dense   | 4             | 50     | PASS |

  Numbers track the upstream `preraulab/artifact_detection` PR #1 closely
  (same Rust kernel, same fixtures, same tolerances).

---

## 2026-05-12  `dynamo_compute_baseline`

- **Rust source:** `dynamo_rs::baseline::compute_baseline` — Hyndman-Fan #5
  per-frequency percentile over the valid (non-excluded, in-range) time
  columns, treating zeros as NaN. Matches MATLAB's `prctile(..., q, 2)`.
- **C ABI:** `int dynamo_compute_baseline(const double *spect, uintptr_t
  n_freqs, uintptr_t n_times, const double *stimes, const double *t_data,
  uintptr_t n_data, const uint8_t *baseline_exclude, double bl_range_lo,
  double bl_range_hi, double baseline_ptile, double *baseline_out)` —
  caller-allocated F-vector output.
- **Layout:** Rust expects row-major (F, T); MEX shim transposes from
  MATLAB column-major (F, T).
- **MEX shim:** `baseline_mex.c` →
  `baseline = baseline_mex(spect, stimes, t_data, baseline_exclude,
  baseline_range, baseline_ptile)`.
- **MATLAB wiring:** `computeTFPeaks.m::computeBaseline` (line ~485) —
  early-return through the MEX when present. Pure-MATLAB path preserved
  as a fallback (and as the reference for the parity gate).
- **Parity** (`validate_baseline_mex.m`): synthetic 128×600 log-normal
  spectrogram with injected zero patches and a 10 s exclude region.
  Max abs drift = **5.55e-17** (f64 round-off) vs budget 1e-9.

---

## 2026-05-12  `dynamo_so_power`

- **Rust source:** `dynamo_rs::so_power::so_power_from_spectrogram(...)` —
  full SO-power time-series + outlier rejection + percentile-shift
  normalization + stage interpolation + optional EEG-rate upsampling.
  Mirrors pydynamo `compute_so_power`; MATLAB analog is the
  292-LOC `computeSOpower.m`.
- **C ABI:** struct-In/Out pattern (mirrors `dynamo_multitaper_spectrogram`).
  `SoPowerIn` carries 16 fields incl. spectrogram, stimes/sfreqs,
  eeg_times, isexcluded (u8), staging arrays, time_range,
  outlier_threshold, retain_fs, and a null-terminated
  `norm_method` byte string (`"p2shift1234"`, `"percent"`,
  `"none"`, etc — parsed via `NormMethod::parse`). `SoPowerOut` has
  three callee-allocated f64 arrays (norm, times, stages) of length
  `n_out` plus a `(kind, value[2])` ptile triple.
- **MEX shim:** `so_power_mex.c` →
  `[SOpower_norm, SOpower_times, SOpower_stages, ptile] =
   so_power_mex(so_spect, stimes, sfreqs, eeg_times, isexcluded,
                stage_times, stage_vals, time_range,
                outlier_threshold, norm_method, retain_fs)`. Spect
  transposed col-major → row-major before the FFI call. Output
  arrays are memcpy-then-free.
- **MATLAB wiring:** **Not** wired into `computeSOpower.m` yet — the
  MATLAB function has a large optional-arg surface (filter-cache,
  diagnostic plots, custom Fs, EEG vs raw spectrogram input). Routing
  it cleanly requires per-arg mapping which is deferred until the
  end-to-end runDYNAMO parity test (task 11) confirms the Rust kernel
  matches MATLAB on canonical fixtures.
- **Bridge contract gate** (`validate_so_power_mex.m`): synthetic SO-band
  spectrogram (F=15 × T=5980) with NREM2/REM staging, three
  norm_methods (`p2shift1234`, `percent`, `none`) × two `retain_fs`
  modes. Asserts output lengths, monotone times, stage∈{0..5},
  ptile shape per method. All 6 cases PASS — bridge is contract-correct.

---

## 2026-05-12  `dynamo_so_phase`

- **Rust source:** `dynamo_rs::so_phase::so_phase_from_eeg(...)` — SOS
  bandpass via `sosfiltfilt` → Hilbert → `atan2` → unwrap → NaN at
  excluded samples → previous-neighbor stage interp.
  Mirrors pydynamo `compute_so_phase`; MATLAB analog is
  `computeSOphase.m`.
- **C ABI:** struct-In/Out. `SoPhaseIn` carries eeg, eeg_times,
  isexcluded (u8), SOS coefficients (row-major (K, 6) scipy layout
  `[b0 b1 b2 a0 a1 a2]`), and staging arrays. `SoPhaseOut` has four
  callee-allocated f64 arrays (so_phase_unwrapped, times, stages,
  filtdata) of length `n_data`.
- **MEX shim:** `so_phase_mex.c` →
  `[SOphase, times, stages, filtdata] = so_phase_mex(eeg, eeg_times,
   isexcluded, sos, stage_times, stage_vals)`. SOS transposed
  column-major (K, 6) → row-major before the FFI call.
- **MATLAB wiring:** **Not** wired into `computeSOphase.m` yet —
  same rationale as SO-power: deferred until end-to-end runDYNAMO
  parity (task 11). MEX is available for the runDYNAMO test
  whether or not the wrapper is rewritten.
- **Bridge contract gate** (`validate_so_phase_mex.m`): 300 s sim EEG
  (1 Hz sinusoid + Gaussian noise) with a 5 s excluded segment,
  Butterworth 4th-order [0.3, 1.5] Hz bandpass via `butter` →
  `zp2sos`. Asserts:
    - Output lengths = N.
    - NaN-mask in `SOphase` and `filtdata` matches `isexcluded` exactly.
    - Unwrapped-phase slope on the 1 Hz signal = **6.2832 rad/s** (= 2π,
      f64-exact agreement with the injected oscillation).
    - Previous-neighbor stage interp with fill=0 outside staging range.

---

## 2026-05-12  End-to-end runDYNAMO parity (after all 5 bridges land)

Ran `runtests('tests/test_simulation_truth')` — the existing
function-based test that runs `runDYNAMO` end-to-end on both backends
against a ground-truth fixture (`tests/simulation_test.mat`):

```
[setupOnce] running matlab backend...    done in 58.7s, 2049 peaks
[setupOnce] running rust backend...      done in  4.4s, 2047 peaks

Totals:
   15 Passed, 0 Failed, 0 Incomplete.
```

- **All 15 Hungarian-matched sub-tests PASS** (PeakTime, PeakFrequency,
  PeakAmplitude, SOpower, SOphase, et al.).
- **13× pipeline speedup** end-to-end (4.4 s vs 58.7 s on this fixture).
- The 2-peak difference between backends (2049 vs 2047) is the same
  numerical-edge drift we see at the per-kernel parity gates and is
  absorbed by the Hungarian matching tolerance.
- The bridges newly wired this session (DPSS + detect_artifacts +
  baseline) are exercised by runDYNAMO via auto-detect of their MEX
  presence; SO-power and SO-phase MEX are available but not yet
  routed through `computeSOpower.m` / `computeSOphase.m` — the
  end-to-end test passing while those two stay on MATLAB paths is the
  expected outcome.
