classdef DYNAMOApp < matlab.apps.AppBase & DYNAMO
    % DYNAMOAPP  GUI application for managing batch file processing in the DYNAM-O toolbox.
    %
    %   This class provides a MATLAB App Designer-based graphical user interface
    %   for loading EDF (polysomnography data) files and paired sleep staging files,
    %   configuring runtime and saving options, and executing batch processing runs
    %   using the DYNAMO analysis pipeline.
    %
    %   Inherits from:
    %       matlab.apps.AppBase  - base class for MATLAB App Designer apps
    %       DYNAMO               - base class providing core DYNAM-O analysis methods
    %
    %   Usage:
    %       app = DYNAMOApp()
    %
    %   See also: DYNAMO, runDYNAMO, matlab.apps.AppBase
    %
    % =========================================================================
    %    ██████╗ ██╗   ██╗███╗   ██╗ █████╗ ███╗   ███╗        ██████╗
    %    ██╔══██╗╚██╗ ██╔╝████╗  ██║██╔══██╗████╗ ████║       ██╔═══██╗
    %    ██║  ██║ ╚████╔╝ ██╔██╗ ██║███████║██╔████╔██║  ███╗ ██║   ██║
    %    ██║  ██║  ╚██╔╝  ██║╚██╗██║██╔══██║██║╚██╔╝██║  ╚══╝ ██║   ██║
    %    ██████╔╝   ██║   ██║ ╚████║██║  ██║██║ ╚═╝ ██║       ╚██████╔╝
    %    ╚═════╝    ╚═╝   ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝     ╚═╝        ╚═════╝
    %
    % -------------------------------------------------------------------------
    %    Characterizing Individualized Neural Dynamics in Sleep EEG
    % -------------------------------------------------------------------------
    %
    %    Developed by the Prerau Laboratory
    %    WEB:       https://sleepeeg.org
    %    TUTORIALS: https://prerau.bwh.harvard.edu/dynam-o/
    %    GITHUB:    https://github.com
    %
    %    ATTRIBUTION
    %    If you use this toolbox in publications or derived work, please cite:
    %
    %    He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
    %    "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
    %    in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
    %
    %    Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
    %    Manoach, D. S., Stickgold, R., Prerau, M. J.
    %    "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
    %   for Electroencephalographic Phenotyping and Biomarker Identification"
    %    Sleep, 2022; zsac223. https://doi.org
    %
    % =========================================================================

    % ======================================================================
    %   PROPERTIES
    % ======================================================================

    properties (Access = private)

        % --- App-wide style ---
        AppStyle                        CSSPreset                       % Single CSSPreset shared by every CSSui* widget; set once in constructor.

        % --- UI Figure & Menus ---
        UIFigure                        matlab.ui.Figure                % Main application window
        FileMenu                        matlab.ui.container.Menu        % Top-level 'Batch Settings' menu
        LoadEDFFileListMenu             matlab.ui.container.Menu        % Menu item: load EDF path list
        LoadStagingFileListMenu         matlab.ui.container.Menu        % Menu item: load staging path list
        ShowRunLogConsoleMenu           matlab.ui.container.Menu        % Menu item: toggle Run Log Console
        SaveBatchSettingsMenu           matlab.ui.container.Menu        % Menu item: save batch settings as JSON
        LoadBatchSettingsMenu           matlab.ui.container.Menu        % Menu item: load batch settings from JSON
        HelpMenu                        matlab.ui.container.Menu        % Top-level 'Help' menu
        HelpMenuItem                    matlab.ui.container.Menu        % Menu item: open README documentation in browser
        AboutMenu                       matlab.ui.container.Menu        % Menu item: show About dialog

        % --- Top-Level Tab Group ---
        ProjectTabGroup                 matlab.ui.container.TabGroup    % Outer tab group (Setup / Analysis)
        DYNAMOSetupTab                  matlab.ui.container.Tab         % Main setup tab
        ResultsBrowserTab               matlab.ui.container.Tab         % Browse outputs from completed runs
        ResultsBrowserGrid              matlab.ui.container.GridLayout  % Root grid inside ResultsBrowserTab (1x1, scales)
        BrowserContentContainer         matlab.ui.container.GridLayout  % 1x3: [controls | splitter | viewer]
        ResultsSplitter                 matlab.ui.container.Panel       % Vertical drag handle between the two columns
        ResultsSplitterDrag_            = struct('active', false, 'startX', 0, 'startW1', 0, 'totalW', 0, ...
                                                 'origMotion', [], 'origUp', [], 'origPointer', '')
        ResultsRowSplitter              matlab.ui.container.Panel       % Horizontal drag handle between tree and status
        ResultsRowSplitterDrag_         = struct('active', false, 'startY', 0, 'startH1', 0, 'totalH', 0, ...
                                                 'origMotion', [], 'origUp', [], 'origPointer', '')
        ResultsLeftGrid                 matlab.ui.container.GridLayout  % Vertical stack inside the left column
        ResultsBrowserOutputDirLabel    % CSSuiLabel    'Select results directory:'
        ResultsBrowserOutputDirField    % CSSuiEditField  Path to results root
        ResultsBrowserOutputDirButton   % CSSuiButton   Browse for directory
        ResultsBrowserTree              CSSuiTree                       % HTML/JS directory tree (filterable)
        ResultsTreeLoadingOverlay       matlab.ui.control.HTML          % Dancing-bars animation, shown over the tree during load
        PreviewProgressBar_                                             % SmoothProgressBar (CSSuicontrols) — current aggregation bar (single-channel right-click path)
        AggregateProgressBars_  = []                                    % containers.Map from channelName → SmoothProgressBar; populated by createAggregateProgressGrid for top-level Aggregate runs (one bar per channel, stacked vertically). [] when not in a top-level run.
        ResultsBrowserStatusGrid        matlab.ui.container.GridLayout  % Status label + text-area sub-grid
        ResultsBrowserStatusLabel       % CSSuiLabel    'STATUS:' header
        ResultsBrowserTextArea          % CSSuiTextArea Aggregate / load console
        ResultsBrowserHeader            % CSSuiLabel    'RESULTS BROWSER' header
        ResultsBrowserTreeLabel         % CSSuiLabel    'DATASET FILE TREE' header above tree
        ResultsBrowserCache_            % struct        Recursive cache of root contents — walked once at Load, filtered in JS
        AggregateOverwriteMode_ = ''    % '' (ask each), 'all' (overwrite all), 'none' (skip all). Reset at the start of each Aggregate run.
        SOPHPlotBoxAspectRatio_ = [0.335*8.5, 0.3*11, 1]   % [W H 1] — matches displaySummaryPlot's SO-Power/Phase boxes (≈ 2.8475 × 3.3 in). Applied to every SOPH render via pbaspect.
        MatPreviewCache_ = struct('path','', 'S', struct())   % caches the last loaded .mat so generic-browser node clicks don't reload
        RunLogger_       = []                                  % DYNAMORunLogger for the active batch (open during runBatch only)
        EdfLabelCache_   = []                                  % containers.Map: abs_path -> struct('labels', cellstr, 'fs', doubleArr, 'mtime', datetime). Built lazily by refreshEdfLabelCache; survives across composer opens; invalidated incrementally on DataList mutations.

        % --- Right-column tab group (viewers) ---
        AnalysisTab                     matlab.ui.container.Tab         % Outer tab — "Aggregate Data"; attached/detached at runtime
        ResultsBrowserPreviewGrid       matlab.ui.container.GridLayout  % Right column of Results Browser — preview pane
        ResultsBrowserPreviewTitle      % CSSuiLabel  — current file path / placeholder
        ResultsBrowserPreviewBody       matlab.ui.container.Panel       % Container for the lazy viewer (axes / table)
        SOHistogramsGrid                matlab.ui.container.GridLayout  % top selector | bottom plot grid
        SOHistogramsSelectorPanel       matlab.ui.container.GridLayout  % wraps the listbox + label
        SOHistogramsChannelLabel        % CSSuiLabel
        SOHistogramsChannelListBox      % CSSuiListBox                  % multi-select channel picker
        SOHistogramsPlotPanel           matlab.ui.container.Panel        % white uipanel hosting figdesign axes
        SOHistogramsPlaceholderAxes     % uiaxes filling the panel when nothing is selected
        SOHist_ChannelInfo_      = []   % struct array: {name, hasPower, hasPhase, powerPath, phasePath}
        SOHist_SuppressFcn_      = false% reentry guard for listbox value change

        % --- Aggregate-Data inner tab group (Mean SOPH | Mode Scatter) ---
        AggregateViewsTabGroup          matlab.ui.container.TabGroup
        MeanSOPHTab                     matlab.ui.container.Tab
        % Mode Scatter has both power and phase dropdown groups in
        % one tab — pairs (power left, phase right) rendered per
        % channel. Each axis kind has independent X/Y/Size/Color
        % dropdowns since the available numeric columns differ
        % (e.g. PrefPhaseArgmax / CouplingArgmax are power-only;
        % SOphaseMean / SOphaseStd are phase-only).
        ModeScatterTab                  matlab.ui.container.Tab
        ModeScatterDropdownGrid         matlab.ui.container.GridLayout
        ModeScatterPlotPanel            matlab.ui.container.Panel
        ModeScatterPlaceholderAxes
        ModeScatterPowerXDropDown       % CSSuiDropdown
        ModeScatterPowerYDropDown       % CSSuiDropdown
        ModeScatterPowerZDropDown       % CSSuiDropdown — '(none)' = 2-D, anything else flips axis to scatter3
        ModeScatterPowerSizeDropDown    % CSSuiDropdown
        ModeScatterPowerColorDropDown   % CSSuiDropdown
        ModeScatterPhaseXDropDown       % CSSuiDropdown
        ModeScatterPhaseYDropDown       % CSSuiDropdown
        ModeScatterPhaseZDropDown       % CSSuiDropdown — '(none)' = 2-D, anything else flips axis to scatter3
        ModeScatterPhaseSizeDropDown    % CSSuiDropdown
        ModeScatterPhaseColorDropDown   % CSSuiDropdown
        % Free-text colormap names per axis kind (e.g. 'hsv', 'jet',
        % 'gouldian'). Default 'hsv' because the most natural Color
        % column is a phase angle, which wraps. Empty / unrecognized
        % names fall back to parula in redrawModeScatter.
        ModeScatterColormapPowerField   % CSSuiEditField
        ModeScatterColormapPhaseField   % CSSuiEditField
        ModeScatterColormapPower_       = 'hsv'
        ModeScatterColormapPhase_       = 'hsv'
        ModeScatter_TableCache_         % containers.Map keyed "<chan>|<axis>" -> table; cleared on aggregate refresh
        ModeScatter_DropdownsInited_    % struct with .power/.phase booleans — tracks first populated refresh per axis
        ModeScatter_AxState_     = []   % struct .sel (cell), .pairs (cell of [axP axPh]) — set by redrawModeScatter, consumed by updateModeScatterData
        ModeScatter_Links_       = []   % struct with .power / .phase linkprop handles. Must be retained on the app: linkprop returns an object whose lifetime IS the link, so dropping the reference breaks the linkage.

        % --- Subject metadata (lazy-joined into aggregates) ---
        % Metadata file picker lives in two surfaces (Batch Setup +
        % Aggregate Data); both fields write through setMetadataFile,
        % which is the single source of truth. MetadataTable_ is the
        % cached readtable() result with the first column canonicalised
        % to 'ID'; cleared whenever MetadataFile_ changes.
        MetadataFile_                 = ''   % canonical absolute path (char)
        MetadataTable_                = []   % cached table from loadSubjectMetadata
        MetadataFileEditField         % CSSuiEditField (Batch Setup)
        MetadataFileFieldAggregate    % CSSuiEditField (Aggregate Data tab)
        MetadataBrowseButtonBatch     % CSSuiButton
        MetadataBrowseButtonAggregate % CSSuiButton
        MetadataClearButtonBatch      % CSSuiButton
        MetadataClearButtonAggregate  % CSSuiButton

        % --- Group-by panel (drives filtering + stats) ---
        ModeScatterGroupByDropDown      % CSSuiDropdown — column to split subjects on; '(none)' = no grouping
        ModeScatterGroupFilterListBox   % CSSuiListBox (Multiselect=true) — which level values to include

        % --- Group Stats inner tab (multicomp_test hooks) ---
        GroupStatsTab                   matlab.ui.container.Tab
        GroupStatsHintLabel             % CSSuiLabel — "select 2 levels" hint when not ready
        GroupStatsScatterTable          matlab.ui.control.Table  % per-paramfit-column results
        GroupStatsSOPHPanel             matlab.ui.container.Panel  % hosts mean A / mean B / sig overlay axes
        SOHistogramsSplitter            matlab.ui.container.Panel  % Draggable bar between channel listbox and inner tabs
        SOHistogramsSplitter_Drag_      % Saved figure WindowButton callbacks during a splitter drag

        % --- Top-Level Layout Grids ---
        FullDYNAMOSetupGrid             matlab.ui.container.GridLayout  % Root grid inside DYNAMOSetupTab
        HelpButton                      % CSSuiButton                   % Opens README documentation in browser
        BottomGrid                      matlab.ui.container.GridLayout  % Grid containing status, run buttons, time estimate

        % --- Time Estimate & Run Controls ---
        TimeEstimateGrid                matlab.ui.container.GridLayout  % Holds progress bar widget
        RunBatchGrid                    matlab.ui.container.GridLayout  % Grid for run/stop buttons and options
        RunBatchOptionsGrid             matlab.ui.container.GridLayout  % Sub-grid for run checkbox options
        OverwriteExistingFilesCheckBox  % CSSuiSwitch                   % If checked, overwrite existing output files
        RunInReverse                    % CSSuiSwitch                   % If checked, process files in reverse order
        RunBatchButton                  % CSSuiButton                   % Initiates batch processing
        StopBatchButton                 % CSSuiButton                   % Requests graceful stop after current subject

        % --- Status / Log Area ---
        StatusTextGrid                  matlab.ui.container.GridLayout  % Grid for status label and text area
        StatusLabel                     % CSSuiLabel                    % 'Status:' label
        TextArea                        % CSSuiTextArea                 % Displays current processing status messages

        % --- Inner Tab Groups ---
        BatchRunTabGroup                matlab.ui.container.TabGroup    % Tabs: File Selection | DYNAM-O Settings
        FileSelectionTab                matlab.ui.container.Tab         % Tab for file lists and runtime options

        % --- File Selection Layout ---
        FileSelectionGrid               matlab.ui.container.GridLayout  % Two-column grid: file lists | runtime options
        RuntimeOptionsGrid              matlab.ui.container.GridLayout  % Right-column grid: channel, staging, saving options

        % --- Saving Options Tab Group ---
        SavingOptionsTabGroupGrid       matlab.ui.container.GridLayout  % Grid for saving options tab
        SavingOptionsTabGroup           matlab.ui.container.TabGroup    % Tabs: Saving Options | FileFormat
        SavingOptionsTab                matlab.ui.container.Tab         % Basic save checkboxes and output directory
        SavingOptionsTabGrid            matlab.ui.container.GridLayout  % Grid inside saving options tab
        SavingDirectoryGrid             matlab.ui.container.GridLayout  % Grid for output directory row
        OutputDirEditField              % CSSuiEditField                % Displays/edits output directory path
        EditFieldLabel                  % CSSuiLabel                    % Label for output directory edit field
        OutputDirButton                 % CSSuiButton                   % Browse button for output directory
        OutputDirLabel                  % CSSuiLabel                    % Instruction label above directory row

        % --- Save Option Switches ---
        SavingOptionsCheckBoxGrid       matlab.ui.container.GridLayout  % Grid holding save option switches
        SaveSplineImagesCheckBox        % CSSuiSwitch                   % Save spline basis figures
        SaveParamImagesCheckBox         % CSSuiSwitch                   % Save parametric basis figures
        SaveDataSummaryCheckBox         % CSSuiSwitch                   % Save data summary figures
        SaveAuxDataCheckBox             % CSSuiSwitch                   % Save auxiliary data (.mat)
        SaveLogsSwitch                  % CSSuiSwitch                   % Toggle saving of run/settings log files
        SaveSplineBasisCheckBox         % CSSuiSwitch                   % Save spline basis data
        SaveParamBasisCheckBox          % CSSuiSwitch                   % Save parametric basis data
        SaveSOPHsCheckBox               % CSSuiSwitch                   % Save SO-Power Histograms
        SavePeakStatsCheckBox           % CSSuiSwitch                   % Save TF-peak stats table
        FigurestoSaveLabel              % CSSuiLabel                    % Column header: 'Figures to Save'
        DatatoSaveLabel                 % CSSuiLabel                    % Column header: 'Data to Save'

        % --- FileFormat Saving Tab ---
        FileFormatTab                   matlab.ui.container.Tab         % FileFormat file format options tab
        FileFormatCheckBoxGrid          matlab.ui.container.GridLayout  % Grid for format dropdowns

        % --- File Format Dropdowns (FileFormat) ---
        SplineFiguresDropDown           % CSSuiDropdown                 % File format for spline figures
        ParametricFiguresDropDown       % CSSuiDropdown                 % File format for parametric figures
        DataSummaryDropDown             % CSSuiDropdown                 % File format for data summary figures
        AuxiliaryDataDropDown           % CSSuiDropdown                 % File format for auxiliary data
        SplineBasisDropDown             % CSSuiDropdown                 % File format for spline basis data
        ParametricBasisDropDown         % CSSuiDropdown                 % File format for parametric basis data
        SOPowerHistogramsDropDown       % CSSuiDropdown                 % File format for SO-Power Histograms
        PeakStatsTableDropDown          % CSSuiDropdown                 % File format for peak stats tables
        FigureFileFormatLabel           % CSSuiLabel                    % Column header: 'Figure File Format'
        DataFileFormatLabel             % CSSuiLabel                    % Column header: 'Data File Format'

        % --- Staging Options Panel ---
        StagingOptionsPanelGrid         matlab.ui.container.GridLayout  % Two-column panel grid
        DelimeterOptionField            % CSSuiDropdown                 % Delimiter used in staging file
        HeaderRowsEditField             % CSSuiNumericField             % Number of header rows to skip
        HeaderRowsEditFieldLabel        % CSSuiLabel
        TimesColumnEditField            % CSSuiNumericField             % Column index for epoch times
        TimesColumnEditFieldLabel       % CSSuiLabel
        StagesColumnEditField           % CSSuiNumericField             % Column index for stage labels
        StagesColumnEditFieldLabel      % CSSuiLabel
        ResampleSwitch                  % CSSuiSwitch                   % Toggle resampling on/off
        ResampleFsEditField             % CSSuiNumericField             % Target sampling frequency for resampling
        ResampleFsEditFieldLabel        % CSSuiLabel

        % --- Stage Label Inputs (Left Panel) ---
        UnknownEditField                % CSSuiEditField                % Identifiers for 'Unknown' stage
        UnknownEditFieldLabel           % CSSuiLabel
        N3EditField                     % CSSuiEditField                % Identifiers for 'N3' stage
        N3EditFieldLabel                % CSSuiLabel
        N2EditField                     % CSSuiEditField                % Identifiers for 'N2' stage
        N2EditFieldLabel                % CSSuiLabel
        N1EditField                     % CSSuiEditField                % Identifiers for 'N1' stage
        N1EditFieldLabel                % CSSuiLabel
        REMEditField                    % CSSuiEditField                % Identifiers for 'REM' stage
        REMEditFieldLabel               % CSSuiLabel
        WakeEditField                   % CSSuiEditField                % Identifiers for 'Wake' stage
        WakeEditFieldLabel              % CSSuiLabel
        ArtifactEditField               % CSSuiEditField                % Identifiers for 'Artifact' stage
        ArtifactEditFieldLabel          % CSSuiLabel

        % --- Channel / Runtime Options ---
        RuntimeOptionsLabel             % CSSuiLabel                    % Section label: 'Runtime Options'
        ChannelInputGrid                matlab.ui.container.GridLayout  % Grid for channel label + field + info button
        ChannelEditField                % CSSuiEditField                % Comma-separated channel names to process
        ChannelEditFieldLabel           % CSSuiLabel
        ViewChannelsButton              % CSSuiButton                   % Opens dialog listing all EDF channels
        ReferenceLabel                  % CSSuiLabel                    % "References" label
        ReferenceEditField              % CSSuiEditField                % Comma-separated NAME = expr reference list

        % --- File List Panels ---
        FileInputGrid                   matlab.ui.container.GridLayout  % Grid for both file list columns
        StagingLabel                    % CSSuiLabel                    % Displays 'Staging (N Files)'
        StagingFileInstructionText      % CSSuiLabel                    % Instruction text for staging files
        DataLabel                       % CSSuiLabel                    % Displays 'Data (N Files)'
        DataFileInstructionText         % CSSuiLabel                    % Instruction text for data files
        StagingListBox                  % CSSuiListBox                  % Scrollable list of staging file paths
        DataListBox                     % CSSuiListBox                  % Scrollable list of EDF file paths

        % --- File List Action Buttons ---
        StagingFileButtonGrid           matlab.ui.container.GridLayout  % Grid for staging list action buttons
        StagingMoveDownButton           % CSSuiButton                   % Move selected staging item down
        StagingMoveUpButton             % CSSuiButton                   % Move selected staging item up
        StagingRemoveButton             % CSSuiButton                   % Remove selected staging file
        StagingAddListButton            % CSSuiButton                   % Add staging files from a path-list file
        StagingAddFolderButton          % CSSuiButton                   % Add all staging files from a folder
        StagingAddFileButton            % CSSuiButton                   % Add individual staging file(s)
        DataFileButtonGrid              matlab.ui.container.GridLayout  % Grid for data list action buttons
        DataMoveDownButton              % CSSuiButton                   % Move selected data item down
        DataMoveUpButton                % CSSuiButton                   % Move selected data item up
        DataRemoveButton                % CSSuiButton                   % Remove selected data file
        DataAddListButton               % CSSuiButton                   % Add EDF files from a path-list file
        DataAddFolderButton             % CSSuiButton                   % Add all EDF files from a folder
        DataAddFileButton               % CSSuiButton                   % Add individual EDF file(s)

        % --- DYNAM-O Settings & Analysis Tabs ---
        DYNAMOSettingsTab               matlab.ui.container.Tab         % Tab hosting DYNAMOOptions sub-app
        DYNAMOSettingsGrid              matlab.ui.container.GridLayout  % Grid inside DYNAMOSettings tab

        % -------------------------
        %   Callback Handles
        % -------------------------
        BatchProcessCallback            function_handle                 % Called when batch run begins; receives file lists + options
        FileValidationCallback          function_handle                 % Called per file; returns true if file is valid

        % -------------------------
        %   File Storage
        % -------------------------
        DataList                        cell = {}                       % Cell array of full EDF file paths (in processing order)
        StagingList                     cell = {}                       % Cell array of full staging file paths (in processing order)

        % -------------------------
        %   Output File Name Stems
        % -------------------------
        input_fbase             = ''   % Base filename (no extension) of the current EDF being processed
        output_fig_name         = ''   % Full path for summary figure output
        output_stats_name       = ''   % Full path for peak stats table output
        output_SOPH_name        = ''   % Full path for SO-Power Histogram output
        output_aux_name         = ''   % Full path for auxiliary data output
        output_paramfit_power_name = '' % Full path for parametric fit (power) output
        output_paramfit_phase_name = '' % Full path for parametric fit (phase) output
        output_splinefit_power_name = '' % Full path for spline fit (power) output
        output_splinefit_phase_name = '' % Full path for spline fit (phase) output
        output_param_name       = ''   % Full path for parametric basis figure output
        output_spline_name      = ''   % Full path for spline basis figure output

        % -------------------------
        %   EDF Header Viewer
        % -------------------------
        header_fig       % Handle to the floating EDF header viewer figure
        uitable_header   % Table UI component showing file-level header fields
        uitable_signal   % Table UI component showing per-signal header fields

        % -------------------------
        %   User Inputs (Parsed)
        % -------------------------
        channel           % Currently active channel name (string)
        ChannelList       % Cell array of channel names parsed from ChannelEditField
        ReferenceList     % Cell array of 'NAME = expr' strings forwarded to read_EDF as 'References'
        delimeter         % Delimiter character used when reading staging files (e.g. ',' '\t')

        % Sleep stage identifier lists (cell arrays of strings from edit fields)
        ArtifactUserInput
        N1UserInput
        N2UserInput
        N3UserInput
        REMUserInput
        WakeUserInput
        UnknownUserInput

        % -------------------------
        %   Options / Struct Storage
        % -------------------------
        options_structs   % Cell array of DYNAMO option structs for the current run
        struct_names      % Cell array of names corresponding to options_structs entries
        auxiliary_data    % Struct holding auxiliary analysis outputs (artifacts, Fs, etc.)

        % -------------------------
        %   Batch Run State
        % -------------------------
        run_error_list          = {}    % Accumulated pre-run validation error messages
        isStopBatchButtonPushed = false % Flag set true when user clicks Stop; halts after current subject
        use_no_stages  logical  = false % Flag set true when user confirms running with no stage files
        anything_run                    % Flag indicating at least one analysis was executed this iteration
        partial_failures        = {}    % Per-iteration list of sub-step failures that didn't fail the whole stage (e.g. only one of power/phase fit failed)
        curr_datetime                   % Timestamp string for the current run (format: yyMMdd_HHmmSS)
        curr_iteration                  % Counter for total channel-subject iterations completed

        % -------------------------
        %   Output Log Handles
        % -------------------------
        runlog_fname      % Filename of the per-run file log (file_log_*.txt)
        runlog_fpath      % Directory path where run log is saved
        runlog_fid        % File identifier (fopen) for the run log
        consolelog_fname  % Filename of the console/diary log (console_log_*.txt)
        consolelog_fpath  % Directory path where console log is saved
        consolelog_fid    % File identifier (fopen) for the console log

        % -------------------------
        %   Run Log Console
        % -------------------------
        LogConsoleFig         % Handle to the floating Run Log Console window
        LogConsoleTextArea    % CSSuiTextArea inside the Run Log Console window
        LogConsoleTimer       % Timer that polls the consolelog file for live updates

        % -------------------------
        %   Child windows for cleanup
        % -------------------------
        ChildWindows = {}     % cell of uifigure handles spawned by the app
                              % (composer dialog, header viewer, etc.) —
                              % torn down on main-figure close.

        % -------------------------
        %   Miscellaneous UI
        % -------------------------
        ProgressBar   % SmoothProgressBar handle displayed in TimeEstimateGrid

        % -------------------------
        %   UI Dimension Constants
        % -------------------------
        WindowWidth             = 1600   % Default figure width in pixels
        WindowHeight            = 1000   % Default figure height in pixels

        % -------------------------
        %   Global Typography
        % -------------------------
        FontName       = 'Helvetica Nue'  % Font applied to every labelled UI control.
        % FontSizeSmall  = 11   % Supplementary / caption font size (px)
        % FontSizeBase   = 13   % Body / instruction text font size (px)
        FontSizeTitle  = 15   % Section-header and list-title font size (px)

    end

    % ======================================================================
    %   PUBLIC METHODS
    % ======================================================================

    methods (Access = public)

        function app = DYNAMOApp(varargin)
            % DYNAMOApp  Constructor – parses arguments and builds the GUI.
            %
            %   Supported Name-Value pairs:
            %     'BatchCallback'      – function_handle invoked at batch start
            %     'ValidationCallback' – function_handle(filepath) -> logical
            %     'Title'              – char window title (default: 'DYNAM-O Toolbox')
            %     'Position'           – [x y w h] figure position vector
            %
            %   Quick-fill (skip re-entering test data each launch):
            %     'EDFPath'            – folder; every *.edf, *.edf.gz, and
            %                            *.edf.zst inside is added to the
            %                            data list (alphabetical order)
            %     'StagingPath'        – folder; every *.csv inside is added
            %                            to the staging list (alphabetical)
            %     'OutputPath'         – sets the output directory field
            %     'Channels'           – channel label(s) to populate the
            %                            Channel(s) field. Accepts a char
            %                            ('C3-A2'), a comma-separated char
            %                            ('C3-A2, O2-A1'), a string scalar,
            %                            a string array, or a cell array of
            %                            char. Multiple entries are joined
            %                            with ', '.
            %     'Delimiter'          – staging-file delimiter; accepts the
            %                            dropdown labels ('Comma','Tab',
            %                            'Space','Semicolon') or the literal
            %                            characters (',', '\t', ' ', ';')
            %     'StagesColumn'       – column index for stage labels
            %     'TimesColumn'        – column index for epoch times
            %     'HeaderRows'         – number of header rows to skip

            p = inputParser;
            addParameter(p,'BatchCallback',[],@(x) isempty(x)||isa(x,'function_handle'));
            addParameter(p,'ValidationCallback',[],@(x) isempty(x)||isa(x,'function_handle'));
            addParameter(p,'Title','DYNAM-O Toolbox',@ischar);
            addParameter(p,'Position',[],@isnumeric);
            addParameter(p,'EDFPath','',@(x) ischar(x)||isstring(x));
            addParameter(p,'StagingPath','',@(x) ischar(x)||isstring(x));
            addParameter(p,'OutputPath','',@(x) ischar(x)||isstring(x));
            addParameter(p,'Channels','',@(x) ischar(x)||isstring(x)||iscellstr(x)); %#ok<ISCLSTR>
            addParameter(p,'Delimiter','',@(x) ischar(x)||isstring(x));
            addParameter(p,'StagesColumn',[],@(x) isempty(x)||(isnumeric(x)&&isscalar(x)));
            addParameter(p,'TimesColumn',[],@(x) isempty(x)||(isnumeric(x)&&isscalar(x)));
            addParameter(p,'HeaderRows',[],@(x) isempty(x)||(isnumeric(x)&&isscalar(x)));
            parse(p,varargin{:});

            % Store optional callbacks if provided
            if ~isempty(p.Results.BatchCallback)
                app.BatchProcessCallback = p.Results.BatchCallback;
            end
            if ~isempty(p.Results.ValidationCallback)
                app.FileValidationCallback = p.Results.ValidationCallback;
            end
            % NOTE: do NOT spin up a parallel pool here. Parpool startup
            % adds 5-15 s to GUI launch and is wasted on the rust backend
            % (rayon inside MEX, no MATLAB pool needed). runDYNAMO starts
            % the pool itself only when backend='matlab' is chosen, via
            % setup_parallel_pool(detection_options.parallel_mode) — see
            % runDYNAMO.m:270-272. Keeping this constructor pool-free
            % means the DYNAMOApp opens instantly and rust runs never
            % touch parpool at all.

            sc = get(0, 'ScreenSize');
            app.WindowWidth             = min(app.WindowWidth, sc(3));   % Default figure width in pixels
            app.WindowHeight            = min(app.WindowHeight, sc(4));

            % Single shared style for every CSSui* widget. Built once here
            % so each createXxxTab method can reference app.AppStyle in
            % place of a literal preset name.
            app.AppStyle = dynamoStyle();

            % Default empty references list — populated by the channel
            % composer dialog or programmatic callers.
            app.ReferenceList = {};

            % Splash screen: pop the logo + version + lab credit while the
            % rest of construction runs. Minimum 2s visible lifetime
            % enforced in closeSplashScreen() below.
            splashFig = app.showSplashScreen();

            % Build all UI components
            createComponents(app, p.Results.Title, p.Results.Position);
            app.enforceMinSize;

            % Apply quick-fill inputs (each independent; skip if not given).
            applyQuickFill(app, p.Results);

            % Reveal the window only after everything is built and any
            % constructor-time auto-population is done. The drawnow flushes
            % pending layout/HTML so the first paint is the finished UI,
            % not a half-drawn skeleton being filled in.
            drawnow;
            app.UIFigure.Visible = 'on';

            % Close the splash once the main window is visible (with a
            % 2s minimum-lifetime guard so it doesn't flash by on a fast
            % build).
            app.closeSplashScreen(splashFig);
        end
        % ------------------------------------------------------------------

        function setEnabled(app, enabled)
            % setEnabled  Show or hide the application window.
            %
            %   setEnabled(app, enabled)
            %
            %   Input:
            %     enabled – logical scalar; true = visible, false = hidden

            app.UIFigure.Visible = matlab.lang.OnOffSwitchState(enabled);
        end

        function delete(app)
            % delete  Class destructor. Triggered by `delete(app)` in
            % uiFigureCloseRequest. Without an explicit destructor,
            % `delete(app)` only marks the AppBase invalid but never
            % closes the UIFigure, so clicking the window's X button
            % has no visible effect. Must be public to match AppBase's
            % superclass `delete` access.
            try
                if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                    delete(app.UIFigure);
                end
            catch
            end
        end

    end % public methods

    % ======================================================================
    %   PRIVATE METHODS
    % ======================================================================

    methods (Access = private)

        % ==================================================================
        %   COMPONENT CREATION
        % ==================================================================

        function createComponents(app, ~, ~)
            % createComponents  Build and lay out all UI components.
            %
            %   Thin dispatcher that delegates each section of the layout to
            %   its own external method file. Order matters:
            %     1. createUIFigureAndShell  — figure, File menu, outer tabs
            %     2. createBatchSetupTab     — File Selection + Runtime Options
            %     3. createBottomBar         — status, RUN/STOP, Help, progress
            %     4. createDYNAMOSettingsTab — embed the options sub-app
            %     5. createResultsBrowserTab — tree + preview pane
            %     6. createAnalysisTab       — SO-Histograms host
            %     7. finalizeUI              — Help menu (rightmost), font, tooltips
            %
            %   Each builder method lives next to this file under @DYNAMOApp/.
            app.createUIFigureAndShell();
            app.createBatchSetupTab();
            app.createBottomBar();
            app.createDYNAMOSettingsTab();
            app.createResultsBrowserTab();
            app.createAnalysisTab();
            % Aggregate Data tab is hidden until either a tree-load
            % discovers an existing aggregates/ folder or the user runs
            % the aggregator. Detaching from the tab group is reversible
            % — children stay parented to the tab itself, so re-attach
            % via updateAggregateDataTabVisibility() restores the full
            % SO-Histograms UI without rebuilding it.
            app.AnalysisTab.Parent = [];
            app.finalizeUI();
        end % createComponents
        % ==================================================================
        %   BUTTON CALLBACKS
        % ==================================================================

        function openReadmeInBrowser(app)
            % showHelpButtonPushed  Open the DYNAM-O App README in the system web browser.
            %
            %   If an internet connection is available, opens the GitHub README.
            %   Otherwise, falls back to a local HTML help file.

            githubURL = 'https://github.com/preraulab/DYNAM-O_dev/blob/master/DYNAMOApp_README.md';

            % Check for internet connectivity
            hasInternet = false;
            try
                java.net.URL('https://github.com').openConnection().connect();
                hasInternet = true;
            catch
            end

            if hasInternet
                web(githubURL, '-browser');
            else
                % Fall back to local HTML help file
                helpPath = fullfile(fileparts(mfilename('fullpath')), 'DYNAMOApp_README.html');
                if ~isfile(helpPath)
                    uialert(app.UIFigure, ...
                        sprintf('Help file not found:\n%s', helpPath), ...
                        'Help', 'Icon', 'warning');
                    return
                end
                if ispc
                    fileURI = ['file:///' strrep(helpPath, '\', '/')];
                else
                    fileURI = ['file://' helpPath];
                end
                fileURI = strrep(fileURI, ' ', '%20');
                web(fileURI, '-browser');
            end
        end
        function showHelpButtonPushed(app)
            % showHelpButtonPushed  Thin callback shim — see openReadmeInBrowser.
            app.openReadmeInBrowser();
        end


        % ------------------------------------------------------------------

        function loadDataFileListFromFile(app)
            % Prompt user for list file
            [filename, filepath] = uigetfile( ...
                {'*.txt;*.csv;*.tsv;*.dat;*.lst', ...
                'Text Files (*.txt, *.csv, *.tsv, *.dat, *.lst)'; ...
                '*.*', 'All Files (*.*)'}, ...
                'Select EDF File Path/Name List');

            if isequal(filename,0)
                return; % User cancelled
            end

            % Full path
            fullFile = fullfile(filepath, filename);

            % Read + clean
            lines = splitlines(fileread(fullFile));
            lines = strtrim(lines);
            lines = lines(lines ~= ""); % remove blank lines

            % Validate files
            validMask = isfile(lines);
            validLines = lines(validMask);
            invalidLines = lines(~validMask);

            % Remove duplicates from valid lines
            [uniqueValidLines, ia] = unique(validLines, 'stable');
            duplicateLines = validLines(setdiff(1:numel(validLines), ia));

            % Store only valid, unique files. Force a row cellstr —
            % `cellstr(<column string array>)` returns a column cellstr,
            % which then breaks horz-concat in addDataFiles
            % (`[app.DataList, filePaths]`) on the next "Add File" click.
            app.DataList = reshape(cellstr(uniqueValidLines), 1, []);
            app.updateDataListBox;
            app.refreshEdfLabelCache();

            % Only show dedicated window if there are skipped or duplicate files
            if isempty(invalidLines) && isempty(duplicateLines)
                return
            end

            % --- Create the dedicated window ---
            win = uifigure('Name','File List Issues','Position',[200 200 800 400]);
            app.trackChildWindow(win);

            % Skipped files listbox
            lblSkipped = CSSuiLabel(win,'Text','Skipped (missing) files:','Position',[20 360 200 20]); %#ok<*NASGU>
            listSkipped = CSSuiListBox(win,'Items',cellstr(invalidLines),'Position',[20 180 360 180],'Multiselect',false,'Style', app.AppStyle); %#ok<NASGU>

            % Duplicate files listbox
            lblDup = CSSuiLabel(win,'Text','Duplicate files removed:','Position',[400 360 200 20]);
            listDup = CSSuiListBox(win,'Items',cellstr(duplicateLines),'Position',[400 180 360 180],'Multiselect',false,'Style', app.AppStyle); %#ok<NASGU>

            % Button to save logfile
            btnSave = CSSuiButton(win,'Text','Save Logfile','Position',[350 50 100 30], ...
                'ButtonPushedFcn', @(btn,event) saveFileLog(invalidLines,duplicateLines));

            % Nested function to save logfile
            function saveFileLog(skipped, duplicates)
                % Default folder: ./logs if exists, else current folder
                defaultFolder = './logs';
                if ~isfolder(defaultFolder)
                    defaultFolder = pwd;
                end
                defaultFileName = fullfile(defaultFolder,'data_list_error.log');

                [file,path] = uiputfile('*.log','Save File Log As',defaultFileName);
                if isequal(file,0)
                    return % user cancelled
                end

                logFullPath = fullfile(path,file);

                fid = fopen(logFullPath,'w');
                if fid == -1
                    uialert(win,sprintf('Cannot write to file: %s',logFullPath),'File Error','Icon','error');
                    return
                end

                fprintf(fid,'Skipped (missing) files:\n');
                if isempty(skipped)
                    fprintf(fid,'None\n');
                else
                    fprintf(fid,'%s\n',skipped{:});
                end

                fprintf(fid,'\nDuplicate files removed:\n');
                if isempty(duplicates)
                    fprintf(fid,'None\n');
                else
                    fprintf(fid,'%s\n',duplicates{:});
                end

                fclose(fid);

                uialert(win,sprintf('Logfile saved to:\n%s',logFullPath),'Log Saved','Icon','info');
            end
        end
        function loadDataFileListCallback(app, ~)
            % loadDataFileListCallback  Thin callback shim — see loadDataFileListFromFile.
            app.loadDataFileListFromFile();
        end


        % ------------------------------------------------------------------

        function loadStagingListFromFile(app)
            % loadStagingListCallback  Load a list of staging file paths
            % from a text/CSV file the user picks. Each line becomes one
            % entry in the staging list. Mirrors loadDataFileListCallback;
            % see that for the file-format conventions and dedupe logic.

            [filename, filepath] = uigetfile( ...
                {'*.txt;*.csv;*.tsv;*.dat;*.lst', ...
                'Text Files (*.txt, *.csv, *.tsv, *.dat, *.lst)'; ...
                '*.*', 'All Files (*.*)'}, ...
                'Select EDF File Path/Name List');

            if isequal(filename,0)
                return; % User cancelled
            end

            % Full path
            fullFile = fullfile(filepath, filename);

            % Read + clean
            lines = splitlines(fileread(fullFile));
            lines = strtrim(lines);
            lines = lines(lines ~= ""); % remove blank lines

            % Validate files
            validMask = isfile(lines);
            validLines = lines(validMask);
            invalidLines = lines(~validMask);

            % Remove duplicates from valid lines
            [uniqueValidLines, ia] = unique(validLines, 'stable');
            duplicateLines = validLines(setdiff(1:numel(validLines), ia));

            % Store only valid, unique files. Force a row cellstr —
            % `cellstr(<column string array>)` returns a column cellstr,
            % which then breaks horz-concat in subsequent
            % "Add Staging Files / Folder" callbacks
            % (`[app.StagingList, filePaths]`). Mirrors the DataList
            % fix in loadDataFileListFromFile.
            app.StagingList = reshape(cellstr(uniqueValidLines), 1, []);
            app.updateStagingListBox;

            % Only show dedicated window if there are skipped or duplicate files
            if isempty(invalidLines) && isempty(duplicateLines)
                return
            end

            % --- Create the dedicated window ---
            win = uifigure('Name','File List Issues','Position',[200 200 800 400]);
            app.trackChildWindow(win);

            % Skipped files listbox
            lblSkipped = CSSuiLabel(win,'Text','Skipped (missing) files:','Position',[20 360 200 20]);
            listSkipped = CSSuiListBox(win,'Items',cellstr(invalidLines),'Position',[20 180 360 180],'Multiselect',false,'Style', app.AppStyle); %#ok<NASGU>

            % Duplicate files listbox
            lblDup = CSSuiLabel(win,'Text','Duplicate files removed:','Position',[400 360 200 20]);
            listDup = CSSuiListBox(win,'Items',cellstr(duplicateLines),'Position',[400 180 360 180],'Multiselect',false,'Style', app.AppStyle); %#ok<NASGU>

            % Button to save logfile
            btnSave = CSSuiButton(win,'Text','Save Logfile','Position',[350 50 100 30], ...
                'ButtonPushedFcn', @(btn,event) saveFileLog(invalidLines,duplicateLines));

            % Nested function to save logfile
            function saveFileLog(skipped, duplicates)
                % Default folder: ./logs if exists, else current folder
                defaultFolder = './logs';
                if ~isfolder(defaultFolder)
                    defaultFolder = pwd;
                end
                defaultFileName = fullfile(defaultFolder,'staging_list_error.log');

                [file,path] = uiputfile('*.log','Save File Log As',defaultFileName);
                if isequal(file,0)
                    return % user cancelled
                end

                logFullPath = fullfile(path,file);

                fid = fopen(logFullPath,'w');
                if fid == -1
                    uialert(win,sprintf('Cannot write to file: %s',logFullPath),'File Error','Icon','error');
                    return
                end

                fprintf(fid,'Skipped (missing) files:\n');
                if isempty(skipped)
                    fprintf(fid,'None\n');
                else
                    fprintf(fid,'%s\n',skipped{:});
                end

                fprintf(fid,'\nDuplicate files removed:\n');
                if isempty(duplicates)
                    fprintf(fid,'None\n');
                else
                    fprintf(fid,'%s\n',duplicates{:});
                end

                fclose(fid);

                uialert(win,sprintf('Logfile saved to:\n%s',logFullPath),'Log Saved','Icon','info');
            end

        end
        function loadStagingListCallback(app, varargin)
            % loadStagingListCallback  Thin callback shim — see loadStagingListFromFile.
            app.loadStagingListFromFile();
        end

        function saveBatchSettingsCallback(app, varargin)
            % saveBatchSettingsCallback  Thin callback shim — see saveBatchSettingsToFile.
            app.saveBatchSettingsToFile();
        end

        function loadBatchSettingsCallback(app, varargin)
            % loadBatchSettingsCallback  Thin callback shim — see loadBatchSettingsFromFile.
            app.loadBatchSettingsFromFile();
        end


        % ------------------------------------------------------------------

        function addDataFilesViaDialog(app)
            % DataAddFileButtonPushed  Open file picker to add one or more EDF files.

            files = pickFilesViaDialog(app, 'Select Data Files', 'data');
            files = setdiff(files, app.DataList, 'stable');
            if ~isempty(files)
                app.DataList = [app.DataList, files];
                updateDataListBox(app);
                app.refreshEdfLabelCache();
            end
        end
        function DataAddFileButtonPushed(app, ~, ~)
            % DataAddFileButtonPushed  Thin callback shim — see addDataFilesViaDialog.
            app.addDataFilesViaDialog();
        end


        % ------------------------------------------------------------------

        function addDataFolderViaDialog(app)
            % DataAddFolderButtonPushed  Add all *.edf, *.edf.gz, *.edf.zst files in a chosen folder.

            folder = uigetdir(pwd, 'Select Data Folder');
            if folder == 0, return; end  % User cancelled

            S     = [dir(fullfile(folder, '*.edf')); ...
                     dir(fullfile(folder, '*.edf.gz')); ...
                     dir(fullfile(folder, '*.edf.zst'))];
            files = fullfile({S.folder}, {S.name});
            files = setdiff(files, app.DataList, 'stable');
            if ~isempty(files)
                app.DataList = [app.DataList, files];
                updateDataListBox(app);
                app.refreshEdfLabelCache();
            end
        end
        function DataAddFolderButtonPushed(app, ~, ~)
            % DataAddFolderButtonPushed  Thin callback shim — see addDataFolderViaDialog.
            app.addDataFolderViaDialog();
        end


        % ------------------------------------------------------------------

        function removeSelectedDataFiles(app)
            % DataRemoveButtonPushed  Remove currently selected EDF files from the list.

            selected = app.DataListBox.Value;
            if isempty(selected), return; end
            app.DataList = setdiff(app.DataList, selected, 'stable');
            updateDataListBox(app);
            app.refreshEdfLabelCache();
        end
        function DataRemoveButtonPushed(app, ~, ~)
            % DataRemoveButtonPushed  Thin callback shim — see removeSelectedDataFiles.
            app.removeSelectedDataFiles();
        end


        % ------------------------------------------------------------------

        function DataMoveUpButtonPushed(app, ~, ~)
            % DataMoveUpButtonPushed  Move selected EDF file(s) one position up in the list.

            moveListItems(app, 'data', 'up');
        end

        % ------------------------------------------------------------------

        function DataMoveDownButtonPushed(app, ~, ~)
            % DataMoveDownButtonPushed  Move selected EDF file(s) one position down in the list.

            moveListItems(app, 'data', 'down');
        end

        % ------------------------------------------------------------------

        function addStagingFilesViaDialog(app)
            % StagingAddFileButtonPushed  Open file picker to add one or more staging files.

            files = pickFilesViaDialog(app, 'Select Staging Files', 'staging');
            files = setdiff(files, app.StagingList, 'stable');
            if ~isempty(files)
                app.StagingList = [app.StagingList, files];
                updateStagingListBox(app);
            end
        end
        function StagingAddFileButtonPushed(app, ~, ~)
            % StagingAddFileButtonPushed  Thin callback shim — see addStagingFilesViaDialog.
            app.addStagingFilesViaDialog();
        end


        % ------------------------------------------------------------------

        function addStagingFolderViaDialog(app)
            % StagingAddFolderButtonPushed  Add all *.csv (or *.txt) files from a chosen folder.
            %
            %   Prefers *.csv; falls back to *.txt if no CSV files are found.

            folder = uigetdir(pwd, 'Select Staging Folder');
            if folder == 0, return; end  % User cancelled

            S = dir(fullfile(folder, '*.csv'));
            if isempty(S)
                S = dir(fullfile(folder, '*.txt'));  % Fallback to .txt
            end
            files = fullfile({S.folder}, {S.name});
            files = setdiff(files, app.StagingList, 'stable');
            if ~isempty(files)
                app.StagingList = [app.StagingList, files];
                updateStagingListBox(app);
            end
        end
        function StagingAddFolderButtonPushed(app, ~, ~)
            % StagingAddFolderButtonPushed  Thin callback shim — see addStagingFolderViaDialog.
            app.addStagingFolderViaDialog();
        end


        % ------------------------------------------------------------------

        function removeSelectedStagingFiles(app)
            % StagingRemoveButtonPushed  Remove currently selected staging files from the list.

            selected = app.StagingListBox.Value;
            if isempty(selected), return; end
            app.StagingList = setdiff(app.StagingList, selected, 'stable');
            updateStagingListBox(app);
        end
        function StagingRemoveButtonPushed(app, ~, ~)
            % StagingRemoveButtonPushed  Thin callback shim — see removeSelectedStagingFiles.
            app.removeSelectedStagingFiles();
        end


        % ------------------------------------------------------------------

        function StagingMoveUpButtonPushed(app, ~, ~)
            % StagingMoveUpButtonPushed  Move selected staging file(s) one position up.

            moveListItems(app, 'staging', 'up');
        end

        % ------------------------------------------------------------------

        function StagingMoveDownButtonPushed(app, ~, ~)
            % StagingMoveDownButtonPushed  Move selected staging file(s) one position down.

            moveListItems(app, 'staging', 'down');
        end

        % ------------------------------------------------------------------

        function viewChannelsButtonPushed(app, ~, ~)
            % viewChannelsButtonPushed  Thin callback shim — the
            %   actual dialog construction lives in
            %   createRunMontageWindow so the high-level entry point
            %   matches the project's createXXTab / createXXWindow
            %   naming convention rather than tracking the GUI
            %   control that fires it.
            app.createRunMontageWindow();
        end
        % ==================================================================
        %   FILE SELECTION HELPERS
        % ==================================================================
        % ==================================================================
        %   LIST-BOX UPDATE METHODS
        % ==================================================================
        % ==================================================================
        %   OUTPUT DIRECTORY MANAGEMENT
        % ==================================================================
        % ------------------------------------------------------------------
        % .mat preview — smart-cases the known DYNAM-O shapes, falls
        % back to a generic variable browser for anything unrecognized.
        % ------------------------------------------------------------------
        % Generic .mat fallback — variable tree on the left, type-aware
        % renderer on the right. Caches the loaded struct so node clicks
        % don't re-read the file.
        % ------------------------------------------------------------------
        % Mode Scatter — paramfit-aggregate scatter view
        % ==================================================================
        %   LOGGING
        % ==================================================================
        % ------------------------------------------------------------------

        function trackChildWindow(app, fig)
            % trackChildWindow  Register a uifigure spawned by the app
            % so it gets closed alongside the main window. Drops dead
            % handles on each call to keep the list bounded.
            alive = cellfun(@(h) ~isempty(h) && isvalid(h), app.ChildWindows);
            app.ChildWindows = app.ChildWindows(alive);
            app.ChildWindows{end+1} = fig;
        end

        function uiFigureCloseRequest(app)
            % uiFigureCloseRequest  Tear down all child resources before
            % the main figure goes away. Without this, the composer
            % dialog, Run Log Console + LogConsoleTimer, header viewer,
            % open log file descriptors, and any in-flight RunLogger
            % keep running with callbacks bound to a soon-to-be-deleted
            % app instance — leaking processes and producing confusing
            % errors on the next session.
            try, app.stopLogConsoleTimer(); catch, end
            for ii = 1:numel(app.ChildWindows)
                try
                    h = app.ChildWindows{ii};
                    if ~isempty(h) && isvalid(h), delete(h); end
                catch
                end
            end
            app.ChildWindows = {};
            try
                if ~isempty(app.LogConsoleFig) && isvalid(app.LogConsoleFig)
                    delete(app.LogConsoleFig);
                end
            catch, end
            try, if ~isempty(app.consolelog_fid) && app.consolelog_fid > 0, fclose(app.consolelog_fid); end, catch, end
            try, diary off; catch, end
            try, if ~isempty(app.runlog_fid) && app.runlog_fid > 0, fclose(app.runlog_fid); end, catch, end
            try, if ~isempty(app.RunLogger_), app.RunLogger_.close(); app.RunLogger_ = []; end, catch, end
            delete(app);
        end
        % ==================================================================
        %   PROCESS USER INPUTS
        % ==================================================================
        % ==================================================================
        %   ANALYSIS RUNNERS
        %   Each function handles one class of output for the current
        %   subject (app.input_fbase) and channel (app.channel).
        % ==================================================================
        % ==================================================================
        %   BATCH RUN
        % ==================================================================

        function startBatchRun(app)
            % RunBatchButtonPushed  Validate inputs and launch the batch processing loop.
            %
            %   Performs the following sequence:
            %     1. Resets the stop-flag from any previous run.
            %     2. Runs updateRunErrorList; shows success or error alert.
            %     3. Optionally reverses the file lists (RunInReverse checkbox).
            %     4. Invokes BatchProcessCallback if one is registered.
            %     5. Delegates to runBatch for the main processing loop.

            % Reset stop flag in case a previous run was halted
            app.isStopBatchButtonPushed = false;

            % Validate inputs and populate run_error_list
            updateRunErrorList(app)

            if isempty(app.run_error_list)

                if isempty(app.StagingList)
                    % All other checks passed but no stage files — ask user to confirm
                    selection = uiconfirm(app.UIFigure, ...
                        ['No stage files selected. Are you sure you want to run with no stages? ' ...
                         'All non-artifact times will be incorporated into TF-peak and SOPH analyses.'], ...
                        'No Stage Files', ...
                        'Options', {'Yes', 'No'}, ...
                        'DefaultOption', 2, ...
                        'CancelOption', 2);
                    if strcmp(selection, 'No')
                        return;
                    end
                    app.use_no_stages = true;
                else
                    app.use_no_stages = false;
                end

                app.RunBatchButton.Enabled  = false;
                app.StopBatchButton.Enabled = true;
                % Reset BEFORE flipping Enabled=true. The path between
                % here and runBatch's first reset() is ~100-500 ms
                % (setRunningState, options struct, log creation, mkdirs,
                % update*Input). With the previous order, that whole
                % gap rendered the previous run's 100% complete bar.
                app.ProgressBar.reset();
                app.ProgressBar.Enabled     = true;
            else
                uialert(app.UIFigure, sprintf('%s\n', app.run_error_list{:}), ...
                    'Run Error', 'Icon', 'error');
                return;
            end

            % Optionally reverse file processing order (use local copies so the
            % GUI list boxes and app.DataList/StagingList are never mutated)
            dataList    = app.DataList;
            stagingList = app.StagingList;

            if app.use_no_stages
                % Build a same-length list of empty strings as placeholder staging paths
                stagingList = repmat({''}, size(dataList));
            end

            if app.RunInReverse.Value
                dataList    = dataList(end:-1:1);
                stagingList = stagingList(end:-1:1);
            end

            % Invoke external batch callback if registered (passes file lists + options)
            if ~isempty(app.BatchProcessCallback)
                opts.OutputDir        = app.OutputDirEditField.Value;
                opts.SavePeakStats    = app.SavePeakStatsCheckBox.Value;
                opts.SaveDataSummary  = app.SaveDataSummaryCheckBox.Value;
                opts.SaveParamBasis   = app.SaveParamBasisCheckBox.Value;
                opts.SaveParamImages  = app.SaveParamImagesCheckBox.Value;
                opts.SaveSplineBasis  = app.SaveSplineBasisCheckBox.Value;
                opts.SaveSplineImages = app.SaveSplineImagesCheckBox.Value;
                app.BatchProcessCallback(dataList, stagingList, opts);
            end

            runBatch(app, dataList, stagingList)
        end
        function RunBatchButtonPushed(app, ~, ~)
            % RunBatchButtonPushed  Thin callback shim — see startBatchRun.
            app.startBatchRun();
        end


        % ------------------------------------------------------------------

        function requestStopBatch(app)
            % StopBatchButtonPushed  Request a graceful stop. Provides
            % immediate visual feedback (status line + disabled button)
            % BEFORE the alert, so the user sees confirmation instantly
            % instead of waiting for the alert dialog to render — which
            % can lag when the run loop is mid-iteration on the MATLAB
            % thread. The actual halt happens at the next per-channel
            % flag check inside runBatch (`isStopBatchButtonPushed`).

            app.isStopBatchButtonPushed = true;
            app.StopBatchButton.Enabled = false;
            app.TextArea.addnl('Stop requested — halting after current channel.');
            drawnow;
            uialert(app.UIFigure, ...
                'Stop requested. The run will halt after the current channel finishes.', ...
                'Stopping', 'Icon', 'warning');
        end
        function StopBatchButtonPushed(app, ~, ~)
            % StopBatchButtonPushed  Thin callback shim — see requestStopBatch.
            app.requestStopBatch();
        end


        % ------------------------------------------------------------------

        function showAboutDialog(app)
            % AboutMenuSelected  Help menu → About handler. Opens a
            % modal-ish uifigure with the toolbox name, version, and
            % links to the lab + documentation.
            fig = uifigure('Name', 'About DYNAM-O', ...
                'Position', [0 0 600 620]);
            app.trackChildWindow(fig);
            movegui(fig, 'center');

            g = uigridlayout(fig, [1 1]);
            g.Padding = [0 0 0 0];
            g.RowHeight = {'1x'};
            g.ColumnWidth = {'1x'};

            % Local-disk cache for Saira (prefdir/dynamo_cache); the
            % gstatic CDN URL is the universal safe default — used on
            % cache miss + first launch and as a guard against the
            % helper being unavailable (older checkout / stale class
            % cache).
            fontUri = 'https://fonts.gstatic.com/s/saira/v23/memjYa2wxmKQyPMrZX79wwYZQMhsyuSLiIvS.woff2';
            try
                cached = app.getSairaFontDataUri();
                if ~isempty(cached)
                    fontUri = cached;
                end
            catch
            end

            htmlContent = [...
                '<html>' ...
                '<head>' ...
                '<style>' ...
                '@font-face{font-family:''Saira'';font-style:normal;font-weight:400;' ...
                'src:local(''Saira''),local(''Saira-Regular''),' ...
                'url(' fontUri ') format(''woff2'');}' ...
                '  html, body { margin: 0; padding: 0; overflow: hidden; height: 100%; box-sizing: border-box; }' ...
                '  body { font-family: "Segoe UI", Tahoma, sans-serif; line-height: 1.5; color: #333; ' ...
                '         background-color: #fdfdfd; padding: 20px 30px; box-sizing: border-box; }' ...
                '  .version { text-align: center; color: #1971b9; font-size: 12px; margin-top: -4px; margin-bottom: 6px; font-family: Menlo, Consolas, "Courier New", monospace; }' ...
                '  .section-header { font-weight: bold; text-transform: uppercase; font-size: 12px; color: #7f8c8d; margin-top: 20px; margin-bottom: 8px; letter-spacing: 1px; }' ...
                '  .lab-info { margin-bottom: 10px; font-size: 14px; }' ...
                '  .citation-card { background: #f4f7f6; border-left: 5px solid #2e86c1; padding: 12px 15px; margin-bottom: 12px; font-size: 13.5px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }' ...
                '  a { color: #2980b9; text-decoration: none; font-weight: 600; cursor: pointer; }' ...
                '  a:hover { text-decoration: underline; }' ...
                '</style>' ...
                '</head>' ...
                '<body>' ...
                ['  <div style="text-align: center; margin-bottom: 6px;">' app.buildLogoSvg('width',250) '</div>'] ...
                ['  <div class="version">Version: ' dynamo_version() '</div>'] ...
                '  <div class="section-header">Developed by the Prerau Laboratory</div>' ...
                '  <div class="lab-info">' ...
                '    <b>Web:</b> <a onclick="sendLink(''http://sleepeeg.org'')">sleepeeg.org</a><br>' ...
                '    <b>Tutorials:</b> <a onclick="sendLink(''http://prerau.bwh.harvard.edu/dynam-o/'')">sleepeeg.org/dynam-o/</a><br>' ...
                '    <b>GitHub:</b> <a onclick="sendLink(''http://github.com/preraulab/DYNAM-O'')">Source Code</a>' ...
                '  </div>' ...
                '  <div class="section-header">Attribution</div>' ...
                '  <p style="font-size: 13px; margin-bottom: 10px;">If you use this toolbox in publications or derived work, please cite:</p>' ...
                '  <div class="citation-card">' ...
                '    He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.<br>' ...
                '    <b>DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics in Sleep EEG</b><br>' ...
                '    <i>bioRxiv</i>, 2026 &ndash; Pending Journal Publication' ...
                '  </div>' ...
                '  <div class="citation-card">' ...
                '    Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S., Manoach, D. S., Stickgold, R., Prerau, M. J.<br>' ...
                '    <b>Transient Oscillation Dynamics During Sleep Provide a Robust Basis for Electroencephalographic Phenotyping and Biomarker Identification</b><br>' ...
                '    <i>Sleep</i>, 2022; zsac223. <a onclick="sendLink(''https://doi.org/10.1093/sleep/zsac223'')">https://doi.org/10.1093/sleep/zsac223</a>' ...
                '  </div>' ...
                '<script>' ...
                'var _hc = null;' ...
                'function sendLink(url) {' ...
                '  if (_hc) _hc.Data = { event: "link", url: url, t: Date.now() };' ...
                '}' ...
                'function setup(hc) {' ...
                '  _hc = hc;' ...
                '  _hc.Data = { event: "ready" };' ...
                '}' ...
                'window.setup = setup;' ...
                '</script>' ...
                '</body>' ...
                '</html>'];

            h = uihtml(g, 'HTMLSource', htmlContent);
            h.Layout.Row = 1;
            h.Layout.Column = 1;

            h.DataChangedFcn = @(src, ~) handleDataChanged(src);

            function handleDataChanged(src)
                d = src.Data;
                if ~isstruct(d) || ~isfield(d, 'event'), return; end
                if strcmp(d.event, 'link') && isfield(d, 'url')
                    web(d.url);
                end
            end
        end
        function AboutMenuSelected(app, ~, ~)
            % AboutMenuSelected  Thin callback shim — see showAboutDialog.
            app.showAboutDialog();
        end

        function applyFont(app)
            % applyFont  Walk every labelled UI control and stamp app.FontName onto it.
            %
            %   Called once at the end of createComponents(), after all controls
            %   exist. Uses the matlab.ui.Figure Children tree so new controls
            %   added in future are picked up automatically without touching this
            %   function.
            %
            %   Controls that receive FontName:
            %     Label, Button, CheckBox, EditField, NumericEditField,
            %     TextArea, DropDown, ListBox
            %
            %   FontSize is left at whatever was set during construction so that
            %   bespoke sizes (FontSizeTitle) are preserved.

            targetClasses = { ...
                ' ', ...
                'matlab.ui.control.Button', ...
                'matlab.ui.control.CheckBox', ...
                ' ', ...
                ' ', ...
                'matlab.ui.control.TextArea', ...
                'matlab.ui.control.DropDown', ...
                'matlab.ui.control.ListBox' };

            % findall() descends through all grid/tab/panel containers
            allChildren = findall(app.UIFigure);

            for k = 1:numel(allChildren)
                ctrl = allChildren(k);
                if ismember(class(ctrl), targetClasses)
                    try
                        ctrl.FontName = app.FontName;
                    catch
                        % Some read-only or transient controls may reject the
                        % assignment — silently skip them.
                    end
                end
            end
        end

        function enforceMinSize(app)
            % enforceMinSize  Cap the RUN button row's flexible columns so
            % the STOP / RUN buttons stay readable when the figure is wide.
            % Locks columns 2-3 to 150px when the figure has slack; otherwise
            % lets all five share equally.
            g = app.RunBatchGrid;
            innerPos = g.InnerPosition; % [left bottom width height]
            totalAvailableWidth = innerPos(3);

            % 2. Account for gaps (Padding and ColumnSpacing)
            % Padding is [left bottom right top] or a single value
            if numel(g.Padding) == 4
                horzPadding = g.Padding(1) + g.Padding(3);
            else
                horzPadding = g.Padding * 2;
            end

            numCols = 5;
            totalGapWidth = horzPadding + (g.ColumnSpacing * (numCols - 1));

            % 3. Calculate what '1x' would be in pixels
            netWidth = totalAvailableWidth - totalGapWidth;
            oneXPixels = netWidth / numCols;

            % 4. Apply the cap
            if oneXPixels > 150
                % If '1x' wants to be > 200, lock 2 & 3 to 200px.
                % The remaining three '1x' columns will share the leftover space.
                if ~isequal(g.ColumnWidth, {'1x', 150, 150, '1x', '1x'})
                    g.ColumnWidth = {'1x', 150, 150, '1x', '1x'};
                end
            else
                % Otherwise, let all five be equal '1x'
                if ~isequal(g.ColumnWidth, {'1x', '1x', '1x', '1x', '1x'})
                    g.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
                end
            end
        end
    end% private methods

    methods (Static)
        % Pure file-format writer for the parametric-fit CSV — exposed so
        % external scripts (and the equivalence-test harness) can write
        % the same comment-headered CSV that runParamBasis writes.
        writeParamfitCsv(filename, PF, axis_kind, freq_bins, so_bins);
    end

    methods (Static, Access=protected)
        svg_html = buildLogoSvg(varargin);
        function filename = fixFilename(filename, replacement)
            % fixFilename  Sanitize a string so it's safe as a filesystem
            % component. Substitutes any character outside [\w.\-() ]
            % with `replacement` (default '_'). Used to make channel
            % names like "C3-A2 - B" usable as path segments.
            if nargin < 2
                replacement = '_';
            end

            % Validate replacement char is safe (must itself be in the allowed set)
            assert(isempty(regexprep(replacement, '[\w.\-() ]', '')), ...
                'replacement character is not a valid filename character');

            filename = char(filename);

            % Separate extension from name
            [~, name, ext] = fileparts(filename);

            % Whitelist: keep alphanumeric, spaces, dots, hyphens, underscores, parens
            name = regexprep(name, '[^\w.\-() ]', replacement);

            % Strip leading/trailing whitespace and dots
            name = strtrim(name);
            name = regexprep(name, '^\.*', '');   % leading dots
            name = regexprep(name, '[. ]+$', ''); % trailing dots/spaces

            % Collapse consecutive replacements/spaces into one
            name = regexprep(name, [regexptranslate('escape', replacement) '+'], replacement);
            name = strtrim(name);  % trim again in case replacement was a space

            % Handle Windows reserved names
            reservedNames = '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$';
            if ~isempty(regexpi(name, reservedNames))
                name = [name '_'];
            end

            % Truncate if too long (preserve extension)
            maxLen = 255 - length(ext);
            if length(name) > maxLen
                name = name(1:maxLen);
            end

            % Fallback if name is now empty
            if isempty(name)
                name = 'unnamed';
            end

            filename = [name ext];
        end

        function out = splitTopLevelCommas(s)
            % splitTopLevelCommas  Split a string on top-level commas.
            %
            %   Treats commas inside parentheses (mean(A1, A2)) and
            %   inside '$LABEL$' escape regions as literal — only
            %   commas at paren depth 0 outside any '$...$' separate
            %   tokens. Each token is trimmed; empty tokens dropped.
            s = char(s);
            out = {};
            depth = 0;
            inDollar = false;
            start = 1;
            for k = 1:numel(s)
                c = s(k);
                if c == '$'
                    inDollar = ~inDollar;
                elseif ~inDollar
                    if c == '('
                        depth = depth + 1;
                    elseif c == ')'
                        depth = max(0, depth - 1);
                    elseif c == ',' && depth == 0
                        tok = strtrim(s(start:k-1));
                        if ~isempty(tok)
                            out{end+1} = tok; %#ok<AGROW>
                        end
                        start = k + 1;
                    end
                end
            end
            tok = strtrim(s(start:end));
            if ~isempty(tok)
                out{end+1} = tok;
            end
        end
    end % static methods

    methods (Access = private)

        function clearIsError(~, component)
            % clearIsError  Clear the IsError flag on a CSSui component.
            %   Used as a ValueChangedFcn to auto-clear validation highlights
            %   the moment a user corrects a field.
            component.IsError = false;
        end
    end % private methods

end % classdef
