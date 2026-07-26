# `app/` — File-by-file map of the GUI

This is a "where does this part of the screen come from" guide. Open the GUI,
look at a region, and this doc tells you which file builds it, which file
fills it with data, and which file runs when you click something inside it.

For the user-facing manual (what each tab/button does), see
[`../DYNAMOApp_README.md`](../DYNAMOApp_README.md).

---

## Top-level folders

```
app/
├── @DYNAMOApp/      ← the GUI class — 130 method files
│   ├── DYNAMOApp.m  ← classdef, properties, callbacks (1-line shims)
│   └── *.m                  ← one method per file (auto-discovered by MATLAB)
├── +results_browser/        ← stateless helpers used by the Results Browser
├── components/CSSuicontrols/← styled uifigure widgets (submodule)
└── dynamoStyle.m            ← global colors / fonts
```

When MATLAB sees `app.someMethod()`, it looks first in `DYNAMOApp.m`
and then in any `someMethod.m` inside `@DYNAMOApp/`. We use that to
keep one *purpose* per file.

---

## Boot sequence — what runs when you launch DFM

```
DYNAMOApp(varargin)            ← constructor in DYNAMOApp.m
└── createComponents(app, ...)         ← also in DYNAMOApp.m
    ├── createUIFigureAndShell.m       ← the uifigure window + tabgroup + menu bar
    ├── createBatchSetupTab.m          ← Tab 1: "DYNAM-O Batch Run"
    ├── createBottomBar.m              ← RUN/STOP buttons + status bar (across all tabs)
    ├── createDYNAMOSettingsTab.m      ← Tab 4: settings sub-app
    ├── createResultsBrowserTab.m      ← Tab 2: "Results Browser"
    ├── createAnalysisTab.m            ← Tab 3: "Aggregate Data"
    └── finalizeUI.m                   ← post-build: tooltips, default state, sizing
```

If you can't find where a widget gets created, start at the matching
`create*.m` file above. Every widget is `app.SomeName = ...` — search for that
property name to find its builder.

---

## The window

| Region you see | Built by | Notes |
|---|---|---|
| Top window frame, menu bar, tab bar | `createUIFigureAndShell.m` | Sets `app.UIFigure`, `app.ProjectTabGroup`, the `File`/`Help` menus |
| Bottom bar (RUN/STOP, status label, progress bar, version) | `createBottomBar.m` | Lives below all tabs |
| Full-app font / spacing | `applyFont` (in classdef), `dynamoStyle.m` | Called at end of `createComponents` |
| Window close (×) → asks "save lists?" | `uiFigureCloseRequest` (in classdef) | Wired in `createUIFigureAndShell.m` |
| Min-size enforcement on resize | `enforceMinSize` (in classdef) | Wired via `SizeChangedFcn` |

---

## Tab 1 — "DYNAM-O Batch Run" (Setup tab)

Built by **`createBatchSetupTab.m`**. The sections you see, top to bottom:

| Section | Widget | Files |
|---|---|---|
| **Data files** list | `app.DataListBox` | Built in `createBatchSetupTab.m` |
| Add file / Add folder / Remove / Move ↑↓ | `Data*ButtonPushed` shims | Implementations: `addDataFilesViaDialog.m`, `addDataFolderViaDialog.m`, `removeSelectedDataFiles.m`, `moveListItems.m` |
| Load list from file (CSV) | `loadDataFileListFromFile.m` | Triggered by File menu or Load button |
| Double-click a row → header preview | `showEdfHeaderDialog.m` | EDF channel browser dialog |
| **Staging files** list | `app.StagingListBox` | Built in `createBatchSetupTab.m` |
| Add/Remove/Move on staging side | `Staging*ButtonPushed` shims | Implementations: `addStagingFilesViaDialog.m`, etc. |
| Load staging list from file | `loadStagingListFromFile.m` | |
| **Channel selection** table + "View Channels" | `app.ChannelTable`, `viewChannelsButtonPushed` | Click → opens `createRunMontageWindow.m` (the channel-selection dialog) |
| Channel sampling-rate warning | `validateChannelSamplingRates.m` | Runs after channel changes |
| Channel-row tooltips | `refreshChannelTooltips.m` | Runs when EDFs load |
| **Staging file format** dropdowns (column / delimiter / header rows) | dropdown callbacks | Update logic: `updateStagesInput.m`, `updateChannelInput.m`, `updateReferenceInput.m`, `updateDelimeterInput.m` |
| **Output options** (output dir, results-browser dir, resample switch, save format) | switch/edit callbacks | `pickOutputDirViaDialog.m`, `pickResultsBrowserDirViaDialog.m`, `onOutputDirChanged.m`, `onResampleSwitchChanged.m` |
| **Quick-fill** preset menu | menu callback | `applyQuickFill.m` |
| Run-error list (red text near bottom) | `app.RunErrorList` | Updated by `updateRunErrorList.m` whenever inputs change |

