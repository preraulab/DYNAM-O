# `app/` — DYNAM-O File Manager Architecture

This folder contains the DYNAM-O File Manager (DFM) — a MATLAB-app-based GUI
for running batch sleep-EEG analyses through the DYNAM-O toolbox. This document
describes how the code is organized so contributors know where to add new
features and where to find existing ones.

For the user-facing manual (what each tab/button does), see
[`../DYNAMOFileManager_README.md`](../DYNAMOFileManager_README.md).

---

## Layout

```
app/
├── @DYNAMOFileManager/      ← the GUI class (130 per-feature method files)
│   ├── DYNAMOFileManager.m  ← classdef + properties + lifecycle + callback shims
│   └── *.m                  ← one method per file, named for purpose
├── +results_browser/        ← pure helpers for the Results Browser tree
│   └── *.m                  ← stateless functions (no `app` argument)
├── components/
│   └── CSSuicontrols/       ← styled wrappers over uifigure controls (submodule)
└── dynamoStyle.m            ← global colour / font palette
```

### `@DYNAMOFileManager/` — the class folder

MATLAB auto-discovers any `function name(app, ...)` defined in a `.m` file inside
`@ClassName/` and treats it as a method of the class. We use this to keep the
classdef file (`DYNAMOFileManager.m`) small and feature-specific code in
focused per-feature files.

Only what *must* live in the classdef stays there:

- `classdef ... < matlab.apps.AppBase` declaration + `properties` block
- Constructor (`DYNAMOFileManager(varargin)`) and `delete(app)`
- `createComponents` (top-level UI assembly — calls into `create*Tab` files)
- Lifecycle helpers: `uiFigureCloseRequest`, `trackChildWindow`,
  `enforceMinSize`, `applyFont`, `setEnabled`
- Tiny pure statics: `fixFilename`, `splitTopLevelCommas`, `clearIsError`
- **MATLAB-app callback shims** (`*ButtonPushed`, `*MenuSelected`, `*Changed`):
  one-liners that delegate to the verb-noun implementation in the corresponding
  per-file method (e.g. `RunBatchButtonPushed → app.startBatchRun()`)

Everything else — UI builders, render passes, run-pipeline stages, file-list
ops, aggregator, logging — lives in its own `.m` file in this folder.

### `+results_browser/` — the package folder

Pure helpers that don't depend on the `app` instance. Lower-case
underscore-style names are used here (`is_dynamo_results_dir`,
`build_tree_node`, `walk_to_cache`) to flag them as plain functions, not class
methods. Anything that needs to mutate `app.state` or touch the UI lives in
`@DYNAMOFileManager/` instead.

### `components/CSSuicontrols/`

Submodule of styled `uifigure` wrappers (`CSSuiButton`, `CSSuiListBox`,
`CSSuiTable`, `CSSuiDropdown`, …). Treat as an external dependency: changes
land via that repo, not here.

---

## Naming convention

**Rule of thumb**: file/method names answer *"what does the user get?"* — not
*"what UI element fired this?"* That means a button callback can be named
`RunBatchButtonPushed` (forced by MATLAB-app), but the implementation it
delegates to is named `startBatchRun`.

| Prefix | Means | Examples |
|---|---|---|
| `create*` | Build a UI structure once (tab, window, panel, bar, dialog) | `createBatchSetupTab`, `createRunMontageWindow`, `createConsoleLogPanel` |
| `render*` | Populate a UI element with data; can run repeatedly | `renderResultsBrowserPreviewMat`, `renderSOPHTiffSliderPage` |
| `refresh*` | Re-derive UI state from current backing data | `refreshChannelTooltips`, `refreshLogConsole` |
| `update*` | Recompute a derived UI piece in response to one input change | `updateRunErrorList`, `updateDataListBox` |
| `run*` | Execute a pipeline stage | `runBatch`, `runStatsTable`, `runParamBasis` |
| `compute*` | Pure computation returning a value, no side effects | `computeScatterLims` |
| `load*` / `read*` | Read from disk / external source | `loadResultsBrowserTree`, `readRunIndexFile` |
| `write*` / `save*` / `append*` | Write to disk or an output buffer | `writeParamfitAggregate`, `saveAuxData`, `appendRunLog` |
| `build*` | Construct a non-UI data structure | `buildCacheFromIndex`, `buildOptionsStruct` |
| `pick*` | Open a file/folder dialog and return the user's selection | `pickFilesViaDialog`, `pickOutputDirViaDialog` |
| `start*` / `end*` / `drag*` | Pointer-drag interaction phases | `startResultsBrowserColumnResize`, `dragResultsBrowserColumnResize`, `endResultsBrowserColumnResize` |
| `on*` | Event handler named after the user-visible event, not the control | `onResultsBrowserMenuAction`, `onResampleSwitchChanged`, `onOutputDirChanged` |
| `validate*` | Check a value/state and surface a warning if invalid | `validateChannelSamplingRates` |
| MATLAB callback shims | `*ButtonPushed`, `*MenuSelected`, `*Changed` | One-liners in `DYNAMOFileManager.m` that delegate to the verb-noun method |

