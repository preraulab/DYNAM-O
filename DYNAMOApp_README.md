<p align="center">
<img src=https://user-images.githubusercontent.com/78376124/214062562-4f8fc73b-5a0a-4cf7-b219-9d0de101528d.png>
</p>

# DYNAM-O App

The DYNAM-O App is the primary graphical interface for running batch EEG/polysomnography analyses with the DYNAM-O (Dynamical Oscillation) toolbox. It manages file loading, analysis configuration, and batch execution across multiple subjects and channels, with real-time progress monitoring and structured output logging.

The goal of the DYNAM-O App is to provide a fully operational GUI — with standalone executables for macOS, Windows, and Linux in development — so users can run DYNAM-O without writing any MATLAB code. For programmatic use of the MATLAB DYNAM-O API (`runDYNAMO`, the `DYNAMO` class, and lower-level pipeline functions), see the main [`README.md`](README.md).

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [Batch Behavior at a Glance](#2-batch-behavior-at-a-glance)
3. [Loading Files](#3-loading-files)
4. [Configuring Channels](#4-configuring-channels)
5. [Configuring Staging File Parsing](#5-configuring-staging-file-parsing)
6. [Configuring Output Options](#6-configuring-output-options)
7. [Configuring Analysis Parameters](#7-configuring-analysis-parameters)
8. [Running the Batch](#8-running-the-batch)
9. [Monitoring and Stopping a Run](#9-monitoring-and-stopping-a-run)
10. [Output Structure](#10-output-structure)
11. [Saving and Reloading Batch Settings](#11-saving-and-reloading-batch-settings)
12. [GUI Reference: Tabs](#12-gui-reference-tabs)
13. [GUI Reference: Menus](#13-gui-reference-menus)
14. [Programmatic API](#14-programmatic-api)

---

## 1. Quick Start

```
1. Add EDF data files and (optionally) matching staging files
2. Select channels to process
3. Set staging file parsing options (if staging files are used)
4. Choose an output directory and what to save
5. (Optional) Adjust analysis parameters in the Settings tab
6. Click RUN
```

**Inputs must be EDF.** MAT-based recordings are not supported by the DYNAM-O App.

Data and staging file counts must match — each EDF is paired with the staging file at the same list position.

---

## 2. Batch Behavior at a Glance

The DYNAM-O App is designed around long-running batches (e.g. 50 EDFs × 2 channels = 100 iterations). Three facts matter before you hit RUN:

### Output Layout (summary)

Results are written into per-channel subdirectories of your chosen output directory:

```
<OutputDir>/<channel>/{TFpeaks, SOPHs, param_basis, spline_basis, auxiliary_data, figures/}
<OutputDir>/logs/       (if Save Logs is on)
<OutputDir>/settings/   (if Save Logs is on)
```

Full tree in [Output Structure](#10-output-structure).

### Skip / Overwrite Semantics

When **Overwrite** is off, the manager checks **per output file**, not per subject. For each output it would produce, if the target already exists on disk it is skipped; if it is missing, the manager re-computes whatever prerequisites are needed (including re-running DYNAMO itself) to produce it. A subject whose `stats_table` exists but whose summary figure is missing will therefore re-run the full pipeline to regenerate the figure.

### Error Containment and Resuming After a Crash

Each subject-channel iteration is wrapped in `try/catch`. A failure on one file (e.g. a requested channel missing from that EDF, a malformed staging file) logs the error to `file_log_*.txt`, prints it to the console log, and the batch continues with the next iteration. One bad file does not abort the run.

If MATLAB itself crashes or the user clicks STOP partway through a 50-file batch, simply re-click **RUN** with Overwrite **off**. Any subject-channel that already has all its requested outputs on disk is skipped; the batch picks up where it left off. Because skip is per-output-file, subjects that were interrupted mid-pipeline will finish the missing steps on the re-run.

### Missing-Channel Behavior

If a requested channel is not present in a given EDF, `load_data` raises an error. The per-iteration `try/catch` catches it, logs `Subject <name>, channel <ch>: not run.` to the file log with the full error report in the console log, and moves on. Other subjects and other channels on that same subject are unaffected.

### Running Without Staging Files

The STAGING list may be left empty. On RUN, a confirmation dialog warns that all non-artifact time will be analyzed; if confirmed, the entire recording is treated as a single N2 epoch (stage value 2) for the purposes of TF-peak and SOPH analyses. Staging-parsing fields are ignored in this mode.

---

## 3. Loading Files

### Adding Files Manually

Each file list (DATA and STAGING) has its own set of action buttons:

| Button | Action |
|--------|--------|
| **Add File** | Opens a file browser to select one or more files |
| **Add Folder** | Adds all matching files in a selected folder (DATA: `*.edf`; STAGING: `*.csv`, falling back to `*.txt` if no CSV files are found) |
| **Delete File** | Removes the currently selected file(s) from the list |
| **Move Up / Move Down** | Reorders files to align data–staging pairs |

- **Add Folder (DATA)** globs `*.edf` in the chosen folder only.
- **Add Folder (STAGING)** globs `*.csv`; if no CSV files are found it falls back to `*.txt`. It does not mix the two or scan other extensions.
- **Double-click an EDF file** to open a floating header viewer showing recording metadata (signal names, sampling rates, record duration, start time).
- **Double-click a staging file** to open it in the default text editor for inspection.

### Loading a File List from a Text File

**File → Load EDF File List...** or **File → Load Staging File List...**

Loads a plain-text file with one file path per line. The manager validates each path, removes duplicates, and reports any issues. If missing or duplicate entries are found, a dedicated window appears showing the skipped and duplicated files, with an option to save a log file for review.

Accepted list-file extensions (shown in the file picker filter): `.txt`, `.csv`, `.tsv`, `.dat`, `.lst`. The file itself is read as plain text — the extension only controls what is offered in the picker.

---

## 4. Configuring Channels

### Channel(s) Field

Enter one or more channel labels as a comma-separated list (e.g., `C3, C4, O1`). Labels must match the signal names stored in the EDF headers exactly.

### Channel Browser

Click **Select** to open the interactive channel browser, which scans all loaded EDF files and displays:

- All available channel names
- Sampling frequency per channel
- How many files contain each channel (e.g., `8 / 10` means 8 of 10 loaded files contain that channel)

Select one or more channels and click **Add to Batch Run** to populate the channel field. Selected channels are appended to any channels already in the field, without introducing duplicates.

#### Creating Rereference Channels

The channel browser supports virtual rereference channels computed as the difference between two real channels (e.g., `C3-A2`). Click **Add Rereference** to open a sub-dialog where you choose a signal and a reference. The manager validates that:

- Both channels exist in the same files
- Both channels share the same sampling rate in every overlapping file
- The rereference label is not already in the channel list

The resulting virtual channel appears in the table with its own file count (only files containing both constituent channels).

#### Sampling Frequency Warnings

When channels are added via the browser, the DYNAM-O App checks each channel's sampling frequency against the DYNAM-O analysis frequency range. The upper analysis bound is the larger of the SOPH frequency range upper limit and the multitaper spectrogram frequency range upper limit (configured in the DYNAM-O Settings tab). Two warnings may appear:

- **Fs too high** (Fs > 10× the upper analysis bound): The channel's sampling rate far exceeds what DYNAM-O analyzes. This wastes memory and processing time. Consider enabling **Resample Data** to downsample before processing.
- **Fs too low** (Fs < 2× the upper analysis bound): The Nyquist frequency (Fs/2) is below the upper analysis bound, meaning the analysis frequency range cannot be fully represented at this sampling rate. You **must** enable **Resample Data** and upsample, or the run will fail. However, note that upsampling does not create real spectral content above the original Nyquist — consider whether narrowing the analysis frequency range is more appropriate.

### Resampling

The **Resample Data** switch is **ON by default at 100 Hz** — leave it that way for standard sleep-oscillation analysis. Why:

- DYNAM-O analyzes **0–30 Hz**, so 100 Hz Nyquist is well above anything the pipeline cares about. Resampling to 100 Hz is **lossless** for sleep oscillations.
- The multitaper FFT size is `2^nextpow2(Fs/0.1)`. Above **Fs = 102.4 Hz** (a common boundary that 128 / 200 / 256 / 500 / 1000 Hz EDFs all cross), NFFT doubles and the spectrogram typically spills past CPU L3 cache. Every downstream stage takes a 2–3× memory-bandwidth hit on top of the doubled FFT cost.
- Empirically: a 10.5 h × 128 Hz EDF runs in ~22 s resampled to 100 Hz vs ~41 s at native rate (Threadripper Pro, Rust backend).

Turn the switch **off** only if you specifically need spectral content above 50 Hz (e.g., gamma analysis beyond DYNAM-O's analyzed band). The DYNAMOApp will warn if a selected channel's native Fs > 102.4 Hz and Resample is disabled.

---

## 5. Configuring Staging File Parsing

Staging files are delimited text files containing sleep stage labels and epoch timestamps, one row per scored epoch. Set these fields to match your staging file format:

| Field | Description |
|-------|-------------|
| **Stages Column** | Column index (1-based) containing sleep stage labels |
| **Times Column** | Column index (1-based) containing epoch onset times (seconds from recording start) |
| **Header Rows** | Number of header rows to skip before data begins |
| **File Delimiter** | Column delimiter: Comma, Tab, Space, or Semicolon |

### Staging File Format

A staging file is a delimited text file. Each row corresponds to one scored epoch. The defaults match `load_data.m`:

- **Epoch onset time** is in **seconds from the start of the EDF recording**, at `time_col`.
- **Stage label** at `stage_col` is mapped through the Stage Label Mapping fields below.
- **Indices are 1-based** (column 1 is the first column).
- **Default epoch duration** is 30 s.
- After label mapping, internal stage values are: `0=Unknown, 1=N3, 2=N2, 3=N1, 4=REM, 5=Wake` (artifact epochs are handled separately via the Artifact mapping).

Minimal two-row example (comma-delimited, one header row, `time_col=1`, `stage_col=2`):

```
onset_s,stage
0,W
30,N1
60,N2
90,N2
```

### Stage Label Mapping

For each stage, enter the identifiers used in your staging file as a comma-separated list. Multiple synonyms are supported (e.g., `W, Wake, 0`).

| Field | Default Labels | Stage |
|-------|----------------|-------|
| **Artifact** | `artifact, A, 6` | Artifact epochs |
| **Wake** | `wake, W, 5` | Wakefulness |
| **REM** | `REM, R, 4` | REM sleep |
| **N1** | `N1, Stage 1, 1` | NREM Stage 1 |
| **N2** | `N2, Stage 2, 2` | NREM Stage 2 |
| **N3** | `N3, Stage 3, 3` | NREM Stage 3 |
| **Unknown** | `Unk, U, Unknown` | Unscored or unknown epochs |


All stage label fields except Unknown must be filled for validation to pass.

---

## 6. Configuring Output Options

### Output Directory

Click **Browse** to select the folder where all results will be saved. Outputs are organized into subdirectories automatically (see [Output Structure](#10-output-structure)).

### Saving Options Tab

Check the boxes for the data types and figures to generate:

**Data to Save**

| Option | Description |
|--------|-------------|
| Peak Stats Tables | TF-peak statistics table per subject-channel |
| SO-Power Histogram | SO-Power and SO-Phase histograms |
| Parametric Basis | Parametric basis fit coefficients |
| Spline Basis | Spline basis fit data |
| Auxiliary Data | Artifacts, Fs, stage times/values, SO-power normalization method |

**Figures to Save**

| Option | Description |
|--------|-------------|
| Data Summary | Overview summary figure (spectrogram, SO-power, detected peaks, histograms) |
| Parametric Basis | Parametric basis fit visualization |
| Spline Basis | Spline basis fit visualization |

**Logging**

| Option | Description |
|--------|-------------|
| Save Logs | Save file log, console log, and run settings to the output `logs/` and `settings/` directories. When disabled, no logs or settings files are written. |

### File Formats Tab

Select the output format for each data type. Every format dropdown also includes a **`--`** value meaning **"do not save this output"**, which suppresses writing even when the corresponding Save checkbox is on.

| Output | Available Formats |
|--------|-------------------|
| Peak Stats Table | `.csv`, `.mat`, All, `--` |
| SO Histograms | `.tiff`, `.mat`, All, `--` |
| Parametric Basis | `.csv`, `.mat`, All, `--` |
| Spline Basis | `.tiff`, `.mat`, All, `--` |
| Auxiliary Data | `.mat` |
| Data Summary Figure | `.png`, `.jpg`, `.jpeg`, `--` |
| Parametric Basis Figure | `.png`, `.jpg`, `.jpeg`, `--` |
| Spline Basis Figure | `.png`, `.jpg`, `.jpeg`, `--` |

Selecting **All** saves every available format for that output type. Selecting **`--`** disables saving for that output.

### Save Logs Switch

The **Save Logs** switch in the output options controls whether `logs/` and `settings/` are written at all. When it is **off**, the guarantees below about `file_log_*.txt`, `console_log_*.txt`, and `batch_settings_*.json` do not apply — no log or settings files are written for the run. Leave it on for any batch you may need to audit, reproduce, or resume after a crash.

---

## 7. Configuring Analysis Parameters

Click the **DYNAM-O Settings** tab to access the embedded settings panel. Parameters are organized into sections:

- **SOPH Options** — SO-Power/Phase histogram configuration (including frequency range)
- **Baseline Options** — Baseline normalization settings
- **Detection Options** — TF-peak detection thresholds (including multitaper frequency range)
- **Parametric Basis Fit Options** — Power and phase parametric model settings
- **Spline Basis Fit Options** — Power and phase spline model settings

These settings are saved with each run to `<OutputDir>/settings/batch_settings_<timestamp>.json` for reproducibility (when Save Logs is on). See [Saving and Reloading Batch Settings](#11-saving-and-reloading-batch-settings) for the full file contents and the load workflow.

---

## 8. Running the Batch

### Pre-Run Validation

Clicking **RUN** triggers an automatic validation pass. The following conditions are checked, and any failures are reported in an error dialog with the offending fields highlighted in red:

- [ ] DATA list has EDF files; STAGING list has matching staging files **or is empty** (see below)
- [ ] DATA and STAGING lists have the same number of files (unless STAGING is empty)
- [ ] Files are paired correctly (same position = same subject)
- [ ] At least one channel is entered
- [ ] All staging parsing fields are filled (ignored if STAGING is empty)
- [ ] An output directory is selected
- [ ] Save Logs switch is set as desired (on = `logs/` and `settings/` written)

If STAGING is empty and all other validation passes, a confirmation dialog asks whether to run without stages. Accepting treats the entire recording as N2 (see [Running Without Staging Files](#running-without-staging-files)).

### Run Options

| Option | Description |
|--------|-------------|
| **Reverse** | Processes files in reverse list order — useful when running parallel instances on the same dataset to avoid overlap |
| **Overwrite** | Re-processes subjects even if output files already exist; when off, missing outputs are computed and existing outputs are skipped on a per-file basis |

### Validation

Clicking **RUN** triggers a validation pass. If any issues are found (mismatched file counts, missing files, empty fields), an alert dialog lists all errors. Fix the reported issues and click RUN again.

### Processing Pipeline (per subject-channel)

For each EDF + staging file pair, for each selected channel:

1. Load EDF and extract the target channel
2. Parse staging file and align epochs (or use whole-recording N2 in no-stages mode)
3. Resample data if enabled
4. Compute TF-peak statistics table and SO-Power/Phase histograms
5. (If enabled) Generate and save data summary figure
6. (If enabled) Fit parametric basis model and save results/figures
7. (If enabled) Fit spline basis model and save results/figures
8. (If enabled) Save auxiliary data
9. Log result (success, skipped, or error) to the file log

### Help Button

A **Help** button is located in the bottom-right area of the DYNAM-O App window, next to the progress bar. Clicking it opens this README documentation in the system's default web browser.

Errors in any step are caught per-iteration — see [Error Containment and Resuming After a Crash](#error-containment-and-resuming-after-a-crash).

---

## 9. Monitoring and Stopping a Run

### Status Area

The STATUS text area (bottom-left) shows real-time processing messages as each subject-channel pair is processed, including loading, analysis step, and saving notifications.

### Progress Bar

The progress bar (bottom-right) fills as iterations complete. The denominator is **files × channels**: a batch of 50 EDFs and 2 channels produces **100 ticks**, one per subject-channel iteration.

### Run Log Console

**File → Show Run Log Console** opens a floating window that displays live console output during processing. This is useful for detailed diagnostics. The full console output is also saved to `<OutputDir>/logs/console_log_<timestamp>.txt` (when Save Logs is on).

### Stopping

Click **STOP** to request a graceful halt. The current subject-channel will finish processing before the run stops. Partial results are saved normally. Re-click **RUN** with Overwrite off to resume.

---

## 10. Output Structure

```
<OutputDir>/
├── <channel>/
│   ├── TFpeaks/
│   │   └── <subject>_stats_table_<channel>.[csv|mat]
│   ├── SOPHs/
│   │   ├── <subject>_SOPHs_power_<channel>.[tiff|mat]
│   │   └── <subject>_SOPHs_phase_<channel>.[tiff|mat]
│   ├── param_basis/
│   │   ├── <subject>_SOpower_paramfit_<channel>.[csv|mat]
│   │   └── <subject>_SOphase_paramfit_<channel>.[csv|mat]
│   ├── spline_basis/
│   │   ├── <subject>_SOpower_splinefit_<channel>.[tiff|mat]
│   │   └── <subject>_SOphase_splinefit_<channel>.[tiff|mat]
│   ├── auxiliary_data/
│   │   └── <subject>_auxiliary_data_<channel>.mat
│   └── figures/
│       ├── summary/
│       │   └── <subject>_summary_figure_<channel>.[png|jpg|jpeg]
│       ├── param_basis/
│       │   └── <subject>_param_basis_figure_<channel>.[png|jpg|jpeg]
│       └── spline_basis/
│           └── <subject>_spline_basis_figure_<channel>.[png|jpg|jpeg]
├── logs/
│   ├── file_log_<timestamp>.txt
│   └── console_log_<timestamp>.txt
└── settings/
    └── run_settings_<timestamp>.txt
```

### Channel Name → Directory Name

The `<channel>` placeholder above is **not** the raw EDF label; the manager runs each channel name through a filesystem-safe sanitizer (`fixFilename`) before using it as a directory or filename component. Characters outside `[A-Za-z0-9._\-() ]` are replaced with `_`; leading dots and trailing dots/spaces are stripped; consecutive replacements are collapsed.

The raw label is still used for channel lookup inside the EDF — only the on-disk names change.

Examples:

| Raw EDF label | Sanitized `<channel>` used in paths |
|---------------|-------------------------------------|
| `C3`          | `C3` |
| `C3-A2`       | `C3-A2` (hyphen is allowed) |
| `EEG C3:A2`   | `EEG C3_A2` |
| `C4/A1`       | `C4_A1` |

### Log and Settings Files

| File | Location | Contents |
|------|----------|----------|
| `file_log_*.txt`         | `<OutputDir>/logs/`     | Per-subject-channel outcome (success, skipped-all-exist, or error message) |
| `console_log_*.txt`      | `<OutputDir>/logs/`     | Full MATLAB console output for the entire run |
| `batch_settings_*.json`  | `<OutputDir>/settings/` | Snapshot of the configuration that produced the run — see below |

All three files are only written when the **Save Logs** switch is on.

---

## 11. Saving and Reloading Batch Settings

The `batch_settings_<timestamp>.json` file is the **complete, reloadable
record** of a run's configuration. Loading it puts the GUI back into the
exact state that produced the run — every field, every toggle, every
analysis option. Use it to reproduce a study months later, hand a config
to a collaborator, or recover from accidentally clearing the GUI.

### What the file contains

A single JSON object with two top-level keys:

| Key | Contents |
|-----|----------|
| `options` | The seven DYNAM-O option structs (`SOPH_options`, `baseline_options`, `detection_options`, `param_basis_power_options`, `param_basis_phase_options`, `spline_basis_power_options`, `spline_basis_phase_options`) — every analysis parameter the run used. |
| `batch_settings` | The GUI batch-level state: `data_files`, `staging_files`, `output_dir`, `save_toggles` (the Save Logs / SOPHs / Param Basis / Spline Basis / Aux Data / Peak Stats / Data Summary / images switches), `formats` (the per-output-type file format dropdowns), `runtime` (overwrite, run-in-reverse), `channels` (channel spec + reference spec), `staging_config` (delimiter, header rows, time/stage columns, resample on/off, target Fs), `stage_labels` (the seven stage-label-to-value mappings). |

A `schema_version` and `run_start` timestamp sit alongside for forward
compatibility.

### Where it comes from

- **Auto-emitted** at the start of every batch run when **Save Logs** is on —
  written to `<OutputDir>/settings/batch_settings_<timestamp>.json`.
- **Manually saved** via **Batch Settings → Save Batch Settings as JSON…**
  in the menu bar. Use this to archive a configuration before kicking off
  a long run, or to share a config without running it first.

### Loading a saved file

**Batch Settings → Load Batch Settings from JSON…** opens a file picker
filtered to `*.json`. After picking a file, the GUI:

1. Pulls in the file lists, output directory, save toggles, channel /
   reference specs, stage label mapping, staging CSV config, and runtime
   options.
2. Validates each `data_files` and `staging_files` entry with `isfile`
   and the `output_dir` with `isfolder`. Missing paths are skipped from
   the lists (data/staging) or left blank (output dir), and a single
   "Missing Paths" dialog summarizes what was dropped so the user can
   fix paths after a directory move.
3. Tolerantly merges each of the seven option structs into the current
   defaults — fields the JSON has overwrite the current values, fields
   the JSON is missing keep the current default, and fields the JSON
   has but the current toolbox doesn't recognize are logged as a warning
   and skipped. This means saved files from older toolbox versions
   still load on a newer install (and vice-versa) without breaking.
4. Re-runs the full pre-flight validation (`updateRunErrorList`) so any
   stale red-border error indicators clear and the **RUN** button gates
   correctly on the newly-loaded configuration.

Legacy `run_settings_*.json` files (from runs prior to the rename) load
fine — same loader, same logic. Files that pre-date the GUI-state
addition (schema v1, options-only) load the seven analysis option
structs but leave the file lists / output dir / save toggles untouched;
the GUI shows an info dialog explaining this.

---

## 12. GUI Reference: Tabs

### File Selection Tab

The main configuration tab. Contains the DATA and STAGING file lists on the left, channel and staging options on the right, and saving/format sub-tabs below.

**Sections:**

- **DATA list** — EDF files to process, with Add File/Add Folder/Delete File/Move Up/Move Down buttons
- **STAGING list** — Paired staging files, with the same set of buttons
- **Channel(s)** — Target channel labels; Select button opens channel browser
- **Staging Options** — Stage label mapping, column indices, delimiter, header row count
- **Resample Data / New Fs** — Optional resampling before analysis
- **Saving Options sub-tab** — Checkboxes for data and figure outputs, plus the Save Logs switch
- **File Formats sub-tab** — Format selector for each output type (including `--` to disable)

### DYNAM-O Settings Tab

Hosts the embedded DYNAMOOptions sub-app for configuring all analysis parameters. Changes here are applied to all subjects in the next run and are saved to the settings log (when Save Logs is on).

---

## 13. GUI Reference: Menus

### Batch Settings Menu

| Item | Description |
|------|-------------|
| **Load EDF File List...** | Load a text file of EDF paths (one per line) into the DATA list |
| **Load Staging File List...** | Load a text file of staging file paths into the STAGING list |
| **Show Run Log Console** | Toggle the floating live console output window |
| **Save Batch Settings as JSON...** | Save the current GUI configuration (file lists, output dir, save toggles, channels, stage labels, all analysis options) to a `*.json` file you choose. The same file format the auto-emitted `batch_settings_<timestamp>.json` uses — see [Saving and Reloading Batch Settings](#11-saving-and-reloading-batch-settings). |
| **Load Batch Settings from JSON...** | Restore the GUI from a `*.json` file written by Save Batch Settings or auto-emitted by a previous run. Missing paths are skipped with a summary dialog; analysis options are tolerantly merged so files from older toolbox versions still load. |

### Help Menu

| Item | Description |
|------|-------------|
| **Help** | Opens this README documentation in the system web browser |
| **About DYNAM-O...** | Displays lab info, website/GitHub links, and paper citations |

---

## 14. Programmatic API

The DYNAM-O App exposes a handful of helper methods for populating file lists and querying state from scripts. It does **not** expose a public method for launching a batch run non-interactively: the batch is driven by the RUN button and depends on internal GUI state, so scripts can pre-populate the manager but a human (or a simulated button click) is still required to start processing. Treat the API below as a convenience layer, not a headless-batch entry point.

### Constructor

```matlab
app = DYNAMOApp()
app = DYNAMOApp('Title', 'My Batch Run')
app = DYNAMOApp('Position', [x y w h])
app = DYNAMOApp('BatchCallback', @myCallback)
app = DYNAMOApp('ValidationCallback', @myValidator)
```

| Parameter | Description |
|-----------|-------------|
| `Title` | Window title (default: `'DYNAM-O Toolbox'`) |
| `Position` | `[x y width height]` figure position vector |
| `BatchCallback` | `function_handle` invoked at batch start; receives `(dataList, stagingList, opts)` where `opts` is a struct of save option values |
| `ValidationCallback` | `function_handle(filepath)` called per file during Add File; return `true` to accept, `false` to reject |

If the Parallel Computing Toolbox is installed and no parallel pool is running, one is started automatically on launch.

### Adding Files

```matlab
% Add individual files
app.addDataFiles('/path/to/subject01.edf')
app.addDataFiles({'/path/to/sub01.edf', '/path/to/sub02.edf'})

app.addStagingFiles('/path/to/subject01_staging.csv')
app.addStagingFiles({'/path/to/sub01_staging.csv', '/path/to/sub02_staging.csv'})
```

Duplicate file paths are silently ignored.

### Retrieving File Lists

```matlab
[dataFiles, stagingFiles] = app.getFileLists()
% Returns cell arrays of full file paths in current list order
```

### Clearing Lists

```matlab
app.clearAllLists()
```

### Showing / Hiding

```matlab
app.setEnabled(true)   % show window
app.setEnabled(false)  % hide window
```
