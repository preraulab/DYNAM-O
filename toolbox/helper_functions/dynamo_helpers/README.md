# dynamo_helpers

Helper utilities that are specific to DYNAM-O (not in any of the lab's public utility submodules) or that are vendored third-party files.

## Files

### DYNAM-O-specific helpers

| File | Purpose |
|---|---|
| `batch_script.m` | Batch-run orchestrator for DYNAMO across subjects |
| `conv_imresize.m` | Convolve-then-resize helper for downsampling 2-D arrays while preserving total energy |
| `generate_run_log.m` | Write per-run log files capturing parameters and timings |
| `hann_event_spectra.m` | Hanning-tapered event-triggered spectrogram (SO-phase-locked analyses) |
| `hmstext2seconds.m` | Parse 'HH:MM:SS' text into seconds |
| `isShiftstr.m` | Check whether a string is a shift-key keyboard code |
| `load_data.m` | DYNAMO-standard data loader |
| `mergeOptsDefaults.m` | Backfill missing fields in an options struct from a defaults struct |
| `printTimingSummary.m` | Pretty-print runDYNAMO per-stage wallclock timings as a sorted table |
| `remove_subj.m` | Filter a subject list down to a working subset |
| `verb_disp.m` | Verbose-conditional display wrapper |

### Vendored third-party

| File | Source |
|---|---|
| `suptitle.m` | MATLAB File Exchange — figure super-title helper |

## Why these live here

Every other helper function DYNAM-O needs comes from a public lab submodule:

- `binning/`, `conversion/`, `data_processing/`, `fig_tools/`, `graphical/`, `nanstats/`, `colormaps/`, `sleep/` — each a public git submodule in this directory
- `CSSuicontrols/`, `read_EDF/`, `artifact_detection/`, `statistical_tests/`, `multitaper_toolbox/` — likewise, public submodules elsewhere in the toolbox

The files in this folder are either (a) DYNAM-O-specific utilities that only make sense in this context, or (b) small third-party files where vendoring is simpler than pulling in a private mirror repo.