**RUN button** (in bottom bar) → `RunBatchButtonPushed` shim → **`startBatchRun.m`**
→ runs the pipeline (see Run pipeline below).
**STOP button** → `StopBatchButtonPushed` → `requestStopBatch.m` (sets a flag
that `runBatch.m` polls between stages).

---

## Tab 2 — "Results Browser"

Built by **`createResultsBrowserTab.m`**. Two-pane layout with a draggable
column splitter; the right pane has a draggable row splitter for the preview.

```
┌─ Results Browser tab ─────────────────────────────────────────┐
│ ┌─ left pane ─────┐ │ ┌─ right pane ────────────────────────┐ │
│ │  results dir    │ │ │  preview header (filename, type)    │ │
│ │  picker          │ │ ├─ row splitter ──────────────────────┤ │
│ │  + tree         │ │ │  preview body (axes / table / text) │ │
│ └─────────────────┘ │ └─────────────────────────────────────┘ │
│        column splitter ↕ (draggable)                          │
└───────────────────────────────────────────────────────────────┘
```

| Region | Built by | Populated by | Reacts via |
|---|---|---|---|
| Results dir picker, tree (`app.ResultsTree`) | `createResultsBrowserTab.m` | `loadResultsBrowserTree.m` (walks dir, reads `_runs/*.jsonl`) | `onResultsBrowserMenuAction.m` (right-click menu) |
| Tree-cache build | — | `buildCacheFromIndex.m`, `scanDirIntoCache.m`, `readRunIndexFile.m`, `promptToSeedRunIndex.m`, `regenerateRunIndex.m` | |
| **Aggregate** menu items (right-click on a channel/root) | — | `aggregateResultsRoot.m`, `aggregateOneChannel.m`, `aggregateChannelByMenu.m` | Writes via `writeParamfitAggregate.m`, `writeSOPHsAggregate.m`; confirms via `confirmAggregateOverwrite.m` |
| Aggregate progress bar (under the tree) | `createAggregateProgressGrid.m` | `tickAggregateProgress.m` (per-stage tick) | Torn down by `destroyAggregateProgressGrid.m` |
| Right-pane preview header | `createResultsBrowserTab.m` | `previewResultsBrowserNode.m` (entry point — switches by file type) | |
| `.mat` preview | — | `renderResultsBrowserPreviewMat.m` → `previewMatSOPHs.m` / `previewMatParamfit.m` / `previewMatSplinefit.m` / `previewMatAuxiliary.m` / `previewMatStatsTable.m` / `previewMatAggregate.m` / `renderResultsBrowserPreviewMatGeneric.m` | |
| `.tiff` preview (multi-page slider) | — | `renderResultsBrowserPreviewTiff.m`, `renderSOPHTiffSliderPage.m`, `replotSOPHTiffPage.m`, `jumpToSOPHTiffPage.m` | |
| `.csv` / `.txt` / `.png` previews | — | `renderResultsBrowserPreviewCsv.m`, `renderResultsBrowserPreviewText.m`, `renderResultsBrowserPreviewImage.m` | |
| 3D volume page (`renderMatNodeValue` slider) | — | `renderMatVolumePage.m`, scroll bar built inline in `renderMatNodeValue.m` | |
| Preview-loading spinner | `createResultsBrowserPreviewProgress.m` | `tickResultsBrowserPreviewProgress.m` | |
| "Open in Finder/Explorer" right-click | — | `openPathInOS.m` (also fires on tree double-click) | |
| **Column splitter** (drag to resize panes) | `createResultsBrowserTab.m` | — | `startResultsBrowserColumnResize.m` → `dragResultsBrowserColumnResize.m` → `endResultsBrowserColumnResize.m` |
| **Row splitter** (drag to resize preview header vs body) | `createResultsBrowserTab.m` | — | `startResultsBrowserRowResize.m` / `drag*` / `end*` |
| **Pop-out toolbar** (the ⤴ button on a preview axes) | `attachPopOutToolbar.m` | — | Click → `openAxesInFigure.m` (re-renders the axes in a standalone figure) |

Pure helpers used here that don't need `app`: see **`+results_browser/`** —
`build_tree_node.m`, `cache_to_tree_node.m`, `walk_to_cache.m`,
`is_dynamo_results_dir.m`, `node_label.m`, `node_menu_items.m`, etc.

---

## Tab 3 — "Aggregate Data" (Analysis tab)

Built by **`createAnalysisTab.m`**. Three-column layout with a draggable
splitter between the channel selector and the inner tab group:

```
┌─ Aggregate Data tab ───────────────────────────────────────────┐
│ channels  ║  ┌─ inner tab group ──────────────────────────┐    │
│ list box  ║  │  Mean SOPH | Mode Scatter | … (sub-tabs)   │    │
│           ║  │                                            │    │
│           ║  │  (plots / dropdowns / colorbar)            │    │
│           ║  └────────────────────────────────────────────┘    │
│  splitter ↕ (draggable)                                        │
└────────────────────────────────────────────────────────────────┘
```

