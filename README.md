<p align="center">
<img src="https://user-images.githubusercontent.com/78376124/214062562-4f8fc73b-5a0a-4cf7-b219-9d0de101528d.png">
</p>

# DYNAM-O (MATLAB) — The Dynamic Oscillation Toolbox

**Prerau Laboratory** · [sleepEEG.org](https://prerau.bwh.harvard.edu/)

This is the **MATLAB implementation** of DYNAM-O. It is the authoritative
pipeline for the algorithm: when results here disagree with the sibling
Python or Rust implementations, this is ground truth.

For the overview of what DYNAM-O is, the algorithm details, background /
motivation, citation, and how this repo relates to the Python and Rust
siblings, see the parent meta-repo:
**[DYNAM-O_toolbox](https://github.com/preraulab/DYNAM-O_toolbox)**.

---

## Start here — the DYNAM-O File Manager (GUI)

The **File Manager** is the primary interface for DYNAM-O. It is a
graphical application for loading EDF recordings and hypnograms,
configuring channels and analysis options, and running batch analyses
across many subjects without writing MATLAB code. Standalone (compiled)
executables for macOS, Windows, and Linux are in development; until those
ship, the File Manager runs inside MATLAB.

- **File Manager guide:** [`DYNAMOFileManager_README.md`](DYNAMOFileManager_README.md)
- **Launch from MATLAB:** `runApp` (sets up the path, then opens the File Manager)

Most users should start with the File Manager. The rest of this README
covers the **MATLAB DYNAM-O API** — `runDYNAMO`, the `DYNAMO` class, and
the underlying pipeline functions — for users writing their own analysis
scripts or integrating DYNAM-O into a larger MATLAB workflow.

---

## MATLAB API at a glance

**What you'll need:** a single-channel EEG time series (`data`, `Fs`) and
a hypnogram (`stage_times`, `stage_vals`).

**What you'll get:** a `stats_table` (one row per detected TF-peak), a
`SOPHs` struct containing SO-power and SO-phase histograms, and a summary
figure showing hypnogram, spectrogram, TF-peak scatter, and both
histograms.

**Time to first plot:** ~30 s (full night, `backend='rust'`) to ~140 s
(`backend='matlab'`) on the bundled `'segment'` example.

> **Staging label gotcha:** DYNAM-O uses `1=N3, 2=N2, 3=N1, 4=REM, 5=Wake`
> — this is the **reverse** of the convention used by most EDF stagers
> and EDF+ annotation files. If your histograms come out empty or
> inverted, check stage numbering first.

---

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Recipes (advanced usage)](#recipes-advanced-usage)
- [Main Pipeline Functions](#main-pipeline-functions)
  - [runDYNAMO](#rundynamo)
  - [DYNAMO (OOP class)](#dynamo-oop-class)
  - [DYNAMOFileManager (GUI)](#dynamofilemanager-gui)
  - [Key Sub-Functions](#key-sub-functions)
- [Options](#options)
  - [Detection Options](#detection-options-detection_opts)
  - [Baseline Options](#baseline-options-baseline_opts)
  - [SO-Power/Phase Histogram Options](#so-powerphase-histogram-options-sopowerphasehist_opts)
- [Output Reference](#output-reference)
  - [stats_table](#stats_table--tf-peak-features)
  - [SOPHs](#sophs--histogram-struct)
  - [timings](#timings--per-stage-wallclock)
- [Saved file formats (GUI batch outputs)](#saved-file-formats-gui-batch-outputs)
- [Unit tests](#unit-tests)
- [Repository Structure](#repository-structure)
- [Algorithm details and background](#algorithm-details-and-background)

---

## Installation

### Requirements

- **MATLAB R2018a or newer** (MEX wrappers use the classic C MEX API).
- **Memory:** 8 GB RAM is comfortable for full-night recordings; 4 GB works for shorter segments.
- Required MATLAB toolboxes: see [Required MATLAB Toolboxes](#required-matlab-toolboxes).

### 1. Clone

You can either clone this repo directly, or clone the parent meta-repo
([DYNAM-O_toolbox](https://github.com/preraulab/DYNAM-O_toolbox)) to get
MATLAB, Python, and Rust together as pinned sub-repos.

**Standalone (MATLAB-only):**

```bash
git clone --recursive https://github.com/preraulab/DYNAM-O.git
cd DYNAM-O
# Re-attach submodules to their tracking branches. The plain
# `--recursive` clone always lands them in detached HEAD; this one-liner
# walks the .gitmodules `branch` field and checks each one out.
git submodule foreach 'b="$(git config -f "$toplevel/.gitmodules" --get "submodule.$name.branch")"; \
                       [ -n "$b" ] && git checkout -q "$b" 2>/dev/null || true'
```

**Meta-repo (recommended — sets up MATLAB + Rust + Python in one go):**

```bash
git clone https://github.com/preraulab/DYNAM-O_toolbox.git
cd DYNAM-O_toolbox
./bootstrap.sh                        # macOS / Linux / WSL
# or
.\bootstrap.ps1                       # Windows
```

`bootstrap.sh` clones the three sub-repos, installs Rust if missing,
builds the Rust core, and (if MATLAB is detected) offers to compile the
MEX wrappers. It also re-attaches every submodule to its tracking
branch automatically. Re-run any time — each step checks whether its
target already exists.

**To pull updates later:** `./refresh.sh` from the meta-repo root pulls
the latest commits on every sub-repo, rebuilds Rust, and re-attaches
submodules. Don't use bare `git submodule update --init --recursive` —
it leaves submodules in detached HEAD and you can't pull or commit
from there cleanly.

### 2. Pick a backend

DYNAM-O ships two pipeline backends:

| Backend | Speed (full-night on M3) | Accuracy | Extra setup |
|---|---|---|---|
| **`'rust'`** *(default)* | **~30 s** | −0.8 % peak count vs MATLAB ground truth | Requires compiled MEX wrappers (step 3) |
| `'matlab'` | ~125 s | authoritative | None — works out of the box with MATLAB only |

<details>
<summary><b>How to select the backend</b> — call site, options struct, or GUI</summary>

Pick at call time:

```matlab
runDYNAMO(data, Fs, stage_times, stage_vals, 'backend', 'rust')     % default
runDYNAMO(..., 'backend', 'matlab')                                 % pure MATLAB
```

Or in a `detection_opts()` struct:

```matlab
opts = detection_opts('backend', 'matlab');
runDYNAMO(data, Fs, stage_times, stage_vals, opts);
```

The GUI (`DYNAMOFileManager` / `DYNAMOOptionsApp`) also surfaces the
`backend` setting as a dropdown on the Detection options panel — no
command-line override needed.

</details>

<details>
<summary><b>Progress feedback</b> — per-pass tick on the MATLAB console (rust backend)</summary>

With `'rust'` backend, each extract pass prints a single-line tick on the
MATLAB console whenever 10 % of segments complete:

```
  Extracting TF peaks: 10% 20% 30% 40% 50% 60% 70% 80% 90% 100%  [29.3s]
```

Disable with `detection_opts('show_pbar', false)` if you're scripting batches
and don't want the noise.

</details>

### 3. Build the Rust backend (optional, for speed)

The `'rust'` backend uses MEX wrappers around a pure-Rust kernel
([`DYNAM-O_rs`](https://github.com/preraulab/DYNAM-O_rs)). If you skip this step,
`'matlab'` backend works immediately. If you call `'rust'` without the MEX files built, 
you get a clear error with the build recipe.

<details>
<summary><b>Two build steps</b>, both one-time — Rust kernel, then MEX wrappers</summary>

**a. Build `libdynamo_rs`** (needs the [Rust toolchain](https://rustup.rs)):

```bash
cd <workspace>/DYNAM-O_rs/rust
cargo build --release
```

**b. Build the MEX wrappers** (needs a C compiler via `mex -setup C`):

```matlab
cd <workspace>/DYNAM-O_dev/rust_bridge
build_rust_mex
```

Produces four `.mex*` files in `rust_bridge/` with the extension for your
platform (`.mexmaca64`, `.mexmaci64`, `.mexa64`, or `.mexw64`).

</details>

See [`rust_bridge/README.md`](rust_bridge/README.md) for per-platform
details and troubleshooting.

### 4. Verify

```matlab
runDYNAMO('segment')
```

A summary figure appears and a timing table prints at the end.

<p align="right"><sub><a href="#table-of-contents">↑ Back to Table of Contents</a></sub></p>

---

## Quick Start

### Run the bundled example

```matlab
runDYNAMO('segment');   % ~90 min excerpt
runDYNAMO('night');     % full night
```

Loads `example_data/example_data.mat`, runs the full pipeline, and
produces a summary figure with the hypnogram, spectrogram, TF-peak
scatter, and SO-power/phase histograms.

### Minimal call on your own data

```matlab
[stats_table, ~, ~, ~, ~, ~, ~, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals);
```

**You get:**
- `stats_table` — one row per detected TF-peak (time, frequency, amplitude, bandwidth, duration, sleep stage, SO-power, SO-phase).
- `SOPHs` — struct with 2D SO-power and SO-phase histograms, bin definitions, and optional parametric/spline fits.
- A summary figure (unless `'plot_on', false`).

### Batch example (many subjects, no plots)

```matlab
for k = 1:numel(subjects)
    close all
    [stats_table{k}, ~, ~, ~, ~, ~, ~, SOPHs{k}] = runDYNAMO( ...
        subjects(k).data, subjects(k).Fs, subjects(k).stage_times, subjects(k).stage_vals, ...
        'plot_on', false, 'verbose', false);
end
```

### OOP interface

```matlab
d = DYNAMO(data, Fs, stage_times, stage_vals);
d.runDYNAMO();
d.fitParamBasis();
fh = d.displaySummaryPlot();
```

Use `runDYNAMO` for one-shot scripted or batch analysis. Use the `DYNAMO`
class when you want to iterate on options against the same recording
without reloading the data — re-run with different SOPH bin sizes or fit
settings via `d.updateOptions(...)` and `d.runDYNAMO()`.

### GUI batch processing

```matlab
runApp
```

<p align="right"><sub><a href="#table-of-contents">↑ Back to Table of Contents</a></sub></p>

---

## Recipes (advanced usage)

### Force MATLAB backend (no Rust dependency)

```matlab
[stats_table, ~, ~, ~, ~, ~, ~, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals, ...
    'backend', 'matlab');
```

### Capture per-stage timings

```matlab
[~, ~, ~, ~, ~, ~, ~, SOPHs, timings] = runDYNAMO(data, Fs, stage_times, stage_vals);
disp(timings)
```

A millisecond-precision summary table also prints at the end of verbose
runs. See [timings](#timings--per-stage-wallclock) for the field list.

### Fast iteration with a precomputed stats_table

TF-peak extraction dominates wallclock (~80 %). To iterate on SOPH bin
sizes, fit options, or plots without recomputing peaks:

```matlab
% First run — save the peak table
[stats_table, ~, ~, ~, ~, ~, ~, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals);
save('run_outputs.mat', 'stats_table', 'data', 'Fs', 'stage_times', 'stage_vals');

% Subsequent iteration — passes stats_table, skips TF-peak extraction
[~, ~, ~, ~, ~, ~, ~, SOPHs, timings] = runDYNAMO(data, Fs, stage_times, stage_vals, ...
    'stats_table', stats_table, 'plot_on', false);
```

Typical speedup: ~30 s → ~5 s.

### Skip the fit stages

```matlab
[~, ~, ~, ~, ~, ~, ~, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals, ...
    'fit_param_basis', false, ...
    'fit_spline_basis', false);
```

### Save the output figure

```matlab
runDYNAMO(data, Fs, stage_times, stage_vals, ...
    'save_output_image', true, ...
    'output_fname', 'subject_001_summary');
```

Writes `subject_001_summary.png` (PNG, 200 DPI). `output_fname` is
resolved against the current working directory — use an absolute path to
write elsewhere. Do not include the `.png` extension.

### Only the TF-peak table (no SOPH)

Request only 7 outputs; SOPH + fits are skipped:

```matlab
[stats_table, spect, stimes, sfreqs, data_tr, t_tr, artifacts] = ...
    runDYNAMO(data, Fs, stage_times, stage_vals);
```

Cuts ~10 s from a typical run.

### Option presets

```matlab
% Reproduce the Stokes-2023 paper parameters
det = detection_opts('quality_setting', 'stokes_2023');

% Highest-precision detection (no spectrogram downsampling)
det = detection_opts('quality_setting', 'precision');

% Custom SO-power normalization
soph = SOpowerphasehist_opts('SOpower_norm_method', 'percentile');

[stats_table, ~, ~, ~, ~, ~, ~, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals, ...
    'detection_options', det, 'SOPH_options', soph);
```

<p align="right"><sub><a href="#table-of-contents">↑ Back to Table of Contents</a></sub></p>

---

## Main Pipeline Functions

### `runDYNAMO`

Primary functional entry point. Orchestrates the complete pipeline.

```matlab
[stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, SOPHs, timings] = ...
    runDYNAMO(data, Fs, stage_times, stage_vals, time_range, baseline_options, detection_options, SOPH_options, ...)
```

**Required inputs:**

| Argument | Type | Description |
|---|---|---|
| `data` | `[N×1]` or `[1×N]` double | Single-channel EEG |
| `Fs` | double | Sampling frequency (Hz) |
| `stage_times` | `[1×S]` double | Sleep stage time markers (s) |
| `stage_vals` | `[1×S]` double | Stage labels — **DYNAM-O convention: 1=N3, 2=N2, 3=N1, 4=REM, 5=Wake** (opposite of most EDF stagers) |

**Optional name-value inputs:**

| Name | Default | Description |
|---|---|---|
| `backend` | `'rust'` | Pipeline backend: `'rust'` (MEX, fast) or `'matlab'` (pure MATLAB, reference) |
| `time_range` | full scored range | `[start, end]` in seconds |
| `baseline_options` | `baseline_opts()` | Baseline subtraction parameters |
| `detection_options` | `detection_opts()` | TF-peak detection parameters |
| `SOPH_options` | `SOpowerphasehist_opts()` | Histogram computation parameters |
| `param_basis_power_options` | `param_basis_opts('power')` | Parametric fit options (SO-power) |
| `param_basis_phase_options` | `param_basis_opts('phase')` | Parametric fit options (SO-phase) |
| `spline_basis_power_options` | `spline_basis_opts('power')` | Spline fit options (SO-power) |
| `spline_basis_phase_options` | `spline_basis_opts('phase')` | Spline fit options (SO-phase) |
| `stats_table` | `[]` | Precomputed peak table (bypasses detection) |
| `fit_param_basis` | `true` | Run parametric Gaussian/von Mises fits |
| `fit_spline_basis` | `true` | Run spline fits |
| `plot_on` | `true` | Generate summary figure |
| `save_output_image` | `false` | Save figure to disk |
| `output_fname` | `'DYNAM-O_output'` | Output filename |
| `verbose` | `true` | Print progress |

**Outputs:** see [Output Reference](#output-reference).

> **Positional vs name-value.** `runDYNAMO` uses `addOptional`, so each
> optional argument can be supplied either by position or by name. Once
> you skip a positional argument you must switch to name-value for the
> rest.

---

### `DYNAMO` (OOP class)

Object-oriented wrapper around `runDYNAMO` that stores data, options, and
results as properties. Use for iterative workflows on the same data.

```matlab
d = DYNAMO(data, Fs, stage_times, stage_vals);
d.runDYNAMO();
d.fitParamBasis();
d.fitSplineBasis();
fh = d.displaySummaryPlot();
```

**Key methods:**

| Method | Description |
|---|---|
| `runDYNAMO()` | Run the full pipeline |
| `updateOptions(opts)` | Update options and re-run |
| `fitParamBasis()` | Fit parametric Gaussian/von Mises |
| `fitSplineBasis()` | Fit spline basis |
| `displaySummaryPlot()` | Generate summary figure |
| `displayTFPeaks()` | Overlay peaks on spectrogram |

---

### `DYNAMOFileManager` (GUI)

App Designer application for batch processing EDF polysomnography files.

```matlab
runApp
```

- Add / remove EDF and staging file pairs
- Channel selection and staging format configuration
- Configure all pipeline options via the GUI
- Save outputs: figures, stats tables, parametric fits, spline fits
- Batch progress tracking with per-file logging

---

### Key Sub-Functions

### `computeTFPeaks`

Runs the watershed-based TF-peak extraction pipeline on raw EEG.

```matlab
[stats_table, spect, stimes, sfreqs, data_trunc, t_data_trunc, artifacts] = ...
    computeTFPeaks(data, Fs, stage_vals, stage_times, ...)
```

Accepts a `'backend'` option (`'rust'` / `'matlab'`) that propagates to
`runSegmentedData` (pass-1 + pass-2) and `refinePeakFrequency`.

### `SOpowerphaseHistogram`

Creates 2D SO-power and SO-phase histograms from TF-peak data.

```matlab
[SOpow_mat, SOphase_mat, SOpow_bins, SOphase_bins, freq_bins, ...] = ...
    SOpowerphaseHistogram(EEG, Fs, TFpeak_freqs, TFpeak_times, ...)
```

<p align="right"><sub><a href="#table-of-contents">↑ Back to Table of Contents</a></sub></p>

---

## Options

### Detection Options (`detection_opts`)

```matlab
opts = detection_opts('quality_setting', 'default', 'trim_vol', 0.8, ...);
```

**Quality presets** (set `downsample_spect`, `seg_time`, `merge_thresh` together):

| Setting | Downsample | Segment | Merge Threshold | Use Case |
|---|---|---|---|---|
| `'stokes_2023'` | none | 60 s | 8 | Reproduces published results |
| `'precision'` | none | 30 s | 8 | Highest accuracy |
| `'default'` | 2×2 | 30 s | 11 | Recommended for general use |

**All parameters:**

| Parameter | Default | Description |
|---|---|---|
| `quality_setting` | `'default'` | Preset (see above) |
| `double_watershed` | `true` | Use two-pass watershed (1 s + 2 s windows) |
| `downsample_spect` | `[2, 2]` | `[time_factor, freq_factor]` pre-watershed decimation |
| `seg_time` | `30` s | Segment duration for parallel processing |
| `merge_thresh` | `11` | Stop merging when edge weight falls below |
| `max_merges` | `Inf` | Maximum region merges allowed |
| `trim_vol` | `0.8` | Trim peaks to this fraction of max volume |
| `dur_max` | `5` s | Reject peaks longer than this |
| `bw_max` | `15` Hz | Reject peaks wider than this |
| `reuse_baseline` | `true` | Reuse pass-1 baseline in pass-2 (skip recompute) |
| `mtm_freq_range` | `[0, 30]` Hz | Spectrogram frequency range |
| `mtm_taper_params` | `[2, 3]` | Multitaper `[time-BW, num-tapers]` |
| `mtm_window_length_1` | `1` s | First-pass watershed window |
| `mtm_window_length_2` | `2` s | Second-pass watershed window |
| `mtm_window_stepsize` | `0.05` s | Spectrogram step |
| `mtm_dsfreqs` | `0.1` Hz | Spectrogram frequency resolution |
| `refinement` | `true` | Refine peak frequency with 1 Hz Hann spectrum |
| `features` | `'all'` | Features to extract (see stats_table below) |
| `show_pbar` | `true` | Show progress bar during parfor |
| `debug_mode` | `false` | Run segments serially (for profiling) |
| `parallel_mode` | `'Processes'` | Pool type for MATLAB backend: `'Processes'`, `'Threads'`, `''` |

### Baseline Options (`baseline_opts`)

```matlab
opts = baseline_opts('baseline_ptile', 2, 'baseline_stages', [1,2,3,4,5]);
```

| Parameter | Default | Description |
|---|---|---|
| `baseline_stages` | `[1,2,3,4,5]` | Sleep stages used for baseline estimation |
| `baseline_exclude` | `[]` | Additional time points to exclude |
| `baseline_ptile` | `2` | Percentile of power used as baseline |
| `baseline_trim` | `[-Inf, Inf]` | Time range for baseline estimation |

### SO-Power/Phase Histogram Options (`SOpowerphasehist_opts`)

```matlab
opts = SOpowerphasehist_opts('SOpower_norm_method', 'p5shift123', 'SOPH_stages', 1:3);
```

| Parameter | Default | Description |
|---|---|---|
| `freq_range` | `[0, 40]` Hz | Frequency axis range |
| `freq_binsizestep` | `[1, 0.2]` Hz | Frequency `[bin size, step]` |
| `SO_freqrange` | `[0.3, 1.5]` Hz | Slow-oscillation band definition |
| `SOpower_norm_method` | `'p2shift1234'` | Normalization method (see below) |
| `SOpower_binsizestep` | adaptive | SO-power `[bin size, step]` |
| `SOphase_binsizestep` | `[2π/5, 2π/100]` rad | SO-phase `[bin size, step]` |
| `SOPH_stages` | `[1, 2, 3]` | Stages included (NREM by default) |
| `SOpower_min_time_in_bin` | `10` min | Min time-in-bin for SO-power axis |
| `SOphase_min_peak_at_freq` | `1` | Min peaks per frequency row in SO-phase |
| `SOphase_norm_dim` | `1` | Dimension for SO-phase row normalization |
| `SOpower_outlier_threshold` | `3` SD | Exclude SO-power outliers |
| `compute_rate` | `true` | Output peaks/min (rate) vs raw count |
| `SOpower_retain_Fs` | `true` | Upsample SO-power timeseries to EEG Fs |
| `tapers` | `[5, 9]` | Multitaper params for SO-power |
| `window_params` | `[5, 0.5]` s | SO-power spectrogram window |

**SO-power normalization methods:**

| Method | Description |
|---|---|
| `'p2shift1234'` | Subtract 2nd percentile of NREM+REM SO-power *(default)* |
| `'pNshiftS'` | Subtract Nth percentile over stages S |
| `'percent'` | Scale between 1st and 99th percentile of artifact-free sleep |
| `'proportion'` | Ratio of SO-power to total power |
| `'none'` | Raw dB power |

<p align="right"><sub><a href="#table-of-contents">↑ Back to Table of Contents</a></sub></p>

---

## Output Reference

### `stats_table` — TF-peak features

One row per detected TF-peak. Available features (controlled by
`detection_opts.features`):

| Feature | Units | Description |
|---|---|---|
| `PeakTime` | s | Peak centroid time (intensity-weighted) |
| `PeakFrequency` | Hz | Peak centroid frequency (refined with 1 Hz Hann) |
| `Height` | μV²/Hz | Peak amplitude above baseline |
| `Area` | s·Hz | Time-frequency area of peak region |
| `Duration` | s | Peak duration |
| `Bandwidth` | Hz | Peak bandwidth |
| `Volume` | s·μV² | Time-frequency volume |
| `Peakiness` | dB | `10·log10(Area · Height / Volume)` — sharpness score |
| `BoundingBox` | (s, Hz, s, Hz) | `[t_tl, f_tl, width, height]` |
| `HeightData` | μV²/Hz | Per-pixel amplitudes within peak region |
| `Boundaries` | (s, Hz) | Boundary pixel `(time, frequency)` |
| `SegmentNum` | # | Segment containing this peak |
| `PeakStage` | — | Sleep stage at peak time (0=Unknown, 1=N3, 2=N2, 3=N1, 4=REM, 5=Wake, 6=Artifact) |
| `SOpower` | dB | Normalized SO-power at peak time |
| `SOphase` | rad | SO-phase at peak time (0=SO peak, ±π=SO trough) |

### `SOPHs` — histogram struct

| Field | Description |
|---|---|
| `SOpow_mat` | `[B×F]` SO-power histogram |
| `SOphase_mat` | `[B×F]` SO-phase histogram |
| `SOpow_bins` | SO-power bin centers |
| `SOphase_bins` | SO-phase bin centers (rad) |
| `freq_bins` | Frequency bin centers (Hz) |
| `SOpow_TIB` | Time-in-bin per SO-power bin (min) |
| `SOphase_TIB` | Time-in-bin per SO-phase bin (min) |
| `peak_SOpower` | Normalized SO-power at each peak |
| `peak_SOphase` | SO-phase at each peak (rad) |
| `peak_selection_inds` | Logical mask of peaks included in histograms |
| `SOpower` / `SOpower_times` | Full SO-power timeseries |
| `SOphase` / `SOphase_times` | Full SO-phase timeseries |
| `pow_param_fit` | Parametric fit (SO-power) — if `fit_param_basis=true` |
| `phase_param_fit` | Parametric fit (SO-phase) — if `fit_param_basis=true` |
| `pow_spline_fit` | Spline fit (SO-power) — if `fit_spline_basis=true` |
| `phase_spline_fit` | Spline fit (SO-phase) — if `fit_spline_basis=true` |

### `timings` — per-stage wallclock

Optional 9th output. Struct with per-stage wallclock seconds.

| Field | Stage |
|---|---|
| `pool_setup` | `setup_parallel_pool` (0 for `'rust'` backend) |
| `mex_build` | First-time MEX auto-compile |
| `spect_pass1` | Multitaper spectrogram, first pass (1 s window) |
| `artifact` | `detect_artifacts` |
| `baseline_pass1` | `computeBaseline`, first pass |
| `extract_pass1` | TF-peak extraction across all segments, first pass |
| `spect_pass2` | Multitaper spectrogram, second pass (2 s window) |
| `baseline_pass2` | Baseline recompute + spectrogram masking, second pass |
| `extract_pass2` | TF-peak extraction, second pass (finer freq resolution) |
| `refine` | `refinePeakFrequency` (Hann refinement) |
| `peak_stage` | `computePeakStage` |
| `peak_sopower` | `computePeakSOpower` |
| `peak_sophase` | `computePeakSOphase` |
| `soph_sopower_hist` | `SOpowerHistogram` (2D binning) |
| `soph_sophase_hist` | `SOphaseHistogram` |
| `plot_summary` | `displaySummaryPlot` (if `plot_on=true`) |
| `fit_param_basis` | Parametric fit (if `fit_param_basis=true`) |
| `fit_spline_basis` | Spline fit (if `fit_spline_basis=true`) |
| `total` | End-to-end wallclock |

<p align="right"><sub><a href="#table-of-contents">↑ Back to Table of Contents</a></sub></p>

---

## Saved file formats (GUI batch outputs)

The DYNAM-O File Manager writes per-subject results into
`<output_dir>/<channel>/<subdir>/`. For each artefact type the
**Saving Options** panel exposes a checkbox (save / don't save) and a
file-format dropdown with `--`, a slim format, `.mat`, and `All`.
Default for all four save formats is `All` so reconstruction is
always possible — pick a single format only when you know what you
need.

This section documents what each format contains, when it's
sufficient, and minimal read snippets in MATLAB and Python.

### Peak stats table — `stats_table/`

Per-subject TF-peak feature table (one row per detected peak; columns
described in [stats_table](#stats_table--tf-peak-features)).

| Format | What it contains | Reconstruct? |
|---|---|---|
| `.csv` | All scalar columns from `stats_table` | ✅ full |
| `.mat` | `stats_table` table variable | ✅ full |
| `All`  | both | ✅ full |

`.csv` is the canonical interchange format here; `.mat` is mainly for
keeping native MATLAB `categorical`s and round-tripping into other
DYNAM-O calls without re-typing.

```matlab
% MATLAB
T = readtable('subj01_stats_table_C3.csv');
S = load('subj01_stats_table_C3.mat');  T = S.stats_table;
```

```python
# Python
import pandas as pd, scipy.io as sio
T  = pd.read_csv('subj01_stats_table_C3.csv')
M  = sio.loadmat('subj01_stats_table_C3.mat', squeeze_me=True)
```

### SO-Histograms (SOPHs) — `SOPHs/`

Per-subject 2-D histograms of TF-peak rate by frequency × SO-feature
(SO-power and SO-phase). The toolbox writes one file per axis
(`*_SOPHs_<channel>` for `.mat`; `*_SOpower_SOPHs_<channel>` and
`*_SOphase_SOPHs_<channel>` for `.tiff`).

| Format | What it contains | Reconstruct? |
|---|---|---|
| `.tiff` | 2-D histogram (`double` IEEE float). `ImageDescription` JSON tag carries `freq_bins` and `SOpower_bins` / `SOphase_bins` so a reader can recover the axes without a sidecar. | ✅ full (image + bins) |
| `.mat`  | The full `SOPHs` struct (see [SOPHs](#sophs--histogram-struct)) — also includes time-in-bin, peak-level coordinates, and any fits already computed. | ✅ full + extras |

```matlab
% MATLAB — read .tiff + bins
M    = imread('subj01_SOpower_SOPHs_C3.tiff');
info = imfinfo('subj01_SOpower_SOPHs_C3.tiff');
meta = jsondecode(info(1).ImageDescription);  % .freq_bins, .SOpower_bins
% MATLAB — read .mat
S    = load('subj01_SOPHs_C3.mat');           % S.SOPHs.*
```

```python
# Python — read .tiff + bins
import json, tifffile, numpy as np, scipy.io as sio
with tifffile.TiffFile('subj01_SOpower_SOPHs_C3.tiff') as tf:
    M    = tf.asarray()
    meta = json.loads(tf.pages[0].tags['ImageDescription'].value)
freq_bins, sopower_bins = meta['freq_bins'], meta['SOpower_bins']

# Python — read .mat
S = sio.loadmat('subj01_SOPHs_C3.mat', squeeze_me=True, struct_as_record=False)
SOPHs = S['SOPHs']
```

### Parametric basis fit — `param_basis/`

Closed-form fit of each SOPH as a sum of rotated 2-D Gaussian
(power) or von-Mises × Gaussian (phase) modes plus a linear
background plane:

```
SOPH(x,y) = Σₙ basis_n(x,y; ampₙ, fmeanₙ, fstdₙ, pmeanₙ, pstdₙ, θₙ)
            + xxx·x + yyy·y + zzz
```

| Format | What it contains | Reconstruct? |
|---|---|---|
| `.csv` | Per-mode params table (`Amplitude, FreqMean, FreqStd, …, Theta`, plus phase-coupling annotation columns for power) **and a fixed-format comment header** carrying `background.{xxx,yyy,zzz}`, `unit_row` (phase only), `gof.{sse,rsquare,dfe,adjrsquare,rmse}`, the source `freq_bins` / `SOpower_bins` (or `SOphase_bins`), and the **raw fitobj coefficients** (`fitobj_coefnames` + `fitobj_coefvalues` JSON arrays). Header lines start with `# ` and are skipped by both MATLAB `readtable` (`'CommentStyle','#'`) and pandas (`comment='#'`). | ✅ full — use `fitobj_coefvalues` for exact reconstruction |
| `.mat`  | Full `*_paramfit` struct — params table, `fitobj` (MATLAB `cfit`), `gof` struct, `model_SOPH` (rendered model), `wshed_img` (watershed segmentation). | ✅ full + cfit + rendered model + watershed |
| `All`   | both | ✅ |

> ⚠️ **Phase Amplitude is not the raw fit coefficient.** For phase fits,
> `param_basis_phase.m` overwrites `params(:,1)` after fitting with an
> *empirical* no-sin amplitude (the model surface value at the peak's
> location with the sinusoidal background zeroed out) so that the
> `Amplitude` column reflects a human-interpretable peak height. Power
> fits do **not** apply this transformation. **For exact reconstruction
> of phase `model_SOPH`, use `fitobj_coefvalues` from the header — not
> the `Amplitude` column.** Power fits can be reconstructed either way
> (the values agree).

The Results Browser CSV preview detects the comment header and
splits the view: a key/value table on top showing the plane,
`unit_row`, gof, bins, and the raw fit coefficients; the per-mode
params table below.

```matlab
% MATLAB — params table + header (one-shot helper)
path = 'subj01_SOpower_paramfit_C3.csv';
T    = readtable(path, 'CommentStyle','#');
fid  = fopen(path,'r');  c = onCleanup(@() fclose(fid));
hdr  = struct();
while true
    L = fgetl(fid); if ~ischar(L) || ~startsWith(strtrim(L),'#'), break, end
    tok = regexp(L, '^#\s*([^:]+):\s*(.*)$', 'tokens', 'once');
    if numel(tok) == 2
        key = matlab.lang.makeValidName(tok{1});
        val = tok{2};
        if startsWith(val,'[') || startsWith(val,'"')
            hdr.(key) = jsondecode(val);
        else
            n = str2double(val); if ~isnan(n), hdr.(key) = n; else, hdr.(key) = val; end
        end
    end
end
% hdr.background_xxx, hdr.fitobj_coefnames, hdr.fitobj_coefvalues, hdr.freq_bins, …
```

```python
# Python — params table + header dict (with array fields parsed)
import json, pandas as pd, re
path = 'subj01_SOpower_paramfit_C3.csv'
T    = pd.read_csv(path, comment='#')

hdr = {}
with open(path) as f:
    for line in f:
        if not line.startswith('#'): break
        m = re.match(r'#\s*([^:]+):\s*(.*)$', line.rstrip())
        if not m: continue
        key, val = m.group(1).strip(), m.group(2).strip()
        if val.startswith('[') or val.startswith('"'):
            hdr[key] = json.loads(val)
        else:
            try: hdr[key] = float(val)
            except ValueError: hdr[key] = val
# hdr['background.xxx'], hdr['fitobj_coefnames'], hdr['fitobj_coefvalues'], …
```

### Spline basis fit — `spline_basis/`

Tensor-product cubic B-spline fit of each SOPH on a small
`(num_knots_x+2) × (num_knots_y+2)` lattice of control points
(`coefs`).

| Format | What it contains | Reconstruct? |
|---|---|---|
| `.tiff` | **2-page** TIFF. Page 1 = `coefs` (the parameter matrix that *is* the model); `ImageDescription` JSON carries `knots_x`, `knots_y`, `freq_bins`, `SOpower_bins` / `SOphase_bins`, plus `page1`/`page2` labels. Page 2 = `splinefit` (the rendered fit on the fit-domain grid) for direct preview without rebuilding the spline. | ✅ full (coefs + knots + fit-domain bins) |
| `.mat`  | Full `*_splinefit` struct: `splinefit`, `coefs`, `knots_x`, `knots_y`, `spline_obj` (MATLAB `spap2` form), plus `fit_SOfeature_bins` / `fit_freq_bins` (the bins the fit was actually computed on). | ✅ full + ready-to-`fnval` `spline_obj` |
| `All`   | both | ✅ |

> ⚠️ **The bins in the spline TIFF are the fit-domain bins, not the
> source SOPH bins.** `spline_basis.m` filters bins by
> `power_limits` / `phase_limits` / `freq_limits` and an
> all-finite-rows validity mask before fitting (`spline_basis.m` ~ line
> 146). Page 2 is the spline rendered on those filtered bins, so the
> bins listed in `ImageDescription` are smaller than the full
> `SOPHs.SOpower_bins` / `freq_bins`. They're also what you need to
> feed `spap2` / `fnval` to exactly reproduce page 2.

```matlab
% MATLAB — coefs + metadata from page 1, rendered fit from page 2
path  = 'subj01_SOpower_splinefit_C3.tiff';
coefs     = double(imread(path, 1));   % size (n_y+2) × (n_x+2)
splinefit = double(imread(path, 2));   % rendered on fit-domain bins
info = imfinfo(path);
meta = jsondecode(info(1).ImageDescription);   % knots_x, knots_y, fit-domain bins

% Reconstruct on the same grid (recovers page 2 exactly):
sp = spmak({augknt(meta.knots_x,3), augknt(meta.knots_y,3)}, coefs.');
[X, Y] = ndgrid(meta.SOpower_bins, meta.freq_bins);
splinefit_recon = reshape(fnval(sp, [X(:)'; Y(:)']), size(X));
% then fnval(sp, [Xq(:)'; Yq(:)']) on any (Xq, Yq) ndgrid you like.
```

```python
# Python — coefs + metadata + rendered preview (via tifffile + scipy)
import json, tifffile, numpy as np
from scipy.interpolate import BSpline   # or RectBivariateSpline

with tifffile.TiffFile('subj01_SOpower_splinefit_C3.tiff') as tf:
    coefs     = tf.pages[0].asarray()      # (n_y+2, n_x+2)
    splinefit = tf.pages[1].asarray()      # rendered, on fit-domain bins
    meta      = json.loads(tf.pages[0].tags['ImageDescription'].value)
# Off-grid reconstruction: build cubic B-splines using
# meta['knots_x'], meta['knots_y'] (augmented in MATLAB via augknt) and
# coefs.T to match MATLAB's [n_x, n_y] layout.
```

### Auxiliary data — `auxiliary_data/`

Per-subject `.mat` only. Contains `artifacts`, `Fs`,
`SOpower_norm_method`, and other run-time scalars used by the
Results Browser and the aggregation step.

### Run settings — `settings/`

Per-run JSON snapshot of every options struct (`detection_options`,
`baseline_options`, `SOPH_options`, the four basis-fit options
structs, etc.) plus a `run_start` timestamp and a `schema_version`.
Written by `generate_run_log` as `run_settings_<timestamp>.json`,
read back by `load_run_log` (and by the File Manager's "Load
settings" action). The format is pure data — no executable code —
so loading a settings file from another user is safe. `Inf`, `-Inf`,
and `NaN` round-trip via sentinel strings (`"__inf__"`, `"__-inf__"`,
`"__nan__"`); arrays containing them are encoded as JSON arrays of
mixed numeric/sentinel entries and decoded back to numeric vectors.

```matlab
% MATLAB
opts = load_run_log('run_settings_260504_165939.json');
% opts.detection_options, opts.baseline_options, ...
```

### Figures — `figures/`

`.png`, `.tiff`, `.pdf` exports of summary, parametric, and spline
figures. These are renderings — they are *not* reloadable into
DYNAM-O state.

### Aggregates — `<output_dir>/aggregates/<channel>/`

Cross-subject stacks built by the Results Browser **Aggregate**
action. The aggregate `.tiff`s are multi-page (one page per subject)
with the same `ImageDescription` bin metadata and a sibling
`*_subjectIDs.txt` listing subject IDs in page order; the
aggregate `.mat`s carry concatenated histogram and paramfit tables.

<p align="right"><sub><a href="#table-of-contents">↑ Back to Table of Contents</a></sub></p>

---

## Unit tests

The `tests/` folder contains a small suite built on MATLAB's standard
`matlab.unittest` framework. The headline test runs both backends on a
synthetic dataset with **known** peak locations, Hungarian-matches each
backend's `stats_table` to ground truth, and asserts on per-peak time,
frequency, and SO-phase bias.

### Running

Interactively, from MATLAB:

```matlab
addpath('/path/to/DYNAM-O_dev');
DYNAMO_addpath();
cd('/path/to/DYNAM-O_dev/tests');
run_all_tests                                 % whole folder, asserts on failure
runtests('test_simulation_truth')             % one file, table output
```

Headless / CI:

```sh
matlab -batch "addpath('<repo>'); DYNAMO_addpath; cd tests; run_all_tests"
```

`run_all_tests` calls `assertSuccess(result)` so the process exits
non-zero on any sub-test failure — drop-in for GitHub Actions.

### What it tests

| Test | Asserts |
| --- | --- |
| `test_recall_matlab` / `test_recall_rust` | every true peak is matched |
| `test_time_bias_matlab` / `test_time_bias_rust` | `\|median Δt\|` < ½ spectrogram bin |
| `test_freq_bias_matlab` / `test_freq_bias_rust` | `\|median Δf\|` < 0.5 Hz |
| `test_phase_bias_matlab` / `test_phase_bias_rust` | `\|median Δphase\|` < 5° |
| `test_cross_backend_dt` | MATLAB vs Rust `\|median Δt\|` < 1 ms |

The phase-bias sub-tests exist as a regression guard for commit
`b59fa85` (2022-09-28), which silently dropped a `-1` from the
`WeightedCentroid` conversion in `computePeakStatsTable.m` and biased
every `PeakTime` by one spectrogram bin (~+13° of SOphase). Restoring
the `-1` collapsed the bias from +12.6° to −1.1° against ground truth.

### Layout

```
tests/
├── run_all_tests.m              CI entry point — runtests + assertSuccess
├── test_simulation_truth.m      Function-based test (functiontests style)
└── simulation_test.mat          Ground-truth fixture (data, Fs, true_values)
```

Both backends run **once** in `setupOnce` (~40 s, dominated by the
MATLAB pass); the matched-pair data is cached in `testCase.TestData`
so the nine assertion sub-tests cost milliseconds each.

<p align="right"><sub><a href="#table-of-contents">↑ Back to Table of Contents</a></sub></p>

---

## Repository Structure

```
DYNAM-O_dev/
├── DYNAMO.m                         OOP pipeline class
├── runDYNAMO.m                      Functional pipeline entry point
├── runApp.m                         GUI launcher (toolbox + app on path, opens FileManager)
├── DYNAMO_addpath.m                 Headless path setup (toolbox only, no GUI)
├── clearDynamoClasses.m             Clear cached DYNAMO classdef state (after edits / branch switch)
├── example_data/
│   ├── example_data.mat             Single-channel sleep EEG example
│   └── runExampleData.m             Example data loader
├── tests/                           matlab.unittest suite (see Unit tests)
│   ├── run_all_tests.m              Folder runner — assertSuccess for CI
│   ├── test_simulation_truth.m      Both-backends-vs-ground-truth assertions
│   └── simulation_test.mat          Synthetic data + true_values fixture
├── rust_bridge/                     Rust backend (MEX wrappers around dynamo_rs)
│   ├── README.md                    Per-platform build guide
│   ├── build_rust_mex.m             MATLAB-side compile script
│   ├── extract_tfpeaks_mex.c        Pass-1 / pass-2 extraction MEX
│   ├── mask_spectrogram_mex.c       Pass-2 mask MEX
│   ├── refine_peaks_mex.c           Hann refinement MEX
│   ├── tfpeak_histogram_mex.c       SOpower / SOphase histogram MEX
│   └── *.mex{a64,maca64,maci64,w64} Platform-specific binaries
├── app/                             GUI lives here (compile target for mcc -m)
│   ├── @DYNAMOFileManager/          Class folder (split-file methods)
│   │   ├── DYNAMOFileManager.m      Properties + constructor + most methods
│   │   ├── createUIFigureAndShell.m Builder: figure, File menu, outer tabs
│   │   ├── createBatchSetupTab.m    Builder: File Selection + Runtime Options
│   │   ├── createBottomBar.m        Builder: status, RUN/STOP, Help, progress
│   │   ├── createResultsBrowserTab.m Builder: tree + preview pane
│   │   ├── createAnalysisTab.m      Builder: SO-Histograms host
│   │   └── finalizeUI.m             Builder: Help menu (rightmost), tooltips
│   ├── +results_browser/            Package: 19 helpers for the Results Browser
│   └── components/
│       └── CSSuicontrols/           Submodule: HTML-backed UI controls
└── toolbox/                         Pure science (importable headlessly via DYNAMO_addpath)
    ├── dynamo_version.m             '1.0.0' release constant
    ├── TFpeak_functions/            Watershed TF-peak extraction
    │   ├── computeTFPeaks.m         Main detection function
    │   ├── runWatershed.m           MATLAB watershed segmentation
    │   ├── runSegmentedData.m       Segment parfor + MEX dispatch
    │   ├── extractTFPeaks.m         Region feature extraction
    │   ├── computePeakStatsTable.m  Build stats table from regions
    │   ├── mergeRegions.m           Region merge implementation
    │   ├── computeMergeWeights.m    Adjacency edge weights
    │   ├── trimWshedRegions.m       Volume-based peak trimming
    │   ├── removeBaseline.m         Percentile baseline subtraction
    │   ├── refinePeakFrequency.m    Sub-resolution frequency refinement
    │   ├── computePeakStage.m       Assign sleep stage to each peak
    │   ├── computePeakSOpower.m     Assign SO-power to each peak
    │   ├── computePeakSOphase.m     Assign SO-phase to each peak
    │   ├── displaySummaryPlot.m     Summary visualization
    │   ├── displayTFPeaks.m         Peak overlay on spectrogram
    │   └── option_sets/             detection_opts, baseline_opts, setup_parallel_pool
    ├── SOpowphase_functions/        SO-power/phase computation and histograms
    ├── SOPH_dim_reduction/          Parametric and spline fitting
    ├── TFsigma_peak_detector/       Alternative sigma-band peak detector
    └── helper_functions/            Multitaper, artifacts, EDF, plotting, tests, …
        └── dynamo_helpers/          Run-record + settings infrastructure
            ├── generate_run_log.m            Write per-run options struct to JSON (safe, no eval)
            ├── load_run_log.m                Read run-settings JSON (replaces legacy `run()` loader)
            ├── DYNAMORunLogger.m             Append-only JSONL writer
            ├── dynamo_index_runs.m           Read+union JSONL files into a single index
            ├── dynamo_walk_results.m         Pure recursive walker (CLI / scripts)
            ├── dynamo_seed_index.m           CLI: walk + emit backfill JSONL
            └── dynamo_seed_index_from_cache.m  Generic seeder (consumed by both walkers)
```

The toolbox is GUI-free: a script that does `DYNAMO_addpath; runDYNAMO(...)`
never sees `app/` on its path. The launcher (`runApp.m`) layers `app/`
and `app/components/` on top for the GUI flow. `app/` is the natural
`mcc -m` compile target.

### Included Submodules

DYNAM-O depends on several standalone libraries included as Git submodules. The toolbox-side submodules live under `toolbox/helper_functions/`; the GUI's UI-control library lives under `app/components/`. All are cloned automatically with `--recursive` (see [Installation](#installation)).

> [!IMPORTANT]
> If you already have a checkout from before the `app/components/CSSuicontrols`
> path was introduced, run once after pulling:
> ```bash
> git submodule sync && git submodule update --init --recursive
> ```
> This flips your local `.git/config` to point CSSuicontrols at its new path.

| Submodule | Repository | Description |
|---|---|---|
| **Multitaper Spectrogram** | [preraulab/multitaper_toolbox](https://github.com/preraulab/multitaper_toolbox) | Multitaper spectral estimation (MATLAB, Python, R, Rust). Provides the time-frequency decomposition underlying TF-peak detection and SO-power computation. Includes an optimized C MEX implementation. |
| **Artifact Detection** | [preraulab/artifact_detection](https://github.com/preraulab/artifact_detection) | Detects and removes artifacts in EEG time series using high-frequency and broadband filtering with adaptive z-score thresholding. Includes Hjorth feature-based detection. |
| **Read EDF** | [preraulab/read_EDF](https://github.com/preraulab/read_EDF) | Reads European Data Format (EDF/EDF+) files with full metadata extraction, per-signal scaling, and optional MEX acceleration. Includes a GUI for exploring EDF headers. |
| **Statistical Tests** | [preraulab/multicomp_test](https://github.com/preraulab/multicomp_test) | Permutation-based statistical tests and false discovery rate (FDR) correction for multi-dimensional data. Provides `permtest`, `gpermtest`, `FDR_1D`, and `FDR_2D`. |
| **CSSuicontrols** | [preraulab/CSSuicontrols](https://github.com/preraulab/CSSuicontrols) | CSS-styled HTML-backed UI controls for MATLAB App Designer. Powers the progress bar, text areas, buttons, and other custom widgets in DYNAMOFileManager. Lives at `app/components/CSSuicontrols/`. |

> [!NOTE]
> To update all submodules to their latest versions:
> ```bash
> git submodule update --recursive --remote
> ```
> This updates the working trees only — `git add` and commit the bumped
> submodule pointers in the parent repo to land them.

### Required MATLAB Toolboxes

| Toolbox | Required For |
|---|---|
| **Image Processing Toolbox** | `watershed`, `regionprops`, `imresize`, `label2rgb`, `bwconncomp`, `imreconstruct` — both backends |
| **Signal Processing Toolbox** | Filtering, Hilbert transform, DPSS windows |
| **Curve Fitting Toolbox** | Parametric Gaussian/von Mises fitting |
| **Statistics and Machine Learning Toolbox** | Distribution fitting, FDR correction |
| **Parallel Computing Toolbox** | *(Optional)* `parfor` in the MATLAB backend |

`runDYNAMO` verifies the Image Processing Toolbox is licensed at startup
and errors with a clear install pointer if it's missing — so you won't hit
cryptic `Undefined function 'watershed'` errors mid-pipeline.

<p align="right"><sub><a href="#table-of-contents">↑ Back to Table of Contents</a></sub></p>

---

## Algorithm details and background

See the parent meta-repo
[DYNAM-O_toolbox README](https://github.com/preraulab/DYNAM-O_toolbox) for:

- High-level algorithm overview (all four pipeline stages)
- Background and motivation (why TF-peaks, why SO-power/phase)
- Pointers to the Rust kernel and Python implementations
- Citation and license

For in-depth algorithm documentation and video tutorials, visit the
[Prerau Lab DYNAM-O page](https://prerau.bwh.harvard.edu/DYNAM-O/).

<details>
<summary><b>Expand to see performance benchmarks</b></summary>

### Backends at a glance

| Backend | Implementation | Parallelism | Peak count (night) | Wallclock |
|---|---|---|---|---|
| **`'rust'`** *(default)* | `dynamo_rs` via MEX | `rayon` inside MEX (no parpool) | 34 511 | ~30 s (M3) |
| `'matlab'` | pure MATLAB | `parfor` over segments | 34 788 (truth) | ~125 s (M3) |

Both produce visually indistinguishable SO-power / SO-phase histograms
(cosine similarity 0.999 / 0.996). The −0.8 % peak-count gap is a subtle
label-assignment detail in Rust merge that shifts ~270 peaks across the
bandwidth/duration filter cutoffs; downstream histograms are unaffected.

### Parallel pool (MATLAB backend only)

The Rust backend ignores the parpool — it parallelises internally via
`rayon`. The MATLAB backend uses a parpool over segments. Override the
pool type via `detection_options.parallel_mode`:

```matlab
det = detection_opts();
det.parallel_mode = 'Processes';   % default
det.parallel_mode = 'Threads';     % thread-pool alternative
det.parallel_mode = '';            % same as 'Processes'
[stats_table, ~, ~, ~, ~, ~, ~, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals, ...
    baseline_opts(), det, 'backend', 'matlab');
```

Both pool types work for the MATLAB backend. On 8-core Apple Silicon
(M2 / M3) `'Threads'` tends to be ~8 % faster than `'Processes'` at
full-night scale; on other hosts `'Processes'` is the safer default.

### Expected runtimes — bundled `'night'` example

| Platform | `'rust'` | `'matlab'` |
|---|---|---|
| Apple M3 Mac (8 cores) | ~30-35 s | ~120-140 s |
| Apple M4 Max (16 cores) | ~25-30 s | ~55-65 s |
| Linux 24-core Threadripper | ~20-25 s | ~60-65 s |
| Linux 32-core Threadripper | ~15-20 s | ~35-40 s |
| Windows 6-core Ryzen | ~45-55 s | ~210-230 s |

Single-run variance ±5–15 % from thermal / OS scheduling. For benchmarks, run 3–5× and take the median.

</details>

### Recommended sampling frequency: 100 Hz

DYNAM-O analyzes 0–30 Hz, so 100 Hz Nyquist is well above anything the pipeline cares about. Resampling higher-rate EDFs (128 / 200 / 256 / 500 / 1000 Hz) **down** to 100 Hz before analysis gives a ~2× end-to-end speedup with **zero analytical change** — the antialiased polyphase filter is lossless for sleep oscillations.

The mechanism: multitaper NFFT = `2^nextpow2(Fs / mtm_dsfreqs)` (default `mtm_dsfreqs = 0.1`). The first NFFT-bucket boundary above 100 Hz sits at exactly **Fs = 102.4 Hz**. Anything above that doubles NFFT (1024 → 2048) and typically spills the spectrogram past CPU L3 cache, so every downstream stage (extract / baseline / mask / watershed) takes a further 2–3× memory-bandwidth hit on top.

| Native Fs | NFFT | Spec stage cost vs 100 Hz |
|---:|---:|---:|
| ≤ 100 | 1024 | 1× |
| 128, 200 | 2048 | ~2.2× |
| 256 | 4096 | ~4.6× |
| 500, 512 | 8192 | ~9.3× |
| 1000 | 16384 | ~18× |

The FileManager has Resample = ON at 100 Hz by default. For scripted callers (`runDYNAMO`, `DYNAMO` class):

```matlab
[p, q] = rat(100 / Fs);
data   = resample(data, p, q);
Fs     = 100;
% then call runDYNAMO(data, Fs, ...) as usual
```

### Troubleshooting

- **`backend='rust' requires compiled MEX files (missing: …)`** — you haven't built the Rust MEX yet. Follow [Installation step 3](#3-build-the-rust-backend-optional-for-speed), or pass `'backend', 'matlab'`.
- **`dynamo_rs.h not found` during `build_rust_mex`** — run `cargo build --release` in `DYNAM-O_rs/rust` first.
- **`mex: Compiler not configured`** — run `mex -setup C` in MATLAB and select a supported compiler (Xcode on macOS, gcc on Linux, MSVC/MinGW-w64 on Windows).
- **MEX run gives subtly different peak counts after a fresh `cargo build`** — restart MATLAB. `libdynamo_rs` stays cached until the session exits; `clear mex` does not unload the dynamic library.
- **Figures accumulate across repeated runs** — pass `'plot_on', false` or call `close all` between iterations.
- **`Undefined function 'multitaper_spectrogram'`** — submodules weren't initialized. From the meta-repo: `./refresh.sh`. Standalone clone: `git submodule update --init --recursive` followed by the re-attach one-liner from the [Clone section](#1-clone).
- **Submodules in detached HEAD after cloning or branch-switching** — bare `git submodule update` always detaches. Run `./refresh.sh` from the meta-repo, or apply the re-attach one-liner from the [Clone section](#1-clone).
- **NaN values in EEG** — the pipeline does not tolerate NaNs in `data`. Interpolate across NaN runs or mark them via the artifact detector.
- **`stage_times` / `stage_vals` length mismatch** — both must be the same length; `stage_times` must be non-decreasing.
- **Recording shorter than one `seg_time` window** (default 30 s) — reduce `detection_opts.seg_time` for very short recordings.
- **Hypnogram starts at `t > 0`** — `stage_times` is interpreted in the same seconds-from-start frame as `data`. Shift `stage_times` to start at 0 or pass an explicit `time_range`.
- **Histograms empty / "power histogram is empty" warnings** — often a staging-convention mismatch (see gotcha at top), or `time_range` too short for SOPH min-time-in-bin.

<p align="right"><sub><a href="#table-of-contents">↑ Back to Table of Contents</a></sub></p>

---

## License

BSD 3-Clause — see [LICENSE](LICENSE) at the repository root.
