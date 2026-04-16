<p align="center">
<img src="https://prerau.bwh.harvard.edu/wp-content/uploads/2023/01/DYNAM-O-Logo-medium.png" width="450">
</p>

<p align="center"><i>Characterizing Individualized Neural Dynamics in Sleep EEG</i></p>

<p align="center">
<b>Developed by the Prerau Laboratory</b><br>
<a href="https://sleepeeg.org">sleepeeg.org</a> |
<a href="https://prerau.bwh.harvard.edu/dynam-o/">Tutorials</a> |
<a href="https://github.com/preraulab/DYNAM-O">GitHub</a>
</p>

---

### Attribution

If you use this toolbox in publications or derived work, please cite:

> He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J. "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics in Sleep EEG", 2026 — *Pending Publication*

> Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S., Manoach, D. S., Stickgold, R., Prerau, M. J. "Transient Oscillation Dynamics During Sleep Provide a Robust Basis for Electroencephalographic Phenotyping and Biomarker Identification", *Sleep*, 2022; zsac223. https://doi.org/10.1093/sleep/zsac223

If using the included perceptually uniform colormaps (`gouldian`, `rainbow4`), also cite:
> Peter Kovesi. *Good Colour Maps: How to Design Them*. arXiv:1509.03700 [cs.GR] 2015. https://arxiv.org/abs/1509.03700

---

## DYNAM-O: The Dynamic Oscillation Toolbox for MATLAB

