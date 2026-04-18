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

> He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J. "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics in Sleep EEG", *bioRxiv*, 2026 -- Pending Journal Publication

> Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S., Manoach, D. S., Stickgold, R., Prerau, M. J. "Transient Oscillation Dynamics During Sleep Provide a Robust Basis for Electroencephalographic Phenotyping and Biomarker Identification", *Sleep*, 2022; zsac223. https://doi.org/10.1093/sleep/zsac223

---

# DYNAM-O File Manager

The DYNAM-O File Manager is the primary graphical interface for running batch EEG/polysomnography analyses with the DYNAM-O (Dynamical Oscillation) toolbox. It manages file loading, analysis configuration, and batch execution across multiple subjects and channels, with real-time progress monitoring and structured output logging.

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [Loading Files](#2-loading-files)
3. [Configuring Channels](#3-configuring-channels)
4. [Sampling Frequency and Resampling](#4-sampling-frequency-and-resampling)
5. [Configuring Staging File Parsing](#5-configuring-staging-file-parsing)
6. [Running Without Staging Files](#6-running-without-staging-files)
7. [Configuring Output Options](#7-configuring-output-options)
8. [Configuring Analysis Parameters](#8-configuring-analysis-parameters)
9. [Running the Batch](#9-running-the-batch)
10. [Monitoring and Stopping a Run](#10-monitoring-and-stopping-a-run)
11. [Output Structure](#11-output-structure)
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

If staging files are provided, the data and staging file counts must match — each EDF is paired with the staging file at the same list position. If no staging files are loaded, the manager can run in a stage-free mode (see [Running Without Staging Files](#6-running-without-staging-files)).

---

## 2. Loading Files

### Adding Files Manually

Each file list (DATA and STAGING) has its own set of action buttons:

| Button | Action |
|--------|--------|
| **Add File** | Opens a file browser to select one or more files |
| **Add Folder** | Adds all matching files in a selected folder (DATA: `*.edf`; STAGING: `*.csv`, falling back to `*.txt` if no CSV files are found) |
| **Delete File** | Removes the currently selected file(s) from the list |
| **Move Up / Move Down** | Reorders files to align data–staging pairs |

Duplicate files are automatically prevented — adding a file that is already in the list has no effect.

- **Double-click an EDF file** to open a floating header viewer showing recording metadata (signal names, sampling rates, record duration, start time). If the header viewer is already open, it refreshes in place.
- **Double-click a staging file** to open it in the default text editor for inspection (TextEdit on Mac, default handler on Windows/Linux).

### Loading a File List from a Text File

**File → Load EDF File List...** or **File → Load Staging File List...**

Loads a plain-text file with one file path per line. The manager validates each path, removes duplicates, and reports any issues. If missing or duplicate entries are found, a dedicated window appears showing the skipped and duplicated files, with an option to save a log file for review.

Supported list file extensions: `.txt`, `.csv`, `.tsv`, `.dat`, `.lst`

---

## 3. Configuring Channels

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

When channels are added via the browser, the File Manager checks each channel's sampling frequency against the DYNAM-O analysis frequency range. The upper analysis bound is the larger of the SOPH frequency range upper limit and the multitaper spectrogram frequency range upper limit (configured in the DYNAM-O Settings tab). Two warnings may appear:

- **Fs too high** (Fs > 10× the upper analysis bound): The channel's sampling rate far exceeds what DYNAM-O analyzes. This wastes memory and processing time. Consider enabling **Resample Data** to downsample before processing.
- **Fs too low** (Fs < 2× the upper analysis bound): The Nyquist frequency (Fs/2) is below the upper analysis bound, meaning the analysis frequency range cannot be fully represented at this sampling rate. You **must** enable **Resample Data** and upsample, or the run will fail. However, note that upsampling does not create real spectral content above the original Nyquist — consider whether narrowing the analysis frequency range is more appropriate.

---

## 4. Sampling Frequency and Resampling

### Why Sampling Frequency Matters

DYNAM-O computes multitaper spectrograms and SO-Power/Phase histograms over configurable frequency ranges. The Nyquist theorem requires that the sampling frequency (Fs) be at least **twice** the highest frequency of interest. For example, if the analysis upper bound is 30 Hz, the data must be sampled at ≥ 60 Hz.

In practice:
- **Fs too low**: If the data's sampling rate doesn't satisfy Nyquist for the configured frequency range, the analysis will fail or produce invalid results. You must either upsample the data (though this does not recover missing spectral content) or lower the analysis frequency range in the DYNAM-O Settings tab.
- **Fs much higher than needed**: Very high sampling rates (e.g., 2000 Hz for a 30 Hz analysis) work correctly but consume significantly more memory and processing time. Downsampling to a reasonable rate (e.g., 200–256 Hz) is recommended.

### Using the Resample Option

Enable the **Resample Data** switch and enter a target frequency in **New Fs (Hz)**. All EDF data will be resampled to this frequency before analysis. Resampling is performed per-channel using MATLAB's `resample` function (polyphase antialiasing filter).

**Choosing a target frequency**: A good default is 4–8× the upper analysis frequency bound. For typical sleep EEG with a 30 Hz upper bound, 200 Hz is a practical choice.

Resampling occurs after EDF loading but before any analysis steps, so all downstream outputs reflect the resampled data.

---

## 5. Configuring Staging File Parsing

Staging files are delimited text files containing sleep stage labels and epoch timestamps. Set these fields to match your staging file format:

| Field | Description |
|-------|-------------|
| **Stages Column** | Column index (1-based) containing sleep stage labels |
| **Times Column** | Column index containing epoch onset times |
| **Header Rows** | Number of header rows to skip before data begins |
| **File Delimiter** | Column delimiter: Comma, Tab, Space, or Semicolon |

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

## 6. Running Without Staging Files

The File Manager supports running without any staging files. If no staging files are loaded when you click **RUN**, a confirmation dialog asks whether to proceed. If confirmed:

- The entire recording is treated as a single N2 epoch spanning from time 0 to the end of the data.
- All non-artifact times are incorporated into TF-peak detection and SO-Power/Phase histogram analyses.
- The staging parsing fields (columns, header rows, delimiter) are still required to pass validation but are not used.

This mode is useful for exploratory analyses on unsegmented data or when sleep staging is unavailable.

---

## 7. Configuring Output Options

### Output Directory

Click **Browse** to select the folder where all results will be saved. If the selected directory does not exist, you will be prompted to create it. Outputs are organized into subdirectories automatically (see [Output Structure](#11-output-structure)).

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

Select the output format for each data type:

| Output | Available Formats |
|--------|-------------------|
| Peak Stats Table | `.csv`, `.mat`, All |
| SO Histograms | `.tiff`, `.mat`, All |
| Parametric Basis | `.csv`, `.mat`, All |
| Spline Basis | `.tiff`, `.mat`, All |
| Auxiliary Data | `.mat` |
| Data Summary Figure | `.png`, `.jpg`, `.jpeg` |
| Parametric Basis Figure | `.png`, `.jpg`, `.jpeg` |
| Spline Basis Figure | `.png`, `.jpg`, `.jpeg` |

Selecting **All** saves every available format for that output type. Selecting **--** disables saving for that output type even if the corresponding checkbox is enabled.

---

## 8. Configuring Analysis Parameters

Click the **DYNAM-O Settings** tab to access the embedded settings panel. Parameters are organized into sections:

- **SOPH Options** — SO-Power/Phase histogram configuration (including frequency range)
- **Baseline Options** — Baseline normalization settings
- **Detection Options** — TF-peak detection thresholds (including multitaper frequency range)
- **Parametric Basis Fit Options** — Power and phase parametric model settings
- **Spline Basis Fit Options** — Power and phase spline model settings

These settings are saved with each run to `<OutputDir>/settings/run_settings_<timestamp>.txt` for reproducibility (when Save Logs is enabled).

**Note:** The upper bounds of the SOPH frequency range and the multitaper frequency range determine the minimum acceptable sampling frequency for your data (see [Sampling Frequency and Resampling](#4-sampling-frequency-and-resampling)).

---

## 9. Running the Batch

### Pre-Run Validation

Clicking **RUN** triggers an automatic validation pass. The following conditions are checked, and any failures are reported in an error dialog with the offending fields highlighted in red:

- At least one EDF data file is loaded
- An output directory is specified
- If staging files are loaded, their count matches the data file count
- Stages column, times column, and header rows are all specified
- At least one channel is entered
- All stage label fields (Artifact, Wake, REM, N1, N2, N3) are non-empty
- Every file in both lists exists on disk

Fix the reported issues and click RUN again. Validation highlights clear automatically when you correct a field.

### Run Options

| Option | Description |
|--------|-------------|
| **Reverse** | Processes files in reverse list order — useful when running two parallel File Manager instances on the same dataset to avoid overlap |
| **Overwrite** | Re-processes subjects even if output files already exist; when off, subjects with existing outputs are skipped automatically |

### Processing Pipeline (per subject-channel)

For each EDF + staging file pair, for each selected channel:

1. Load EDF and extract the target channel
2. Parse staging file and align epochs (or assign full-recording N2 if running without stages)
3. Resample data if enabled
4. Compute TF-peak statistics table and SO-Power/Phase histograms
5. (If enabled) Generate and save data summary figure
6. (If enabled) Fit parametric basis model and save results/figures
7. (If enabled) Fit spline basis model and save results/figures
8. (If enabled) Save auxiliary data
9. Log result (success, skipped, or error) to the file log

### Help Button

A **Help** button is located in the bottom-right area of the File Manager window, next to the progress bar. Clicking it opens this README documentation in the system's default web browser.

---

## 10. Monitoring and Stopping a Run

### Status Area

The STATUS text area (bottom-left) shows real-time processing messages as each subject-channel pair is processed, including loading, analysis step, and saving notifications.

### Progress Bar

The progress bar (bottom-right) fills as iterations complete, showing overall batch progress across all file–channel combinations.

### Run Log Console

**File → Show Run Log Console** opens a floating window that displays live console output during processing (polled every 0.3 seconds). This is useful for detailed diagnostics. The menu item toggles to **Hide Run Log Console** while the window is open; closing the window also stops polling. The full console output is saved to `<OutputDir>/logs/console_log_<timestamp>.txt` (when Save Logs is enabled).

### Stopping

Click **STOP** to request a graceful halt. The current subject-channel will finish processing before the run stops. Partial results up to that point are saved normally.

---

## 11. Output Structure

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

**Note:** Channel names containing special characters (e.g., `C3-A2`) are sanitized for filesystem compatibility — invalid characters are removed and the cleaned name is used for directory and file naming.

All required subdirectories are created automatically before the batch loop begins.

### Log Files

| File | Contents |
|------|----------|
| `file_log_*.txt` | Per-subject outcome: success, skipped (outputs already exist), or error with details |
| `console_log_*.txt` | Full MATLAB console output for the entire run |
| `run_settings_*.txt` | All DYNAM-O option structs used for the run |

Logs and settings files are only written when **Save Logs** is enabled.

---

## 12. GUI Reference: Tabs

### File Selection Tab

The main configuration tab. Contains the DATA and STAGING file lists on the left, channel and staging options on the right, and saving/format sub-tabs below.

**Sections:**

- **DATA list** — EDF files to process, with Add File/Add Folder/Delete File/Move Up/Move Down buttons
- **STAGING list** — Paired staging files, with the same set of buttons
- **Channel(s)** — Target channel labels; Select button opens channel browser with sampling rate display
- **Staging Options** — Stage label mapping (with default values), column indices, delimiter, header row count
- **Resample Data / New Fs** — Optional resampling before analysis (disabled by default; enable switch to activate frequency field)
- **Saving Options sub-tab** — Checkboxes for data and figure outputs, plus Save Logs toggle
- **File Formats sub-tab** — Format selector for each output type

### DYNAM-O Settings Tab

Hosts the embedded DYNAMOOptions sub-app for configuring all analysis parameters. Changes here are applied to all subjects in the next run and are saved to the settings log.

---

## 13. GUI Reference: Menus

### File Menu

| Item | Description |
|------|-------------|
| **Load EDF File List...** | Load a text file of EDF paths (one per line) into the DATA list |
| **Load Staging File List...** | Load a text file of staging file paths into the STAGING list |
| **Show Run Log Console** | Toggle the floating live console output window |

### Help Menu

| Item | Description |
|------|-------------|
| **Help** | Opens this README documentation in the system web browser |
| **About DYNAM-O...** | Displays lab info, website/GitHub links, and paper citations |

---

## 14. Programmatic API

The File Manager can be embedded in scripts or larger applications.

### Constructor

```matlab
app = DYNAMOFileManager()
app = DYNAMOFileManager('Title', 'My Batch Run')
app = DYNAMOFileManager('Position', [x y w h])
app = DYNAMOFileManager('BatchCallback', @myCallback)
app = DYNAMOFileManager('ValidationCallback', @myValidator)
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