---

## Feature groupings

The 130 methods in `@DYNAMOFileManager/` cluster into these features. The list
below points at the *entry-point* file for each feature; follow its `app.*`
calls to find the rest.

| Feature | Entry point |
|---|---|
| App boot / top-level layout | `createUIFigureAndShell.m`, `finalizeUI.m` |
| Setup tab (file lists, channels, options) | `createBatchSetupTab.m` |
| Run-montage dialog (channel-selection window) | `createRunMontageWindow.m` |
| Settings tab | `createDYNAMOSettingsTab.m` |
| Bottom bar (Run / Stop / progress) | `createBottomBar.m` |
| Run pipeline (driver + stage runners) | `runBatch.m`, `runStatsTable.m`, `runParamBasis.m`, `runSplineBasis.m`, `runDataSummaryFigure.m`, `saveAuxData.m` |
| Results Browser tree + aggregator | `loadResultsBrowserTree.m`, `aggregateResultsRoot.m` |
| Results Browser preview pane | `previewResultsBrowserNode.m` |
| Aggregate Data tab (SOPH histograms / mode scatter) | `createAnalysisTab.m`, `renderSOPHHistograms.m`, `renderModeScatter.m` (look for verb-noun render entry points in the analysis tab builder) |
| Logging / run-log console | `createRunLogConsole.m`, `appendRunLog.m`, `toggleRunLogConsole.m` |
| Splitters | `startResultsBrowserColumnResize.m`, `startResultsBrowserRowResize.m`, `startDragSOHistogramsSplitter.m` |

---

## Adding a new feature

1. **Pick a verb prefix from the table above** that matches what the function
   does for the user. If none fits, add a new prefix to the convention rather
   than picking a vague verb (`do*`, `process*`, `handle*`).
2. **Create a new `.m` file** in `app/@DYNAMOFileManager/` named
   `<verb><Noun>.m` containing a single function `function <verb><Noun>(app, ...)`.
   MATLAB will auto-discover it as a method.
3. **If wired to a button/menu**, add a 1-line MATLAB-app callback shim in
   `DYNAMOFileManager.m`:
   ```matlab
   function MyButtonPushed(app, ~, ~)
       app.myVerbNoun();
   end
   ```
4. **Helpers that don't need `app`** belong in `+results_browser/` (or a new
   `+package/` if the feature is large enough to warrant its own).
5. **Don't add new properties to a per-file method** — properties have to live
   in the classdef's `properties` block. Add them grouped by feature there.

---

## Why this layout

The class was a single 8,400-line file before this split. Discoverability and
naming inconsistency were the two pain points:

- **Discoverability**: with one method per file, `ls @DYNAMOFileManager` is the
  feature index. Verb prefixes mean even partial-recall searches
  (`createRun…`, `runStats…`) land on the right file.
- **Naming consistency**: half the methods used to be named for the GUI
  control that fired them (`viewChannelsButtonPushed`, `RunBatchButtonPushed`).
  Now those names survive only as one-line callback shims; the implementation
  is named for what it does (`createRunMontageWindow`, `startBatchRun`).

Per-file methods do not have a measurable runtime cost — MATLAB caches
class-folder method tables on first use of the class, so the parse cost is paid
once per session.

---

## Out of scope (for future refactors)

- Splitting the 611-line `runBatch` further into per-stage helpers (a
  per-channel/per-stage split is the natural next pass).
- Promoting groups of methods to standalone classes (e.g. a
  `ResultsBrowserModel` with its own state). The flat `@`-folder is sufficient
  for navigability now that file names describe purpose.
- Reorganizing the `properties` block — properties can't be declared in
  per-file methods, so they stay grouped by feature in the classdef.