This repository contains the updated and optimized MATLAB toolbox for extracting transient oscillatory events from sleep EEG and characterizing them via slow-oscillation power and phase histograms. A [Python port (pyDYNAM-O)](https://github.com/preraulab/pyDYNAM-O) is also available.

---

## Table of Contents

- [Overview](#overview)
- [Background and Motivation](#background-and-motivation)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Main Pipeline Functions](#main-pipeline-functions)
  - [runDYNAMO](#rundynamo)
  - [DYNAMO (OOP class)](#dynamo-oop-class)
  - [DYNAMOFileManager (GUI)](#dynamofilemanager-gui)
- [Key Sub-Functions](#key-sub-functions)
  - [computeTFPeaks](#computetfpeaks)
  - [SOpowerphaseHistogram](#sopowerphasehIstogram)
- [Options and Configuration](#options-and-configuration)
  - [Detection Options](#detection-options-detection_opts)
  - [Baseline Options](#baseline-options-baseline_opts)
  - [SO-Power/Phase Histogram Options](#so-powerphase-histogram-options-sopowerphasehist_opts)
- [Output Reference](#output-reference)
  - [stats_table — TF-Peak Features](#stats_table--tf-peak-features)
  - [SOPHs — Histogram Struct](#sophs--histogram-struct)
- [Algorithm Details](#algorithm-details)
  - [Part 1: TF-Peak Detection](#part-1-tf-peak-detection)
  - [Part 2: Feature Computation](#part-2-feature-computation)
  - [Part 3: Feature Histograms](#part-3-feature-histograms)
  - [Dimensionality Reduction of Feature Histograms](#dimensionality-reduction-of-feature-histograms)
    - [Parametric Basis Fitting](#parametric-basis-fitting)
    - [Spline Basis Fitting](#spline-basis-fitting)
  - [Part 4: Statistical Testing](#part-4-statistical-testing)
  - [SO-Power Computation and Normalization](#so-power-computation-and-normalization)
  - [SO-Phase Computation](#so-phase-computation)
- [Repository Structure](#repository-structure)
- [Required Toolboxes](#required-toolboxes)

---

## Overview

The primary goal of DYNAM-O is to provide an analytic framework for characterizing and understanding the multidimensional dynamics of spindle-like transient oscillations in the sleep EEG spectrogram. This framework includes methods to extract time-frequency peaks (TF-peaks) and their properties, to visualize distributions of TF-peak features in an interpretable and efficient manner, and to conduct statistical tests to gain insights into sleep physiology. In doing so, DYNAM-O provides a powerful tool through which researchers can explore stable features of sleep EEG, efficiently capturing the neural dynamics of tens of thousands of transient oscillatory events throughout the night.

The processing pipeline is structured into four main parts:

1. **Identifying TF-peaks from spectrograms** — extract transient oscillation events from a multitaper spectrogram using a watershed-based algorithm with sequential optimization for temporal and spectral resolution
2. **Computing feature properties of TF-peaks** — compute microscopic (geometry, location) and macroscopic (sleep stage, SO-power, SO-phase) properties for each peak
3. **Encoding TF-peak dynamics with feature histograms** — represent the overnight distribution of TF-peak properties as SO-power and SO-phase histograms, with optional parametric and spline dimensionality reduction
4. **Statistical tests on TF-peak dynamics** — whole-histogram and mode-based group comparisons with FDR correction and permutation testing

The analyses can be applied autonomously to any single-channel electrophysiological recording from overnight sleep EEG data. While DYNAM-O is designed for sleep EEG, `computeTFPeaks` can also be used with dummy staging to analyze transient oscillation events in any time series data.

---

## Background and Motivation

Electroencephalography (EEG) is one of the most important modalities to study sleep physiology. Since the onset of sleep research, clinicians and researchers have been carefully inspecting time traces for brain wave patterns, where both macroscopic structures of sleep such as distinct sleep stages, and microscopic features such as sleep spindles, have been established as part of the clinical manual for sleep scoring. However, brain wave patterns in polysomnography (PSG) are noisy and difficult to quantify, often producing diverging results from repeated recordings or from two different raters reading the same recording. It is challenging to determine whether within-subject changes in EEG measures over multiple nights are meaningful or simply natural variability.

It is important to recognize that EEG signals during sleep are primarily generated by cortical activity within a sleeping individual, whose neuronal and subcortical origins presumably do not change drastically from night to night. This suggests that some features of sleep should be robust to nightly perturbations while being highly individualized. Indeed, recent studies have revealed numerous stable and individualized features of sleep, including aspects of the EEG power spectrum, waveform morphological traits, and properties of sleep spindles. Measures that capture these stable patterns carry great potential to be more representative of an individual's physiological state during sleep and more informative of underlying neural dynamics.

A common challenge for sleep EEG measures to capture neural dynamics is that conventional measures are often derived heuristically instead of from a principled basis. A prominent example is sleep spindles, traditionally defined as a train of distinct waves oscillating within 11–16 Hz lasting more than 0.5 seconds — a definition that stems from the earliest days of visual PSG inspection. Imposing hard-coded cutoffs may appear to enforce consistent standards but in fact renders outcome measures more variable and less interpretable due to bias. Our earlier work showed that sleep spindles detected by human experts represent only about 30% of spindle-like transient oscillations in the spindle frequency range during NREM sleep. When considering all detectable transient oscillations, there is a much stronger night-to-night stability in event counts than in spindle rates or spectral power.

By studying all transient oscillations from spectrograms in an agnostic way, we coined the term **time-frequency peaks (TF-peaks)** to denote spindle-like electrophysiological events in sleep EEG. These TF-peaks turned out to be highly robust and individualized across multiple nights of sleep from the same subjects. Furthermore, studying TF-peaks allowed us to summarize in a single view the dynamics of tens of thousands of transient oscillations, revealing previously unreported changes in low-alpha transient oscillations in schizophrenia patients compared to controls.

<figure><img src="https://prerau.bwh.harvard.edu/images/TF peak%20detection_small.png" alt="TF peaks" style="width:100%">
<figcaption><b>Transient oscillation activity in the time domain appears as contiguous high-power regions (TF-peaks) in the spectrogram.</b></figcaption></figure>
<br/>

Rather than stratifying TF-peaks by fixed sleep stages, DYNAM-O characterizes their activity against two continuous markers of brain state during sleep:
- **Slow-oscillation power (SO-power)**: a continuous proxy for depth of sleep
- **Slow-oscillation phase (SO-phase)**: timing relative to cortical up/down states

These produce **SO-power** and **SO-phase histograms** — comprehensive, continuous representations of transient oscillation dynamics that capture structures of TF-peak distributions more robustly than conventional averaging approaches.

<figure><img src="https://prerau.bwh.harvard.edu/images/SOpowphase_small.png" alt="SO-power/phase histograms" style="width:100%">
<figcaption><b>SO-power and SO-phase histograms encode TF-peak activity as a function of sleep depth and cortical state timing.</b></figcaption></figure>

---

## Installation

Clone the repository with submodules:

```bash
mkdir DYNAM-O_dev
git clone --recursive git@github.com:preraulab/DYNAM-O_dev.git DYNAM-O_dev
git submodule foreach --recursive git checkout master
```

To update submodules later:

```bash
git submodule update --remote
```

No separate installation step is needed. `runDYNAMO` automatically adds the toolbox to the MATLAB path via `addpath(genpath(...))`.

---

## Quick Start

### Run the bundled example

```matlab
% Segment (~90 minutes):
runDYNAMO('segment');

% Full night:
runDYNAMO('night');
```

This loads `example_data/example_data.mat`, runs the full pipeline, and produces a summary figure showing the hypnogram, spectrogram, TF-peak scatter, and SO-power/phase histograms.

### Run on your own data

```matlab
% Minimal call — all options use defaults
[stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, SOPHs] = ...
    runDYNAMO(data, Fs, stage_times, stage_vals);
```

### OOP interface

```matlab
d = DYNAMO(data, Fs, stage_times, stage_vals);
d.runDYNAMO();
d.fitParamBasis();
fh = d.displaySummaryPlot();
```

### GUI batch processing

```matlab
DYNAMOFileManager();
```

---

## Main Pipeline Functions

### `runDYNAMO`

The primary functional entry point. Orchestrates the complete pipeline and returns all outputs.

```matlab
[stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, SOPHs] = ...
    runDYNAMO(data, Fs, stage_times, stage_vals, time_range, baseline_options, detection_options, SOPH_options, ...)
```

**Required inputs:**

| Argument | Type | Description |
|---|---|---|
| `data` | `[N×1] double` | Single-channel EEG time series |
| `Fs` | `double` | Sampling frequency (Hz) |
| `stage_times` | `[1×S] double` | Sleep stage time markers (s) |
| `stage_vals` | `[1×S] double` | Stage labels: 1=N3, 2=N2, 3=N1, 4=REM, 5=Wake |

**Optional name-value inputs:**

| Name | Default | Description |
|---|---|---|
| `time_range` | full scored range | `[start, end]` in seconds |
| `baseline_options` | `baseline_opts()` | Baseline subtraction parameters |
| `detection_options` | `detection_opts()` | TF-peak detection parameters |
| `SOPH_options` | `SOpowerphasehist_opts()` | Histogram computation parameters |
| `param_basis_power_options` | `param_basis_opts('power')` | Parametric fit options for SO-power histogram |
| `param_basis_phase_options` | `param_basis_opts('phase')` | Parametric fit options for SO-phase histogram |
| `spline_basis_power_options` | `spline_basis_opts('power')` | Spline fit options for SO-power histogram |
| `spline_basis_phase_options` | `spline_basis_opts('phase')` | Spline fit options for SO-phase histogram |
| `stats_table` | `[]` | Precomputed peak table (bypasses detection) |
| `fit_param_basis` | `true` | Run parametric Gaussian/von Mises fits |
| `fit_spline_basis` | `true` | Run spline fits |
| `plot_on` | `true` | Generate summary figure |
| `save_output_image` | `false` | Save figure to disk |
| `output_fname` | `'DYNAM-O_output'` | Output filename for saved figure |
| `verbose` | `true` | Print progress info |

**Outputs:** See [Output Reference](#output-reference).

---

### `DYNAMO` (OOP class)

An object-oriented wrapper around `runDYNAMO` that stores data, options, and results as properties.

```matlab
d = DYNAMO(data, Fs, stage_times, stage_vals, time_range, baseline_options, detection_options, SOPH_options);
d.runDYNAMO();
d.fitParamBasis();
d.fitSplineBasis();
fh = d.displaySummaryPlot();
```

**Key properties:** `Data`, `Fs`, `stage_times`, `stage_vals`, `stats_table`, `spect`, `stimes`, `sfreqs`, `artifacts`, `SOPHs`

**Key methods:**

| Method | Description |
|---|---|
| `runDYNAMO()` | Run the full pipeline |
| `updateOptions(opts)` | Update options and re-run |
| `fitParamBasis()` | Fit parametric Gaussian/von Mises to histograms |
| `fitSplineBasis()` | Fit spline basis to histograms |
| `displaySummaryPlot()` | Generate and return summary figure |
| `displayTFPeaks()` | Overlay detected peaks on spectrogram |

---

### `DYNAMOFileManager` (GUI)

An App Designer application for batch processing EDF polysomnography files.

```matlab
DYNAMOFileManager();
```

**Features:**
- Add/remove EDF and staging file pairs
- Channel selection and staging format configuration (delimiter, column indices, stage labels)
- Configure all pipeline options via the GUI
- Save outputs: figures, stats tables, parametric fits, spline fits
- Batch progress tracking with per-file logging

---

## Key Sub-Functions

### `computeTFPeaks`

Runs the watershed-based TF-peak extraction pipeline on raw EEG.

```matlab
[stats_table, spect, stimes, sfreqs, data_trunc, t_data_trunc, artifacts] = ...
    computeTFPeaks(data, Fs, stage_vals, stage_times, ...)
```

**Required inputs:**

| Argument | Description |
|---|---|
| `data` | `[1×N] double` — EEG time series |
| `Fs` | Sampling frequency (Hz) |
| `stage_vals` | Sleep stage values at each `stage_times` |
| `stage_times` | Timestamps of stage values |

**Key optional inputs:**

| Name | Default | Description |
|---|---|---|
| `t_data` | `(0:N-1)/Fs` | Timestamps for data samples |
| `time_range` | full data range | `[start, end]` (s) to analyze |
| `features` | `'all'` | Features to extract (see table below) |
| `artifacts` | `[]` (auto-detect) | Precomputed artifact mask |
| `quality_setting` | `'default'` | `'stokes_2023'`, `'precision'`, or `'default'` |
| `verbose` | `true` | Print progress |

**Outputs:**

| Name | Description |
|---|---|
| `stats_table` | Table of TF-peak features (see below) |
| `spect` | `[F×T]` multitaper spectrogram |
| `stimes` | Spectrogram time centers (s) |
| `sfreqs` | Frequency bins (Hz) |
| `data_trunc` | Data within `time_range` |
| `t_data_trunc` | Timestamps for `data_trunc` |
| `artifacts` | `[1×T] logical` artifact mask |

---

### `SOpowerphaseHistogram`

Creates 2D SO-power and SO-phase histograms from TF-peak data.

```matlab
[SOpow_mat, SOphase_mat, SOpow_bins, SOphase_bins, freq_bins, ...
 SOpow_TIB, SOphase_TIB, peak_SOpower, peak_SOphase, ...
 peak_selection_inds, SOpower, SOpower_times, SOphase, SOphase_times] = ...
    SOpowerphaseHistogram(EEG, Fs, TFpeak_freqs, TFpeak_times, ...)
```

**Required inputs:**

| Argument | Description |
|---|---|
| `EEG` | `[1×N] double` — EEG time series |
| `Fs` | Sampling frequency (Hz) |
| `TFpeak_freqs` | `[P×1]` — frequency of each TF peak (Hz) |
| `TFpeak_times` | `[P×1]` — time of each TF peak (s) |

**Key optional inputs:**

| Name | Default | Description |
|---|---|---|
| `stage_vals` / `stage_times` | — | For stage-restricted histograms |
| `freq_range` | `[0, 40]` Hz | Frequency axis range |
| `freq_binsizestep` | `[1, 0.2]` Hz | Frequency bin size and step |
| `SO_freqrange` | `[0.3, 1.5]` Hz | Slow-oscillation band definition |
| `SOpower_norm_method` | `'p2shift1234'` | SO-power normalization (see below) |
| `SOPH_stages` | `[1, 2, 3]` | Stages to include (default: NREM only) |
| `compute_rate` | `true` | Output peaks/min instead of count |
| `SOpower_min_time_in_bin` | `10` min | Minimum occupancy per SO-power bin |
| `plot_on` | `false` | Plot histograms |

**Outputs:**

| Name | Description |
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
| `SOpower` / `SOpower_times` | Full SO-power timeseries |
| `SOphase` / `SOphase_times` | Full SO-phase timeseries |

---

## Options and Configuration

### Detection Options (`detection_opts`)

Control the spectrogram computation, watershed algorithm, and peak filtering.

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
| `double_watershed` | `true` | Use two-pass watershed (1s + 2s windows) |
| `downsample_spect` | `[]` | `[time_factor, freq_factor]` decimation before watershed |
| `seg_time` | `[]` | Segment duration for parallel processing (s) |
| `merge_thresh` | `[]` | Stop merging when weight falls below this value |
| `max_merges` | `Inf` | Maximum region merges allowed |
| `trim_vol` | `0.8` | Trim peaks to this fraction of maximum volume |
| `dur_max` | `5` s | Reject peaks longer than this |
| `bw_max` | `15` Hz | Reject peaks wider than this |
| `mtm_freq_range` | `[0, 30]` Hz | Spectrogram frequency range |
| `mtm_taper_params` | `[2, 3]` | Multitaper `[time-BW, num-tapers]` |
| `mtm_window_length_1` | `1` s | Window for first watershed pass |
| `mtm_window_length_2` | `2` s | Window for second watershed pass |
| `mtm_window_stepsize` | `0.05` s | Spectrogram window step |
| `mtm_dsfreqs` | `0.1` Hz | Spectrogram frequency resolution |
| `refinement` | `true` | Refine peak frequency with 1Hz Hann spectrum |
| `features` | `'all'` | Features to extract (see stats_table below) |
| `show_pbar` | `true` | Show progress bar during segmented processing |
| `debug_mode` | `false` | Run segments serially instead of parfor |

---

### Baseline Options (`baseline_opts`)

Control how the spectrogram baseline is estimated and subtracted.

```matlab
opts = baseline_opts('baseline_ptile', 2, 'baseline_stages', [1,2,3,4,5]);
```

| Parameter | Default | Description |
|---|---|---|
| `baseline_stages` | `[1,2,3,4,5]` | Sleep stages used for baseline estimation |
| `baseline_exclude` | `[]` | Additional time points to exclude from baseline |
| `baseline_ptile` | `2` | Percentile of power used as baseline |
| `baseline_trim` | `[-Inf, Inf]` | Time range for baseline estimation, or buffer (min) around first/last sleep period |

---

### SO-Power/Phase Histogram Options (`SOpowerphasehist_opts`)

Control binning, normalization, and filtering for the SO-power and SO-phase histograms.

```matlab
opts = SOpowerphasehist_opts('SOpower_norm_method', 'p5shift123', 'SOPH_stages', 1:3);
```

**Key parameters:**

| Parameter | Default | Description |
|---|---|---|
| `freq_range` | `[0, 40]` Hz | Frequency axis range for histograms |
| `freq_binsizestep` | `[1, 0.2]` Hz | Frequency `[bin size, step]` |
| `SO_freqrange` | `[0.3, 1.5]` Hz | Band defining "slow oscillation" |
| `SOpower_norm_method` | `'p2shift1234'` | Normalization (see below) |
| `SOpower_binsizestep` | adaptive | SO-power `[bin size, step]` |
| `SOphase_binsizestep` | `[2π/5, 2π/100]` rad | SO-phase `[bin size, step]` |
| `SOPH_stages` | `[1, 2, 3]` | Stages included in histograms (NREM by default) |
| `SOpower_min_time_in_bin` | `10` min | Minimum time-in-bin for SO-power axis |
| `SOphase_min_peak_at_freq` | `1` | Minimum peaks per frequency row in SO-phase histogram |
| `SOphase_norm_dim` | `1` | Dimension over which SO-phase rows normalize to 1 |
| `SOpower_outlier_threshold` | `3` SD | Exclude SO-power outliers beyond this threshold |
| `compute_rate` | `true` | Output peaks/min (rate) rather than raw count |
| `SOpower_retain_Fs` | `true` | Upsample SO-power timeseries to EEG sampling rate |
| `tapers` | `[5, 9]` | Multitaper params for SO-power computation |
| `window_params` | `[5, 0.5]` s | Window `[length, step]` for SO-power spectrogram |

**SO-power normalization methods:**

| Method | Description |
|---|---|
| `'p2shift1234'` | Subtract 2nd percentile of NREM+REM SO-power *(default)* |
| `'pNshiftS'` | Subtract Nth percentile computed over stages S (e.g., `'p5shift123'` = 5th percentile of N3/N2/N1) |
| `'percent'` | Scale between 1st and 99th percentile of artifact-free sleep data |
| `'proportion'` | Ratio of SO-power to total power |
| `'none'` | No normalization — raw dB power |

> **Note:** `p5shift` (percentile-shifted) is recommended for multi-subject comparisons as it aligns subjects at approximately the same sleep depth baseline. `percent` is only appropriate for within-night comparisons where all subjects reach N3.

---

## Output Reference

### `stats_table` — TF-Peak Features

A MATLAB table with one row per detected TF peak. Available features (controlled by `detection_opts.features`):

| Feature | Units | Description |
|---|---|---|
| `PeakTime` | s | Peak centroid time (weighted) |
| `PeakFrequency` | Hz | Peak centroid frequency (refined with 1Hz Hann window) |
| `Height` | μV²/Hz | Peak amplitude above baseline |
| `Area` | s·Hz | Time-frequency area of peak region |
| `Duration` | s | Peak duration |
| `Bandwidth` | Hz | Peak bandwidth |
| `Volume` | s·μV² | Time-frequency volume of peak |
| `BoundingBox` | (s, Hz, s, Hz) | `[top-left time, top-left freq, width, height]` |
| `HeightData` | μV²/Hz | Amplitude at every pixel within peak region |
| `Boundaries` | (s, Hz) | `(time, frequency)` of boundary pixels |
| `SegmentNum` | # | Index of the processing segment containing this peak |
| `PeakStage` | — | Sleep stage at peak time (0=Unknown, 1=N3, 2=N2, 3=N1, 4=REM, 5=Wake, 6=Artifact) |
| `SOpower` | dB | Normalized SO-power at peak time |
| `SOphase` | rad | SO-phase at peak time (0=SO peak, ±π=SO trough) |

---

### `SOPHs` — Histogram Struct

The `SOPHs` struct returned by `runDYNAMO` contains:

| Field | Description |
|---|---|
| `SOpow_mat` | `[B×F]` SO-power histogram (peaks/min or count) |
| `SOphase_mat` | `[B×F]` SO-phase histogram (probability density or count) |
| `SOpow_bins` | SO-power bin centers |
| `SOphase_bins` | SO-phase bin centers (rad) |
| `freq_bins` | Frequency bin centers (Hz) |
| `SOpow_TIB` | Time-in-bin for each SO-power bin (min) |
| `SOphase_TIB` | Time-in-bin for each SO-phase bin (min) |
| `peak_SOpower` | Normalized SO-power at each TF peak |
| `peak_SOphase` | SO-phase at each TF peak (rad) |
| `peak_selection_inds` | Logical mask of peaks included in histograms |
| `SOpower` / `SOpower_times` | Full SO-power timeseries and times |
| `SOphase` / `SOphase_times` | Full SO-phase timeseries and times |
| `pow_param_fit` | Parametric fit results for SO-power histogram (if `fit_param_basis=true`) |
| `phase_param_fit` | Parametric fit results for SO-phase histogram (if `fit_param_basis=true`) |
| `pow_spline_fit` | Spline fit for SO-power histogram (if `fit_spline_basis=true`) |
| `phase_spline_fit` | Spline fit for SO-phase histogram (if `fit_spline_basis=true`) |

---

## Algorithm Details

### Part 1: TF-Peak Detection

**Spectrogram estimation.** To study the time-frequency information contained in sleep EEG, DYNAM-O first transforms the recording into a spectrogram using the multi-taper method (MTM). While wavelet transforms are often used in sleep EEG analysis, MTM provides regularly discretized and equal controls of spectral and temporal resolutions, and MTM spectrograms are more conducive for the subsequent image processing steps.

**Spectrogram normalization.** Electrophysiological recordings exhibit a 1/f-like drop-off in power with frequency. To emphasize transient oscillatory activity above this aperiodic background, DYNAM-O normalizes the spectrogram by subtracting a baseline spectrum estimated as the 2nd percentile of spectral power at each frequency across non-artifact periods.

**The watershed algorithm.** The watershed algorithm — an image segmentation method from computer vision — identifies prominent peaks on a landscape by finding where "water" flowing downward gets trapped. Applied to the baseline-corrected spectrogram, it identifies all local spectral peaks at once, where each "catchment basin" corresponds to a candidate transient oscillation event.

**Region merging.** Running watershed on a noisy spectrogram produces many small fragmented peaks (over-segmentation). DYNAM-O uses a custom merging algorithm that iteratively recombines neighboring regions into larger, better-defined peaks. The algorithm computes a weight for each pair of adjacent regions reflecting how likely they are part of the same peak vs. truly distinct events. Regions are merged in order of decreasing weight until all remaining weights fall below a threshold.

**TF-peak trimming.** Because spectral peaks are relatively sparse on real spectrograms, merged regions often have wide, flat bases extending far from the central peak. Each detected peak is trimmed to retain 80% of its volume, yielding contours that tightly enclose the main body of the peak. Peaks are also filtered by minimum duration, bandwidth, and height thresholds to separate meaningful events from noise.

**Sequential optimization for temporal and spectral resolution.** Due to the uncertainty principle, there is a fundamental tradeoff between temporal and spectral resolution in spectrogram estimation. DYNAM-O addresses this by performing two rounds of the watershed-merging-trimming process: a first pass with a 1-second window (4 Hz spectral resolution) to resolve events that are close in time, followed by a second pass with a 2-second window (2 Hz spectral resolution) to resolve events that are close in frequency. Peaks detected in the first pass are masked before the second pass so only additional peaks are extracted. The combined set captures the full range of transient oscillation events.

**Parallel processing.** The spectrogram is split into 30-second segments processed independently in a `parfor` loop, then stitched together. For speed, watershed and merging can run on a decimated spectrogram; boundaries are interpolated back to full resolution afterward.

---

### Part 2: Feature Computation

For each identified TF-peak, DYNAM-O computes several feature properties, which can be divided into **microscopic** and **macroscopic** categories:

**Microscopic properties** describe the geometry and location of the peak on the spectrogram: time, frequency, height, area, duration, bandwidth, volume, and bounding box (see [stats_table](#stats_table--tf-peak-features)).

**Macroscopic properties** capture the contextual brain state at the time of each peak. The current version of DYNAM-O focuses on three macroscopic properties:
- **Sleep stage** at which a TF-peak event occurs
- **Slow oscillation power (SO-power, 0.3–1.5 Hz)** — a continuous proxy for depth of sleep
- **Slow oscillation phase (SO-phase, 0.3–1.5 Hz)** — a continuous proxy for cortical up/down states

These are motivated by extensive literature on discrete sleep stages, continuous measures of sleep depth, and cross-frequency coupling of fast transient oscillations with cortical states reflected by slow oscillations.

**Peak frequency refinement.** The spectrogram used for TF-peak extraction has a spectral resolution of ~2 Hz (from the 2s MTM window). Many electroencephalographic phenomena during sleep — such as slow vs. fast sleep spindles — manifest with frequency separations less than 2 Hz. DYNAM-O therefore refines the peak frequency for each detected event by computing a Hann-windowed power spectrum on a 4-second segment centered at the peak time, achieving 1 Hz resolution. The Hann window is chosen over multitaper estimation for this step because its single central lobe provides a cleaner peak estimate without the sidelobe leakage that can arise from higher-order DPSS tapers. This refinement is critical for the interpretability of subsequent feature histograms.

---

### Part 3: Feature Histograms

The first two parts of the DYNAM-O pipeline yield a table of identified TF-peaks, each described by a collection of local (microscopic) and contextual (macroscopic) feature properties. Rather than stratifying TF-peaks by fixed frequency cutoffs or sleep stage labels — which impose arbitrary boundaries and ignore substantial within-stage variability — DYNAM-O takes a distributional approach. Feature histograms encode the occurrence of tens of thousands of discrete TF-peak events across the multi-dimensional feature space, providing a condensed snapshot of overnight sleep dynamics.

**SO-power histogram.** A 2D histogram encoding the density of TF-peak occurrence (events/minute) as a function of peak frequency and SO-power (a continuous proxy for depth of sleep). This reveals how different types of transient oscillations emerge and change across the full continuum of sleep depth throughout the night.

**SO-phase histogram.** A 2D histogram encoding the density of TF-peaks as a function of peak frequency and SO-phase (the instantaneous phase of the slow oscillation, where 0 rad = SO peak and ±π = SO trough). Because SO-phase is circular, row densities are normalized to sum to 1 across each peak frequency, producing probability distributions. This reveals the preferred timing of different oscillation types relative to cortical up/down states.

<figure><img src="https://prerau.bwh.harvard.edu/images/SOpowphase_small.png" alt="SO-power/phase histograms" style="width:100%">
<figcaption><b>Example SO-power (left) and SO-phase (right) histograms from an overnight sleep EEG recording.</b></figcaption></figure>
<br/>

Visualizing the SO feature histograms already provides substantial insight into overnight sleep dynamics. For subsequent statistical comparisons across subjects or conditions, DYNAM-O provides two complementary dimensionality reduction approaches — [parametric basis fitting](#parametric-basis-fitting) and [spline basis fitting](#spline-basis-fitting) — described in detail below.

---

### Dimensionality Reduction of Feature Histograms

Feature histograms contain thousands of bins, making direct statistical comparison challenging. DYNAM-O provides two complementary approaches to reduce dimensionality while preserving the key structures in the histograms.

#### Parametric Basis Fitting

Parametric fitting identifies prominent clusters (modes) in the histogram and fits interpretable basis functions to each. The objective is to construct a low-dimensional representation where each mode corresponds to a distinct type of transient oscillation activity (e.g., sleep spindles, theta bursts), described by a small set of meaningful parameters that can be directly compared across subjects or conditions.

**How it works:**

1. The watershed algorithm is first run on the histogram itself to identify potential peaks as initial conditions for fitting
2. A sequence of models with increasing numbers of modes is fit via nonlinear least squares (MATLAB `fit()`)
3. At each iteration, a new mode is added from the next watershed region and the full model is refit
4. Modes that fall below a minimum amplitude or exceed a maximum spatial overlap with existing modes are rejected
5. The optimal number of modes is selected based on the adjusted R² curve — either by minimum percentage change in R² or by the kneedle (elbow) algorithm

**SO-power histograms** (`param_basis_power`): The SO-power histogram is modeled as a sum of *N* rotated 2D Gaussian modes on a linear baseline plane, where *p* is SO-power and *f* is frequency:

$$H(p, f) = \text{baseline}(p, f) + \sum_{n=1}^{N} \text{mode}_n(p, f)$$

The baseline is a linear plane capturing any residual trend in the histogram:

$$\text{baseline}(p, f) = \beta_{0} + \beta_{p} p + \beta_{f} f$$

Each mode is a rotated 2D Gaussian:

$$\text{mode}_n(p, f) = A \exp\left(-\left(\frac{(f - \mu_f)\cos\theta + (p - \mu_p)\sin\theta}{\sigma_f}\right)^2 - \left(\frac{-(f - \mu_f)\sin\theta + (p - \mu_p)\cos\theta}{\sigma_p}\right)^2\right)$$

The fitted parameters for each mode are:

| Parameter | Description |
|---|---|
| `amplitude` (*A*) | Peak density of the mode |
| `center_frequency` (*μ_f*) | Center frequency (Hz) |
| `center_SOpower` (*μ_p*) | Center SO-power (dB) |
| `frequency_std` (*σ_f*) | Spread in frequency |
| `SOpower_std` (*σ_p*) | Spread in SO-power |
| `rotation` (*θ*) | Rotation angle of the Gaussian |

**SO-phase histograms** (`param_basis_phase`): The SO-phase histogram is modeled as a sum of *N* von Mises × Gaussian modes on a sinusoidal baseline, where *ϕ* is SO-phase and *f* is frequency:

$$H(\phi, f) = \text{baseline}(\phi, f) + \sum_{n=1}^{N} \text{mode}_n(\phi, f)$$

The baseline is sinusoidal, capturing any overall phase preference across all frequencies:

$$\text{baseline}(\phi, f) = \beta_{0} + \beta_{1} \sin(\phi + \beta_{2})$$

Each mode is a von Mises (circular) × Gaussian (frequency) product:

$$\text{mode}_n(\phi, f) = A \exp\left(-(f - \mu_f)^2 / \sigma_f\right) \exp\left(\kappa \cos(\phi - \mu_\phi + (f - \mu_f)\sin\theta) - \kappa\right)$$

The von Mises component handles the periodicity of phase naturally, while the Gaussian component models the frequency spread. The subtraction of *κ* in the exponent normalizes the von Mises peak to 1, so *A* directly represents mode amplitude. To handle modes spanning the ±π boundary, three concatenated copies of the histogram are used during watershed seeding. After fitting, each frequency row is optionally normalized to sum to 1. The fitted parameters for each mode are:

| Parameter | Description |
|---|---|
| `amplitude` (*A*) | Peak density of the mode |
| `center_frequency` (*μ_f*) | Center frequency (Hz) |
| `center_SOphase` (*μ_ϕ*) | Preferred SO-phase (rad) |
| `frequency_std` (*σ_f*) | Spread in frequency |
| `von_Mises_kappa` (*κ*) | Concentration parameter (higher = more phase-locked) |
| `rotation` (*θ*) | Phase–frequency coupling angle |

**Usage:**

```matlab
% Fit SO-power histogram
params = param_basis_power(SOPHs.SOpower_mat, SOPHs.SOpower_bins, SOPHs.freq_bins);

% Fit SO-phase histogram
params = param_basis_phase(SOPHs.SOphase_mat, SOPHs.SOphase_bins, SOPHs.freq_bins);
```

Both functions return a parameter matrix with one row per identified mode and have built-in plotting functionality.

**Parametric Basis Options** (`param_basis_opts`):

```matlab
opts = param_basis_opts('power');   % or 'phase'
```

| Parameter | Default (power / phase) | Description |
|---|---|---|
| `freq_limits` | `[2, 16]` | Frequency range for fitting (Hz) |
| `power_limits` / `phase_limits` | `[-2, 20]` / `[-π, π]` | SO-power or SO-phase range for fitting |
| `max_peaks` | `6` | Maximum number of modes to fit (`-1` for unlimited) |
| `max_overlap` | `0.2` / `0.15` | Maximum allowed spatial overlap between modes |
| `criterion` | `'minpctr2'` | Model selection criterion: `'minpctr2'` (minimum % change in R²), `'mindr2'` (minimum absolute change), `'kneedle'` (elbow detection), `'max'` (fit all modes) |
| `min_pctr2` | `0.01` / `0.025` | Minimum percentage change in R² to accept a new mode |
| `min_dr2` | `0.01` | Minimum absolute change in R² |
| `watershed_params` | *(see below)* | `[merge_thresh, dur_min, bw_min, height_min, trim_vol]` for initial peak finding |
| `prefix_modes` | `[]` | Preset mode parameters to include before watershed-seeded modes |
| `prefix_modes_order` | `-1` | `-1` = append after, `0` = use only prefix, `1` = prepend before watershed modes |
| `plot_on` | `1` | `0` = none, `1` = final result, `2` = each iteration, `3` = both |
| `verbose` | `true` | Print progress information |

---

#### Spline Basis Fitting

While parametric fitting yields interpretable modes, some histograms have complex patterns that are not easily represented as Gaussian peaks. Spline basis fitting provides a nonparametric alternative by fitting a smooth two-dimensional surface to the histogram, capturing all structure regardless of shape.

**How it works:**

A two-dimensional tensor-product B-spline surface is fit to the histogram values across the SO-power (or SO-phase) and frequency axes using least-squares approximation. The spline is defined by a grid of internal knots along each axis, with the knot density controlling the tradeoff between smoothness and fidelity. The fitted spline coefficients provide a compact representation of the histogram that can be used for statistical comparisons.

**Usage:**

```matlab
% Fit SO-power histogram
[splinefit, coefs] = spline_basis('power', SOPHs.SOpower_mat, SOPHs.SOpower_bins, SOPHs.freq_bins);

% Fit SO-phase histogram
[splinefit, coefs] = spline_basis('phase', SOPHs.SOphase_mat, SOPHs.SOphase_bins, SOPHs.freq_bins);
```

`splinefit` is the smoothed histogram surface (same dimensions as the input), and `coefs` is the matrix of spline coefficients used for dimensionality-reduced comparisons.

**Spline Basis Options** (`spline_basis_opts`):

```matlab
opts = spline_basis_opts('power');   % or 'phase'
```

| Parameter | Default (power / phase) | Description |
|---|---|---|
| `freq_limits` | `[2, 16]` | Frequency range for fitting (Hz) |
| `power_limits` / `phase_limits` | `[-2, 20]` / `[-π, π]` | SO-power or SO-phase range for fitting |
| `num_knots_x` | `5` | Number of internal knots along the SO-power/phase axis |
| `num_knots_y` | `18` / `9` | Number of internal knots along the frequency axis |
| `plot_on` | `true` | Plot fitted surface |
| `SOPH_clim_prctiles` | `[5, 98]` | Percentiles for heatmap color scaling |

The difference in frequency knots (18 for power, 9 for phase) reflects the typically smoother structure of SO-phase histograms, which require fewer knots to capture their variation.

---

### Part 4: Statistical Testing

The outputs from the DYNAM-O Toolbox are naturally suited for statistical tests in different forms.

**Feature and mode analysis.** Hypothesis testing can be performed on individual TF-peak feature properties from `stats_table` (analogous to conventional spindle analyses but extended to all TF-peaks), or on parametric mode parameters extracted from fitted histograms. For example, mode center frequencies, amplitudes, and SO-power positions can be compared across groups to identify differences in specific types of transient oscillations.

**Whole-histogram analysis.** Given feature histograms from multiple subjects or recording sessions, DYNAM-O supports "whole-histogram" group comparisons (analogous to whole-brain voxel-wise fMRI analyses). Two approaches are implemented:

- **Pixel-wise FDR testing** (`FDR_2D`): Two-sample or paired-sample statistical tests at each histogram bin, with false discovery rate correction using the [Benjamini–Yekutieli procedure](https://en.wikipedia.org/wiki/False_discovery_rate#Benjamini%E2%80%93Yekutieli_procedure).
- **Global permutation testing** (`gpermtest`): Tests on the linearized feature histograms based on the number of bins exceeding acceptance bounds, providing greater sensitivity to detect small but consistent differences across the entire histogram. Based on the method described in [Harrison et al. (2009)](https://www.nature.com/articles/nn.2501).

These methods enable detection of group differences (e.g., between clinical populations or across experimental conditions) that may be distributed across multiple frequency ranges and sleep depths simultaneously.

---

### SO-Power Computation and Normalization

The total spectral power within the 0.3–1.5 Hz slow oscillation band of the raw recording is used to measure the strength of slow oscillations as a proxy for sleep depth:

1. Compute a multitaper spectrogram of the raw EEG (default: time-bandwidth product 5, 9 tapers, 5s window, 0.5s step)
2. Integrate spectral power between 0.3 and 1.5 Hz to obtain the SO-power time series
3. Normalize by selected method (see [SO-power normalization methods](#so-power-normalization-methods))
4. Assign SO-power to each TF-peak based on its peak time

### SO-Phase Computation

The phase of slow oscillations reflects the timing of cortical up/down states:

1. Bandpass filter the raw EEG to the SO band (0.3–1.5 Hz) using a zero-phase IIR bandpass filter
2. Apply the Hilbert transform to obtain the instantaneous phase
3. Unwrap phase to be monotonically increasing
4. Interpolate the unwrapped phase at each TF-peak time
5. Re-wrap to `[-π, π]` where **0 rad = SO peak** (cortical up state) and **±π = SO trough** (cortical down state)

---

## Repository Structure

```
DYNAMO_dev/
├── DYNAMO.m                         OOP pipeline class
├── runDYNAMO.m                      Functional pipeline entry point
├── DYNAMOFileManager.m              GUI batch processing app
├── example_data/
│   ├── example_data.mat             Single-channel sleep EEG example
│   └── runExampleData.m             Example data loader
└── toolbox/
    ├── TFpeak_functions/            Watershed TF-peak extraction
    │   ├── computeTFPeaks.m         Main detection function
    │   ├── runWatershed.m           MATLAB watershed segmentation
    │   ├── runSegmentedData.m       Parallel segment processing
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
    │   └── option_sets/
    │       ├── detection_opts.m     Detection parameter struct
    │       └── baseline_opts.m      Baseline parameter struct
    ├── SOpowphase_functions/        SO-power/phase computation and histograms
    │   ├── SOpowerphaseHistogram.m  Main histogram function
    │   ├── computeSOpower.m         SO-power timeseries
    │   ├── computeSOphase.m         SO-phase timeseries (Hilbert)
    │   ├── SOpowerHistogram.m       SO-power histogram wrapper
    │   ├── SOphaseHistogram.m       SO-phase histogram wrapper
    │   ├── TFPeakHistogram.m        1D frequency histogram
    │   └── SOpowerphasehist_opts.m  Histogram options struct
    ├── SOPH_dim_reduction/          Parametric and spline fitting
    │   ├── param_basis_power.m      Rotated Gaussian fits (SO-power)
    │   ├── param_basis_phase.m      von Mises fits (SO-phase)
    │   ├── spline_basis.m           Bivariate spline fits
    │   ├── fit_rotGauss.m           Rotated 2D Gaussian fitting
    │   ├── fit_vmGauss.m            von Mises × Gaussian fitting
    │   ├── extracthistpeaks.m       Watershed on histogram for seeding
    │   ├── select_modes.m           Mode pruning and selection
    │   ├── kneedle.m                Elbow detection in scree plots
    │   ├── plot_SOPH_paramfits.m    Parametric fit visualization
    │   ├── plot_SOPH_splinefits.m   Spline fit visualization
    │   └── [utilities]              mode_centroid, mode_overlap, get_mode_params, ...
    ├── TFsigma_peak_detector/       Alternative sigma-band peak detector
    │   ├── TF_peak_detection.m      Frequency/time peak detection
    │   ├── TF_peak_selection.m      Signal/noise discrimination
    │   ├── find_frequency_peaks.m   Frequency-domain peak finding
    │   ├── find_time_peaks.m        Time-domain peak finding
    │   └── [utilities]              extract_freq_clusters, extract_event_centroid, ...
    └── helper_functions/            Utilities organized by category
        ├── multitaper_spectrogram/  DPSS multitaper spectral estimation (+ MEX)
        ├── artifact_detection/      detect_artifacts, detect_artifacts_hjorth
        ├── read_EDF/                read_EDF, header_gui, load_data
        ├── plotting/                hypnoplot, figdesign, colormaps, scrollzoompan
        ├── statistical_tests/       permtest, gpermtest, FDR_1D, FDR_2D
        ├── data_processing/         nanzscore, nanpow2db, get_chunks, create_bins
        └── conversion/              csv2table, read_staging, struct2nvp, hmstext2seconds
```

---

## Required Toolboxes

| Toolbox | Required For |
|---|---|
| **Signal Processing Toolbox** | Filtering, Hilbert transform, DPSS windows |
| **Curve Fitting Toolbox** | Parametric Gaussian/von Mises fitting |
| **Statistics and Machine Learning Toolbox** | Distribution fitting, FDR correction |
| **Parallel Computing Toolbox** | *(Optional)* `parfor` in `runSegmentedData` — significant speedup for long recordings |

---

## Documentation and Tutorials

For in-depth documentation and video tutorials, visit the [Prerau Lab DYNAM-O page](https://prerau.bwh.harvard.edu/DYNAM-O/).
