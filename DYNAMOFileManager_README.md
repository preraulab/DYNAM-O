# DYNAM-O File Manager

The DYNAM-O File Manager is the primary graphical interface for running batch EEG/polysomnography analyses with the DYNAM-O (Dynamical Oscillation) toolbox. It manages file loading, analysis configuration, and batch execution across multiple subjects and channels, with real-time progress monitoring and structured output logging.

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [Loading Files](#2-loading-files)
3. [Configuring Channels](#3-configuring-channels)
4. [Configuring Staging File Parsing](#4-configuring-staging-file-parsing)
5. [Configuring Output Options](#5-configuring-output-options)
6. [Configuring Analysis Parameters](#6-configuring-analysis-parameters)
7. [Running the Batch](#7-running-the-batch)
8. [Monitoring and Stopping a Run](#8-monitoring-and-stopping-a-run)
9. [Output Structure](#9-output-structure)
10. [GUI Reference: Tabs](#10-gui-reference-tabs)
11. [GUI Reference: Menus](#11-gui-reference-menus)
12. [Programmatic API](#12-programmatic-api)

---

## 1. Quick Start

```
1. Add EDF data files and matching staging files
2. Select channels to process
3. Set staging file parsing options
4. Choose an output directory and what to save
5. (Optional) Adjust analysis parameters in the Settings tab
6. Click RUN
```

Data and staging file counts must match — each EDF is paired with the staging file at the same list position.

---

## 2. Loading Files

### Adding Files Manually

Each file list (DATA and STAGING) has its own set of action buttons:

| Button | Action |
|--------|--------|
| **Add File** | Opens a file browser to select one or more files |
| **Add Folder** | Adds all valid files in a selected folder |
| **Delete File** | Removes the currently selected file from the list |
| **Move Up / Move Down** | Reorders files to align data–staging pairs |

- **Double-click an EDF file** to open a floating header viewer showing recording metadata (signal names, sampling rates, record duration, start time).
- **Double-click a staging file** to open it in the default text editor for inspection.

### Loading a File List from a Text File

**File → Load EDF File List...** or **File → Load Staging File List...**

Loads a plain-text file with one file path per line. The manager validates each path, reports missing and duplicate entries, and offers to save a log of any skipped files.

Supported list file extensions: `.txt`, `.csv`, `.tsv`, `.dat`, `.lst`

---

## 3. Configuring Channels

### Channel(s) Field

Enter one or more channel labels as a comma-separated list (e.g., `C3, C4, O1`). Labels must match the signal names stored in the EDF headers exactly.

### Channel Browser

Click **Select** to open the interactive channel browser, which scans all loaded EDF files and displays:

- All available channel names
- Sampling frequency per channel
- How many files contain each channel

Select one or more channels and click **Add to Batch Run** to populate the channel field.

#### Creating Rereference Channels

The channel browser supports virtual rereference channels computed as the difference between two real channels (e.g., `C3-A2`). Use the rereference sub-dialog to choose a signal and a reference; the manager validates that both channels exist in the same files and share the same sampling rate.

---

## 4. Configuring Staging File Parsing

Staging files are delimited text files containing sleep stage labels and epoch timestamps. Set these fields to match your staging file format:

| Field | Description |
|-------|-------------|
| **Stages Column** | Column index (1-based) containing sleep stage labels |
| **Times Column** | Column index containing epoch onset times |
| **Header Rows** | Number of header rows to skip before data begins |
| **File Delimiter** | Column delimiter: Comma, Tab, Space, or Semicolon |

### Stage Label Mapping

For each stage, enter the identifiers used in your staging file as a comma-separated list. Multiple synonyms are supported (e.g., `W, Wake, 0`).

| Field | Stage |
|-------|-------|
| **Artifact** | Artifact epochs |
| **Wake** | Wakefulness |
| **REM** | REM sleep |
| **N1** | NREM Stage 1 |
| **N2** | NREM Stage 2 |
| **N3** | NREM Stage 3 |
| **Unknown** | Unscored or unknown epochs |

### Resampling

Enable the **Resample Data** switch and enter a target frequency in **New Fs (Hz)** to resample all EDF data before analysis.

---

## 5. Configuring Output Options

### Output Directory

Click **Browse** to select the folder where all results will be saved. Outputs are organized into subdirectories automatically (see [Output Structure](#9-output-structure)).

### Saving Options Tab

Check the boxes for the data types and figures to generate:

**Data to Save**
| Option | Description |
|--------|-------------|
| Peak Stats Tables | TF-peak statistics table per subject-channel |
| SO-Power Histogram | SO-Power and SO-Phase histograms |
| Parametric Basis | Parametric basis fit coefficients |
| Spline Basis | Spline basis fit data |
| Auxiliary Data | Artifacts, Fs, stage times/values, normalization method |

**Figures to Save**
| Option | Description |
|--------|-------------|
| Data Summary | Overview summary figure |
| Parametric Basis | Parametric basis fit visualization |
| Spline Basis | Spline basis fit visualization |

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

Selecting **All** saves every available format for that output type.

---

## 6. Configuring Analysis Parameters

Click the **DYNAM-O Settings** tab to access the embedded settings panel. Parameters are organized into sections:

- **SOPH Options** — SO-Power/Phase histogram configuration
- **Baseline Options** — Baseline normalization settings
- **Detection Options** — TF-peak detection thresholds
- **Parametric Basis Fit Options** — Power and phase parametric model settings
- **Spline Basis Fit Options** — Power and phase spline model settings

These settings are saved with each run to `<OutputDir>/settings/run_settings_<timestamp>.txt` for reproducibility.

---

## 7. Running the Batch

### Pre-Run Checklist

Before clicking RUN, verify:

- [ ] DATA and STAGING lists have the same number of files
- [ ] Files are paired correctly (same position = same subject)
- [ ] At least one channel is entered
- [ ] All staging parsing fields are filled
- [ ] An output directory is selected

### Run Options

| Option | Description |
|--------|-------------|
| **Reverse** | Processes files in reverse list order — useful when running parallel instances on the same dataset to avoid overlap |
| **Overwrite** | Re-processes subjects even if output files already exist; when off, subjects with existing outputs are skipped |

### Validation

Clicking **RUN** triggers a validation pass. If any issues are found (mismatched file counts, missing files, empty fields), an alert dialog lists all errors. Fix the reported issues and click RUN again.

### Processing Pipeline (per subject-channel)

For each EDF + staging file pair, for each selected channel:

1. Load EDF and extract the target channel
2. Parse staging file and align epochs
3. Resample data if enabled
4. Compute TF-peak statistics table
5. Generate SO-Power and SO-Phase histograms
6. (If enabled) Fit parametric basis model
7. (If enabled) Fit spline basis model
8. (If enabled) Generate and save summary/basis figures
9. Save selected outputs to structured output directory
10. Log result to file log

---

## 8. Monitoring and Stopping a Run

### Status Area

The STATUS text area (bottom-left) shows real-time processing messages as each subject-channel pair is processed.

### Progress Bar

The progress bar (bottom-right) fills as iterations complete, showing overall batch progress.

### Run Log Console

**File → Show Run Log Console** opens a floating window that displays live console output during processing. This is useful for detailed diagnostics. The full console output is also saved to `<OutputDir>/logs/console_log_<timestamp>.txt`.

### Stopping

Click **STOP** to request a graceful halt. The current subject-channel will finish processing before the run stops. Partial results are saved normally.

---

## 9. Output Structure

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

### Log Files

| File | Contents |
|------|----------|
| `file_log_*.txt` | Per-subject outcome (success or error message) |
| `console_log_*.txt` | Full MATLAB console output for the entire run |
| `run_settings_*.txt` | All DYNAM-O option structs used for the run |

---

## 10. GUI Reference: Tabs

### File Selection Tab

The main configuration tab. Contains the DATA and STAGING file lists on the left, channel and staging options on the right, and saving/format sub-tabs below.

**Sections:**

- **DATA list** — EDF files to process, with Add/Delete/Move/AddFolder buttons
- **STAGING list** — Paired staging files, with the same set of buttons
- **Channel(s)** — Target channel labels; Select button opens channel browser
- **Staging Options** — Stage label mapping, column indices, delimiter, header row count
- **Resample Data / New Fs** — Optional resampling before analysis
- **Saving Options sub-tab** — Checkboxes for data and figure outputs
- **File Formats sub-tab** — Format selector for each output type

### DYNAM-O Settings Tab

Hosts the embedded DYNAMOOptions sub-app for configuring all analysis parameters. Changes here are applied to all subjects in the next run and are saved to the settings log.

---

## 11. GUI Reference: Menus

### File Menu

| Item | Description |
|------|-------------|
| **Load EDF File List...** | Load a text file of EDF paths (one per line) into the DATA list |
| **Load Staging File List...** | Load a text file of staging file paths into the STAGING list |
| **Show Run Log Console** | Toggle the floating live console output window |

### Help Menu

| Item | Description |
|------|-------------|
| **Help** | Shows a brief usage guide dialog |
| **About DYNAM-O...** | Displays lab info, website/GitHub links, and paper citations |

---

## 12. Programmatic API

The File Manager can be embedded in scripts or larger applications.

### Constructor

```matlab
app = DYNAMOFileManager()
app = DYNAMOFileManager('Title', 'My Batch Run')
app = DYNAMOFileManager('Position', [x y w h])
app = DYNAMOFileManager('BatchCallback', @myCallback)
app = DYNAMOFileManager('ValidationCallback', @myValidator)
```

### Adding Files

```matlab
% Add individual files
app.addDataFiles('/path/to/subject01.edf')
app.addDataFiles({'/path/to/sub01.edf', '/path/to/sub02.edf'})

app.addStagingFiles('/path/to/subject01_staging.csv')
app.addStagingFiles({'/path/to/sub01_staging.csv', '/path/to/sub02_staging.csv'})
```

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