| Region | Built by | Populated by | Reacts via |
|---|---|---|---|
| Channel list (`app.SOHistogramsChannelListBox`) | `createAnalysisTab.m` | `refreshSOHistogramsAvailability.m` (greys out channels with no aggregate on disk) | Selection-change → re-renders all sub-tabs |
| **Splitter** between channel list and tab group | `createAnalysisTab.m` | — | `startDragSOHistogramsSplitter.m` → `dragSOHistogramsSplitter.m` → `endDragSOHistogramsSplitter.m` |
| **Mean SOPH** sub-tab (`app.MeanSOPHTab`) — pair grid of histograms | `createAnalysisTab.m` (grid) + `buildPairGrid.m` (axes) | `renderSOPHHistograms.m`, `plotAggregateSOHist.m`, `styleSOPHAxes.m` | Reads aggregate via `loadParamfitAggregateForChannel.m`, `findSOHistAggregate.m` |
| **Mode Scatter** sub-tab — N×N pair plot | `createAnalysisTab.m` + `buildPairGrid.m` | `renderModeScatter.m` (scatter), dropdown handlers in `createAnalysisTab.m` | Color/size dropdowns recompute via `computeScatterLims.m`; redrawn by `redrawModeScatter.m` |
| Range hints used by axes (`x` from frequency, `y` from SO-power bins) | — | `getSOPHFreqRange.m`, `getSOPHPowerBinRange.m`, `binsForParamfit.m` | |
| "Has data?" gating (greys sub-tabs without aggregate on disk) | — | `hasModeParamData.m` | |
| Pop-out an axes to a figure | `attachPopOutToolbar.m` | — | `openAxesInFigure.m` |

This tab and the Results Browser preview share the SOPH plotting helpers
(`plotAggregateSOHist`, `styleSOPHAxes`, `renderSOPHTiffSliderPage`,
`peekSOPHTiffBins`) — that's why those files don't live "inside" either tab.

---

## Tab 4 — "DYNAM-O Settings"

Built by **`createDYNAMOSettingsTab.m`**. Embeds the settings sub-app from
the toolbox. Most logic is in the embedded settings UI; this file just
host-mounts it.

---

## Run pipeline (the RUN button)

`RunBatchButtonPushed` (shim) → **`startBatchRun.m`** → loops over selected
data files → for each file, calls **`runBatch.m`** which orchestrates the
five pipeline stages with per-file save gates:

| Stage | File | What it does |
|---|---|---|
| `runDataSummaryFigure.m` | hypnogram + spectrogram QC figure | |
| `runStatsTable.m` | SOPH 2D-histograms (`.mat` + `.csv`) | |
| `runParamBasis.m` | parametric peak-fit basis | |
| `runSplineBasis.m` | spline-fit basis | |
| `saveAuxData.m` | aux outputs (per-file `_aux.mat`) | |

UI state during a run:
- `setRunningState.m` — disables most controls, swaps RUN icon for spinner.
- `resetRunUiState.m` — restores normal state on completion / abort.
- `appendRunLog.m` — writes one line to the run-log buffer.
- `toggleRunLogConsole.m` — opens/closes the floating run-log window
  (`createRunLogConsole.m` builds it).
- `refreshLogConsole.m` + `startLogConsoleTimer.m` / `stopLogConsoleTimer.m`
  — periodically tail the buffer into the console.

The driver checks `app.UserStopRequest` between stages to honor the STOP
button (`requestStopBatch.m` flips that flag).

---

## Where do shared things live?

- **MATLAB-app callbacks** (`*ButtonPushed`, `*MenuSelected`, `*Changed`):
  in `DYNAMOApp.m` as 1-line shims that call the verb-noun method.
  Don't put logic in the shim — put it in the per-file method.
- **Properties** (`app.SomeWidget`, `app.SomeState`): in the `properties`
  block of `DYNAMOApp.m` (per-file methods can't declare properties).
- **Stateless helpers** (no `app` argument): under `+results_browser/` if
  Results-Browser-specific, else inline in the calling method.
- **CSS-styled widgets** (`CSSuiButton`, `CSSuiListBox`, `CSSuiTable`,
  `CSSuiDropdown`, `CSSuiLabel`): submodule under `components/CSSuicontrols/`.
  Build issues with these (e.g. selection-change events) are fixed in that
  repo, not here.

---

## Adding a new feature — minimal recipe

1. Pick a verb (`create`/`render`/`refresh`/`update`/`run`/`build`/`load`/
   `pick`/`on`/…) that describes what it does for the user.
2. Add `app/@DYNAMOApp/<verb><Noun>.m` containing
   `function <verb><Noun>(app, ...)` — MATLAB auto-discovers it.
3. If wired to a button, add a one-line shim in `DYNAMOApp.m`:
   ```matlab
   function MyButtonPushed(app, ~, ~)
       app.myVerbNoun();
   end
   ```
4. If you need new state, add a property to the `properties` block.
5. If it's stateless and doesn't touch `app`, put it in `+results_browser/`
   (or a new `+package/`) instead.
