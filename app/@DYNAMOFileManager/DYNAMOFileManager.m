classdef DYNAMOFileManager < matlab.apps.AppBase & DYNAMO
    % DYNAMOFILEMANAGER  GUI application for managing batch file processing in the DYNAM-O toolbox.
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
    %       app = DYNAMOFileManager()
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
        FileMenu                        matlab.ui.container.Menu        % Top-level 'File' menu
        LoadEDFFileListMenu             matlab.ui.container.Menu        % Menu item: load EDF path list
        LoadStagingFileListMenu         matlab.ui.container.Menu        % Menu item: load staging path list
        ShowRunLogConsoleMenu           matlab.ui.container.Menu        % Menu item: toggle Run Log Console
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
        ModeScatterPowerSizeDropDown    % CSSuiDropdown
        ModeScatterPowerColorDropDown   % CSSuiDropdown
        ModeScatterPhaseXDropDown       % CSSuiDropdown
        ModeScatterPhaseYDropDown       % CSSuiDropdown
        ModeScatterPhaseSizeDropDown    % CSSuiDropdown
        ModeScatterPhaseColorDropDown   % CSSuiDropdown
        ModeScatter_TableCache_         % containers.Map keyed "<chan>|<axis>" -> table; cleared on aggregate refresh
        ModeScatter_DropdownsInited_    % struct with .power/.phase booleans — tracks first populated refresh per axis
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
        StagingAddFolderButton          % CSSuiButton                   % Add all staging files from a folder
        StagingAddFileButton            % CSSuiButton                   % Add individual staging file(s)
        DataFileButtonGrid              matlab.ui.container.GridLayout  % Grid for data list action buttons
        DataMoveDownButton              % CSSuiButton                   % Move selected data item down
        DataMoveUpButton                % CSSuiButton                   % Move selected data item up
        DataRemoveButton                % CSSuiButton                   % Remove selected data file
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

        function app = DYNAMOFileManager(varargin)
            % DYNAMOFileManager  Constructor – parses arguments and builds the GUI.
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
            % means the FileManager opens instantly and rust runs never
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
        end

        % ------------------------------------------------------------------

        function applyQuickFill(app, opts)
            % applyQuickFill  Populate file lists / staging fields from
            % constructor Name-Value pairs so a launch like
            %   DYNAMOFileManager('EDFPath','/x','StagingPath','/x', ...
            %                     'OutputPath','/x','Delimiter','Tab', ...
            %                     'StagesColumn',2,'TimesColumn',3, ...
            %                     'HeaderRows',14)
            % skips the manual click-through every test cycle.

            % EDF folder → glob *.edf, *.edf.gz, *.edf.zst → data list
            if ~isempty(opts.EDFPath)
                folder = char(opts.EDFPath);
                if isfolder(folder)
                    files = [dir(fullfile(folder, '*.edf')); ...
                             dir(fullfile(folder, '*.edf.gz')); ...
                             dir(fullfile(folder, '*.edf.zst'))];
                    if ~isempty(files)
                        paths = arrayfun(@(f) fullfile(f.folder, f.name), ...
                            files, 'UniformOutput', false);
                        app.addDataFiles(paths(:)');
                    else
                        warning('DYNAMOFileManager:noEDFs', ...
                            'No .edf, .edf.gz, or .edf.zst files found in %s.', folder);
                    end
                else
                    warning('DYNAMOFileManager:badEDFPath', ...
                        'EDFPath does not exist: %s', folder);
                end
            end

            % Staging folder → glob *.csv, add to staging list
            if ~isempty(opts.StagingPath)
                folder = char(opts.StagingPath);
                if isfolder(folder)
                    files = dir(fullfile(folder, '*.csv'));
                    if ~isempty(files)
                        paths = arrayfun(@(f) fullfile(f.folder, f.name), ...
                            files, 'UniformOutput', false);
                        app.addStagingFiles(paths(:)');
                    else
                        warning('DYNAMOFileManager:noCSVs', ...
                            'No .csv files found in %s.', folder);
                    end
                else
                    warning('DYNAMOFileManager:badStagingPath', ...
                        'StagingPath does not exist: %s', folder);
                end
            end

            if ~isempty(opts.OutputPath)
                app.OutputDirEditField.Value = char(opts.OutputPath);
                app.outputDirChanged();
            end

            % Channel labels → comma-separated string in the Channel(s) field.
            % Accepts char, string scalar/array, or cellstr; multi-entry inputs
            % are joined with ', ' to match the format the field expects.
            % The field is created disabled (composer is the primary writer);
            % CSSuiEditField drops setValue while disabled, so we must enable
            % first, then write, then drop back into the populated read-only
            % display state. We also assign ChannelList directly so the
            % parsed list is correct even if the JS-side Value write races.
            if ~isempty(opts.Channels)
                if ischar(opts.Channels)
                    chanStr = strtrim(opts.Channels);
                elseif isstring(opts.Channels)
                    parts   = strtrim(string(opts.Channels(:)));
                    parts   = parts(strlength(parts) > 0);
                    chanStr = char(strjoin(parts, ', '));
                else  % cellstr
                    parts   = strtrim(opts.Channels(:));
                    parts   = parts(~cellfun('isempty', parts));
                    chanStr = strjoin(parts, ', ');
                end
                if ~isempty(chanStr)
                    app.ChannelEditField.Enabled  = true;
                    app.ChannelEditField.Editable = false;
                    app.ChannelEditField.Value    = chanStr;
                    app.ChannelList = app.splitTopLevelCommas(chanStr);
                end
            end

            if ~isempty(opts.Delimiter)
                d = char(opts.Delimiter);
                switch d
                    case {'Comma', ','},                 label = 'Comma';
                    case {'Tab', '\t', sprintf('\t')},   label = 'Tab';
                    case {'Space', ' '},                 label = 'Space';
                    case {'Semicolon', ';'},             label = 'Semicolon';
                    otherwise
                        warning('DYNAMOFileManager:badDelimiter', ...
                            'Unknown delimiter "%s"; leaving dropdown unchanged.', d);
                        label = '';
                end
                if ~isempty(label)
                    app.DelimeterOptionField.Value = label;
                end
            end

            if ~isempty(opts.StagesColumn)
                app.StagesColumnEditField.Value = opts.StagesColumn;
            end
            if ~isempty(opts.TimesColumn)
                app.TimesColumnEditField.Value = opts.TimesColumn;
            end
            if ~isempty(opts.HeaderRows)
                app.HeaderRowsEditField.Value = opts.HeaderRows;
            end
        end

        % ------------------------------------------------------------------

        function addDataFiles(app, filePaths)
            % addDataFiles  Programmatically append EDF files to the data list.
            %
            %   addDataFiles(app, filePaths)
            %
            %   Input:
            %     filePaths – char or cell array of char, full file path(s) to add

            if ~iscell(filePaths), filePaths = {filePaths}; end
            filePaths = setdiff(filePaths, app.DataList, 'stable');
            app.DataList = [app.DataList, filePaths];
            updateDataListBox(app);
        end

        % ------------------------------------------------------------------

        function addStagingFiles(app, filePaths)
            % addStagingFiles  Programmatically append staging files to the staging list.
            %
            %   addStagingFiles(app, filePaths)
            %
            %   Input:
            %     filePaths – char or cell array of char, full file path(s) to add

            if ~iscell(filePaths), filePaths = {filePaths}; end
            filePaths = setdiff(filePaths, app.StagingList, 'stable');
            app.StagingList = [app.StagingList, filePaths];
            updateStagingListBox(app);
        end

        % ------------------------------------------------------------------

        function [dataFiles, stagingFiles] = getFileLists(app)
            % getFileLists  Return current data and staging file lists.
            %
            %   [dataFiles, stagingFiles] = getFileLists(app)
            %
            %   Outputs:
            %     dataFiles    – cell array of EDF file paths
            %     stagingFiles – cell array of staging file paths

            dataFiles    = app.DataList;
            stagingFiles = app.StagingList;
        end

        % ------------------------------------------------------------------

        function clearAllLists(app)
            % clearAllLists  Remove all entries from both the data and staging lists.
            %
            %   clearAllLists(app)

            app.DataList    = {};
            app.StagingList = {};
            updateDataListBox(app);
            updateStagingListBox(app);
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
            %   Each builder method lives next to this file under @DYNAMOFileManager/.
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
            % showHelpButtonPushed  Open the File Manager README in the system web browser.
            %
            %   If an internet connection is available, opens the GitHub README.
            %   Otherwise, falls back to a local HTML help file.

            githubURL = 'https://github.com/preraulab/DYNAM-O_dev/blob/master/DYNAMOFileManager_README.md';

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
                helpPath = fullfile(fileparts(mfilename('fullpath')), 'DYNAMOFileManager_README.html');
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

            % Store only valid, unique files
            app.StagingList = cellstr(uniqueValidLines);
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


        % ------------------------------------------------------------------

        function addDataFilesViaDialog(app)
            % DataAddFileButtonPushed  Open file picker to add one or more EDF files.

            files = selectFiles(app, 'Select Data Files', 'data');
            files = setdiff(files, app.DataList, 'stable');
            if ~isempty(files)
                app.DataList = [app.DataList, files];
                updateDataListBox(app);
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

            files = selectFiles(app, 'Select Staging Files', 'staging');
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

        % ------------------------------------------------------------------

        function app = ShowFile(app, varargin)
            % ShowFile  Open a staging file.
            %
            %   Triggered by double-clicking an item in FileListBox.

            if isempty(app.StagingList) || isempty(app.StagingListBox.Value)
                return
            end

            curr_file = app.StagingListBox.Value{:};
            if ~exist(curr_file, 'file')
                uialert(app.UIFigure, sprintf('File does not exist: %s', curr_file), 'Error', 'Icon', 'error');
                return
            end

            if ispc        % Windows
                % winopen is a MATLAB function, it handles spaces automatically
                winopen(curr_file);
            elseif ismac   % macOS
                system(['open -a TextEdit "' curr_file '"']);
            elseif isunix  % Linux
                % system() calls the terminal; quotes are required for spaces
                system(['xdg-open "' curr_file '"']);
            end

        end

        function app = ShowHeader(app, varargin)
            % ShowHeader  Open (or update) a floating window showing the EDF file header.
            %
            %   Triggered by double-clicking an item in DataListBox. If the header
            %   viewer figure already exists, its tables are refreshed in place;
            %   otherwise a new figure is created via header_gui.

            if isempty(app.DataList) || isempty(app.DataListBox.Value)
                return
            end

            curr_file = app.DataListBox.Value{:};
            if ~exist(curr_file, 'file')
                uialert(app.UIFigure, sprintf('File does not exist: %s', curr_file), 'Error', 'Icon', 'error');
                return
            end

            [header, signalHeader] = read_EDF(curr_file);

            if isempty(app.header_fig) || (~isempty(app.header_fig) && ~ishandle(app.header_fig))
                % First call or figure was closed: create a new header viewer
                [~, ~, app.header_fig, app.uitable_header, app.uitable_signal] = ...
                    header_gui(header, signalHeader);
            else
                % Viewer exists: refresh table data without reopening
                [header_tbl, signal_tbl] = header_gui(header, signalHeader, 'CreateGUI', false);
                app.uitable_header.Data  = header_tbl;
                app.uitable_signal.Data  = signal_tbl;
            end
        end

        % ------------------------------------------------------------------

        function moveListItems(app, listType, direction)
            % moveListItems  Shift selected items up or down in a file list.
            %
            %   moveListItems(app, listType, direction)
            %
            %   Inputs:
            %     listType  – 'data' or 'staging'
            %     direction – 'up' or 'down'
            %
            %   The function is order-preserving: contiguous blocks move as a unit.

            % Resolve the target list and list-box based on type
            switch listType
                case 'data',    currentList = app.DataList;    lb = app.DataListBox;
                case 'staging', currentList = app.StagingList; lb = app.StagingListBox;
            end

            selected = lb.Value;
            if isempty(selected), return; end

            % Find indices of selected items in the current list
            idx     = find(ismember(currentList, selected));
            newList = currentList;

            if strcmp(direction, 'up') && idx(1) > 1
                % Shift each selected item one position toward the start
                for i = 1:length(idx)
                    tmp = newList{idx(i)};
                    newList{idx(i)}   = newList{idx(i)-1};
                    newList{idx(i)-1} = tmp;
                end
            elseif strcmp(direction, 'down') && idx(end) < length(newList)
                % Shift each selected item one position toward the end (iterate in reverse)
                for i = length(idx):-1:1
                    tmp = newList{idx(i)};
                    newList{idx(i)}   = newList{idx(i)+1};
                    newList{idx(i)+1} = tmp;
                end
            end

            % Write back and refresh the list-box, restoring the selection
            switch listType
                case 'data'
                    app.DataList = newList;
                    updateDataListBox(app);
                    lb.Value = selected;
                case 'staging'
                    app.StagingList = newList;
                    updateStagingListBox(app);
                    lb.Value = selected;
            end
        end

        % ==================================================================
        %   FILE SELECTION HELPERS
        % ==================================================================

        function files = selectFiles(app, title, type)
            % selectFiles  Open a multi-select file dialog and optionally validate results.
            %
            %   files = selectFiles(app, title, type)
            %
            %   Inputs:
            %     title – dialog window title (char)
            %     type  – 'data' | 'staging' | anything else (controls filter list)
            %
            %   Output:
            %     files – cell array of fully-qualified file paths, empty if cancelled.
            %             Passes each path through FileValidationCallback if one is set.

            switch type
                case 'data',    filter = {'*.edf;*.edf.gz;*.edf.zst;*.gz;*.zst', ...
                                          'EDF Files (*.edf, *.edf.gz, *.edf.zst)'; ...
                                          '*.*','All Files'};
                case 'staging', filter = {'*.csv','CSV (*.csv)'; '*.txt','Text (*.txt)'; '*.*','All Files'};
                otherwise,      filter = {'*.*','All Files'};
            end

            [f, p] = uigetfile(filter, title, 'MultiSelect', 'on');
            if isequal(f, 0), files = {}; return; end  % User cancelled

            if ~iscell(f), f = {f}; end  % Wrap single-file selection in a cell
            files = strcat(p, f);

            % Run optional validation callback; keep only files that pass
            if ~isempty(app.FileValidationCallback)
                keep = false(1, numel(files));
                for i = 1:numel(files)
                    keep(i) = app.FileValidationCallback(files{i});
                end
                files = files(keep);
            end
        end

        % ==================================================================
        %   LIST-BOX UPDATE METHODS
        % ==================================================================

        function updateDataListBox(app)
            % updateDataListBox  Refresh the DataListBox items and update the file-count label.
            %
            % Both DataListBox AND StagingListBox have their IsError
            % cleared because the "files mismatch" validation reddens
            % both boxes simultaneously — fixing it from either side
            % should clear both, otherwise the un-edited box keeps a
            % stale red highlight until the next failed validation.

            app.DataListBox.IsError    = false;
            app.StagingListBox.IsError = false;
            app.DataListBox.Items = app.DataList;
            if length(app.DataList) == 1 %#ok<*ISCL>
                app.DataLabel.Text = 'DATA (1 File)';
            else
                app.DataLabel.Text = sprintf('DATA (%d Files)', length(app.DataList));
            end
        end

        % ------------------------------------------------------------------

        function updateStagingListBox(app)
            % updateStagingListBox  Refresh the StagingListBox items and update the file-count label.
            % Clears IsError on both lists; see updateDataListBox.

            app.DataListBox.IsError    = false;
            app.StagingListBox.IsError = false;
            app.StagingListBox.Items = app.StagingList;
            if length(app.StagingList) == 1
                app.StagingLabel.Text = 'STAGING (1 File)';
            else
                app.StagingLabel.Text = sprintf('STAGING (%d Files)', length(app.StagingList));
            end
        end

        % ------------------------------------------------------------------

        function updateRunErrorList(app)
            % updateRunErrorList  Populate run_error_list with any blocking validation issues.
            %   Also sets IsError on related CSSui components to highlight problems visually.
            %
            %   Checks the following conditions and appends a descriptive message
            %   to app.run_error_list for each failure:
            %     - DataList is empty
            %     - StagingList is empty
            %     - No output directory specified
            %     - Data and staging file counts do not match
            %     - Stages column not specified
            %     - Times column not specified
            %     - Header rows not specified
            %     - No channels selected
            %     - Any listed file does not exist on disk

            app.run_error_list = {};  % Clear before re-validating

            % Clear all component error states before re-evaluating
            app.DataListBox.IsError           = false;
            app.StagingListBox.IsError        = false;
            app.OutputDirEditField.IsError    = false;
            app.StagesColumnEditField.IsError = false;
            app.TimesColumnEditField.IsError  = false;
            app.HeaderRowsEditField.IsError   = false;
            app.ViewChannelsButton.IsError    = false;
            app.ArtifactEditField.IsError     = false;
            app.WakeEditField.IsError         = false;
            app.REMEditField.IsError          = false;
            app.N1EditField.IsError           = false;
            app.N2EditField.IsError           = false;
            app.N3EditField.IsError           = false;

            if isempty(app.DataList)
                app.run_error_list(end+1) = {'- Data list empty. Need edf files to run.'};
                app.DataListBox.IsError = true;
            end

            if isempty(app.OutputDirEditField.Value)
                app.run_error_list(end+1) = {'- No output directory given. Need somewhere to save files.'};
                app.OutputDirEditField.IsError = true;
            end

            if ~isempty(app.StagingList) && length(app.DataList) ~= length(app.StagingList)
                app.run_error_list(end+1) = {strcat('- Number of data files (', ...
                    num2str(length(app.DataList)), ...
                    ') does not match staging files (', ...
                    num2str(length(app.StagingList)), ').')};
                app.DataListBox.IsError    = true;
                app.StagingListBox.IsError = true;
            end

            if isempty(app.StagesColumnEditField.Value)
                app.run_error_list(end+1) = {'- No staging column given in the staging file.'};
                app.StagesColumnEditField.IsError = true;
            end

            if isempty(app.TimesColumnEditField.Value)
                app.run_error_list(end+1) = {'- No times column given in the staging file.'};
                app.TimesColumnEditField.IsError = true;
            end

            if isempty(app.HeaderRowsEditField.Value)
                app.run_error_list(end+1) = {'- No header rows given in the staging file.'};
                app.HeaderRowsEditField.IsError = true;
            end

            % Channel field is read-only; the composer is the only
            % writer. So the failure mode is "user never opened the
            % composer", which we surface by reddening the launcher
            % button rather than the (greyed-out) text field.
            if isempty(app.ChannelList)
                app.run_error_list(end+1) = {'- No channels selected.'};
                app.ViewChannelsButton.IsError = true;
            end

            % Check that required stage label fields are not empty
            stage_label_fields = {'Artifact','Wake','REM','N1','N2','N3'};
            for ii = 1:numel(stage_label_fields)
                name = stage_label_fields{ii};
                c = app.([name 'EditField']);
                if isempty(strtrim(c.Value))
                    app.run_error_list(end+1) = {['- ' name ' stage label is empty.']};
                    c.IsError = true;
                end
            end

            % Check that every file in both lists actually exists on disk
            allFiles = [app.DataList(:); app.StagingList(:)];
            missing  = allFiles(~isfile(allFiles));

            if ~isempty(missing)
                app.run_error_list{end+1} = sprintf('Missing files:\n%s', strjoin(missing, '\n'));
                app.DataListBox.IsError    = true;
                app.StagingListBox.IsError = true;
            end
        end

        % ==================================================================
        %   OUTPUT DIRECTORY MANAGEMENT
        % ==================================================================

        function browseOutputDir(app)
            % browseOutputDir  Open a folder picker and set the output directory field.
            %
            %   After selection, delegates to outputDirChanged to validate/create
            %   the directory if it does not yet exist.

            folder = uigetdir;
            if folder ~= 0
                app.OutputDirEditField.IsError = false;
                app.OutputDirEditField.Value   = folder;
                outputDirChanged(app);
            end
        end

        % ------------------------------------------------------------------

        function browseResultsBrowserDir(app)
            % browseResultsBrowserDir  Folder picker for the Results Browser tab.
            % Auto-loads the tree once a folder is chosen.
            startDir = char(app.ResultsBrowserOutputDirField.Value);
            if isempty(startDir) || ~isfolder(startDir), startDir = pwd; end
            folder = uigetdir(startDir, 'Select results directory');
            if folder ~= 0
                app.ResultsBrowserOutputDirField.Value = folder;
                app.loadResultsBrowserTree();
            end
        end
        % ------------------------------------------------------------------
        % .mat preview — smart-cases the known DYNAM-O shapes, falls
        % back to a generic variable browser for anything unrecognized.
        % ------------------------------------------------------------------
        % Generic .mat fallback — variable tree on the left, type-aware
        % renderer on the right. Caches the loaded struct so node clicks
        % don't re-read the file.
        % ------------------------------------------------------------------
        % Mode Scatter — paramfit-aggregate scatter view
        % ------------------------------------------------------------------

        function logResultsBrowser(app, msg)
            % logResultsBrowser  Mirror a status message to (1) the Results
            % Browser status text area and (2) the MATLAB command window.
            % Auto-scrolls the text area to the bottom so streaming output
            % stays visible during long-running aggregate/load operations.
            fprintf('%s\n', msg);
            try
                app.ResultsBrowserTextArea.addnl(msg);
                % CSSBase.pushCmd writes to HTMLComponent.Data, and two
                % rapid writes in the same synchronous block race — JS only
                % sees the second one, so the appended text would be lost.
                % drawnow flushes the appendText event before scrollBottom.
                drawnow;
                app.ResultsBrowserTextArea.scrollToBottom();
            catch
                % Fall back silently if the widget hasn't been built yet.
            end
        end

        % ------------------------------------------------------------------

        function outputDirChanged(app)
            % outputDirChanged  Validate the output directory and ensure it
            % terminates in a DYNAM-O_results folder.
            %
            %   Called whenever the output directory path is modified (Browse,
            %   direct text entry, or constructor quick-fill). The chosen path
            %   is treated as the parent in which a DYNAM-O_results folder
            %   lives — if the user already pointed at a DYNAM-O_results
            %   folder we leave the path alone (no .../DYNAM-O_results/DYNAM-O_results
            %   nesting). The parent must exist (prompt-to-create if not);
            %   the DYNAM-O_results subfolder is created silently.

            pathStr = char(app.OutputDirEditField.Value);
            if isempty(pathStr)
                return;
            end

            % Strip trailing path separators so fileparts sees the leaf.
            while ~isempty(pathStr) && ...
                    (pathStr(end) == '/' || pathStr(end) == filesep)
                pathStr(end) = [];
            end

            [~, leaf] = fileparts(pathStr);
            if strcmp(leaf, 'DYNAM-O_results')
                targetDir = pathStr;
                parentDir = fileparts(pathStr);
            else
                parentDir = pathStr;
                targetDir = fullfile(pathStr, 'DYNAM-O_results');
            end

            % Parent must exist — keep the existing prompt behaviour.
            if ~isfolder(parentDir)
                selection = uiconfirm(app.UIFigure, ...
                    sprintf('Directory does not exist:\n%s\nCreate it?', parentDir), ...
                    'Create Directory?', 'Options', {'Yes','No'}, 'DefaultOption', 2);
                if strcmp(selection, 'Yes')
                    mkdir(parentDir);
                else
                    app.OutputDirEditField.Value = '';
                    return;
                end
            end

            % DYNAM-O_results itself is always created silently.
            if ~isfolder(targetDir)
                mkdir(targetDir);
            end

            app.OutputDirEditField.Value = targetDir;
        end

        % ==================================================================
        %   LOGGING
        % ==================================================================
        % ------------------------------------------------------------------

        function writeLog(app, msg)
            % writeLog  Write a structured message to the run log file.
            %   Console output is captured separately via diary() and
            %   mirrored by the LogConsoleTimer polling the consolelog file.
            if ~isempty(app.runlog_fid) && app.runlog_fid > 0
                fprintf(app.runlog_fid, '%s', msg);
            end
        end

        % ------------------------------------------------------------------

        function toggleRunLogConsole(app, ~, ~)
            % toggleRunLogConsole  Show or hide the floating Run Log Console.
            %   Mirrors the consolelog (diary) file in real time via a timer.

            if ~isempty(app.LogConsoleFig) && isvalid(app.LogConsoleFig)
                % Already open — close it (toggle off)
                app.stopLogConsoleTimer();
                delete(app.LogConsoleFig);
                app.LogConsoleFig      = [];
                app.LogConsoleTextArea = [];
                app.ShowRunLogConsoleMenu.Text = 'Show Run Log Console';
                return
            end

            % Create the console window
            ss = get(0, 'ScreenSize');
            cW = 720; cH = 520;
            fig = uifigure('Name', 'Run Log Console', ...
                'Position', [(ss(3)-cW)/2, (ss(4)-cH)/2, cW, cH], ...
                'WindowStyle', 'normal', ...
                'Resize', 'on', ...
                'CloseRequestFcn', @(~,~) onConsoleClose());

            g = uigridlayout(fig, ...
                'RowHeight', {'1x'}, 'ColumnWidth', {'1x'}, ...
                'Padding', [6 6 6 6]);

            ta = CSSuiTextArea(g, ...
                'Editable',         false, ...
                'Scroll',           true, ...
                'WordWrap',         false, ...
                'Style', app.AppStyle, ...
                'BackgroundColor',  '#ffffff', ...
                'FontSize',         '12px', ...
                'Color',            '#414c57', ...
                'FontWeight',       '500');
            ta.Layout.Row    = 1;
            ta.Layout.Column = 1;

            app.LogConsoleFig      = fig;
            app.LogConsoleTextArea = ta;
            app.ShowRunLogConsoleMenu.Text = 'Hide Run Log Console';

            % If a run is already in progress, load existing content and
            % start the polling timer.
            diaryRunning = ~isempty(app.consolelog_fpath) && ...
                           ~isempty(app.consolelog_fname);
            if diaryRunning
                app.updateLogConsole();
                app.startLogConsoleTimer();
            end

            function onConsoleClose()
                app.stopLogConsoleTimer();
                delete(fig);
                app.LogConsoleFig      = [];
                app.LogConsoleTextArea = [];
                app.ShowRunLogConsoleMenu.Text = 'Show Run Log Console';
            end
        end

        % ------------------------------------------------------------------

        function updateLogConsole(app)
            % updateLogConsole  Read the consolelog file and refresh the text area.
            if isempty(app.LogConsoleFig) || ~isvalid(app.LogConsoleFig)
                return
            end
            fpath = fullfile(app.consolelog_fpath, app.consolelog_fname);
            if ~isfile(fpath), return, end
            try
                app.LogConsoleTextArea.Value = fileread(fpath);
            catch
            end
        end

        % ------------------------------------------------------------------

        function startLogConsoleTimer(app)
            % startLogConsoleTimer  Create and start the 0.3 s polling timer.
            app.stopLogConsoleTimer();  % ensure no duplicate
            app.LogConsoleTimer = timer( ...
                'Period',        0.3, ...
                'ExecutionMode', 'fixedRate', ...
                'TimerFcn',      @(~,~) app.updateLogConsole());
            start(app.LogConsoleTimer);
        end

        % ------------------------------------------------------------------

        function stopLogConsoleTimer(app)
            % stopLogConsoleTimer  Stop and delete the polling timer if running.
            if ~isempty(app.LogConsoleTimer) && isvalid(app.LogConsoleTimer)
                stop(app.LogConsoleTimer);
                delete(app.LogConsoleTimer);
            end
            app.LogConsoleTimer = [];
        end

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

        function createOptionsStruct(app)
            % createOptionsStruct  Package DYNAMO option structs into indexed cell arrays.
            %
            %   Reads the option structs from the DYNAMO base class properties and
            %   stores them in app.options_structs alongside their names in
            %   app.struct_names for use in logging and processing.

            app.struct_names    = {'SOPH_options','baseline_options','detection_options', ...
                'param_basis_power_options','param_basis_phase_options', ...
                'spline_basis_power_options','spline_basis_phase_options'};
            app.options_structs = { app.SOPH_options, ...
                app.baseline_options, ...
                app.detection_options, ...
                app.param_basis_power_options, ...
                app.param_basis_phase_options, ...
                app.spline_basis_power_options, ...
                app.spline_basis_phase_options };
        end

        % ------------------------------------------------------------------

        function updateStagesInput(app)
            % updateStagesInput  Parse stage identifier edit fields into cell arrays.
            %
            %   Reads each stage label field (Artifact, Wake, REM, N1, N2, N3, Unknown),
            %   splits the comma-separated string, and stores the resulting cell arrays
            %   as app.*UserInput properties for use by load_data.

            app.ArtifactUserInput = textscan(app.ArtifactEditField.Value, '%s', 'Delimiter', ',');
            app.ArtifactUserInput = app.ArtifactUserInput{1,1};

            app.WakeUserInput = textscan(app.WakeEditField.Value, '%s', 'Delimiter', ',');
            app.WakeUserInput = app.WakeUserInput{1,1};

            app.REMUserInput = textscan(app.REMEditField.Value, '%s', 'Delimiter', ',');
            app.REMUserInput = app.REMUserInput{1,1};

            app.N1UserInput = textscan(app.N1EditField.Value, '%s', 'Delimiter', ',');
            app.N1UserInput = app.N1UserInput{1,1};

            app.N2UserInput = textscan(app.N2EditField.Value, '%s', 'Delimiter', ',');
            app.N2UserInput = app.N2UserInput{1,1};

            app.N3UserInput = textscan(app.N3EditField.Value, '%s', 'Delimiter', ',');
            app.N3UserInput = app.N3UserInput{1,1};

            app.UnknownUserInput = textscan(app.UnknownEditField.Value, '%s', 'Delimiter', ',');
            app.UnknownUserInput = app.UnknownUserInput{1,1};
        end

        % ------------------------------------------------------------------

        function updateChannelInput(app)
            % updateChannelInput  Parse the channel edit field into a cell array of names.
            %
            %   Splits the comma-separated string in ChannelEditField and stores
            %   the result in app.ChannelList. Commas inside parentheses
            %   ('mean(A1, A2)') and inside '$LABEL$' escape regions are
            %   ignored — only top-level commas separate channel specs.

            app.ChannelList = app.splitTopLevelCommas(app.ChannelEditField.Value);
        end

        function updateReferenceInput(app)
            % updateReferenceInput  Parse the reference edit field into
            % a cell array of 'NAME = expr' strings. Same paren/$-aware
            % comma split as updateChannelInput, so 'R1 = mean(A1, A2)'
            % stays one entry. The composer is the primary writer; this
            % parses any subsequent in-place edits the user makes after
            % the field is enabled.
            app.ReferenceList = app.splitTopLevelCommas(app.ReferenceEditField.Value);
        end

        % ------------------------------------------------------------------

        function checkChannelSamplingRates(app, selectedChannels, tableData)
            % checkChannelSamplingRates  Warn if any selected channel's Fs is
            %   above the multitaper NFFT-jump threshold or below Nyquist
            %   for the configured analysis range.
            %
            %   High threshold: 102.4 Hz. The multitaper spectrogram NFFT
            %   is computed as 2^nextpow2(Fs/mtm_dsfreqs); with the
            %   default mtm_dsfreqs=0.1, NFFT=1024 for Fs <= 102.4 and
            %   doubles to 2048 for Fs > 102.4 (and again at 204.8, etc).
            %   That single jump roughly doubles spectrogram cost AND
            %   pushes the working set past CPU L3 cache on most modern
            %   hardware, so every downstream stage (extract, baseline,
            %   mask, watershed) takes a 2-3x memory-bandwidth hit on top
            %   of the FFT cost. Resampling to <=100 Hz avoids both.
            %
            %   Low threshold: 2x the max analysis upper bound (Nyquist).
            %   Below this, the pipeline literally can't resolve the
            %   target frequency band — must upsample.
            %
            %   The high warning is suppressed if Resample is already on
            %   at a target <=102.4 Hz, since the user has already
            %   resolved the issue.

            soph_upper  = app.SOPH_options.freq_range(2);
            mtm_upper   = app.detection_options.mtm_freq_range(2);
            max_upper   = max(soph_upper, mtm_upper);
            high_thresh = 102.4;     % NFFT-jump boundary at default dsfreqs=0.1
            low_thresh  = 2 * max_upper;

            % If user has already enabled Resample at <=102.4, the high-Fs
            % warning is just noise — they've already got the fix wired up.
            resample_already_fixed = ~isempty(app.ResampleSwitch) && ...
                logical(app.ResampleSwitch.Value) && ...
                app.ResampleFsEditField.Value <= high_thresh;

            tooHigh = {};
            tooLow  = {};
            for ii = 1:numel(selectedChannels)
                lbl = selectedChannels{ii};
                idx = find(strcmp(tableData(:,1), lbl), 1);
                if isempty(idx)
                    continue
                end
                fs_vals = sscanf(tableData{idx,2}, '%g');
                if isempty(fs_vals)
                    continue
                end
                entry = sprintf('  %s (%s)', lbl, tableData{idx,2});
                if max(fs_vals) > high_thresh
                    tooHigh{end+1} = entry; %#ok<AGROW>
                end
                if min(fs_vals) < low_thresh
                    tooLow{end+1}  = entry; %#ok<AGROW>
                end
            end

            if ~isempty(tooHigh) && ~resample_already_fixed
                msg = sprintf(['The following channel(s) have Fs > %.1f Hz, which doubles ' ...
                    'the multitaper FFT size (NFFT 1024 -> 2048+) and typically pushes the ' ...
                    'spectrogram beyond CPU L3 cache, slowing the whole pipeline 2-3x:\n\n' ...
                    '%s\n\n' ...
                    'Recommendation: enable "Resample Data" with target Fs = 100 Hz. ' ...
                    'DYNAMO analyzes 0-30 Hz (Nyquist 50 Hz) so 100 Hz is well above ' ...
                    'anything the pipeline cares about — lossless for sleep oscillations.'], ...
                    high_thresh, strjoin(tooHigh, newline));
                uialert(app.UIFigure, msg, 'High Sampling Rate', 'Icon', 'warning');
            end

            if ~isempty(tooLow)
                msg = sprintf(['The following selected channel(s) have a sampling frequency ' ...
                    'below the minimum required by DYNAMO (< %g Hz, i.e. 2x the upper analysis ' ...
                    'bound of %g Hz by Nyquist):\n\n%s\n\n' ...
                    'You must enable the "Resample Data" option to upsample these channels ' ...
                    'before processing, otherwise the run will fail.'], ...
                    low_thresh, max_upper, strjoin(tooLow, newline));
                uialert(app.UIFigure, msg, 'Low Sampling Rate', 'Icon', 'warning');
            end
        end

        % ------------------------------------------------------------------

        function updateDelimeterInput(app)
            % updateDelimeterInput  Convert the delimiter dropdown selection to a format character.
            %
            %   Maps the human-readable dropdown value (Comma/Tab/Space/Semicolon)
            %   to the actual delimiter character stored in app.delimeter.

            switch app.DelimeterOptionField.Value
                case 'Comma',     app.delimeter = ',';
                case 'Tab',       app.delimeter = '\t';
                case 'Space',     app.delimeter = ' ';
                case 'Semicolon', app.delimeter = ';';
            end
        end

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
                'Position', [0 0 600 600]);
            app.trackChildWindow(fig);
            movegui(fig, 'center');

            g = uigridlayout(fig, [1 1]);
            g.Padding = [0 0 0 0];
            g.RowHeight = {'1x'};
            g.ColumnWidth = {'1x'};

            htmlContent = [...
                '<html>' ...
                '<head>' ...
                '<style>' ...
                '  html, body { margin: 0; padding: 0; overflow: hidden; height: 100%; box-sizing: border-box; }' ...
                '  body { font-family: "Segoe UI", Tahoma, sans-serif; line-height: 1.5; color: #333; ' ...
                '         background-color: #fdfdfd; padding: 20px 30px; box-sizing: border-box; }' ...
                '  .section-header { font-weight: bold; text-transform: uppercase; font-size: 12px; color: #7f8c8d; margin-top: 20px; margin-bottom: 8px; letter-spacing: 1px; }' ...
                '  .lab-info { margin-bottom: 10px; font-size: 14px; }' ...
                '  .citation-card { background: #f4f7f6; border-left: 5px solid #2e86c1; padding: 12px 15px; margin-bottom: 12px; font-size: 13.5px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }' ...
                '  a { color: #2980b9; text-decoration: none; font-weight: 600; cursor: pointer; }' ...
                '  a:hover { text-decoration: underline; }' ...
                '</style>' ...
                '</head>' ...
                '<body>' ...
                ['  <div style="text-align: center; margin-bottom: 15px;">' app.buildLogoSvg('width',250) '</div>'] ...
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

        function updateChannelTooltips(app)
            % updateChannelTooltips  Refresh the Channel(s) and
            % Reference(s) field/label tooltips to reflect current
            % state. Called from finalizeUI (initial empty state) and
            % from the composer's doOk after committing changes.
            %
            % Empty:     "No channels yet. Click Select Channels to add."
            % Populated: "Channels (N): a, b, c. Click Select Channels
            %             to add or remove."
            if isempty(app.ChannelList)
                chanTip = 'No output channels yet. Click Select Channels to add channels.';
            else
                chanTip = sprintf('Output channels (%d): %s. Click Select Channels to add or remove.', ...
                    numel(app.ChannelList), strjoin(app.ChannelList, ', '));
            end
            if isempty(app.ReferenceList)
                refTip = 'No references defined. References are optional — click Select Channels to add one.';
            else
                refTip = sprintf('References (%d): %s. Click Select Channels to add or remove.', ...
                    numel(app.ReferenceList), strjoin(app.ReferenceList, ', '));
            end
            app.ChannelEditField.HTMLComponent.Tooltip      = chanTip;
            app.ChannelEditFieldLabel.HTMLComponent.Tooltip = chanTip;
            app.ReferenceEditField.HTMLComponent.Tooltip    = refTip;
            app.ReferenceLabel.HTMLComponent.Tooltip        = refTip;
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

        function onResampleSwitchChanged(app)
            % onResampleSwitchChanged  Enable/disable the Sampling Freq field
            %   to match the Resample Data switch state.
            app.ResampleFsEditField.Enabled          = logical(app.ResampleSwitch.Value);
            app.ResampleFsEditFieldLabel.Enabled     = logical(app.ResampleSwitch.Value);
        end

    end % private methods

end % classdef
