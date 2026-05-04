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
        AggregateProgressBars_  = []                                    % containers.Map from channelName → SmoothProgressBar; populated by setupAggregateProgressGrid for top-level Aggregate runs (one bar per channel, stacked vertically). [] when not in a top-level run.
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

        % ------------------------------------------------------------------

        function createDYNAMOSettingsTab(app)
            % createDYNAMOSettingsTab  Embed the DYNAMOOptions sub-app into the settings tab.
            %
            %   Calls DYNAMOOptionsApp to populate DYNAMOSettingsGrid with the
            %   DYNAM-O parameter controls. The 'false' arguments suppress
            %   standalone figure creation.

            app.DYNAMOOptionsApp(false, app.UIFigure, app.DYNAMOSettingsGrid, false);
        end

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

        function onResultsBrowserMenuAction(app, evt)
            % onResultsBrowserMenuAction  Dispatch a CSSuiTree right-
            % click action. evt.Action is the action id from the menu
            % definition in node_menu_items; evt.NodeData is the path.
            if ~isfield(evt,'Action') || isempty(evt.Action), return, end
            p = '';
            if isfield(evt,'NodeData') && ~isempty(evt.NodeData)
                p = char(evt.NodeData);
            end
            switch evt.Action
                case 'open'
                    if isempty(p), return, end
                    app.openInOS(p);
                case 'aggregate-all'
                    app.aggregateResultsRoot();
                case 'regenerate-run-index'
                    if isempty(p), return, end
                    app.regenerateRunIndex(p);
                case 'aggregate-channel'
                    app.aggregateChannelByMenu(p, ...
                        {'paramPower','paramPhase','sophsPower','sophsPhase'});
                case 'aggregate-paramfit'
                    chDir = app.resolveChannelDir(p);
                    app.aggregateChannelByMenu(chDir, ...
                        {'paramPower','paramPhase'});
                case 'aggregate-sophs'
                    chDir = app.resolveChannelDir(p);
                    app.aggregateChannelByMenu(chDir, ...
                        {'sophsPower','sophsPhase'});
            end
        end

        % ------------------------------------------------------------------

        function aggregateChannelByMenu(app, channelDir, categories)
            % Run aggregation for a single channel from a right-click,
            % then refresh the tree so the new aggregates folder shows
            % up. Mirrors aggregateResultsRoot's surrounding scaffolding.
            if isempty(channelDir) || ~isfolder(channelDir)
                app.logResultsBrowser(sprintf('Aggregate: invalid channel dir: %s', channelDir));
                return
            end
            root = strtrim(char(app.ResultsBrowserOutputDirField.Value));
            aggregatesRoot = fullfile(root, 'aggregates');

            drawnow;
            app.AggregateOverwriteMode_ = '';   % reset standing answer
            % Right-click is a single-channel op — drop any per-channel
            % bar map left over from a top-level run so aggProgressTick
            % falls back to the single-bar path.
            app.teardownAggregateProgressGrid();
            app.aggregateOneChannel(channelDir, aggregatesRoot, categories);
            app.refreshAggregatesNodeInCache(root);
            app.updateAggregateDataTabVisibility(true);
        end

        % ------------------------------------------------------------------

        function chDir = resolveChannelDir(~, p)
            % resolveChannelDir  Walk up from the clicked node until the
            % parent directory is the results root (i.e., the next level
            % up has no more parametric/SOPH structure). For a node
            % already at channel level (param_basis/SOPHs subdir was the
            % click target), walk one step up.
            chDir = '';
            if isempty(p), return, end
            if isfolder(p), chDir = p; else, chDir = fileparts(p); end
            [~, name] = fileparts(chDir);
            if strcmp(name,'param_basis') || strcmp(name,'SOPHs')
                chDir = fileparts(chDir);
            end
        end

        % ------------------------------------------------------------------

        function openInOS(~, p)
            % Shared helper used by both right-click 'Open' and the
            % NodeDoubleClickedFcn double-click handler.
            if ~isfile(p) && ~isfolder(p)
                warning('DYNAMOFileManager:openInOS', ...
                    'Path does not resolve: %s', p);
                return
            end
            fprintf('Opening: %s\n', p);
            quoted = ['"' strrep(p, '"', '\"') '"'];
            if ispc
                winopen(p);
            elseif ismac
                system(['open ' quoted]);
            else
                system(['xdg-open ' quoted]);
            end
        end

        % ------------------------------------------------------------------

        function beginColumnResize(app)
            % Mouse-down on the splitter — capture figure-level motion/up
            % callbacks and set a hand cursor while the drag is active.
            fig = app.UIFigure;
            pos = fig.CurrentPoint;        % [x y] in pixels, fig-relative
            % Resolve current column 1 width into an absolute pixel value.
            leftPos = getpixelposition(app.ResultsLeftGrid, true);
            rightPos = getpixelposition(app.ResultsBrowserPreviewGrid, true);
            startW1   = leftPos(3);
            totalW    = startW1 + rightPos(3);

            app.ResultsSplitterDrag_.active      = true;
            app.ResultsSplitterDrag_.startX      = pos(1);
            app.ResultsSplitterDrag_.startW1     = startW1;
            app.ResultsSplitterDrag_.totalW      = totalW;
            app.ResultsSplitterDrag_.origMotion  = fig.WindowButtonMotionFcn;
            app.ResultsSplitterDrag_.origUp      = fig.WindowButtonUpFcn;
            app.ResultsSplitterDrag_.origPointer = fig.Pointer;

            fig.Pointer              = 'left';
            fig.WindowButtonMotionFcn = @(~,~) app.dragColumnResize();
            fig.WindowButtonUpFcn     = @(~,~) app.endColumnResize();
        end

        function dragColumnResize(app)
            % dragColumnResize  Mouse-motion handler while dragging the
            % vertical splitter between the tree column and the preview
            % column. Updates BrowserContentContainer.ColumnWidth in
            % real time, clamping each side to a minimum width.
            if ~app.ResultsSplitterDrag_.active, return, end
            fig    = app.UIFigure;
            pos    = fig.CurrentPoint;
            dx     = pos(1) - app.ResultsSplitterDrag_.startX;
            startW = app.ResultsSplitterDrag_.startW1;
            total  = app.ResultsSplitterDrag_.totalW;
            minW   = 120;        % don't let either side collapse below this
            newW1  = min(max(startW + dx, minW), total - minW);
            newW2  = max(total - newW1, minW);
            app.BrowserContentContainer.ColumnWidth = {newW1, 6, newW2};
        end

        function endColumnResize(app)
            % endColumnResize  Mouse-up handler that releases the column
            % splitter — restores the figure's original motion / up
            % callbacks and pointer style.
            fig = app.UIFigure;
            fig.WindowButtonMotionFcn = app.ResultsSplitterDrag_.origMotion;
            fig.WindowButtonUpFcn     = app.ResultsSplitterDrag_.origUp;
            fig.Pointer               = app.ResultsSplitterDrag_.origPointer;
            app.ResultsSplitterDrag_.active = false;
        end

        function beginRowResize(app)
            % Mouse-down on the horizontal splitter — capture motion/up
            % so the user can drag the tree/status height boundary.
            fig    = app.UIFigure;
            pos    = fig.CurrentPoint;
            % CSSuiTree is a wrapper class, not a graphics handle — use
            % its underlying uihtml component for getpixelposition.
            treeP  = getpixelposition(app.ResultsBrowserTree.HTMLComponent, true);
            statP  = getpixelposition(app.ResultsBrowserStatusGrid, true);
            startH = treeP(4);
            totalH = startH + statP(4);

            app.ResultsRowSplitterDrag_.active      = true;
            app.ResultsRowSplitterDrag_.startY      = pos(2);
            app.ResultsRowSplitterDrag_.startH1     = startH;
            app.ResultsRowSplitterDrag_.totalH      = totalH;
            app.ResultsRowSplitterDrag_.origMotion  = fig.WindowButtonMotionFcn;
            app.ResultsRowSplitterDrag_.origUp      = fig.WindowButtonUpFcn;
            app.ResultsRowSplitterDrag_.origPointer = fig.Pointer;

            fig.Pointer               = 'top';
            fig.WindowButtonMotionFcn = @(~,~) app.dragRowResize();
            fig.WindowButtonUpFcn     = @(~,~) app.endRowResize();
        end

        function dragRowResize(app)
            % dragRowResize  Mouse-motion handler while dragging the
            % horizontal splitter between the tree (rows 1-5) and the
            % status pane (row 7). Live-updates ResultsLeftGrid.RowHeight
            % with clamped heights for both panes.
            if ~app.ResultsRowSplitterDrag_.active, return, end
            fig    = app.UIFigure;
            pos    = fig.CurrentPoint;
            % Figure y grows upward; dragging the splitter UP shrinks the
            % tree (above) and grows the status (below). The startY is
            % captured at click; positive dy (cursor above start) means
            % the splitter has moved up, so tree height should decrease.
            dy     = pos(2) - app.ResultsRowSplitterDrag_.startY;
            startH = app.ResultsRowSplitterDrag_.startH1;
            total  = app.ResultsRowSplitterDrag_.totalH;
            minH   = 80;
            newH1  = min(max(startH - dy, minH), total - minH);
            newH2  = max(total - newH1, minH);
            rh = app.ResultsLeftGrid.RowHeight;
            rh{5} = newH1;
            rh{7} = newH2;
            app.ResultsLeftGrid.RowHeight = rh;
        end

        function endRowResize(app)
            % endRowResize  Mouse-up handler that releases the row
            % splitter — restores the figure's prior motion / up
            % callbacks and pointer style.
            fig = app.UIFigure;
            fig.WindowButtonMotionFcn = app.ResultsRowSplitterDrag_.origMotion;
            fig.WindowButtonUpFcn     = app.ResultsRowSplitterDrag_.origUp;
            fig.Pointer               = app.ResultsRowSplitterDrag_.origPointer;
            app.ResultsRowSplitterDrag_.active = false;
        end

        function previewResultsBrowserNode(app, evt)
            % previewResultsBrowserNode  Render a preview of the
            % single-clicked tree node in the right-column preview pane.
            % Images and TIFFs go into a uiaxes; CSVs into a uitable;
            % MAT and other types fall back to a "preview not available"
            % placeholder per current scope.
            if ~isfield(evt,'NodeData') || isempty(evt.NodeData)
                app.renderResultsBrowserPreviewPlaceholder();
                return
            end
            p = char(evt.NodeData);
            if isfolder(p)
                app.renderResultsBrowserPreviewPlaceholder();
                return
            end
            if ~isfile(p)
                app.renderResultsBrowserPreviewMessage(...
                    sprintf('File not found:\n%s', p));
                return
            end

            [~, name, ext] = fileparts(p);
            app.ResultsBrowserPreviewTitle.Text = upper([name, ext]);

            ext = lower(ext);
            % Show the dancing-bars animation while the renderer prepares
            % the preview. Each renderer below replaces the body's
            % children, which clears the spinner.
            app.renderResultsBrowserPreviewPlaceholder('loading');
            drawnow;
            try
                switch ext
                    case {'.png','.jpg','.jpeg','.gif','.bmp'}
                        app.renderResultsBrowserPreviewImage(p);
                    case {'.tif','.tiff'}
                        app.renderResultsBrowserPreviewTiff(p);
                    case '.csv'
                        app.renderResultsBrowserPreviewCsv(p);
                    case '.txt'
                        app.renderResultsBrowserPreviewText(p);
                    case '.mat'
                        app.renderResultsBrowserPreviewMat(p);
                    otherwise
                        app.renderResultsBrowserPreviewMessage(...
                            sprintf('Preview not available for %s files.', ext));
                end
            catch ME
                app.renderResultsBrowserPreviewMessage(...
                    sprintf('Preview failed:\n%s', ME.message));
            end
        end

        % ------------------------------------------------------------------

        function renderResultsBrowserPreviewPlaceholder(app, mode)
            % Optional mode: 'empty' | 'loading' | 'idle'. If omitted,
            % inferred from cache state.
            if nargin < 2 || isempty(mode)
                if isempty(app.ResultsBrowserCache_)
                    mode = 'empty';
                else
                    mode = 'idle';
                end
            end
            app.ResultsBrowserPreviewTitle.Text = 'PREVIEW';
            delete(app.ResultsBrowserPreviewBody.Children);

            if strcmp(mode, 'loading')
                % Render the same SVG animation that the RUN button uses
                % when a batch is in flight (set_running). uihtml only
                % positions cleanly via a grid layout (it has no Units
                % property), so we wrap it in a 1x1 grid that fills the
                % preview body's uipanel.
                g = uigridlayout(app.ResultsBrowserPreviewBody, [1 1]);
                g.Padding     = [0 0 0 0];
                g.RowHeight   = {'1x'};
                g.ColumnWidth = {'1x'};
                h = uihtml(g);
                h.Layout.Row    = 1;
                h.Layout.Column = 1;
                h.HTMLSource    = app.loadingAnimationHtml('Loading directory tree…');
                return
            end

            switch mode
                case 'empty'
                    msg = sprintf(['Select a DYNAM-O results directory above to begin.\n\n' ...
                                   'Use the Browse button or paste a path into the field.']);
                otherwise
                    msg = 'Click a file in the tree to preview it.';
            end
            ax = uiaxes(app.ResultsBrowserPreviewBody, ...
                'Units','normalized','Position',[0 0 1 1], ...
                'BackgroundColor','white');
            axis(ax,'off');
            text(ax, 0.5, 0.5, msg, ...
                'HorizontalAlignment','center','VerticalAlignment','middle', ...
                'Color',[0.55 0.6 0.65], 'FontSize', 13);
        end

        function html = loadingAnimationHtml(~, caption)
            %LOADINGANIMATIONHTML  Build the centered HTML wrapper around
            %   the dancing-bars SVG (the same one set_running puts on the
            %   RUN button). Used by both the preview pane placeholder and
            %   the file-tree loading overlay so the GUI's "something is
            %   churning" cue is consistent everywhere.
            %
            %   `caption` is shown beneath the bars (e.g. 'Loading…').
            %   Pass '' to omit.
            if nargin < 2, caption = ''; end
            % SVG copied verbatim from set_running so updates to either
            % stay coupled. The `currentColor` fill picks up the CSS
            % color we set on the wrapper div.
            svg = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 135 140" ', ...
                   'fill="currentColor" style="width:96px;height:96px;">', ...
                   '<rect y="10" width="15" height="120" rx="6">', ...
                   '<animate attributeName="height" begin="0.5s" dur="1s" ', ...
                   'values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/>', ...
                   '<animate attributeName="y" begin="0.5s" dur="1s" ', ...
                   'values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/>', ...
                   '</rect>', ...
                   '<rect x="30" y="10" width="15" height="120" rx="6">', ...
                   '<animate attributeName="height" begin="0.25s" dur="1s" ', ...
                   'values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/>', ...
                   '<animate attributeName="y" begin="0.25s" dur="1s" ', ...
                   'values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/>', ...
                   '</rect>', ...
                   '<rect x="60" width="15" height="140" rx="6">', ...
                   '<animate attributeName="height" begin="0s" dur="1s" ', ...
                   'values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/>', ...
                   '<animate attributeName="y" begin="0s" dur="1s" ', ...
                   'values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/>', ...
                   '</rect>', ...
                   '<rect x="90" y="10" width="15" height="120" rx="6">', ...
                   '<animate attributeName="height" begin="0.25s" dur="1s" ', ...
                   'values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/>', ...
                   '<animate attributeName="y" begin="0.25s" dur="1s" ', ...
                   'values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/>', ...
                   '</rect>', ...
                   '<rect x="120" y="10" width="15" height="120" rx="6">', ...
                   '<animate attributeName="height" begin="0.5s" dur="1s" ', ...
                   'values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/>', ...
                   '<animate attributeName="y" begin="0.5s" dur="1s" ', ...
                   'values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/>', ...
                   '</rect>', ...
                   '</svg>'];
            captionHtml = '';
            if ~isempty(caption)
                captionHtml = sprintf( ...
                    '<div style="margin-top:14px;font-size:13px;color:#8a939e;">%s</div>', ...
                    caption);
            end
            html = ['<!DOCTYPE html><html><head><style>', ...
                    'html,body{margin:0;padding:0;height:100%;background:white;}', ...
                    '.wrap{display:flex;flex-direction:column;align-items:center;', ...
                          'justify-content:center;height:100%;color:#5a98c0;', ...
                          'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;}', ...
                    '</style></head><body>', ...
                    '<div class="wrap">', svg, captionHtml, '</div>', ...
                    '</body></html>'];
        end

        function setupResultsBrowserPreviewProgress(app, prefix, total)
            % setupResultsBrowserPreviewProgress  Replace the preview body
            %   with a fresh CSSuicontrols SmoothProgressBar configured for
            %   one aggregation stage (N = total files). Called at the
            %   start of every (category, stage) pair so each pass gets
            %   its own browser-side animation cycle (rAF timing, ETA,
            %   colormap-fill — all native to SmoothProgressBar).
            delete(app.ResultsBrowserPreviewBody.Children);
            app.PreviewProgressBar_  = [];
            if total <= 0, return, end

            % Two-row layout: a fixed-pixel row hosts the bar with the
            % same proportions as the batch run progress bar at the
            % bottom of the window (createBottomBar.m: BarHeight=0.35,
            % pill BorderRadius). The remaining row is empty so the bar
            % sits near the top of the preview pane and doesn't stretch
            % vertically across the entire preview area.
            g = uigridlayout(app.ResultsBrowserPreviewBody, [2 1]);
            g.Padding     = [24 24 24 24];
            g.RowHeight   = {80, '1x'};
            g.ColumnWidth = {'1x'};
            pb = SmoothProgressBar(g, total, ...
                'BarHeight',       0.35, ...
                'BarBorderRadius', '999px', ...
                'BorderRadius',    '999px', ...
                'TextPosition',    'above');
            pb.Layout.Row    = 1;
            pb.Layout.Column = 1;
            pb.LabelPrefix       = prefix;
            pb.ShowPercentage    = true;
            pb.ShowTimeRemaining = true;
            pb.start();
            app.PreviewProgressBar_  = pb;
        end

        function tickResultsBrowserPreviewProgress(app, k)
            % tickResultsBrowserPreviewProgress  Advance the current
            %   SmoothProgressBar to iteration k. Silently no-ops if the
            %   bar was destroyed (e.g. by a file preview render that
            %   cleared the preview body) — the next setup call will
            %   rebuild on the next stage transition.
            pb = app.PreviewProgressBar_;
            if isempty(pb) || ~isvalid(pb), return, end
            try
                pb.updateIteration(k);
            catch
                % Bar may have been completed externally; ignore.
            end
        end

        function setupAggregateProgressGrid(app, channelNames)
            % setupAggregateProgressGrid  Replace the preview body with
            %   one SmoothProgressBar per channel, stacked vertically,
            %   each titled with the channel name. Each bar is reused
            %   across that channel's stages; aggProgressTick swaps
            %   the bar's `N` and `LabelPrefix` whenever a new (cat,
            %   stage) starts. Bars are stored in
            %   app.AggregateProgressBars_ (containers.Map) so the
            %   per-file callback can find them by channel name.
            delete(app.ResultsBrowserPreviewBody.Children);
            app.PreviewProgressBar_     = [];
            app.AggregateProgressBars_  = [];
            if nargin < 2 || isempty(channelNames), return, end
            channelNames = cellstr(channelNames);
            n = numel(channelNames);

            % Each row = a label (channel + current stage) above a
            % progress bar. Fixed pixel heights; the outer grid is
            % marked Scrollable so big channel sets don't overflow.
            ROW_PX  = 56;     % label (18) + bar (~30) + gap
            outer = uigridlayout(app.ResultsBrowserPreviewBody, [n 1]);
            outer.RowHeight   = repmat({ROW_PX}, 1, n);
            outer.ColumnWidth = {'1x'};
            outer.RowSpacing  = 6;
            outer.Padding     = [16 16 16 16];
            outer.Scrollable  = 'on';

            bars = containers.Map('KeyType','char','ValueType','any');
            for ii = 1:n
                ch = channelNames{ii};
                row = uigridlayout(outer);
                row.Layout.Row    = ii;
                row.Layout.Column = 1;
                row.RowHeight     = {18, '1x'};
                row.ColumnWidth   = {'1x'};
                row.RowSpacing    = 2;
                row.Padding       = [0 0 0 0];

                pb = SmoothProgressBar(row, 1, ...
                    'BarHeight',       0.5, ...
                    'BarBorderRadius', '999px', ...
                    'BorderRadius',    '999px', ...
                    'TextPosition',    'above');
                pb.Layout.Row    = 2;
                pb.Layout.Column = 1;
                pb.LabelPrefix       = ch;
                pb.ShowPercentage    = true;
                pb.ShowTimeRemaining = false;
                pb.start();
                bars(ch) = pb;
            end
            app.AggregateProgressBars_ = bars;
        end

        function teardownAggregateProgressGrid(app)
            % teardownAggregateProgressGrid  Drop the per-channel bar
            %   map so the next single-channel right-click aggregation
            %   uses the single-bar path instead of trying to look up
            %   a non-existent entry.
            app.AggregateProgressBars_ = [];
        end

        function renderResultsBrowserPreviewMessage(app, msg)
            % renderResultsBrowserPreviewMessage  Render a centered text
            % message in the preview pane — used for "file not found",
            % unsupported types, and similar status messages. Treats
            % `msg` literally (Interpreter='none') so paths and errors
            % render exactly as given.
            delete(app.ResultsBrowserPreviewBody.Children);
            ax = uiaxes(app.ResultsBrowserPreviewBody, ...
                'Units','normalized','Position',[0 0 1 1], ...
                'BackgroundColor','white');
            axis(ax,'off');
            text(ax, 0.5, 0.5, msg, ...
                'HorizontalAlignment','center','VerticalAlignment','middle', ...
                'Interpreter','none','Color',[0.45 0.5 0.55], 'FontSize', 13);
        end

        function renderResultsBrowserPreviewError(app, root)
            % Full-text explanation for an invalid results folder, rendered
            % into the right-hand preview pane (the "big window") instead
            % of cluttering the tree.
            app.ResultsBrowserPreviewTitle.Text = 'INVALID RESULTS FOLDER';
            delete(app.ResultsBrowserPreviewBody.Children);

            ta = app.makeFillTextArea(app.ResultsBrowserPreviewBody);
            ta.FontName        = 'Helvetica';
            ta.FontSize        = 13;
            ta.FontColor       = [0.30 0.34 0.40];
            ta.BackgroundColor = [1 1 1];

            lines = {
                'Not a DYNAM-O_results folder.'
                ''
                sprintf('Selected: %s', root)
                ''
                'A valid DYNAM-O_results folder is one produced by the FileManager'
                'batch run. Each save category is independently optional, so this'
                'folder is accepted if ANY of the following is present:'
                ''
                '  • settings/run_settings_*.txt                (always emitted by a run)'
                ''
                '  • a channel subdirectory containing any of:'
                '       param_basis/        — parametric power/phase fit tables'
                '       SOPHs/              — SO-Power and SO-Phase histograms'
                '       TFpeaks/            — time-frequency peak tables'
                '       spline_basis/       — spline-basis fit outputs'
                '       figures/            — saved figures'
                '       auxiliary_data/     — auxiliary outputs'
                ''
                '  • aggregates/<channel>/ containing any of:'
                '       param_basis_power/  param_basis_phase/'
                '       SOPHs_power/        SOPHs_phase/'
                '       spline_basis_power/ spline_basis_phase/'
                '       TFpeaks/  figures/  auxiliary_data/'
                ''
                'Pick the top-level results folder (the one that contains the channel'
                'subdirs and/or the settings/ folder), then press Enter.'
                };
            ta.Value = lines;
        end

        % ------------------------------------------------------------------
        % .mat preview — smart-cases the known DYNAM-O shapes, falls
        % back to a generic variable browser for anything unrecognized.
        % ------------------------------------------------------------------

        function renderResultsBrowserPreviewMat(app, p)
            % renderResultsBrowserPreviewMat  Top-level dispatcher for
            % .mat preview. Inspects top-level variables via whos to
            % avoid loading large files, then routes to a smart-case
            % renderer (SOPHs, paramfit, splinefit, auxiliary, stats,
            % aggregate) or falls back to a generic struct browser.
            delete(app.ResultsBrowserPreviewBody.Children);
            try
                info = whos('-file', p);
            catch ME
                app.renderResultsBrowserPreviewMessage( ...
                    sprintf('Could not read MAT file:\n%s', ME.message));
                return
            end
            if isempty(info)
                app.renderResultsBrowserPreviewMessage('Empty .mat file.');
                return
            end
            names = {info.name};

            % --- Smart cases (peek var names, then load only what's needed) ---
            try
                if any(strcmp(names, 'SOPHs'))
                    app.previewMatSOPHs(p);                    return
                end
                if any(strcmp(names, 'SOpower_paramfit')) || ...
                   any(strcmp(names, 'SOphase_paramfit'))
                    app.previewMatParamfit(p, names);          return
                end
                if any(strcmp(names, 'SOpower_splinefit')) || ...
                   any(strcmp(names, 'SOphase_splinefit'))
                    app.previewMatSplinefit(p, names);         return
                end
                if any(strcmp(names, 'auxiliary_data'))
                    app.previewMatAuxiliary(p);                return
                end
                if any(strcmp(names, 'stats_table'))
                    app.previewMatStatsTable(p);               return
                end
                if any(strcmp(names, 'aggregate'))
                    app.previewMatAggregate(p);                return
                end
            catch ME
                app.renderResultsBrowserPreviewMessage( ...
                    sprintf('Smart-case render failed:\n%s', ME.message));
                return
            end

            % --- Generic fallback ---
            app.renderResultsBrowserPreviewMatGeneric(p, info);
        end

        function previewMatSOPHs(app, p)
            % Per-subject SOPHs.mat → two tabs (Power / Phase).
            S = load(p);
            if ~isfield(S, 'SOPHs')
                app.renderResultsBrowserPreviewMessage('SOPHs variable missing.');
                return
            end
            tg = uitabgroup(app.ResultsBrowserPreviewBody, ...
                'Units','normalized','Position',[0 0 1 1]);

            tPow  = uitab(tg, 'Title','SO-Power');
            gPow  = uigridlayout(tPow);
            gPow.ColumnWidth = {'1x'}; gPow.RowHeight = {'1x'};
            gPow.Padding = [12 12 12 12];
            axP = uiaxes(gPow, 'BackgroundColor','white');
            axP.Layout.Row = 1; axP.Layout.Column = 1;
            app.plotAggregateSOHist(axP, p, 'power');
            app.attachPopOutToolbar(axP, ...
                @(a) app.plotAggregateSOHist(a, p, 'power'), 'SO-Power Histogram');

            tPh   = uitab(tg, 'Title','SO-Phase');
            gPh   = uigridlayout(tPh);
            gPh.ColumnWidth = {'1x'}; gPh.RowHeight = {'1x'};
            gPh.Padding = [12 12 12 12];
            axPh = uiaxes(gPh, 'BackgroundColor','white');
            axPh.Layout.Row = 1; axPh.Layout.Column = 1;
            app.plotAggregateSOHist(axPh, p, 'phase');
            app.attachPopOutToolbar(axPh, ...
                @(a) app.plotAggregateSOHist(a, p, 'phase'), 'SO-Phase Histogram');
        end

        function previewMatParamfit(app, p, names)
            % paramfit struct: params (table) + model_SOPH (2D) + wshed_img (RGB)
            varName = '';
            for n = names
                if endsWith(n{1}, '_paramfit'), varName = n{1}; break, end
            end
            if isempty(varName)
                app.renderResultsBrowserPreviewMessage('paramfit variable missing.');
                return
            end
            S = load(p, varName);
            PF = S.(varName);

            % Decide axis kind from the variable name for SOPH-style rendering.
            if startsWith(varName, 'SOpower'), axis_kind = 'power';
            else,                              axis_kind = 'phase';
            end

            tg = uitabgroup(app.ResultsBrowserPreviewBody, ...
                'Units','normalized','Position',[0 0 1 1]);

            % --- params table ---
            if isfield(PF, 'params') && istable(PF.params)
                tT = uitab(tg, 'Title', sprintf('params (%d×%d)', ...
                    height(PF.params), width(PF.params)));
                ut = uitable(tT);
                ut.Units = 'normalized'; ut.Position = [0 0 1 1];
                ut.Data = PF.params; ut.ColumnSortable = true;
            end

            % --- model SOPH heatmap ---
            % Reuse the canonical SOPHs rendering (styleSOPHAxes) so the
            % parametric model gets the same transpose, colormap, freq
            % window, robust color limits, and binned axes as the per-
            % subject SOPHs view. Without this the imagesc came out with
            % integer bin indices instead of actual frequency / SO-axis
            % values, which made comparing the parametric model to the
            % data SOPH visually impossible.
            if isfield(PF, 'model_SOPH') && ~isempty(PF.model_SOPH)
                tM = uitab(tg, 'Title','model SOPH');
                axM = uiaxes(tM, 'Units','normalized','Position',[0 0 1 1], ...
                    'BackgroundColor','white');
                [freq_bins, so_bins] = app.bins_for_paramfit(PF, p, axis_kind);
                % model_SOPH comes from meshgrid(so_bins, freq_bins), so it
                % is [Nfreq × Nso]. styleSOPHAxes expects [Nso × Nfreq] —
                % transpose to match.
                app.styleSOPHAxes(axM, PF.model_SOPH.', freq_bins, so_bins, axis_kind);
                title(axM, 'Parametric model SOPH');
            end

            % --- watershed RGB ---
            if isfield(PF, 'wshed_img') && ~isempty(PF.wshed_img)
                tW = uitab(tg, 'Title','watershed');
                axW = uiaxes(tW, 'Units','normalized','Position',[0 0 1 1], ...
                    'BackgroundColor','white');
                imshow(PF.wshed_img, 'Parent', axW);
                title(axW, 'Watershed segmentation');
            end

            % --- gof / fitobj summary ---
            if isfield(PF, 'gof') || isfield(PF, 'fitobj')
                tG = uitab(tg, 'Title','fit info');
                ta = app.makeFillTextArea(tG);
                lines = {};
                if isfield(PF, 'gof')
                    lines = [lines; {'--- gof ---'}; ...
                        splitlines(string(evalc('disp(PF.gof)')))];
                end
                if isfield(PF, 'fitobj')
                    lines = [lines; {''; '--- fitobj ---'}; ...
                        splitlines(string(evalc('disp(PF.fitobj)')))];
                end
                ta.Value = cellstr(lines);
            end
        end

        function previewMatSplinefit(app, p, names)
            % previewMatSplinefit  Render a per-subject splinefit .mat:
            % a tab group with the fitted SOPH model image and a text
            % dump of the spline coefficients/knots. `names` is the list
            % of top-level variables in the file (from whos).
            varName = '';
            for n = names
                if endsWith(n{1}, '_splinefit'), varName = n{1}; break, end
            end
            S = load(p, varName);
            SF = S.(varName);

            tg = uitabgroup(app.ResultsBrowserPreviewBody, ...
                'Units','normalized','Position',[0 0 1 1]);

            if isfield(SF, 'splinefit') && ~isempty(SF.splinefit)
                tS = uitab(tg, 'Title','splinefit');
                axS = uiaxes(tS, 'Units','normalized','Position',[0 0 1 1], ...
                    'BackgroundColor','white');
                % Same canonical SOPH rendering as the parametric preview —
                % gives the spline fit real frequency / SO-axis values
                % instead of bin indices.
                if startsWith(varName, 'SOpower'), axis_kind = 'power';
                else,                              axis_kind = 'phase';
                end
                [freq_bins, so_bins] = app.bins_for_paramfit(SF, p, axis_kind);
                app.styleSOPHAxes(axS, SF.splinefit, freq_bins, so_bins, axis_kind);
                title(axS, 'Spline-fitted SOPH');
            end

            tI = uitab(tg, 'Title','knots / coefs');
            ta = app.makeFillTextArea(tI);
            lines = {};
            for fld = {'knots_x','knots_y','coefs','spline_obj'}
                if isfield(SF, fld{1})
                    lines = [lines; {sprintf('--- %s ---', fld{1})}; ...
                        splitlines(string(evalc('disp(SF.(fld{1}))')))]; %#ok<AGROW>
                end
            end
            ta.Value = cellstr(lines);
        end

        function renderSplinefitTiffPreview(app, p, axis_kind)
            % Mirror of previewMatSplinefit but for the multi-page
            % splinefit TIFF (page 1 = coefs, page 2 = rendered fit).
            % Two tabs: rendered image + knots/coefs dump. Bins, knots,
            % and coefs are recovered from the page-1 ImageDescription
            % JSON (written by runSplineBasis) so this reconstructs the
            % .mat preview without needing the .mat alongside.
            info = imfinfo(p);
            meta = struct();
            if ~isempty(info) && isfield(info,'ImageDescription') && ...
                    ~isempty(info(1).ImageDescription)
                try, meta = jsondecode(info(1).ImageDescription); catch, end
            end

            tg = uitabgroup(app.ResultsBrowserPreviewBody, ...
                'Units','normalized','Position',[0 0 1 1]);

            % --- Tab 1: rendered splinefit (page 2) ---
            tS = uitab(tg, 'Title','splinefit');
            gS = uigridlayout(tS);
            gS.ColumnWidth = {'1x'}; gS.RowHeight = {'1x'};
            gS.Padding = [12 12 12 12];
            axS = uiaxes(gS, 'BackgroundColor','white');
            axS.Layout.Row = 1; axS.Layout.Column = 1;
            try
                if numel(info) >= 2
                    M = double(imread(p, 2));
                else
                    M = double(imread(p, 1));
                end
                freq_bins = []; so_bins = [];
                binsField = ['SO' axis_kind '_bins'];
                if isfield(meta, 'freq_bins'),    freq_bins = meta.freq_bins(:); end
                if isfield(meta, binsField),      so_bins   = meta.(binsField)(:); end
                app.styleSOPHAxes(axS, M, freq_bins, so_bins, axis_kind);
                title(axS, 'Spline-fitted SOPH');
                app.attachPopOutToolbar(axS, ...
                    @(a) app.styleSOPHAxes(a, M, freq_bins, so_bins, axis_kind), ...
                    'Spline-fitted SOPH');
            catch ME
                axis(axS,'off');
                text(axS, 0.5, 0.5, sprintf('render failed: %s', ME.message), ...
                    'HorizontalAlignment','center','Color','red');
            end

            % --- Tab 2: knots / coefs dump (knots from metadata, coefs
            %     from page 1 of the TIFF). Mirrors the .mat preview's
            %     text dump so the two views agree.
            tI = uitab(tg, 'Title','knots / coefs');
            ta = app.makeFillTextArea(tI);
            lines = {};
            if isfield(meta, 'knots_x')
                lines = [lines; {'--- knots_x ---'}; ...
                    splitlines(string(evalc('disp(meta.knots_x(:).'')')))];
            end
            if isfield(meta, 'knots_y')
                lines = [lines; {'--- knots_y ---'}; ...
                    splitlines(string(evalc('disp(meta.knots_y(:).'')')))];
            end
            try
                coefs = double(imread(p, 1));
                lines = [lines; {sprintf('--- coefs (%d×%d) ---', ...
                    size(coefs,1), size(coefs,2))}; ...
                    splitlines(string(evalc('disp(coefs)')))];
            catch
                % Page 1 unreadable; skip the dump silently.
            end
            ta.Value = cellstr(lines);
        end

        function previewMatAuxiliary(app, p)
            % Single-panel mirror of displaySummaryPlot's hypn_spect_ax(1)
            % and hypn_spect_ax(3): properties table on top, hypnogram
            % with artifacts in the middle, SOpower trace below.
            S  = load(p);
            AD = S.auxiliary_data;

            g = uigridlayout(app.ResultsBrowserPreviewBody);
            g.ColumnWidth = {'1x'};
            g.RowHeight   = {70, '1x', '1x'};
            g.RowSpacing  = 6;
            g.Padding     = [6 6 6 6];

            % --- Row 1: properties table ---
            propRows = {
                'Fs (Hz)',              num2str(AD.Fs)
                'SOpower norm method',  char(string(AD.SOpower_norm_method))
                };
            ut = uitable(g);
            ut.Layout.Row    = 1; ut.Layout.Column = 1;
            ut.Data          = propRows;
            ut.ColumnName    = {'Property','Value'};
            ut.ColumnWidth   = {180, 'auto'};
            ut.RowName       = [];

            % --- Row 2: hypnogram with artifacts overlay ---
            axH = uiaxes(g, 'BackgroundColor','white');
            axH.Layout.Row = 2; axH.Layout.Column = 1;
            try
                stage_t = double(AD.stage_times(:)') / 3600;     % hours
                if isfield(AD,'artifacts') && ~isempty(AD.artifacts) && ...
                        isfield(AD,'Fs') && AD.Fs > 0
                    N    = numel(AD.artifacts);
                    tArt = (0:N-1) / double(AD.Fs) / 3600;       % hours
                    hypnoplot(axH, stage_t, double(AD.stage_vals(:)'), ...
                        'Artifacts', logical(AD.artifacts), ...
                        'ArtifactTimes', tArt, ...
                        'TimesUnit', 'hours');
                else
                    hypnoplot(axH, stage_t, double(AD.stage_vals(:)'), ...
                        'TimesUnit', 'hours');
                end
                title(axH, 'Sleep Hypnogram');
            catch ME
                cla(axH); axis(axH, 'off');
                text(axH, 0.5, 0.5, sprintf('hypnoplot failed: %s', ME.message), ...
                    'HorizontalAlignment','center', 'Color', 'red', ...
                    'Interpreter','none');
            end

            % --- Row 3: SOpower trace ---
            axP = uiaxes(g, 'BackgroundColor','white');
            axP.Layout.Row = 3; axP.Layout.Column = 1;
            if isfield(AD,'SOpower_norm') && ~isempty(AD.SOpower_norm) && ...
                    isfield(AD,'Fs') && AD.Fs > 0
                N    = numel(AD.SOpower_norm);
                tHr  = (0:N-1) / double(AD.Fs) / 3600;
                plot(axP, tHr, double(AD.SOpower_norm), 'LineWidth', 1.2);
                methodStr = char(string(AD.SOpower_norm_method));
                switch methodStr
                    case 'percent',    ylab = 'Normalized SOP (%)';
                    case 'proportion', ylab = 'Normalized SOP (proportion)';
                    otherwise,         ylab = 'Normalized SOP (dB)';
                end
                ylabel(axP, ylab);
                xlabel(axP, 'Time (hr)');
                grid(axP, 'on');
                if ~isempty(tHr)
                    xlim(axP, [tHr(1) tHr(end)]);
                end
                title(axP, sprintf('Normalized Slow Oscillation Power (%s)', methodStr));
                try, linkaxes([axH, axP], 'x'); catch, end
            else
                axis(axP, 'off');
                text(axP, 0.5, 0.5, '(no SOpower_norm data)', ...
                    'HorizontalAlignment','center', 'Color',[0.45 0.5 0.55]);
            end
        end

        function previewMatStatsTable(app, p)
            % previewMatStatsTable  Render a TFpeaks stats_table .mat as
            % a sortable uitable filling the preview pane.
            S = load(p);
            ut = uitable(app.ResultsBrowserPreviewBody);
            ut.Units = 'normalized'; ut.Position = [0 0 1 1];
            ut.Data = S.stats_table; ut.ColumnSortable = true;
        end

        function previewMatAggregate(app, p)
            % previewMatAggregate  Render an aggregate .mat — handles
            % both shapes the aggregator emits: a stacked paramfit
            % `params` table (uitable) and a 3-D SOPHs volume keyed by
            % subject (page slider over an imagesc per subject).
            import results_browser.*
            S = load(p);
            agg = S.aggregate;

            % --- Paramfit aggregate: aggregate.params is a stacked table.
            if isfield(agg, 'params') && istable(agg.params)
                ut = uitable(app.ResultsBrowserPreviewBody);
                ut.Units = 'normalized'; ut.Position = [0 0 1 1];
                ut.Data = agg.params; ut.ColumnSortable = true;
                return
            end

            % --- SOPHs aggregate: 3-D power or phase volume + page slider.
            if isfield(agg, 'SOpower_mat'), axis_kind = 'power';
            elseif isfield(agg, 'SOphase_mat'), axis_kind = 'phase';
            else
                app.renderResultsBrowserPreviewMessage( ...
                    'Unknown aggregate shape (no params / SO*_mat).');
                return
            end
            field = ['SO' axis_kind '_mat'];
            V = agg.(field);            % Nfreq × Nbin × Nsubj
            nSubj = size(V, 3);
            ids = {};
            if isfield(agg, 'subjectIDs'), ids = cellstr(string(agg.subjectIDs(:))); end

            g = uigridlayout(app.ResultsBrowserPreviewBody);
            g.ColumnWidth = {'1x'}; g.RowHeight = {'1x', 36};
            g.RowSpacing = 6; g.Padding = [12 12 12 12];

            ax = uiaxes(g, 'BackgroundColor','white');
            ax.Layout.Row = 1; ax.Layout.Column = 1;

            sliderRow             = uigridlayout(g);
            sliderRow.ColumnWidth = {70, '1x', 60};
            sliderRow.RowHeight   = {'1x'};
            sliderRow.ColumnSpacing = 8;
            sliderRow.Padding     = [0 0 0 0];
            sliderRow.Layout.Row  = 2; sliderRow.Layout.Column = 1;

            ed = CSSuiNumericField(sliderRow, ...
                'Style', app.AppStyle, ...
                'Min', 1, 'Max', max(1, nSubj), ...
                'Value', 1, ...
                'Format', '%d', ...
                'HorizontalAlignment', 'center');
            ed.Layout.Column = 1;
            sl = uislider(sliderRow, 'Limits',[1 max(1,nSubj)], 'Value', 1, ...
                'MajorTicks', sparseSliderTicks(nSubj), ...
                'MinorTicks', []);
            sl.Layout.Column = 2;
            uilabel(sliderRow, 'Text', sprintf('of %d', nSubj), ...
                'HorizontalAlignment','right');

            renderPage(1);
            sl.ValueChangedFcn = @(s,~) jumpTo(round(s.Value));
            ed.ValueChangedFcn = @(s,~) jumpTo(round(s.Value));

            function jumpTo(k)
                k = max(1, min(nSubj, round(k)));
                if sl.Value ~= k, sl.Value = k; end
                if ed.Value ~= k, ed.Value = k; end
                renderPage(k);
            end

            function renderPage(k)
                k = max(1, min(nSubj, k));
                M = V(:,:,k);
                cla(ax);
                bins = []; freq_bins = [];
                if isfield(agg, ['SO' axis_kind '_bins']), bins = agg.(['SO' axis_kind '_bins'])(:); end
                if isfield(agg, 'freq_bins'), freq_bins = agg.freq_bins(:); end
                app.styleSOPHAxes(ax, M, freq_bins, bins, axis_kind);
                if k <= numel(ids)
                    title(ax, sprintf('Subject %d/%d — %s', k, nSubj, ids{k}), ...
                        'Interpreter','none');
                else
                    title(ax, sprintf('Subject %d/%d', k, nSubj));
                end
            end
        end

        % ------------------------------------------------------------------
        % Generic .mat fallback — variable tree on the left, type-aware
        % renderer on the right. Caches the loaded struct so node clicks
        % don't re-read the file.
        % ------------------------------------------------------------------

        function renderResultsBrowserPreviewMatGeneric(app, p, info)
            % renderResultsBrowserPreviewMatGeneric  Generic .mat browser
            % used when no smart-case applies: a left-side variable tree
            % (one node per top-level variable, expandable into struct
            % fields and cell elements) paired with a right-side
            % type-aware viewer (uitable / imagesc / page slider /
            % uitextarea). Caches the loaded struct on the app so node
            % clicks don't re-load the file.
            import results_browser.*
            try
                S = load(p);
            catch ME
                app.renderResultsBrowserPreviewMessage( ...
                    sprintf('load() failed:\n%s', ME.message));
                return
            end
            app.MatPreviewCache_.path = p;
            app.MatPreviewCache_.S    = S;

            g = uigridlayout(app.ResultsBrowserPreviewBody);
            g.ColumnWidth  = {220, '1x'};
            g.RowHeight    = {'1x'};
            g.ColumnSpacing = 4; g.RowSpacing = 0;
            g.Padding = [4 4 4 4];

            tree = uitree(g);
            tree.Layout.Row = 1; tree.Layout.Column = 1;

            rightPanel = uipanel(g, 'BorderType','none', 'BackgroundColor','white');
            rightPanel.Layout.Row = 1; rightPanel.Layout.Column = 2;

            for ii = 1:numel(info)
                nm = info(ii).name;
                build_var_node(tree, nm, S.(nm), nm);
            end
            tree.SelectionChangedFcn = @(t,e) onSelect(e);
            % Auto-render the first leaf so the right pane isn't empty.
            firstLeaf = find_first_leaf(tree);
            if ~isempty(firstLeaf)
                tree.SelectedNodes = firstLeaf;
                renderNode(firstLeaf);
            end

            function onSelect(e)
                if isempty(e.SelectedNodes), return, end
                renderNode(e.SelectedNodes(1));
            end

            function renderNode(node)
                if isempty(node) || isempty(node.NodeData), return, end
                % NodeData carries the dotted path (e.g. 'SOPHs.SOpower_mat')
                val = resolve_path(S, node.NodeData);
                delete(rightPanel.Children);
                app.renderMatNodeValue(rightPanel, val, node.NodeData);
            end
        end

        function renderMatNodeValue(app, parent, val, label)
            % Type-aware render of a single .mat node into `parent`
            % (a uipanel or grid). `label` is the dotted variable path.

            if istable(val)
                ut = uitable(parent);
                ut.Units = 'normalized'; ut.Position = [0 0 1 1];
                ut.Data = val; ut.ColumnSortable = true;
                return
            end

            if ischar(val) || isstring(val)
                ta = app.makeFillTextArea(parent);
                ta.Value = cellstr(string(val));
                return
            end

            if isstruct(val) || iscell(val)
                ta = app.makeFillTextArea(parent);
                ta.Value = cellstr(splitlines(string(evalc('disp(val)'))));
                return
            end

            if islogical(val) || isnumeric(val)
                sz = size(val);
                if isscalar(val)
                    uilabel(parent, 'Text', sprintf('%s = %s', label, num2str(val)), ...
                        'Position',[10 10 600 30]);
                    return
                end
                if numel(sz) == 2 && (sz(1) == 1 || sz(2) == 1)
                    ax = uiaxes(parent, 'Units','normalized','Position',[0 0 1 1], ...
                        'BackgroundColor','white');
                    plot(ax, double(val(:)));
                    grid(ax,'on');
                    title(ax, sprintf('%s (%dx%d)', label, sz(1), sz(2)), ...
                        'Interpreter','none');
                    return
                end
                if numel(sz) == 2
                    ax = uiaxes(parent, 'Units','normalized','Position',[0 0 1 1], ...
                        'BackgroundColor','white');
                    imagesc(ax, double(val));
                    axis(ax,'xy'); colormap(ax,parula); colorbar(ax);
                    title(ax, sprintf('%s (%dx%d)', label, sz(1), sz(2)), ...
                        'Interpreter','none');
                    return
                end
                if numel(sz) == 3
                    nP = sz(3);
                    g = uigridlayout(parent);
                    g.ColumnWidth = {'1x'}; g.RowHeight = {'1x', 32};
                    g.Padding = [4 4 4 4];
                    ax = uiaxes(g, 'BackgroundColor','white');
                    ax.Layout.Row = 1; ax.Layout.Column = 1;
                    sliderRow             = uigridlayout(g);
                    sliderRow.ColumnWidth = {'1x', '5x', '2x'};
                    sliderRow.Padding     = [0 0 0 0];
                    sliderRow.Layout.Row  = 2;
                    uilabel(sliderRow, 'Tag','genPgLabel', 'Text','Page 1');
                    sl = uislider(sliderRow, 'Limits',[1 max(1,nP)], 'Value',1, ...
                        'MajorTicks',[],'MinorTicks',[]);
                    sl.Layout.Column = 2;
                    uilabel(sliderRow, 'Text', sprintf('of %d', nP), ...
                        'HorizontalAlignment','right');
                    app.drawMatVolumePage(ax, sliderRow, val, label, 1);
                    sl.ValueChangedFcn = @(s,e) ...
                        app.drawMatVolumePage(ax, sliderRow, val, label, round(s.Value));
                    return
                end
            end

            % Fallback: text dump.
            ta = app.makeFillTextArea(parent);
            ta.Value = cellstr(splitlines(string(evalc('disp(val)'))));
        end

        function ta = makeFillTextArea(~, parent)
            % uitextarea has no Units property — wrap it in a fill grid
            % so it stretches to the parent (uitab / uipanel / uifigure).
            g = uigridlayout(parent);
            g.RowHeight   = {'1x'};
            g.ColumnWidth = {'1x'};
            g.Padding     = [0 0 0 0];
            ta = uitextarea(g);
            ta.Editable = 'off';
        end

        function drawMatVolumePage(~, ax, sliderRow, val, label, k)
            % drawMatVolumePage  Draw the k-th page of a 3-D numeric
            % array into the given axes, clamping k to [1, nP] and
            % updating the page-counter label in `sliderRow`.
            nP = size(val, 3);
            k  = max(1, min(nP, k));
            cla(ax);
            imagesc(ax, double(val(:,:,k)));
            axis(ax,'xy'); colormap(ax,parula); colorbar(ax);
            title(ax, sprintf('%s page %d/%d', label, k, nP), ...
                'Interpreter','none');
            lblObj = findobj(sliderRow,'Tag','genPgLabel');
            if ~isempty(lblObj), lblObj.Text = sprintf('Page %d', k); end
        end

        function renderResultsBrowserPreviewImage(app, p)
            % renderResultsBrowserPreviewImage  Render a still image
            % (PNG/JPG/BMP) into the preview pane via imshow, with a
            % pop-out toolbar button that opens the same image in a
            % separate figure.
            delete(app.ResultsBrowserPreviewBody.Children);
            img = imread(p);
            ax = uiaxes(app.ResultsBrowserPreviewBody, ...
                'Units','normalized','Position',[0 0 1 1], ...
                'BackgroundColor','white');
            imshow(img, 'Parent', ax);
            app.attachPopOutToolbar(ax, ...
                @(a) imshow(img, 'Parent', a), p);
        end

        function renderResultsBrowserPreviewTiff(app, p)
            % SOPH TIFFs (per-subject and aggregate) get the same look
            % as the Analysis → SO-Histograms tab: transposed imagesc
            % with the right colormap, freq clip to 2–16 Hz, x-axis
            % matched to bin metadata, mean across pages for multi-page
            % aggregates. Generic multi-page TIFFs fall back to a page
            % slider with parula.
            import results_browser.*
            [~, base, ~] = fileparts(p);
            baseLower = lower(base);
            if contains(baseLower, 'sophs_power')
                axis_kind = 'power';
            elseif contains(baseLower, 'sophs_phase')
                axis_kind = 'phase';
            else
                axis_kind = '';
            end

            % Splinefit TIFFs (page 1 = coefs, page 2 = rendered fit)
            % get a dedicated 2-tab preview that mirrors the .mat
            % splinefit preview: rendered image + knots/coefs dump.
            isSplineTiff = contains(baseLower, 'splinefit');
            if isSplineTiff
                if contains(baseLower, 'sopower'),       splineAxisKind = 'power';
                elseif contains(baseLower, 'sophase'),   splineAxisKind = 'phase';
                else,                                    splineAxisKind = 'power';
                end
                delete(app.ResultsBrowserPreviewBody.Children);
                app.renderSplinefitTiffPreview(p, splineAxisKind);
                return
            end

            delete(app.ResultsBrowserPreviewBody.Children);

            if ~isempty(axis_kind)
                info  = imfinfo(p);
                nPage = numel(info);
                % Recover bins from the TIFF metadata or sidecar/settings.
                [freq_bins, bins] = app.peekSOPHTiffBins(p, info, axis_kind);

                if nPage <= 1
                    % Wrap in a padded grid so the SOPH image breathes.
                    gOne = uigridlayout(app.ResultsBrowserPreviewBody);
                    gOne.ColumnWidth = {'1x'}; gOne.RowHeight = {'1x'};
                    gOne.Padding = [12 12 12 12];
                    ax = uiaxes(gOne, 'BackgroundColor','white');
                    ax.Layout.Row = 1; ax.Layout.Column = 1;
                    M = double(imread(p, 1));
                    app.styleSOPHAxes(ax, M, freq_bins, bins, axis_kind);
                    title(ax, sprintf('SO-%s Histogram', upper(axis_kind(1))), ...
                        'Interpreter','none');
                    app.attachPopOutToolbar(ax, ...
                        @(a) app.replotSOPHTiffPage(a, p, axis_kind, 1), ...
                        sprintf('SO-%s Histogram', upper(axis_kind(1))));
                    return
                end

                % Multi-page aggregate TIFF: page slider + numeric edit
                % so a 1000-subject aggregate is still navigable.
                g = uigridlayout(app.ResultsBrowserPreviewBody);
                g.ColumnWidth = {'1x'}; g.RowHeight = {'1x', 36};
                g.RowSpacing = 6; g.Padding = [12 12 12 12];

                ax = uiaxes(g, 'BackgroundColor','white');
                ax.Layout.Row = 1; ax.Layout.Column = 1;

                sliderRow             = uigridlayout(g);
                sliderRow.ColumnWidth = {70, '1x', 60};
                sliderRow.RowHeight   = {'1x'};
                sliderRow.ColumnSpacing = 8;
                sliderRow.Padding     = [0 0 0 0];
                sliderRow.Layout.Row  = 2; sliderRow.Layout.Column = 1;

                ed = CSSuiNumericField(sliderRow, ...
                    'Style', app.AppStyle, ...
                    'Min', 1, 'Max', nPage, ...
                    'Value', 1, ...
                    'Format', '%d', ...
                    'HorizontalAlignment', 'center');
                ed.Layout.Column = 1;
                sl = uislider(sliderRow, 'Limits',[1 nPage], 'Value', 1, ...
                    'MajorTicks', sparseSliderTicks(nPage), ...
                    'MinorTicks', []);
                sl.Layout.Column = 2;
                uilabel(sliderRow, 'Text', sprintf('of %d', nPage), ...
                    'HorizontalAlignment','right');

                ctx = struct('ax', ax, 'sliderRow', sliderRow, ...
                    'slider', sl, 'edit', ed, ...
                    'path', p, 'axis_kind', axis_kind, 'nPage', nPage, ...
                    'freq_bins', freq_bins, 'bins', bins);
                app.renderSOPHTiffSliderPage(ctx, 1);
                sl.ValueChangedFcn = @(s,~) app.jumpSOPHTiff(ctx, round(s.Value));
                ed.ValueChangedFcn = @(s,~) app.jumpSOPHTiff(ctx, round(s.Value));
                app.attachPopOutToolbar(ax, ...
                    @(a) app.replotSOPHTiffPage(a, p, axis_kind, 1), ...
                    sprintf('SO-%s Histogram', upper(axis_kind(1))));
                return
            end

            % --- Generic TIFF fallback (rare): page-by-page browser ---
            info  = imfinfo(p);
            nPage = numel(info);
            if nPage <= 1
                ax = uiaxes(app.ResultsBrowserPreviewBody, ...
                    'Units','normalized','Position',[0 0 1 1], ...
                    'BackgroundColor','white');
                M = double(imread(p, 1));
                imagesc(ax, M); colormap(ax, parula); axis(ax,'image','xy');
                colorbar(ax);
                app.attachPopOutToolbar(ax, ...
                    @(a) drawImagescFigure(a, M), p);
                return
            end

            g = uigridlayout(app.ResultsBrowserPreviewBody);
            g.ColumnWidth = {'1x'}; g.RowHeight = {'1x', 32};
            g.RowSpacing = 2; g.Padding = [4 4 4 4];

            ax = uiaxes(g);
            ax.Layout.Row = 1; ax.Layout.Column = 1;
            ax.BackgroundColor = 'white';

            sliderRow             = uigridlayout(g);
            sliderRow.ColumnWidth = {80, '1x', 60};
            sliderRow.RowHeight   = {'1x'};
            sliderRow.Padding     = [0 0 0 0];
            sliderRow.Layout.Row  = 2; sliderRow.Layout.Column = 1;

            uilabel(sliderRow, 'Text', sprintf('Page 1/%d', nPage), ...
                'Tag','tiffPageLabel', ...
                'HorizontalAlignment','left');
            sl = uislider(sliderRow, 'Limits',[1 nPage], 'Value', 1, ...
                'MajorTicks',[], 'MinorTicks',[]);
            sl.Layout.Column = 2;
            uilabel(sliderRow, 'Text', sprintf('of %d', nPage), ...
                'HorizontalAlignment','right');

            renderPage(1);
            sl.ValueChangedFcn = @(s,e) renderPage(round(s.Value));

            function renderPage(k)
                k = max(1, min(nPage, k));
                M = double(imread(p, k));
                cla(ax);
                imagesc(ax, M); colormap(ax, parula); axis(ax,'image','xy');
                colorbar(ax);
                lbl = findobj(sliderRow,'Tag','tiffPageLabel');
                if ~isempty(lbl), lbl.Text = sprintf('Page %d/%d', k, nPage); end
            end
        end

        function renderResultsBrowserPreviewCsv(app, p)
            % renderResultsBrowserPreviewCsv  Render a CSV in the preview
            %   pane. If the file starts with a `# DYNAM-O parametric fit`
            %   comment header (written by writeParamfitCsv), shows a
            %   tabbed layout that mirrors the .mat paramfit preview:
            %     - "params"   : the params table (sortable)
            %     - "fit info" : gof + fitobj coefs + background plane +
            %                    unit_row + bins, formatted as a text
            %                    dump (matches the .mat fit info tab)
            %   Plain CSVs render as a single sortable table.
            delete(app.ResultsBrowserPreviewBody.Children);

            headerLines = local_peekCommentHeader(p);
            isParamfit  = ~isempty(headerLines) && ...
                          contains(headerLines{1}, 'DYNAM-O parametric fit');

            if isParamfit
                hdr     = local_parseHeaderToStruct(headerLines);
                paramsT = readtable(p, 'CommentStyle','#');

                tg = uitabgroup(app.ResultsBrowserPreviewBody, ...
                    'Units','normalized','Position',[0 0 1 1]);

                % --- params table tab ---
                tP = uitab(tg, 'Title', sprintf('params (%d×%d)', ...
                    height(paramsT), width(paramsT)));
                utp = uitable(tP);
                utp.Units    = 'normalized'; utp.Position = [0 0 1 1];
                utp.Data     = paramsT;
                utp.ColumnSortable = true;

                % --- fit info tab (text dump, matches the .mat preview) ---
                tG = uitab(tg, 'Title', 'fit info');
                ta = app.makeFillTextArea(tG);
                ta.Value = local_buildFitInfoLines(hdr);
            else
                T = readtable(p);
                ut = uitable(app.ResultsBrowserPreviewBody);
                ut.Units    = 'normalized';
                ut.Position = [0 0 1 1];
                ut.Data     = T;
                ut.ColumnSortable = true;
            end

            % --- nested helpers ---
            function L = local_peekCommentHeader(filename)
                L = {};
                fid = fopen(filename, 'r');
                if fid < 0, return, end
                cu = onCleanup(@() fclose(fid)); %#ok<NASGU>
                for k = 1:50
                    ln = fgetl(fid);
                    if ~ischar(ln), break, end
                    s = strtrim(ln);
                    if startsWith(s, '#')
                        L{end+1} = s; %#ok<AGROW>
                    elseif isempty(s)
                        % Tolerate blank lines inside a header block
                        continue
                    else
                        break
                    end
                end
            end
            function H = local_parseHeaderToStruct(lines)
                % Parse '# key: value' lines into a struct. JSON arrays
                % decode to numeric / cellstr; scalars to double; the
                % rest stay char.
                H = struct();
                for k = 1:numel(lines)
                    s = regexprep(lines{k}, '^#\s*', '');
                    if isempty(s), continue, end
                    idx = strfind(s, ':');
                    if isempty(idx), continue, end
                    key = strtrim(s(1:idx(1)-1));
                    val = strtrim(s(idx(1)+1:end));
                    fld = matlab.lang.makeValidName(key);
                    if startsWith(val, '[') || startsWith(val, '"')
                        try, H.(fld) = jsondecode(val); continue, catch, end
                    end
                    n = str2double(val);
                    if ~isnan(n) || strcmpi(val, 'nan')
                        H.(fld) = n;
                    else
                        H.(fld) = val;
                    end
                end
            end
            function L = local_buildFitInfoLines(H)
                % Mirror of the .mat preview's "fit info" tab: a flat
                % text dump grouped by section. Sections are skipped
                % silently when the corresponding header field is
                % missing — older paramfit CSVs without fitobj coefs
                % still get a useful gof/background block.
                L = {};
                if isfield(H,'fit_type') || isfield(H,'n_modes') || isfield(H,'version')
                    L = [L; {'--- summary ---'}];
                    if isfield(H,'fit_type'), L = [L; {sprintf('  fit_type: %s', char(string(H.fit_type)))}]; end
                    if isfield(H,'n_modes'),  L = [L; {sprintf('  n_modes : %g', H.n_modes)}]; end
                    if isfield(H,'version'),  L = [L; {sprintf('  version : %g', H.version)}]; end
                    L = [L; {''}];
                end
                gofKeys  = {'sse','rsquare','dfe','adjrsquare','rmse'};
                gofPres  = false;
                for kk = 1:numel(gofKeys)
                    if isfield(H, ['gof_' gofKeys{kk}]), gofPres = true; break, end
                end
                if gofPres
                    L = [L; {'--- gof ---'}];
                    for kk = 1:numel(gofKeys)
                        f = ['gof_' gofKeys{kk}];
                        if isfield(H, f)
                            L = [L; {sprintf('  %-10s: %.6g', gofKeys{kk}, H.(f))}];
                        end
                    end
                    L = [L; {''}];
                end
                if isfield(H,'fitobj_coefnames') && isfield(H,'fitobj_coefvalues')
                    cn = H.fitobj_coefnames;
                    cv = H.fitobj_coefvalues;
                    if iscell(cn) || (isstring(cn) && numel(cn) > 1)
                        cn = cellstr(cn);
                    end
                    if isnumeric(cv), cv = double(cv); end
                    if numel(cn) == numel(cv)
                        L = [L; {'--- fitobj coefficients ---'}];
                        for kk = 1:numel(cn)
                            L = [L; {sprintf('  %-12s: %.6g', cn{kk}, cv(kk))}];
                        end
                        L = [L; {''}];
                    end
                end
                bgKeys = {'background_xxx','background_yyy','background_zzz','unit_row'};
                bgPres = any(cellfun(@(k) isfield(H,k), bgKeys));
                if bgPres
                    L = [L; {'--- background plane ---'}];
                    for kk = 1:numel(bgKeys)
                        if isfield(H, bgKeys{kk})
                            L = [L; {sprintf('  %-12s: %.6g', bgKeys{kk}, H.(bgKeys{kk}))}];
                        end
                    end
                    L = [L; {''}];
                end
                if isfield(H,'freq_bins') || isfield(H,'SOpower_bins') || isfield(H,'SOphase_bins')
                    L = [L; {'--- bins ---'}];
                    if isfield(H,'freq_bins')
                        fb = H.freq_bins(:).';
                        L = [L; {sprintf('  freq_bins (n=%d, range=[%.3g, %.3g])', ...
                            numel(fb), min(fb), max(fb))}];
                        L = [L; splitlines(string(evalc('disp(fb)')))];
                    end
                    if isfield(H,'SOpower_bins')
                        sb = H.SOpower_bins(:).';
                        L = [L; {sprintf('  SOpower_bins (n=%d, range=[%.3g, %.3g])', ...
                            numel(sb), min(sb), max(sb))}];
                        L = [L; splitlines(string(evalc('disp(sb)')))];
                    end
                    if isfield(H,'SOphase_bins')
                        sb = H.SOphase_bins(:).';
                        L = [L; {sprintf('  SOphase_bins (n=%d, range=[%.3g, %.3g])', ...
                            numel(sb), min(sb), max(sb))}];
                        L = [L; splitlines(string(evalc('disp(sb)')))];
                    end
                end
                L = cellstr(L);
            end
        end

        function renderResultsBrowserPreviewText(app, p)
            % renderResultsBrowserPreviewText  Render a text file in a
            % read-only uitextarea. Truncates to 5000 lines so very
            % large logs/CSVs don't lock up the UI.
            delete(app.ResultsBrowserPreviewBody.Children);
            ta = app.makeFillTextArea(app.ResultsBrowserPreviewBody);
            try
                txt = fileread(p);
                lines = strsplit(txt, newline);
                if numel(lines) > 5000
                    lines = [lines(1:5000), {sprintf('… (truncated, %d more lines)', ...
                                                     numel(lines)-5000)}];
                end
                ta.Value = lines;
            catch ME
                ta.Value = {sprintf('Read failed: %s', ME.message)};
            end
        end

        % ------------------------------------------------------------------

        function openResultsBrowserNode(app, evt)
            % openResultsBrowserNode  Open the double-clicked file leaf in
            % the OS default application via openInOS.
            if ~isfield(evt,'NodeData') || isempty(evt.NodeData), return; end
            p = evt.NodeData;
            if ~ischar(p) && ~(isstring(p) && isscalar(p)), return; end
            app.openInOS(char(p));
        end
        % ------------------------------------------------------------------
        % Mode Scatter — paramfit-aggregate scatter view
        % ------------------------------------------------------------------

        function attachPopOutToolbar(app, ax, popFcn, ttl)
            % attachPopOutToolbar  Add a 'Pop out to figure' button to
            % the axes toolbar. popFcn is @(newAx) -> draws into newAx.
            % ttl is used as the figure name and axes title (optional).
            % The toolbar appears on hover at the top-right of the axes;
            % right-click on uiaxes covered by imagesc swallows events,
            % so this is the dependable hook.
            try
                tb  = axtoolbar(ax, 'default');
                btn = axtoolbarbtn(tb, 'push', ...
                    'Icon', 'export', ...
                    'Tooltip', 'Pop out to figure');
                btn.ButtonPushedFcn = @(~,~) app.popOutToFigure(popFcn, ttl);
            catch
                % axtoolbar can fail on some legacy graphics contexts;
                % silently skip the button rather than blocking the plot.
            end
        end

        function popOutToFigure(~, popFcn, ttl)
            % popOutToFigure  Open a separate MATLAB figure and call
            % popFcn(ax) into it — used by axes pop-out toolbar buttons
            % so users can detach a plot for save/zoom/copy.
            if nargin < 3, ttl = ''; end
            f  = figure('Color','w', 'NumberTitle','off');
            if ~isempty(ttl), f.Name = ttl; end
            ax = axes(f);
            popFcn(ax);
            if ~isempty(ttl), title(ax, ttl, 'Interpreter','none'); end
        end

        function plotAggregateSOHist(app, ax, filePath, axis_kind)
            % plotAggregateSOHist  Read aggregate, mean across subjects,
            % render with displaySummaryPlot styling.
            import results_browser.*
            field     = ['SO' axis_kind '_mat'];
            binsField = ['SO' axis_kind '_bins'];

            freq_bins = []; bins = []; M = [];
            try
                [~, ~, ext] = fileparts(filePath);
                switch lower(ext)
                    case '.mat'
                        S = load(filePath);
                        if     isfield(S, 'aggregate'), agg = S.aggregate;
                        elseif isfield(S, 'SOPHs'),     agg = S.SOPHs;
                        else,                           agg = S;
                        end
                        if isfield(agg, field) && ~isempty(agg.(field))
                            M = mean(agg.(field), 3, 'omitnan');
                        end
                        if isfield(agg, 'freq_bins'), freq_bins = agg.freq_bins(:); end
                        if isfield(agg, binsField),   bins      = agg.(binsField)(:); end
                    case '.tiff'
                        info = imfinfo(filePath);
                        accum = double(imread(filePath, 1));
                        for pp = 2:numel(info)
                            accum = accum + double(imread(filePath, pp));
                        end
                        M = accum / numel(info);
                        % First try the TIFF's own ImageDescription tag;
                        % aggregates and per-subject TIFFs written by
                        % current DYNAMO carry bins there as JSON.
                        if isfield(info,'ImageDescription') && ~isempty(info(1).ImageDescription)
                            try
                                meta = jsondecode(info(1).ImageDescription);
                                if isfield(meta,'freq_bins'), freq_bins = meta.freq_bins(:); end
                                bf = ['SO' axis_kind '_bins'];
                                if isfield(meta, bf), bins = meta.(bf)(:); end
                            catch
                                % Tag present but unparseable — fall through.
                            end
                        end
                        % Sidecar *_bins.csv covers older aggregates.
                        if isempty(freq_bins) || isempty(bins)
                            [d, n, ~] = fileparts(filePath);
                            binsCsv = fullfile(d, [n '_bins.csv']);
                            if isfile(binsCsv)
                                try
                                    B = readtable(binsCsv);
                                    if isempty(freq_bins) && any(strcmp(B.Properties.VariableNames,'freq'))
                                        fb = B.freq(~isnan(B.freq)); freq_bins = fb(:);
                                    end
                                    axisCol = ['SO' axis_kind];
                                    if isempty(bins) && any(strcmp(B.Properties.VariableNames, axisCol))
                                        sb = B.(axisCol)(~isnan(B.(axisCol))); bins = sb(:);
                                    end
                                catch
                                    % Bins CSV unreadable; fall back to pixel indices.
                                end
                            end
                        end
                        % Per-subject TIFFs (and aggregates without
                        % bins.csv) fall back to a run_settings dump
                        % found by walking up to ancestor folders. Only
                        % freq_bins and SOphase_bins are recoverable
                        % this way (SOpower bins are adaptive).
                        if isempty(freq_bins) || (isempty(bins) && strcmp(axis_kind,'phase'))
                            [fb2, sb2] = peek_bins_from_settings_walk(filePath, axis_kind);
                            if isempty(freq_bins) && ~isempty(fb2), freq_bins = fb2; end
                            if isempty(bins)      && ~isempty(sb2), bins      = sb2; end
                        end
                end
            catch ME
                axis(ax,'off');
                text(ax, 0.5, 0.5, sprintf('load failed: %s', ME.message), ...
                     'HorizontalAlignment','center','Color','red');
                return
            end

            if isempty(M)
                axis(ax,'off');
                text(ax, 0.5, 0.5, '(empty aggregate)', 'HorizontalAlignment','center');
                return
            end

            app.styleSOPHAxes(ax, M, freq_bins, bins, axis_kind);
        end

        function [freq_bins, bins] = peekSOPHTiffBins(~, filePath, info, axis_kind)
            % Recover (freq_bins, SO{power,phase}_bins) from a SOPH TIFF.
            % Order: ImageDescription JSON tag → sidecar *_bins.csv →
            % run_settings_*.txt walk. Returns [] for whichever can't
            % be recovered; caller falls back to pixel indices.
            import results_browser.*
            freq_bins = []; bins = [];
            if isfield(info,'ImageDescription') && ~isempty(info(1).ImageDescription)
                try
                    meta = jsondecode(info(1).ImageDescription);
                    if isfield(meta,'freq_bins'), freq_bins = meta.freq_bins(:); end
                    bf = ['SO' axis_kind '_bins'];
                    if isfield(meta, bf), bins = meta.(bf)(:); end
                catch
                end
            end
            if isempty(freq_bins) || isempty(bins)
                [d, n, ~] = fileparts(filePath);
                binsCsv = fullfile(d, [n '_bins.csv']);
                if isfile(binsCsv)
                    try
                        B = readtable(binsCsv);
                        if isempty(freq_bins) && any(strcmp(B.Properties.VariableNames,'freq'))
                            fb = B.freq(~isnan(B.freq)); freq_bins = fb(:);
                        end
                        axisCol = ['SO' axis_kind];
                        if isempty(bins) && any(strcmp(B.Properties.VariableNames, axisCol))
                            sb = B.(axisCol)(~isnan(B.(axisCol))); bins = sb(:);
                        end
                    catch
                    end
                end
            end
            if isempty(freq_bins) || (isempty(bins) && strcmp(axis_kind,'phase'))
                [fb2, sb2] = peek_bins_from_settings_walk(filePath, axis_kind);
                if isempty(freq_bins) && ~isempty(fb2), freq_bins = fb2; end
                if isempty(bins)      && ~isempty(sb2), bins      = sb2; end
            end
        end

        function renderSOPHTiffSliderPage(app, ctx, k)
            % Slider callback target — render page k of a multi-page SOPH
            % TIFF using cached metadata from ctx.
            k = max(1, min(ctx.nPage, k));
            M = double(imread(ctx.path, k));
            cla(ctx.ax);
            app.styleSOPHAxes(ctx.ax, M, ctx.freq_bins, ctx.bins, ctx.axis_kind);
            title(ctx.ax, sprintf('SO-%s Histogram — Subject %d/%d', ...
                upper(ctx.axis_kind(1)), k, ctx.nPage), 'Interpreter','none');
        end

        function jumpSOPHTiff(app, ctx, k)
            % jumpSOPHTiff  Move the multi-page SOPH TIFF preview to
            % page k. Clamps to [1, nPage], keeps both the slider and
            % the numeric edit field in sync (suppressing feedback
            % loops), and redraws the page.
            k = max(1, min(ctx.nPage, round(k)));
            if isfield(ctx,'slider') && isvalid(ctx.slider) && ctx.slider.Value ~= k
                ctx.slider.Value = k;
            end
            if isfield(ctx,'edit') && isvalid(ctx.edit) && ctx.edit.Value ~= k
                ctx.edit.Value = k;
            end
            app.renderSOPHTiffSliderPage(ctx, k);
        end

        function replotSOPHTiffPage(app, ax, filePath, axis_kind, pageIdx)
            % Pop-out closure target: render a single SOPH TIFF page to ax
            % with full styling (used so the popped figure carries the same
            % colormap / clipping / aspect as the inline preview).
            try
                info = imfinfo(filePath);
                pageIdx = max(1, min(numel(info), pageIdx));
                [freq_bins, bins] = app.peekSOPHTiffBins(filePath, info, axis_kind);
                M = double(imread(filePath, pageIdx));
                app.styleSOPHAxes(ax, M, freq_bins, bins, axis_kind);
            catch ME
                axis(ax,'off');
                text(ax, 0.5, 0.5, sprintf('load failed: %s', ME.message), ...
                    'HorizontalAlignment','center','Color','red');
            end
        end

        function [freq_bins, so_bins] = bins_for_paramfit(~, S, p, axis_kind)
            %BINS_FOR_PARAMFIT  Recover (freq_bins, SO<axis>_bins) for a
            %   paramfit / splinefit struct preview. Order:
            %     1. Direct fields on the struct (freq_bins, SO<axis>_bins).
            %     2. Embedded SOPH metadata (some saves stash a copy under
            %        a sub-struct called 'SOPH_options' or 'SOPHs').
            %     3. peek_bins_from_settings_walk on the file path —
            %        same fallback the SOPH TIFF preview uses, walks up
            %        to find run_settings_*.txt and reconstructs the bin
            %        centers from the recorded ranges.
            %   Returns [] for whichever can't be recovered; the caller
            %   (styleSOPHAxes) treats [] as "use bin indices" so the
            %   image still renders, just with integer ticks.
            import results_browser.*
            freq_bins = [];
            so_bins   = [];
            binsField = ['SO' axis_kind '_bins'];
            % Splinefit structs carry the FIT-DOMAIN bins (after the
            % validity-mask filter in spline_basis), not the source SOPH
            % bins — the splinefit/coefs matrices are sized to those
            % filtered bins, so previewing must use them or the axes
            % won't match the image dimensions. Check these first.
            if isfield(S, 'fit_freq_bins') && ~isempty(S.fit_freq_bins)
                freq_bins = S.fit_freq_bins(:);
            end
            if isfield(S, 'fit_SOfeature_bins') && ~isempty(S.fit_SOfeature_bins)
                so_bins = S.fit_SOfeature_bins(:);
            end
            if isempty(freq_bins) && isfield(S, 'freq_bins') && ~isempty(S.freq_bins)
                freq_bins = S.freq_bins(:);
            end
            if isempty(so_bins) && isfield(S, binsField) && ~isempty(S.(binsField))
                so_bins = S.(binsField)(:);
            end
            if isfield(S, 'SOPHs') && isstruct(S.SOPHs)
                if isempty(freq_bins) && isfield(S.SOPHs, 'freq_bins')
                    freq_bins = S.SOPHs.freq_bins(:);
                end
                if isempty(so_bins) && isfield(S.SOPHs, binsField)
                    so_bins = S.SOPHs.(binsField)(:);
                end
            end
            if isempty(freq_bins) || isempty(so_bins)
                [fb, sb] = peek_bins_from_settings_walk(p, axis_kind);
                if isempty(freq_bins), freq_bins = fb; end
                if isempty(so_bins),   so_bins   = sb; end
            end
        end

        function styleSOPHAxes(app, ax, M, freq_bins, bins, axis_kind)
            % Render a single (nSObins × nFreq) SOPH slice into `ax` with
            % displaySummaryPlot styling: imagesc with bins on x and
            % freq_bins on y, locked aspect, kind-appropriate colormap,
            % freq window 2–16 Hz, robust [5, 98]-prctile colour limits,
            % and a colorbar with a kind-appropriate label.
            if isempty(bins),      bins      = (1:size(M, 1)).'; end
            if isempty(freq_bins), freq_bins = (1:size(M, 2)).'; end

            imagesc(ax, bins, freq_bins, M.');
            axis(ax,'xy');
            pbaspect(ax, app.SOPHPlotBoxAspectRatio_);
            switch axis_kind
                case 'power'
                    try, colormap(ax, gouldian); catch, colormap(ax, parula); end
                    xlabel(ax, 'SO-Power (dB)');
                    colMask = any(M ~= 0 & isfinite(M), 2);
                    if any(colMask) && numel(bins) == numel(colMask)
                        xlim(ax, [bins(find(colMask,1,'first')), ...
                                  bins(find(colMask,1,'last' ))]);
                    end
                case 'phase'
                    try, colormap(ax, magma);   catch, colormap(ax, hot);    end
                    xlabel(ax, 'SO-Phase (rad)');
                    xlim(ax, [-pi pi]);
                    xticks(ax, [-pi -pi/2 0 pi/2 pi]);
                    xticklabels(ax, {'-\pi','-\pi/2','0','\pi/2','\pi'});
            end
            ylabel(ax, 'Frequency (Hz)');

            freq_lim = [max(2, min(freq_bins)), min(16, max(freq_bins))];
            if freq_lim(2) > freq_lim(1)
                ylim(ax, freq_lim);
                tmp_idx = freq_bins >= freq_lim(1) & freq_bins <= freq_lim(2);
                tmp = M(:, tmp_idx);
                tmp = tmp(tmp ~= 0 & isfinite(tmp));
                if ~isempty(tmp)
                    cp = prctile(tmp, [5, 98]);
                    if isfinite(cp(1)) && isfinite(cp(2)) && cp(2) > cp(1)
                        clim(ax, cp);
                    end
                end
            end
            cb = colorbar(ax);
            switch axis_kind
                case 'power', cb.Label.String = 'Density (peaks/min/bin)';
                case 'phase', cb.Label.String = 'Proportion';
            end
        end

        % ------------------------------------------------------------------

        function loadResultsBrowserTree(app)
            % loadResultsBrowserTree  Walk the chosen results root once,
            % build a JSON-friendly node tree, and hand it to the
            % CSSuiTree. All filtering thereafter is client-side (JS
            % toggles display:none on <li> nodes — no disk I/O, no
            % MATLAB rebuilds).
            import results_browser.*
            % Note: the entry-level drawnow that used to live here was a
            % first-call hot spot (~4-5s on a freshly-constructed
            % uifigure because it forced full layout before any work).
            % The status-pane logs and overlay flips below already pump
            % the event loop, so the eager flush isn't needed.
            root = strtrim(char(app.ResultsBrowserOutputDirField.Value));

            if isempty(root)
                app.ResultsBrowserCache_  = [];
                app.ResultsBrowserTree.Data = ...
                    {struct('text','No results directory selected.', ...
                            'data','', 'isLeaf', true, 'children', {{}})};
                return
            end
            if ~isfolder(root)
                app.ResultsBrowserCache_  = [];
                app.ResultsBrowserTree.Data = ...
                    {struct('text', sprintf('Directory not found: %s', root), ...
                            'data','', 'isLeaf', true, 'children', {{}})};
                return
            end
            if ~is_dynamo_results_dir(root)
                % Before reporting failure, see if the user pointed at a
                % parent that *contains* a DYNAM-O_results subfolder
                % (common when they pick the project root rather than
                % the results folder itself). Check the immediate child
                % first, then a single shallow scan for any descendant
                % named DYNAM-O_results — keeps the auto-correct cheap
                % on slow shares.
                cand = local_findResultsDir(root);
                if ~isempty(cand) && is_dynamo_results_dir(cand)
                    app.logResultsBrowser(sprintf( ...
                        'Auto-corrected to DYNAM-O_results subfolder: %s', cand));
                    app.ResultsBrowserOutputDirField.Value = cand;
                    root = cand;
                else
                    app.ResultsBrowserCache_  = [];
                    app.ResultsBrowserTree.Data = ...
                        {struct('text','Invalid DYNAM-O_results folder — see preview pane.', ...
                                'data','', 'isLeaf', true, 'children', {{}})};
                    app.renderResultsBrowserPreviewError(root);
                    app.logResultsBrowser(sprintf('Load aborted: not a DYNAM-O_results folder: %s', root));
                    return
                end
            end

            app.logResultsBrowser(sprintf('Loading %s', root));

            % Fast path: read the JSONL run index FIRST. If non-empty, the
            % tree is built directly from the index — every (subject,
            % channel) entry carries the list of output files it produced,
            % so we have an exhaustive catalog without any recursive walk.
            % The few non-cataloged folders (settings/, figures/, logs/,
            % aggregates/) get a shallow per-folder dir() to populate them.
            % On SMB this turns a 30-45 minute walk into a sub-second load.
            idx = app.tryReadRunIndexEarly(root);
            haveIndex = ~isempty(idx) && ~isempty(idx.entries);

            app.ResultsBrowserTree.Data = ...
                {struct('text','Loading directory tree…', ...
                        'data','', 'isLeaf', true, 'children', {{}})};
            % Show the dancing-bars animation over the tree area while
            % the load runs. The placeholder text node still renders
            % beneath the overlay; the overlay sits on top because it
            % shares the same grid cell.
            app.ResultsTreeLoadingOverlay.HTMLSource = ...
                app.loadingAnimationHtml('Loading…');
            app.ResultsTreeLoadingOverlay.Visible = 'on';
            drawnow;

            if haveIndex
                tBuild = tic;
                app.ResultsBrowserCache_ = app.buildCacheFromIndex(root, idx);
                [nDirs, nFiles] = count_cache(app.ResultsBrowserCache_);
                app.logResultsBrowser(sprintf( ...
                    '  Built tree from index: %d folder(s), %d file(s) in %.2fs', ...
                    nDirs, nFiles, toc(tBuild)));
                app.ResultsBrowserTree.Data = cache_to_tree_node(app.ResultsBrowserCache_);
            else
                % No index — fall back to the recursive walk + offer to
                % seed an index afterwards. Slow on SMB, but only on the
                % first load of a freshly-populated results folder.
                app.logResultsBrowser('  Scanning directory tree…');
                tStart = tic;
                app.ResultsBrowserCache_ = walk_to_cache_progress(root, ...
                    @(msg) app.logResultsBrowser(msg));
                [nDirs, nFiles] = count_cache(app.ResultsBrowserCache_);
                app.logResultsBrowser(sprintf( ...
                    '  Scanned %d folder(s), %d file(s) in %.2f s', ...
                    nDirs, nFiles, toc(tStart)));

                app.logResultsBrowser('  Building tree…');
                drawnow;
                tBuild = tic;
                app.ResultsBrowserTree.Data = cache_to_tree_node(app.ResultsBrowserCache_);
                app.logResultsBrowser(sprintf('  Tree built in %.2f s', toc(tBuild)));
            end

            % Hide the loading overlay so the populated tree is visible.
            app.ResultsTreeLoadingOverlay.Visible = 'off';
            app.renderResultsBrowserPreviewPlaceholder();
            % Reveal the Aggregate Data tab when this root already has
            % an aggregates/ folder, otherwise keep it hidden. Refresh
            % is left lazy here (forceRefresh=false): refreshing the
            % SO-Histograms uiaxes is ~3-4s on first call, so we let
            % the tab group's SelectionChangedFcn pick it up only if
            % the user actually clicks the tab.
            app.updateAggregateDataTabVisibility(false);
            app.logResultsBrowser('Done.');

            % If no index existed at load time, offer to seed one from the
            % in-memory cache the walk just produced — no second disk pass.
            if ~haveIndex
                app.maybePromptForRunIndex(root);
            end

            % Offer to aggregate per-subject outputs into per-channel
            % stacks. Skip the prompt if the user already has an
            % aggregates/ tree under root (re-running aggregate is a
            % deliberate right-click action via the tree menu).
            if ~isfolder(fullfile(root, 'aggregates'))
                sel = uiconfirm(app.UIFigure, ...
                    'Aggregate per-subject outputs into per-channel stacks now?', ...
                    'Aggregate results', ...
                    'Options', {'Aggregate', 'Skip'}, ...
                    'DefaultOption', 1, ...
                    'CancelOption', 2, ...
                    'Icon', 'question');
                if strcmp(sel, 'Aggregate')
                    app.aggregateResultsRoot();
                end
            end

            function r = local_findResultsDir(parent)
                % Look for a DYNAM-O_results subfolder under parent.
                % Tries the obvious immediate-child name first, then
                % falls back to a single shallow dir() scan for any
                % match (case-sensitive on POSIX, case-insensitive on
                % Windows — dir()'s native behavior). Returns '' if
                % nothing matches; the caller treats that as "no
                % auto-correct possible".
                r = '';
                direct = fullfile(parent, 'DYNAM-O_results');
                if isfolder(direct), r = direct; return, end
                d = dir(parent);
                d = d([d.isdir]);
                names = {d.name};
                hit = find(strcmpi(names, 'DYNAM-O_results'), 1);
                if ~isempty(hit)
                    r = fullfile(parent, names{hit});
                end
            end
        end

        % ------------------------------------------------------------------

        function idx = tryReadRunIndexEarly(app, root)
            %TRYREADRUNINDEXEARLY  Read <root>/_runs/*.jsonl and log a summary
            %   BEFORE the directory walk runs. Returns the index struct on
            %   success (empty struct array [] when no JSONL exists or read
            %   fails). The caller uses non-emptiness to decide whether to
            %   build the tree from the index or fall back to a recursive
            %   walk.
            idx = [];
            try
                runsDir = fullfile(root, '_runs');
                if ~isfolder(runsDir), return, end
                d = dir(fullfile(runsDir, '*.jsonl'));
                if isempty(d), return, end
                nFiles = numel(d);
                if nFiles == 1
                    app.logResultsBrowser(sprintf( ...
                        'Reading run index from 1 file (%s)...', d(1).name));
                else
                    app.logResultsBrowser(sprintf( ...
                        'Reading run index from %d files...', nFiles));
                end
                drawnow;
                t0 = tic;
                idx = dynamo_index_runs(root);
                app.logResultsBrowser(sprintf( ...
                    'Run index: %d entries across %d subjects, %d channels (%d run files, %.2fs)', ...
                    numel(idx.entries), numel(idx.subjects), ...
                    numel(idx.channels), numel(idx.runFiles), toc(t0)));
            catch ME
                app.logResultsBrowser(['Run-index read failed: ', ME.message]);
                idx = [];
            end
        end

        function cache = buildCacheFromIndex(app, root, idx)
            %BUILDCACHEFROMINDEX  Synthesize a walk_to_cache-shaped struct
            %   from the JSONL index, with no recursive filesystem walk.
            %   Each entry's `files` list is binned by directory; folders
            %   the index doesn't know about (settings/, figures/, logs/,
            %   aggregates/) are filled in via shallow per-folder dir()
            %   calls so the user can still browse them. The returned
            %   cache has the same shape as walk_to_cache_progress so
            %   downstream tree rendering, preview, and aggregate code
            %   keeps working unchanged.
            %
            %   On a 730-subject SMB tree this drops load time from the
            %   30-45 minute recursive walk to ~5 seconds.

            [~, baseName] = fileparts(root);
            if isempty(baseName), baseName = root; end
            cache = struct('name', baseName, 'path', root, 'isDir', true, ...
                           'dirs', {{}}, 'files', struct('name',{},'path',{}));

            % --- Phase 1: bin every cataloged file path by its parent dir.
            % keyToDir maps "C3/SOPHs" → struct('files', {{paths...}}).
            % Channels that show up in any path become the top-level dirs.
            chanMap = containers.Map('KeyType','char','ValueType','any');
            for ii = 1:numel(idx.entries)
                e = idx.entries{ii};
                if ~isfield(e,'files') || isempty(e.files), continue, end
                for jj = 1:numel(e.files)
                    relPath = char(e.files{jj});
                    relPath = strrep(relPath, '\', '/');
                    parts = strsplit(relPath, '/');
                    if numel(parts) < 2, continue, end
                    chanName = parts{1};
                    catName  = parts{2};
                    fname    = parts{end};
                    if ~isKey(chanMap, chanName)
                        chanMap(chanName) = containers.Map( ...
                            'KeyType','char','ValueType','any');
                    end
                    catMap = chanMap(chanName);
                    if ~isKey(catMap, catName)
                        catMap(catName) = {};
                    end
                    fpaths = catMap(catName);
                    fullPath = fullfile(root, parts{:});
                    fpaths{end+1} = struct('name', fname, 'path', fullPath); %#ok<AGROW>
                    catMap(catName) = fpaths;
                    chanMap(chanName) = catMap;
                end
            end

            % --- Phase 2: for each channel known from the index, build
            % the channel node. After populating its index-cataloged
            % category subdirs, do ONE shallow dir() to find any extra
            % subfolders the index doesn't track (figures/ etc.) and
            % include them as folder-only nodes the user can expand.
            chanNames = sort(chanMap.keys);
            chanDirs = cell(1, numel(chanNames));
            for ic = 1:numel(chanNames)
                chanName = chanNames{ic};
                chanPath = fullfile(root, chanName);
                catMap = chanMap(chanName);

                catNames = sort(catMap.keys);
                catDirs  = cell(1, numel(catNames));
                for is = 1:numel(catNames)
                    catName = catNames{is};
                    catPath = fullfile(chanPath, catName);
                    fileStructs = catMap(catName);
                    fileNames = cellfun(@(s) s.name, fileStructs, 'UniformOutput', false);
                    filePaths = cellfun(@(s) s.path, fileStructs, 'UniformOutput', false);
                    % Drop entries whose path does not exist on disk. The
                    % synth in dynamo_files_for_components is conservative
                    % (lists every companion the run COULD produce), but
                    % users can choose .mat-only or .tiff-only at run
                    % time, and legacy JSONLs may have stale entries from
                    % an earlier synth bug. Filtering here keeps the tree
                    % from showing leaves that resolve to "File not
                    % found" when clicked.
                    keep = cellfun(@(p) isfile(p), filePaths);
                    fileNames = fileNames(keep);
                    filePaths = filePaths(keep);
                    % Sort files by name for stable display
                    [fileNames, sortIdx] = sort(fileNames);
                    filePaths = filePaths(sortIdx);
                    catDirs{is} = struct( ...
                        'name', catName, 'path', catPath, 'isDir', true, ...
                        'dirs', {{}}, ...
                        'files', struct('name', fileNames, 'path', filePaths));
                end

                % Detect non-cataloged subdirs (figures, etc.) at the
                % channel level and scan their contents so the user can
                % browse them. scanDirToCache caps depth (4) and entries
                % per folder (500), which keeps huge SMB trees from
                % re-introducing the latency the JSONL was designed to
                % avoid — but populates the realistic case (a handful of
                % per-subject PNGs) so the user can preview them.
                extraDirs = app.shallowDirsExcept( ...
                    chanPath, [{'.','..','_runs'}, catNames]);
                for ie = 1:numel(extraDirs)
                    extraName = extraDirs{ie};
                    catDirs{end+1} = app.scanDirToCache( ...
                        fullfile(chanPath, extraName), extraName, 0); %#ok<AGROW>
                end

                chanDirs{ic} = struct( ...
                    'name', chanName, 'path', chanPath, 'isDir', true, ...
                    'dirs', {catDirs}, ...
                    'files', struct('name',{},'path',{}));
            end

            % --- Phase 3: at the root, the index-known channels plus any
            % other root-level dirs (aggregates/, settings/, logs/) found
            % via a single shallow dir() at root.
            extraRootDirs = app.shallowDirsExcept( ...
                root, [{'.','..','_runs'}, chanNames]);
            allRootDirs = [chanDirs, cell(1, numel(extraRootDirs))];
            for ie = 1:numel(extraRootDirs)
                extraName = extraRootDirs{ie};
                tScan = tic;
                allRootDirs{numel(chanDirs)+ie} = app.scanDirToCache( ...
                    fullfile(root, extraName), extraName, 0);
                app.logResultsBrowser(sprintf( ...
                    'Scanned %s/ (%.2fs)', extraName, toc(tScan)));
            end
            cache.dirs = allRootDirs;
        end

        function names = shallowDirsExcept(~, parentDir, excludeList)
            %SHALLOWDIRSEXCEPT  One dir() call returning sorted subdir names
            %   under parentDir, with names in excludeList filtered out.
            %   Used by buildCacheFromIndex to discover folders the JSONL
            %   doesn't catalog (figures/, settings/, etc.) without doing
            %   a full recursive walk.
            names = {};
            try
                entries = dir(parentDir);
            catch
                return
            end
            if isempty(entries), return, end
            isDir = [entries.isdir];
            allNames = {entries.name};
            keep = isDir & ~ismember(allNames, excludeList) ...
                & ~startsWith(allNames, '.');
            names = sort(allNames(keep));
        end

        function node = scanDirToCache(app, dirPath, displayName, depth)
            %SCANDIRTOCACHE  Recursively walk a JSONL-uncataloged root
            %   folder (aggregates/, logs/, settings/) into a
            %   walk_to_cache-shaped node. Caps protect against
            %   accidentally diving into a deep or huge tree on slow
            %   network shares — when a cap trips, the offending subdir
            %   becomes an empty placeholder the user can still open in
            %   the OS.
            %
            %   Caps:
            %     MaxDepth   = 4  (root → channel → axis → bin/file)
            %     MaxEntries = 500 entries per folder
            MaxDepth   = 4;
            MaxEntries = 500;

            node = struct('name', displayName, 'path', dirPath, ...
                          'isDir', true, ...
                          'dirs', {{}}, ...
                          'files', struct('name',{},'path',{}));
            try
                entries = dir(dirPath);
            catch
                return
            end
            if isempty(entries), return, end
            if numel(entries) > MaxEntries
                app.logResultsBrowser(sprintf( ...
                    '  (skipping %s - %d entries exceeds cap of %d; %s)', ...
                    displayName, numel(entries), MaxEntries, ...
                    'shown as a folder placeholder'));
                return
            end
            isDirFlag = [entries.isdir];
            allNames  = {entries.name};
            keepDir   = isDirFlag & ~ismember(allNames, {'.','..'}) ...
                                  & ~startsWith(allNames, '.');
            keepFile  = ~isDirFlag & ~startsWith(allNames, '.');

            subDirNames = sort(allNames(keepDir));
            subDirs = cell(1, numel(subDirNames));
            for ii = 1:numel(subDirNames)
                subPath = fullfile(dirPath, subDirNames{ii});
                if depth + 1 >= MaxDepth
                    subDirs{ii} = struct( ...
                        'name', subDirNames{ii}, 'path', subPath, ...
                        'isDir', true, ...
                        'dirs', {{}}, ...
                        'files', struct('name',{},'path',{}));
                else
                    subDirs{ii} = app.scanDirToCache( ...
                        subPath, subDirNames{ii}, depth + 1);
                end
            end
            node.dirs = subDirs;

            fileNames = sort(allNames(keepFile));
            if ~isempty(fileNames)
                filePaths = cellfun( ...
                    @(n) fullfile(dirPath, n), fileNames, ...
                    'UniformOutput', false);
                node.files = struct('name', fileNames, 'path', filePaths);
            end
        end

        function maybePromptForRunIndex(app, root)
            %MAYBEPROMPTFORRUNINDEX  No JSONL in <root>/_runs/ — offer to
            %   seed one from the in-memory cache (the tree walker already
            %   visited every file, so no second disk pass is needed). Only
            %   called from loadResultsBrowserTree when tryReadRunIndexEarly
            %   returned false.
            try
                runsDir = fullfile(root, '_runs');
                sel = uiconfirm(app.UIFigure, ...
                    sprintf(['No run index was found at:\n  %s\n\n' ...
                             'A run index catalogs every (subject, channel) so the ' ...
                             'browser can answer "what''s computed?" without ' ...
                             're-walking the tree. Generate one now from the existing files?'], ...
                             runsDir), ...
                    'Generate run index?', ...
                    'Options', {'Generate', 'Skip'}, ...
                    'DefaultOption', 1, ...
                    'CancelOption', 2, ...
                    'Icon', 'question');
                if strcmp(sel, 'Generate')
                    app.regenerateRunIndex(root);
                end
            catch ME
                app.logResultsBrowser(['Run-index prompt failed: ', ME.message]);
            end
        end

        function regenerateRunIndex(app, root)
            %REGENERATERUNINDEX  Build a backfill JSONL from the cached tree.
            try
                app.logResultsBrowser('Generating run index from current tree...');
                drawnow;
                t0 = tic;
                outPath = dynamo_seed_index_from_cache(root, app.ResultsBrowserCache_);
                app.logResultsBrowser(sprintf( ...
                    '  Wrote %s in %.2f s', outPath, toc(t0)));
                idx = dynamo_index_runs(root);
                app.logResultsBrowser(sprintf( ...
                    '  Index now: %d entries across %d subjects, %d channels', ...
                    numel(idx.entries), numel(idx.subjects), numel(idx.channels)));
            catch ME
                app.logResultsBrowser(['Run-index generation failed: ', ME.message]);
            end
        end

        % ------------------------------------------------------------------

        function aggregateResultsRoot(app)
            % aggregateResultsRoot  For each channel under the chosen results
            % root, stack per-subject paramfit tables and SOPHs histograms
            % into per-channel aggregates inside <root>/aggregates/<chan>/.
            %
            % Channels and per-channel file lists come from the JSONL run
            % index, so the aggregator skips dir() entirely. Falls back to
            % a one-shot dir() at root only if no index is present.

            drawnow;
            app.ResultsBrowserTextArea.Value = {''};   % clear previous
            app.AggregateOverwriteMode_ = '';          % reset standing answer
            root = strtrim(char(app.ResultsBrowserOutputDirField.Value));
            if isempty(root) || ~isfolder(root)
                app.logResultsBrowser(sprintf('Aggregate: invalid root: %s', root));
                return
            end

            % Index-driven discovery: channels come from the index, file
            % lists come pre-grouped per (subject, channel). Synth fallback
            % in dynamo_index_runs ensures legacy entries (components-only,
            % no `files` field) still produce usable file paths.
            idx = [];
            try
                runsDir = fullfile(root, '_runs');
                if isfolder(runsDir) && ~isempty(dir(fullfile(runsDir,'*.jsonl')))
                    idx = dynamo_index_runs(root);
                end
            catch ME
                app.logResultsBrowser(['Aggregate: index read failed: ', ME.message]);
            end

            if ~isempty(idx) && ~isempty(idx.entries)
                filesByChannel = app.groupIndexFilesByChannel(root, idx);
                channels = sort(filesByChannel.keys);
                app.logResultsBrowser(sprintf( ...
                    'Aggregate: %d channel(s) from index; no directory scan needed', ...
                    numel(channels)));
            else
                % No index — fall back to the single-level dir() at root
                % to find candidate channel folders.
                entries = dir(root);
                channels = {};
                for ii = 1:numel(entries)
                    if ~entries(ii).isdir, continue, end
                    if startsWith(entries(ii).name, '.'), continue, end
                    if ismember(entries(ii).name, {'settings','logs','aggregates'}), continue, end
                    ch = fullfile(root, entries(ii).name);
                    if isfolder(fullfile(ch, 'param_basis')) || isfolder(fullfile(ch, 'SOPHs'))
                        channels{end+1} = ch; %#ok<AGROW>
                    end
                end
                if isempty(channels)
                    app.logResultsBrowser('Aggregate: no channel directories found under root.');
                    return
                end
                app.logResultsBrowser(sprintf( ...
                    'Aggregate: %d channel(s) under %s (no index, scanning dirs)', ...
                    numel(channels), root));
                filesByChannel = containers.Map();
            end

            aggregatesRoot = fullfile(root, 'aggregates');

            % --- Pre-flight overwrite check ------------------------
            % If the aggregates/ tree already has any files, ask once
            % up-front instead of forcing the user to dismiss a
            % per-(channel, category) prompt later. The standing answer
            % feeds confirmAggregateOverwrite via AggregateOverwriteMode_,
            % which short-circuits all subsequent per-file prompts.
            if isfolder(aggregatesRoot) && ~app.aggregatesRootIsEmpty(aggregatesRoot)
                msg = sprintf(['Existing aggregates were found under:' ...
                    '\n\n%s\n\nOverwrite them?'], aggregatesRoot);
                try
                    sel = uiconfirm(app.UIFigure, msg, 'Aggregate exists', ...
                        'Options', {'Yes', 'No', 'All', 'Cancel'}, ...
                        'DefaultOption', 'All', ...
                        'CancelOption',  'Cancel', ...
                        'Icon', 'question');
                catch
                    sel = 'Cancel';
                end
                switch sel
                    case 'Yes'
                        % Overwrite, but keep per-file prompting so the
                        % user can still skip individual conflicts.
                        app.AggregateOverwriteMode_ = '';
                        app.logResultsBrowser('  user chose: Yes — overwrite (with per-file prompts)');
                    case 'No'
                        app.AggregateOverwriteMode_ = 'none';
                        app.logResultsBrowser('  user chose: No — keep all existing aggregates');
                    case 'All'
                        app.AggregateOverwriteMode_ = 'all';
                        app.logResultsBrowser('  user chose: All — overwrite everything without prompts');
                    otherwise
                        app.logResultsBrowser('Aggregate: cancelled by user.');
                        app.renderResultsBrowserPreviewPlaceholder('idle');
                        return
                end
            end

            % Resolve channel display names (leaf folder name) once,
            % matching what aggregateOneChannel uses as its `chan` key
            % when calling the progress callback. These names are also
            % what setupAggregateProgressGrid keys the bar map by.
            channelLeafNames = cell(1, numel(channels));
            for ci = 1:numel(channels)
                if iscell(channels), spec = channels{ci}; else, spec = channels(ci); end
                if isKey(filesByChannel, spec)
                    channelLeafNames{ci} = spec;
                else
                    [~, channelLeafNames{ci}] = fileparts(spec);
                end
            end

            % Pre-build one progress bar per channel, stacked vertically.
            % aggProgressTick swaps each bar's N / LabelPrefix as that
            % channel moves through its (cat, stage) sequence.
            app.setupAggregateProgressGrid(channelLeafNames);

            for ci = 1:numel(channels)
                if ischar(channels) || iscell(channels)
                    chSpec = channels{ci};
                else
                    chSpec = channels(ci);
                end
                if isKey(filesByChannel, chSpec)
                    chDir   = fullfile(root, chSpec);
                    chFiles = filesByChannel(chSpec);
                else
                    chDir   = chSpec;   % legacy path: full channel directory
                    chFiles = {};
                end
                app.aggregateOneChannel(chDir, aggregatesRoot, [], chFiles);
            end

            app.teardownAggregateProgressGrid();
            app.logResultsBrowser('Aggregate: done.');
            app.renderResultsBrowserPreviewPlaceholder('idle');
            % Surgical refresh: re-scan only aggregates/ and splice the
            % new subtree into the existing cache. Avoids re-reading the
            % JSONL and re-building the whole tree, which was O(N) in
            % entries and slow on large trees (e.g. 730 subjects on SMB).
            app.refreshAggregatesNodeInCache(root);
            % Refresh the Aggregate Data tab now (and reveal it if it
            % was hidden) so the listbox reflects the new aggregate
            % files immediately.
            app.updateAggregateDataTabVisibility(true);
        end

        function tf = aggregatesRootIsEmpty(~, aggregatesRoot)
            % aggregatesRootIsEmpty  Return true if aggregates/ exists
            %   but contains no regular files in any subtree. Cheap
            %   recursive walk; bails out as soon as the first file
            %   is found.
            tf = true;
            if ~isfolder(aggregatesRoot), return, end
            stack = {aggregatesRoot};
            while ~isempty(stack)
                d = stack{end}; stack(end) = [];
                entries = dir(d);
                for ii = 1:numel(entries)
                    e = entries(ii);
                    if any(strcmp(e.name, {'.','..'})), continue, end
                    if e.isdir
                        stack{end+1} = fullfile(d, e.name); %#ok<AGROW>
                    else
                        tf = false; return
                    end
                end
            end
        end

        function refreshAggregatesNodeInCache(app, root)
            %REFRESHAGGREGATESNODEINCACHE  Re-scan <root>/aggregates/ and
            %   replace just that node in app.ResultsBrowserCache_, then
            %   push the updated cache to the tree. The rest of the
            %   cache (per-channel JSONL-driven entries) is untouched —
            %   no JSONL re-read, no walk of the full tree.
            import results_browser.*
            if isempty(app.ResultsBrowserCache_), return, end
            cache = app.ResultsBrowserCache_;

            aggPath = fullfile(root, 'aggregates');
            if ~isfolder(aggPath)
                app.logResultsBrowser('  (no aggregates/ folder to splice)');
                return
            end

            tScan = tic;
            newNode = app.scanDirToCache(aggPath, 'aggregates', 0);
            app.logResultsBrowser(sprintf( ...
                '  Re-scanned aggregates/ in %.2fs (%d folder(s), %d file(s))', ...
                toc(tScan), numel(newNode.dirs), numel(newNode.files)));

            replaced = false;
            for ii = 1:numel(cache.dirs)
                if strcmp(cache.dirs{ii}.name, 'aggregates')
                    cache.dirs{ii} = newNode;
                    replaced = true;
                    break
                end
            end
            if ~replaced
                cache.dirs{end+1} = newNode;
            end
            app.ResultsBrowserCache_ = cache;

            tTree = tic;
            app.ResultsBrowserTree.Data = cache_to_tree_node(cache);
            app.logResultsBrowser(sprintf( ...
                '  Tree updated in %.2fs', toc(tTree)));
        end

        function map = groupIndexFilesByChannel(~, root, idx)
            %GROUPINDEXFILESBYCHANNEL  Bin idx.entries' files cell by channel,
            %   resolving each entry's root-relative paths to absolute paths.
            %   Returns a containers.Map of channel name → cell of absolute
            %   paths (deduped). Used by aggregateResultsRoot to drive the
            %   aggregator without any filesystem walk.
            map = containers.Map('KeyType','char','ValueType','any');
            for ii = 1:numel(idx.entries)
                e = idx.entries{ii};
                if ~isfield(e,'files') || isempty(e.files), continue, end
                chan = char(e.channel);
                if isKey(map, chan)
                    fpaths = map(chan);
                else
                    fpaths = {};
                end
                for jj = 1:numel(e.files)
                    rel = strrep(char(e.files{jj}), '/', filesep);
                    fpaths{end+1} = fullfile(root, rel); %#ok<AGROW>
                end
                map(chan) = fpaths;
            end
            % Dedupe each channel's list (synth can produce duplicates when
            % multiple components share a category subdir).
            chKeys = map.keys;
            for ii = 1:numel(chKeys)
                map(chKeys{ii}) = unique(map(chKeys{ii}), 'stable');
            end
        end

        % ------------------------------------------------------------------

        function aggProgressTick(app, state, chan, catName, stage, ii, total)
            % aggProgressTick  Per-file progress callback used by the
            %   aggregator. Two display modes:
            %     1. Top-level Aggregate run: app.AggregateProgressBars_
            %        is a Map populated by setupAggregateProgressGrid.
            %        Each channel gets its own pre-built bar; this
            %        callback updates that bar's N/LabelPrefix on stage
            %        transitions and ticks within a stage.
            %     2. Single-channel right-click: the Map is empty and
            %        we fall back to the legacy single-bar path
            %        (setupResultsBrowserPreviewProgress / tick).
            key = sprintf('%s/%s', catName, stage);
            isStageStart = ~strcmp(state('lastKey'), key);
            if isStageStart
                app.logResultsBrowser(sprintf( ...
                    '  [%s] %s (%s): %d file(s)', chan, catName, stage, total));
                state('lastKey') = key;
                state('lastPct') = -1;
                prefix = sprintf('[%s] %s · %s', chan, catName, stage);

                if isa(app.AggregateProgressBars_, 'containers.Map') ...
                        && isKey(app.AggregateProgressBars_, chan)
                    pb = app.AggregateProgressBars_(chan);
                    if ~isempty(pb) && isvalid(pb)
                        try
                            pb.N           = max(1, total);
                            pb.LabelPrefix = prefix;
                            pb.start();
                        catch
                            % bar may have been deleted; ignore
                        end
                    end
                else
                    app.setupResultsBrowserPreviewProgress(prefix, total);
                end
            end

            % Throttle to ~every 5% so the HTML re-render cost doesn't
            % dominate wall-clock on big stages. Always fire the final
            % tick (ii == total) so the bar reaches 100% / completes.
            pct = floor(100 * ii / max(1, total));
            if ii >= total || pct - state('lastPct') >= 5
                state('lastPct') = pct;
                if isa(app.AggregateProgressBars_, 'containers.Map') ...
                        && isKey(app.AggregateProgressBars_, chan)
                    pb = app.AggregateProgressBars_(chan);
                    if ~isempty(pb) && isvalid(pb)
                        try
                            pb.updateIteration(ii);
                        catch
                            % bar may have been completed; ignore
                        end
                    end
                else
                    app.tickResultsBrowserPreviewProgress(ii);
                end
            end
        end

        function aggregateOneChannel(app, channelDir, aggregatesRoot, categories, files)
            % aggregateOneChannel  Build aggregates inside
            % <aggregatesRoot>/<channelName>/ from per-subject inputs in
            % channelDir. `categories` is an optional cell-array subset of
            % {'paramPower','paramPhase','sophsPower','sophsPhase'}; the
            % default writes all four. `files` is an optional cell array
            % of absolute paths from the JSONL index — when provided, the
            % aggregator skips dir() entirely and pulls per-category lists
            % from this in-memory list instead.

            if nargin < 4 || isempty(categories)
                categories = {'paramPower','paramPhase','sophsPower','sophsPhase'};
            end
            if nargin < 5
                files = {};
            end
            wants = @(c) any(strcmp(categories, c));

            [~, channelName] = fileparts(channelDir);
            if isempty(files)
                app.logResultsBrowser(sprintf('[%s] scanning (dir mode)...', channelName));
            else
                app.logResultsBrowser(sprintf( ...
                    '[%s] aggregating %d cataloged file(s) from index...', ...
                    channelName, numel(files)));
            end

            % Per-stage progress callback. Logs a header line on the first
            % tick of each (cat, stage) and refreshes the preview-pane
            % progress bar at most every ~5% to keep HTML re-render cost
            % from dominating wall-clock. State lives in a containers.Map
            % so the closure can mutate it across calls (Map is a handle).
            stageState = containers.Map('KeyType','char','ValueType','any');
            stageState('lastKey') = '';
            stageState('lastPct') = -1;
            progressCb = @(catName, stage, ii, total) ...
                app.aggProgressTick(stageState, channelName, ...
                                    catName, stage, ii, total);

            try
                R = aggregate_DYNAMO_outputs(channelDir, ...
                    'Files', files, 'ProgressFcn', progressCb);
            catch ME
                app.logResultsBrowser(sprintf('[%s] failed: %s', channelName, ME.message));
                return
            end

            for ii = 1:size(R.skipped, 1)
                app.logResultsBrowser(sprintf('  dedupe-skip: %s — %s', R.skipped{ii,1}, R.skipped{ii,2}));
            end
            if isfield(R, 'warnings')
                for ii = 1:numel(R.warnings)
                    app.logResultsBrowser(sprintf('  warning: %s', R.warnings{ii}));
                end
            end

            aggRoot = fullfile(aggregatesRoot, channelName);

            if wants('paramPower')
                app.writeParamfitAggregate(R.paramPower, ...
                    fullfile(aggRoot, 'param_basis_power'), ...
                    channelName, 'SOpower_paramfit', 'paramPower');
            end
            if wants('paramPhase')
                app.writeParamfitAggregate(R.paramPhase, ...
                    fullfile(aggRoot, 'param_basis_phase'), ...
                    channelName, 'SOphase_paramfit', 'paramPhase');
            end
            if wants('sophsPower')
                app.writeSOPHsAggregate(R.sophsPower, ...
                    fullfile(aggRoot, 'SOPHs_power'), ...
                    channelName, 'power', 'SOPHs power');
            end
            if wants('sophsPhase')
                app.writeSOPHsAggregate(R.sophsPhase, ...
                    fullfile(aggRoot, 'SOPHs_phase'), ...
                    channelName, 'phase', 'SOPHs phase');
            end
        end

        % ------------------------------------------------------------------

        function writeParamfitAggregate(app, partial, outDir, channelName, tag, label)
            % writeParamfitAggregate  Write CSV / MAT aggregate for one paramfit
            % category. Skips entirely if no contributors were found, or if the
            % user declines to overwrite an existing aggregate.
            hasCsv = istable(partial.csv_table) && height(partial.csv_table) > 0;
            hasMat = istable(partial.mat_table) && height(partial.mat_table) > 0;
            if ~hasCsv && ~hasMat, return, end

            base = fullfile(outDir, [channelName '_aggregate_' tag]);
            if ~app.confirmAggregateOverwrite(base, {'.csv','.mat'}, channelName, label)
                app.logResultsBrowser(sprintf('  [%s] %s: kept existing (skipped)', channelName, label));
                return
            end
            if ~isfolder(outDir), mkdir(outDir); end

            if hasCsv
                writetable(partial.csv_table, [base '.csv']);
                app.logResultsBrowser(sprintf('  [%s] wrote %s.csv (%d rows)', ...
                    channelName, [channelName '_aggregate_' tag], height(partial.csv_table)));
            end
            if hasMat
                aggregate = struct( ...
                    'params',     partial.mat_table, ...
                    'subjectIDs', {partial.subjectIDs}); %#ok<NASGU>
                save([base '.mat'], 'aggregate');
                app.logResultsBrowser(sprintf('  [%s] wrote %s.mat (%d rows)', ...
                    channelName, [channelName '_aggregate_' tag], height(partial.mat_table)));
            end
        end

        % ------------------------------------------------------------------

        function writeSOPHsAggregate(app, partial, outDir, channelName, axis, label)
            % writeSOPHsAggregate  Write 3-D MAT and multi-page TIFF aggregates
            % for one SOPHs axis. Skips entirely if no contributors were found,
            % or if the user declines to overwrite an existing aggregate.
            hasMat  = isstruct(partial.mat_struct) && ...
                      ~isempty(fieldnames(partial.mat_struct));
            hasTiff = ~isempty(partial.tiff_pages);
            if ~hasMat && ~hasTiff, return, end

            base = fullfile(outDir, [channelName '_aggregate_SOPHs_' axis]);
            if ~app.confirmAggregateOverwrite(base, {'.mat','.tiff'}, channelName, label)
                app.logResultsBrowser(sprintf('  [%s] %s: kept existing (skipped)', channelName, label));
                return
            end
            if ~isfolder(outDir), mkdir(outDir); end

            if hasMat
                aggregate = partial.mat_struct; %#ok<NASGU>
                save([base '.mat'], 'aggregate');
                fld = ['SO' axis '_mat'];
                app.logResultsBrowser(sprintf('  [%s] wrote %s.mat (size %s)', ...
                    channelName, [channelName '_aggregate_SOPHs_' axis], ...
                    mat2str(size(partial.mat_struct.(fld)))));
            end
            if hasTiff
                tiffPath = [base '.tiff'];
                if isfile(tiffPath), delete(tiffPath); end
                t = Tiff(tiffPath, 'w');
                cleaner = onCleanup(@() close(t));
                % Build a JSON ImageDescription for the first page so
                % downstream readers can recover bins directly from the
                % TIFF (no sidecar required).
                tiffDesc = '';
                fb = []; sb = [];
                if isfield(partial,'freq_bins'), fb = partial.freq_bins; end
                if isfield(partial,'so_bins'),   sb = partial.so_bins;   end
                if ~isempty(fb) || ~isempty(sb)
                    metaStruct = struct();
                    if ~isempty(fb), metaStruct.freq_bins = fb(:).'; end
                    if ~isempty(sb), metaStruct.(['SO' axis '_bins']) = sb(:).'; end
                    tiffDesc = jsonencode(metaStruct);
                end
                for kk = 1:numel(partial.tiff_pages)
                    page = partial.tiff_pages{kk};
                    tagstruct.ImageLength      = size(page, 1);
                    tagstruct.ImageWidth       = size(page, 2);
                    tagstruct.Photometric      = Tiff.Photometric.MinIsBlack;
                    tagstruct.BitsPerSample    = 64;
                    tagstruct.SamplesPerPixel  = 1;
                    tagstruct.SampleFormat     = Tiff.SampleFormat.IEEEFP;
                    tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
                    tagstruct.Compression      = Tiff.Compression.None;
                    if kk == 1 && ~isempty(tiffDesc)
                        tagstruct.ImageDescription = tiffDesc;
                    elseif isfield(tagstruct,'ImageDescription')
                        tagstruct = rmfield(tagstruct,'ImageDescription');
                    end
                    t.setTag(tagstruct);
                    t.write(page);
                    if kk < numel(partial.tiff_pages)
                        t.writeDirectory();
                    end
                end
                clear cleaner;

                sidecar = [base '_subjectIDs.txt'];
                ids = partial.tiff_ids;
                fid = fopen(sidecar, 'w');
                for kk = 1:numel(ids)
                    fprintf(fid, '%s\n', ids{kk});
                end
                fclose(fid);
                app.logResultsBrowser(sprintf('  [%s] wrote %s.tiff (%d pages)', ...
                    channelName, [channelName '_aggregate_SOPHs_' axis], ...
                    numel(partial.tiff_pages)));
            end

            % Bins CSV — one file per aggregate, two columns padded with NaN
            % to the longer length so plotting can label axes in Hz/dB/rad.
            freq_bins = []; so_bins = [];
            if isfield(partial, 'freq_bins'), freq_bins = partial.freq_bins; end
            if isfield(partial, 'so_bins'),   so_bins   = partial.so_bins;   end
            hasFreq = ~isempty(freq_bins);
            hasSO   = ~isempty(so_bins);
            if hasFreq || hasSO
                nF = numel(freq_bins); nS = numel(so_bins);
                nMax = max(nF, nS);
                fCol = nan(nMax, 1); if hasFreq, fCol(1:nF) = freq_bins(:); end
                sCol = nan(nMax, 1); if hasSO,   sCol(1:nS) = so_bins(:);   end
                soColName = ['SO' axis];
                Tbins = table(fCol, sCol, 'VariableNames', {'freq', soColName});
                writetable(Tbins, [base '_bins.csv']);
                app.logResultsBrowser(sprintf('  [%s] wrote %s_bins.csv (%d rows)', ...
                    channelName, [channelName '_aggregate_SOPHs_' axis], nMax));
            else
                app.logResultsBrowser(sprintf('  [%s] no bins available — skipping bins.csv (re-run batch with .mat SOPHs to recover Hz/dB labels)', ...
                    channelName));
            end
        end

        % ------------------------------------------------------------------

        function ok = confirmAggregateOverwrite(app, baseStem, exts, channelName, label)
            % confirmAggregateOverwrite  Returns true if the caller may write
            % the aggregate file(s) — either none of them exist yet, or the
            % user said Overwrite (this one or all). Returns false (skip) if
            % the user said Skip (this one or all).
            %
            % A standing answer ("Overwrite All" / "Skip All") is honored for
            % the rest of the Aggregate run via app.AggregateOverwriteMode_.

            existing = {};
            for ii = 1:numel(exts)
                p = [baseStem exts{ii}];
                if isfile(p), existing{end+1} = p; end %#ok<AGROW>
            end
            if isempty(existing)
                ok = true; return
            end

            % Honor the standing "All" answer if one was given earlier.
            switch app.AggregateOverwriteMode_
                case 'all',  ok = true;  return
                case 'none', ok = false; return
            end

            shortNames = cell(size(existing));
            for ii = 1:numel(existing)
                [~, n, e] = fileparts(existing{ii});
                shortNames{ii} = [n e];
            end
            msg = sprintf(['Aggregate for %s in channel "%s" already exists:' ...
                           '\n\n%s\n\nOverwrite?'], ...
                          label, channelName, strjoin(shortNames, sprintf('\n')));
            try
                sel = uiconfirm(app.UIFigure, msg, 'Aggregate exists', ...
                    'Options', {'Overwrite', 'Overwrite All', 'Skip', 'Skip All'}, ...
                    'DefaultOption', 'Skip', ...
                    'CancelOption',  'Skip', ...
                    'Icon', 'question');
            catch
                % Fallback if uiconfirm isn't available: default to Skip.
                sel = 'Skip';
            end
            switch sel
                case 'Overwrite All'
                    app.AggregateOverwriteMode_ = 'all';
                    app.logResultsBrowser('  user chose: Overwrite All for this Aggregate run');
                    ok = true;
                case 'Skip All'
                    app.AggregateOverwriteMode_ = 'none';
                    app.logResultsBrowser('  user chose: Skip All for this Aggregate run');
                    ok = false;
                case 'Overwrite'
                    ok = true;
                otherwise
                    ok = false;
            end
        end

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

        function createRunLog(app)
            % createRunLog  Initialise the per-run file log and write the header.
            %
            %   Creates <OutputDir>/logs/file_log_<timestamp>.txt and
            %   <OutputDir>/settings/run_settings_<timestamp>.txt via
            %   generate_run_log. Stores the file handle for subsequent writes.
            %   Resets LogBuffer so the Run Log Console shows only this run.

            generate_run_log(app.options_structs, app.struct_names, ...
                'run_start', app.curr_datetime, ...
                'file_path', strcat(app.OutputDirEditField.Value, '/settings/'));

            app.runlog_fname = matlab.lang.makeValidName(strcat('file_log_', app.curr_datetime, '.txt'));
            app.runlog_fpath = strcat(app.OutputDirEditField.Value, '/logs/');
            app.runlog_fid   = fopen(fullfile(app.runlog_fpath, app.runlog_fname), 'w');

            app.writeLog(sprintf('Date and time of run start: %s\n', app.curr_datetime));
            app.writeLog(sprintf('Run with settings file: %s\n\n', ...
                strcat('run_settings_', app.curr_datetime, '.txt')));
            app.writeLog(sprintf('Files run: \n\n'));
        end

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

        % ------------------------------------------------------------------

        function createConsoleLog(app)
            % createConsoleLog  Redirect MATLAB diary output to a timestamped console log.
            %
            %   Creates <OutputDir>/logs/console_log_<timestamp>.txt and activates
            %   MATLAB's diary function to capture all subsequent console output.

            app.consolelog_fname = strcat('console_log_', app.curr_datetime, '.txt');
            app.consolelog_fpath = strcat(app.OutputDirEditField.Value, '/logs/');
            fullpath = fullfile(app.consolelog_fpath, app.consolelog_fname);

            % Write the header via a scoped fopen + fclose. We must NOT hold
            % the fid open, because `diary` takes ownership of the file right
            % after this; two open handles to the same path makes diary's
            % appends unreliable on macOS (silent failure with empty log).
            fid = fopen(fullpath, 'w');
            if fid < 0
                warning('createConsoleLog:fopen', ...
                    'Could not open console log at %s; diary not started.', fullpath);
                app.consolelog_fid = [];
                return
            end
            fprintf(fid, 'Date and time of run start: %s\n\n', app.curr_datetime);
            fclose(fid);
            app.consolelog_fid = [];  % no persistent fid; diary owns the file

            % Start diary. Wrapped so that if MATLAB errors on diary(path)
            % we don't kill the whole batch (the console log is nice-to-have).
            try
                diary off
                diary(fullpath)
            catch diaryErr
                warning('createConsoleLog:diary', ...
                    'diary(%s) failed: %s', fullpath, diaryErr.message);
            end

            % If the Run Log Console is already open, start live polling now.
            if ~isempty(app.LogConsoleFig) && isvalid(app.LogConsoleFig)
                app.startLogConsoleTimer();
            end
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

        function runStatsTable(app)
            % runStatsTable  Run DYNAMO and save TF-peak stats and SO-Power Histograms.
            %
            %   Calls app.run() to execute the DYNAMO pipeline, then saves:
            %     - stats_table: TF-peak statistics table (.csv, .mat, or both)
            %     - SOPHs: SO-Power Histograms (.tiff, .mat, or both)
            %
            %   Skips execution if all output files already exist and
            %   OverwriteExistingFilesCheckBox is unchecked.

            % Channel/output dirs prepared once in runBatch; reuse cached paths
            chanDir     = fullfile(app.OutputDirEditField.Value, app.channel);
            tfpeaksDir  = fullfile(chanDir, 'TFpeaks');
            sophsDir    = fullfile(chanDir, 'SOPHs');
            statsBase   = fullfile(tfpeaksDir, [app.input_fbase '_stats_table_' app.channel]);
            sophBase    = fullfile(sophsDir,   [app.input_fbase '_SOPHs_' app.channel]);
            sophPowBase = fullfile(sophsDir,   [app.input_fbase '_SOPHs_power_' app.channel]);
            sophPhaBase = fullfile(sophsDir,   [app.input_fbase '_SOPHs_phase_' app.channel]);

            stats_csv = [statsBase '.csv'];
            stats_mat = [statsBase '.mat'];
            SOPH_mat  = [sophBase  '.mat'];

            % ---- (0) Build the list of files this stage would emit
            %      under the current (checkbox + dropdown) choices.
            %      Used both for the skip-when-cached gate at compute
            %      time AND for per-file save gating below — so a
            %      run with .csv on disk but the user requesting .mat
            %      still writes .mat instead of being silently skipped.
            overwrite = app.OverwriteExistingFilesCheckBox.Value;

            stats_choice = app.PeakStatsTableDropDown.Value;
            stats_expected = {};
            if app.SavePeakStatsCheckBox.Value && ~strcmp(stats_choice,'--')
                if any(strcmp(stats_choice, {'.csv','All'})), stats_expected{end+1} = stats_csv; end
                if any(strcmp(stats_choice, {'.mat','All'})), stats_expected{end+1} = stats_mat; end
            end

            soph_choice = app.SOPowerHistogramsDropDown.Value;
            soph_targets = {};   % each entry: struct('path', ..., 'kind', 'tiff_power'|'tiff_phase'|'mat')
            if app.SaveSOPHsCheckBox.Value && ~strcmp(soph_choice,'--')
                if any(strcmp(soph_choice, {'.tiff','All'}))
                    soph_targets{end+1} = struct('path', [sophPowBase '.tiff'], 'kind', 'tiff_power');
                    soph_targets{end+1} = struct('path', [sophPhaBase '.tiff'], 'kind', 'tiff_phase');
                end
                if any(strcmp(soph_choice, {'.mat','All'}))
                    soph_targets{end+1} = struct('path', SOPH_mat, 'kind', 'mat');
                end
            end

            % ---- (1) Make sure SOPHs + stats_table are in memory ----
            % The overwrite flag gates the on-disk cache: when checked,
            % previous in-memory copies are cleared and the disk-load
            % shortcut is skipped so we always recompute via runDYNAMO.
            if overwrite
                app.SOPHs       = [];
                app.stats_table = [];
            end
            need_compute = isempty(app.SOPHs) || isempty(app.stats_table);
            if need_compute && ~overwrite && isfile(SOPH_mat) && isfile(stats_mat)
                app.TextArea.addnl('   Loading cached SOPHs and stats table...');
                app.SOPHs       = load(SOPH_mat).SOPHs;
                app.stats_table = load(stats_mat).stats_table;
                need_compute    = false;
            end
            if need_compute
                app.anything_run = 1;
                app.TextArea.addnl('   Running DYNAMO...');
                app.TextArea.addnl('   Computing TF peak stats table...');
                drawnow;
                app.runDYNAMO();
            end

            stats_table = app.stats_table;
            SOPHs       = app.SOPHs;

            % ---- (2) Save according to user choices, with per-file
            %      overwrite gating — write only the (format × file)
            %      combinations that don't already exist (or all of
            %      them when overwrite is on).
            if ~isempty(stats_expected)
                wrote_any = false;
                for ii = 1:numel(stats_expected)
                    p = stats_expected{ii};
                    if ~overwrite && isfile(p), continue, end
                    if ~wrote_any
                        app.TextArea.addnl('   Saving stats table...');
                        wrote_any = true;
                    end
                    [~,~,ext] = fileparts(p);
                    app.output_stats_name = p;
                    switch lower(ext)
                        case '.csv', table2csv(stats_table, p);
                        case '.mat', save(p, 'stats_table');
                    end
                end
            end

            if ~isempty(soph_targets)
                powMeta = jsonencode(struct( ...
                    'freq_bins',    SOPHs.freq_bins(:).', ...
                    'SOpower_bins', SOPHs.SOpower_bins(:).'));
                phaMeta = jsonencode(struct( ...
                    'freq_bins',    SOPHs.freq_bins(:).', ...
                    'SOphase_bins', SOPHs.SOphase_bins(:).'));
                wrote_any = false;
                for ii = 1:numel(soph_targets)
                    t = soph_targets{ii};
                    if ~overwrite && isfile(t.path), continue, end
                    if ~wrote_any
                        app.TextArea.addnl('   Saving SOPHs');
                        wrote_any = true;
                    end
                    app.output_SOPH_name = t.path;
                    switch t.kind
                        case 'tiff_power', app.writeTiff(t.path, SOPHs.SOpower_mat, powMeta);
                        case 'tiff_phase', app.writeTiff(t.path, SOPHs.SOphase_mat, phaMeta);
                        case 'mat',        save(t.path, 'SOPHs');
                    end
                end
            end
        end % runStatsTable

        % ------------------------------------------------------------------

        function runDataSummaryFigure(app)
            % runDataSummaryFigure  Generate and save the data summary figure.
            %
            %   Loads SOPHs and stats_table from memory or disk as needed, then
            %   calls displaySummaryPlot and saves the result using the format
            %   specified by DataSummaryDropDown.

            % Channel/output dirs prepared once in runBatch; reuse cached paths
            chanDir    = fullfile(app.OutputDirEditField.Value, app.channel);
            summaryDir = fullfile(chanDir, 'figures', 'summary');
            sophMat    = fullfile(chanDir, 'SOPHs', [app.input_fbase '_SOPHs_' app.channel '.mat']);

            % ---- Skip-when-cached gate ----
            % If the dropdown is '--' there's nothing to write, and if
            % the target file already exists and overwrite is off we
            % can short-circuit before paying the SOPH/stats load cost.
            fig_choice = app.DataSummaryDropDown.Value;
            if strcmp(fig_choice,'--')
                return
            end
            figPath = fullfile(summaryDir, ...
                [app.input_fbase '_summary_figure_' app.channel fig_choice]);
            overwrite = app.OverwriteExistingFilesCheckBox.Value;
            if ~overwrite && isfile(figPath)
                app.TextArea.addnl('   Skipping summary figure (file already exists).');
                return
            end

            % ---- Ensure SOPHs are available ----
            if isempty(app.SOPHs)
                if isfile(sophMat)
                    app.SOPHs = load(sophMat).SOPHs;
                else
                    runStatsTable(app);   % Compute from scratch
                end
            end

            % ---- Ensure stats_table is available ----
            if isempty(app.stats_table)
                statsBase = fullfile(chanDir, 'TFpeaks', [app.input_fbase '_stats_table_' app.channel]);
                csvPath = [statsBase '.csv'];
                matPath = [statsBase '.mat'];
                matExists = isfile(matPath);
                csvExists = isfile(csvPath);

                if matExists
                    app.stats_table = load(matPath,'stats_table').stats_table;
                elseif csvExists
                    app.stats_table = csv2table(csvPath);
                else
                    runStatsTable(app);      % Compute from scratch
                end
            end

            app.output_fig_name = figPath;
            app.anything_run    = 1;
            app.TextArea.addnl('   Generating summary figure...');
            fh = app.displaySummaryPlot;
            app.TextArea.addnl('   Saving summary figure...');
            exportgraphics(fh, figPath, 'Resolution', 300);
            close all;
        end % runDataSummaryFigure

        % ------------------------------------------------------------------

        function runParamBasis(app)
            % runParamBasis  Fit the parametric basis model and save results/figures.
            %
            %   Loads SOPHs if needed, calls fitParamBasis, and saves:
            %     - Parametric fit figure (if SaveParamImagesCheckBox is checked)
            %     - SOpower/SOphase parametric fit data (.csv, .mat, or both)
            %       according to ParametricBasisDropDown selection.

            % Channel/output dirs prepared once in runBatch; reuse cached paths
            chanDir        = fullfile(app.OutputDirEditField.Value, app.channel);
            paramDir       = fullfile(chanDir, 'param_basis');
            paramFigDir    = fullfile(chanDir, 'figures', 'param_basis');
            sophMat        = fullfile(chanDir, 'SOPHs', [app.input_fbase '_SOPHs_' app.channel '.mat']);
            paramPowerBase = fullfile(paramDir, [app.input_fbase '_SOpower_paramfit_' app.channel]);
            paramPhaseBase = fullfile(paramDir, [app.input_fbase '_SOphase_paramfit_' app.channel]);

            % ---- Skip-when-cached gate ----
            % Build the list of files this stage would emit under the
            % current dropdown choices. If overwrite is off AND every
            % one already exists, the (expensive) fitParamBasis call
            % is pure waste — bail out early.
            overwrite = app.OverwriteExistingFilesCheckBox.Value;
            expected  = {};
            basis_choice = app.ParametricBasisDropDown.Value;
            if ~strcmp(basis_choice, '--')
                if any(strcmp(basis_choice, {'.csv','All'}))
                    expected{end+1} = [paramPowerBase '.csv']; %#ok<AGROW>
                    expected{end+1} = [paramPhaseBase '.csv']; %#ok<AGROW>
                end
                if any(strcmp(basis_choice, {'.mat','All'}))
                    expected{end+1} = [paramPowerBase '.mat']; %#ok<AGROW>
                    expected{end+1} = [paramPhaseBase '.mat']; %#ok<AGROW>
                end
            end
            fig_choice = app.ParametricFiguresDropDown.Value;
            if app.SaveParamImagesCheckBox.Value && ~strcmp(fig_choice,'--')
                expected{end+1} = fullfile(paramFigDir, ...
                    [app.input_fbase '_param_basis_figure_' app.channel fig_choice]); %#ok<AGROW>
            end
            if ~overwrite && ~isempty(expected) && all(cellfun(@isfile, expected))
                app.TextArea.addnl('   Skipping parametric basis (outputs already exist).');
                return
            end

            % ---- Ensure SOPHs are available ----
            if isempty(app.SOPHs)
                if isfile(sophMat)
                    app.SOPHs = load(sophMat).SOPHs;
                else
                    app.anything_run = 1;
                    app.TextArea.addnl('   Running DYNAMO (computing SOPHs)...');
                    runStatsTable(app);
                end
            end

            % Fit parametric basis model
            app.TextArea.addnl('   Running parametric basis...');
            app.TextArea.addnl('   Generating parametric basis figure...');
            app.fitParamBasis();
            fh = gcf;

            % Optionally save the parametric basis figure (overwrite-gated)
            if app.SaveParamImagesCheckBox.Value && ~strcmp(fig_choice,'--')
                figPath = fullfile(paramFigDir, ...
                    [app.input_fbase '_param_basis_figure_' app.channel fig_choice]);
                if overwrite || ~isfile(figPath)
                    app.anything_run = 1;
                    app.output_param_name = figPath;
                    app.TextArea.addnl('   Saving parametric basis figure...');
                    exportgraphics(fh, figPath, 'Resolution', 300);
                end
            end
            close all;

            % Save parametric fit data — fitParamBasis leaves *_paramfit
            % empty when its sub-fit failed; skip those saves so a failed
            % phase fit doesn't prevent saving the (good) power fit.
            % Per-file overwrite gating ensures we don't re-write existing
            % outputs unless the user asked for it.
            pow_have   = ~isempty(app.SOPHs.SOpower_paramfit);
            phase_have = ~isempty(app.SOPHs.SOphase_paramfit);
            if ~pow_have
                app.TextArea.addnl('   Skipping parametric power save (fit failed).');
                app.partial_failures{end+1} = 'parametric power fit';
            end
            if ~phase_have
                app.TextArea.addnl('   Skipping parametric phase save (fit failed).');
                app.partial_failures{end+1} = 'parametric phase fit';
            end
            if ~strcmp(basis_choice,'--')
                save_csv = any(strcmp(basis_choice, {'.csv','All'}));
                save_mat = any(strcmp(basis_choice, {'.mat','All'}));
                if pow_have
                    if save_csv, write_paramfit_csv([paramPowerBase '.csv'], app.SOPHs.SOpower_paramfit, 'power', app.SOPHs.SOpower_bins); end
                    if save_mat, write_paramfit_mat([paramPowerBase '.mat'], app.SOPHs.SOpower_paramfit, 'SOpower_paramfit');             end
                end
                if phase_have
                    if save_csv, write_paramfit_csv([paramPhaseBase '.csv'], app.SOPHs.SOphase_paramfit, 'phase', app.SOPHs.SOphase_bins); end
                    if save_mat, write_paramfit_mat([paramPhaseBase '.mat'], app.SOPHs.SOphase_paramfit, 'SOphase_paramfit');             end
                end
            end

            function write_paramfit_csv(p, fitData, axis_kind, bins)
                if ~overwrite && isfile(p), return, end
                app.TextArea.addnl(sprintf('   Saving parametric %s as .csv...', axis_kind));
                if strcmp(axis_kind,'power')
                    app.output_paramfit_power_name = p;
                else
                    app.output_paramfit_phase_name = p;
                end
                app.writeParamfitCsv(p, fitData, axis_kind, app.SOPHs.freq_bins, bins);
            end

            function write_paramfit_mat(p, fitData, varName)
                if ~overwrite && isfile(p), return, end
                app.TextArea.addnl(sprintf('   Saving %s as .mat...', varName));
                if contains(varName,'power')
                    app.output_paramfit_power_name = p;
                else
                    app.output_paramfit_phase_name = p;
                end
                S.(varName) = fitData; %#ok<STRNU>
                save(p, '-struct', 'S');
            end

            % If both fits failed, surface that to the per-stage try/catch in
            % runBatch so the subject is logged as "partially run".
            if ~pow_have && ~phase_have
                error('DYNAMOFileManager:runParamBasis:bothFitsFailed', ...
                    'Both parametric power and phase fits failed.');
            end
        end % runParamBasis

        % ------------------------------------------------------------------

        function runSplineBasis(app)
            % runSplineBasis  Fit the spline basis model and save results/figures.
            %
            %   Loads SOPHs if needed, calls fitSplineBasis, and saves:
            %     - Spline basis figure (if SaveSplineImagesCheckBox is checked)
            %     - SOpower/SOphase spline fit data (.tiff, .mat, or both)
            %       according to SplineBasisDropDown selection.

            % Channel/output dirs prepared once in runBatch; reuse cached paths
            chanDir         = fullfile(app.OutputDirEditField.Value, app.channel);
            splineDir       = fullfile(chanDir, 'spline_basis');
            splineFigDir    = fullfile(chanDir, 'figures', 'spline_basis');
            sophMat         = fullfile(chanDir, 'SOPHs', [app.input_fbase '_SOPHs_' app.channel '.mat']);
            splinePowerBase = fullfile(splineDir, [app.input_fbase '_SOpower_splinefit_' app.channel]);
            splinePhaseBase = fullfile(splineDir, [app.input_fbase '_SOphase_splinefit_' app.channel]);

            % ---- Skip-when-cached gate ----
            % Build the list of files this stage would emit under the
            % current dropdown choices. If overwrite is off AND every
            % one already exists, the (expensive) fitSplineBasis call
            % is pure waste — bail out early.
            overwrite = app.OverwriteExistingFilesCheckBox.Value;
            expected  = {};
            basis_choice = app.SplineBasisDropDown.Value;
            if ~strcmp(basis_choice, '--')
                if any(strcmp(basis_choice, {'.tiff','All'}))
                    expected{end+1} = [splinePowerBase '.tiff']; %#ok<AGROW>
                    expected{end+1} = [splinePhaseBase '.tiff']; %#ok<AGROW>
                end
                if any(strcmp(basis_choice, {'.mat','All'}))
                    expected{end+1} = [splinePowerBase '.mat']; %#ok<AGROW>
                    expected{end+1} = [splinePhaseBase '.mat']; %#ok<AGROW>
                end
            end
            fig_choice = app.SplineFiguresDropDown.Value;
            if app.SaveSplineImagesCheckBox.Value && ~strcmp(fig_choice,'--')
                expected{end+1} = fullfile(splineFigDir, ...
                    [app.input_fbase '_spline_basis_figure_' app.channel fig_choice]); %#ok<AGROW>
            end
            if ~overwrite && ~isempty(expected) && all(cellfun(@isfile, expected))
                app.TextArea.addnl('   Skipping spline basis (outputs already exist).');
                return
            end

            % ---- Ensure SOPHs are available ----
            if isempty(app.SOPHs)
                if isfile(sophMat)
                    app.SOPHs = load(sophMat).SOPHs;
                else
                    app.anything_run = 1;
                    app.TextArea.addnl('   Running DYNAMO (computing SOPHs)...');
                    runStatsTable(app);
                end
            end

            % Fit spline basis model
            app.TextArea.addnl(   'Running spline basis...');
            app.TextArea.addnl('   Generating spline basis figure...');
            app.fitSplineBasis();
            fh = gcf;

            % Optionally save the spline basis figure (overwrite-gated)
            if app.SaveSplineImagesCheckBox.Value && ~strcmp(fig_choice,'--')
                figPath = fullfile(splineFigDir, ...
                    [app.input_fbase '_spline_basis_figure_' app.channel fig_choice]);
                if overwrite || ~isfile(figPath)
                    app.anything_run = 1;
                    app.TextArea.addnl('   Saving spline figure...');
                    app.output_spline_name = figPath;
                    exportgraphics(fh, figPath, 'Resolution', 300);
                end
            end
            close all;

            % Save spline fit data — empty *_splinefit means that sub-fit
            % failed; skip those without erroring the surviving one.
            % Per-file overwrite gating below (write_splinefit_*).
            pow_have   = ~isempty(app.SOPHs.SOpower_splinefit);
            phase_have = ~isempty(app.SOPHs.SOphase_splinefit);
            if ~pow_have
                app.TextArea.addnl('   Skipping spline power save (fit failed).');
                app.partial_failures{end+1} = 'spline power fit';
            end
            if ~phase_have
                app.TextArea.addnl('   Skipping spline phase save (fit failed).');
                app.partial_failures{end+1} = 'spline phase fit';
            end
            if ~strcmp(basis_choice,'--')
                save_tiff = any(strcmp(basis_choice, {'.tiff','All'}));
                save_mat  = any(strcmp(basis_choice, {'.mat','All'}));

                % .tiff is multi-page: page 1 = coefs (the parameter
                % matrix that IS the model); page 2 = the rendered
                % splinefit on the fit-domain grid for direct preview.
                % knots_x/y + FIT-DOMAIN bins (filtered, not full SOPH
                % bins) go in page-1 ImageDescription so feeding them
                % + coefs + knots into spap2/fnval reproduces page 2.
                if pow_have
                    [powMeta, powPages] = build_splinefit_payload( ...
                        app.SOPHs.SOpower_splinefit, app.SOPHs.SOpower_bins, app.SOPHs.freq_bins, 'SOpower_bins');
                    if save_tiff, write_splinefit_tiff([splinePowerBase '.tiff'], powPages, powMeta, 'power'); end
                    if save_mat,  write_splinefit_mat([splinePowerBase '.mat'],  app.SOPHs.SOpower_splinefit, 'SOpower_splinefit'); end
                end
                if phase_have
                    [phaMeta, phaPages] = build_splinefit_payload( ...
                        app.SOPHs.SOphase_splinefit, app.SOPHs.SOphase_bins, app.SOPHs.freq_bins, 'SOphase_bins');
                    if save_tiff, write_splinefit_tiff([splinePhaseBase '.tiff'], phaPages, phaMeta, 'phase'); end
                    if save_mat,  write_splinefit_mat([splinePhaseBase '.mat'],  app.SOPHs.SOphase_splinefit, 'SOphase_splinefit'); end
                end
            end

            if ~pow_have && ~phase_have
                error('DYNAMOFileManager:runSplineBasis:bothFitsFailed', ...
                    'Both spline power and phase fits failed.');
            end

            function [meta, pages] = build_splinefit_payload(SF, defaultSObins, defaultFreqBins, soBinsField)
                if isfield(SF,'fit_SOfeature_bins') && ~isempty(SF.fit_SOfeature_bins)
                    fitSO = SF.fit_SOfeature_bins;
                else
                    fitSO = defaultSObins;     % pre-refactor structs
                end
                if isfield(SF,'fit_freq_bins') && ~isempty(SF.fit_freq_bins)
                    fitFB = SF.fit_freq_bins;
                else
                    fitFB = defaultFreqBins;
                end
                metaStruct = struct( ...
                    'knots_x',     SF.knots_x(:).', ...
                    'knots_y',     SF.knots_y(:).', ...
                    'freq_bins',   fitFB(:).', ...
                    (soBinsField), fitSO(:).', ...
                    'page1',       'coefs', ...
                    'page2',       'splinefit');
                meta  = jsonencode(metaStruct);
                pages = {SF.coefs, SF.splinefit};
            end

            function write_splinefit_tiff(p, pages, meta, axisLabel)
                if ~overwrite && isfile(p), return, end
                app.TextArea.addnl(sprintf('   Saving spline %s as .tiff (coefs + splinefit)...', axisLabel));
                if strcmp(axisLabel,'power')
                    app.output_splinefit_power_name = p;
                else
                    app.output_splinefit_phase_name = p;
                end
                app.writeTiff(p, pages, meta);
            end

            function write_splinefit_mat(p, fitData, varName)
                if ~overwrite && isfile(p), return, end
                app.TextArea.addnl(sprintf('   Saving %s as .mat...', varName));
                if contains(varName,'power')
                    app.output_splinefit_power_name = p;
                else
                    app.output_splinefit_phase_name = p;
                end
                S.(varName) = fitData; %#ok<STRNU>
                save(p, '-struct', 'S');
            end
        end % runSplineBasis

        % ------------------------------------------------------------------

        function saveAuxData(app)
            % saveAuxData  Collect and save auxiliary analysis data for the current subject/channel.
            %
            %   Packages artifacts, sampling rate, and SO-power normalisation method
            %   into a struct and saves it to:
            %     <OutputDir>/<channel>/auxiliary_data/<fbase>_auxiliary_data_<channel>.mat
            %
            %   TO-DO: Expand to include additional auxiliary fields.

            % Channel/output dirs prepared once in runBatch; reuse cached paths
            chanDir = fullfile(app.OutputDirEditField.Value, app.channel);
            auxDir  = fullfile(chanDir, 'auxiliary_data');

            % Skip the entire stage when the .mat already exists and
            % the user hasn't asked to overwrite — saveAuxData is the
            % single-output stage where this is cheap to short-circuit.
            outPath = fullfile(auxDir, [app.input_fbase '_auxiliary_data_' app.channel '.mat']);
            overwrite = app.OverwriteExistingFilesCheckBox.Value;
            if ~overwrite && isfile(outPath)
                app.TextArea.addnl('   Skipping auxiliary data (file already exists).');
                return
            end

            % Ensure SOPHs are available (needed for SOpower_norm field)
            if isempty(app.SOPHs)
                SOPHmat = fullfile(chanDir, 'SOPHs', [app.input_fbase '_SOPHs_' app.channel '.mat']);
                if isfile(SOPHmat)
                    app.SOPHs = load(SOPHmat).SOPHs;
                else
                    app.anything_run = 1;
                    app.TextArea.addnl('   Computing SOPHs for auxiliary data...');
                    runStatsTable(app);
                end
            end

            % Package auxiliary data fields
            % TO-DO: Add additional fields (e.g. normalised power, spindle indices)
            app.auxiliary_data.artifacts             = app.artifacts;
            app.auxiliary_data.Fs                    = app.Fs;
            app.auxiliary_data.SOpower_norm_method   = app.SOPH_options.SOpower_norm_method;
            app.auxiliary_data.SOpower_norm          = app.SOPHs.SOpower_norm;
            app.auxiliary_data.stage_times           = app.stage_times;
            app.auxiliary_data.stage_vals            = app.stage_vals;

            auxiliary_data = app.auxiliary_data; %#ok<ADPROP>

            app.TextArea.addnl(   'Saving auxiliary data...');

            app.output_aux_name = fullfile(auxDir, ...
                [app.input_fbase '_auxiliary_data_' app.channel '.mat']);
            save(app.output_aux_name,'auxiliary_data');
        end

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
                % (set_running, options struct, log creation, mkdirs,
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
                ['  <div style="text-align: center; margin-bottom: 15px;">' app.make_logo_svg('width',250) '</div>'] ...
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


        % ------------------------------------------------------------------

        function runBatch(app, dataList, stagingList)
            % runBatch  Main batch processing loop: iterates over all files and channels.
            %
            %   runBatch(app, dataList, stagingList)
            %
            %   dataList/stagingList are the ordered file lists to process. They are
            %   passed in (rather than read from app.DataList/StagingList) so that
            %   reverse-order runs do not permanently mutate the GUI state.
            %
            %   Execution order per iteration:
            %     1. Load EDF and staging data via load_data.
            %     2. Run selected analysis steps (stats, summary, param basis, spline, aux).
            %     3. Log the outcome (success or error) to the run log file.
            %     4. Update the progress bar.
            %
            %   The loop checks isStopBatchButtonPushed at the start of each
            %   file iteration and exits early if the Stop button was pressed.
            %
            %   On completion, all open log file handles are closed and diary is
            %   stopped automatically when consolelog_fid is closed.

            app.TextArea.Value = 'Beginning run...';
            app.curr_datetime   = char(datetime('now','Format','yyMMdd_HHmmSS'));
            app.set_running;
            drawnow;

            % Build DYNAMO options struct from current GUI settings
            app.TextArea.Value = 'Updating advanced options...';
            drawnow;
            createOptionsStruct(app)

            % Create required output subdirectories and initialise logs (if enabled)
            if app.SaveLogsSwitch.Value
                if ~exist(strcat(app.OutputDirEditField.Value,'/settings/'),'dir')
                    mkdir(strcat(app.OutputDirEditField.Value,'/settings/'))
                end
                if ~exist(strcat(app.OutputDirEditField.Value,'/logs/'),'dir')
                    mkdir(strcat(app.OutputDirEditField.Value,'/logs/'))
                end
                app.TextArea.Value = 'Creating run log...';
                drawnow;
                createRunLog(app)
                app.TextArea.Value = 'Creating console log...';
                drawnow;
                createConsoleLog(app)
            end

            % Open the per-run JSONL logger. One file per batch
            % invocation, written to <output_dir>/_runs/. Concurrent
            % batches on different machines each open their own file
            % and union at read time via dynamo_index_runs.
            try
                app.RunLogger_ = DYNAMORunLogger(app.OutputDirEditField.Value);
            catch ME
                app.RunLogger_ = [];
                app.TextArea.addnl(['Warning: could not open run log: ', ME.message]);
            end

            % Parse channel list, stage identifiers, and delimiter once before the loop
            app.TextArea.Value = 'Processing channel inputs.';
            updateChannelInput(app)
            updateReferenceInput(app)
            updateStagesInput(app)
            updateDelimeterInput(app)
            drawnow;

            % Initialize the progress bar widget — ticks once per (file,
            % channel) pair so the bar reflects the full work unit count.
            % The label prefix is updated each channel to show "Subject m/M,
            % Channel n/N" so the user can see exactly where the run is.
            nFiles    = length(dataList);
            nChannels = length(app.ChannelList);
            app.ProgressBar.reset();
            app.ProgressBar.N = nFiles * nChannels;
            app.ProgressBar.LabelPrefix = '';
            app.ProgressBar.start;

            % ---------------------------------------------------------------
            %   MAIN BATCH LOOP
            %   Outer: EDF files | Inner: channels
            % ---------------------------------------------------------------
            warnState = warning('off','all');  % suppress all warnings during run
            set(0, 'DefaultFigureVisible', 'off');  % suppress figure windows during batch
            % Guaranteed-restore via onCleanup so an unhandled exception
            % below cannot leave the MATLAB session globally muted (no
            % warnings) or invisible (every new figure hidden until the
            % session restarts). The explicit restores in the normal
            % cleanup and Stop/error branches still run first; these
            % are the belt-and-braces backstops.
            cleanupWarn = onCleanup(@() warning(warnState)); %#ok<NASGU>
            cleanupVis  = onCleanup(@() set(0, 'DefaultFigureVisible', 'on')); %#ok<NASGU>
            app.curr_iteration = 0;

            % Cache the channel list (raw names for load_data) and a parallel
            % list of filesystem-safe names (used by analysis runners for paths).
            % Sanitising once up front avoids O(N_channels x N_runners)
            % redundant fixFilename calls during the loop.
            % For aliased channel specs ('NAME = expr') the output dir
            % name is the alias — never the raw expression — so that a
            % rereferenced or mean-derived channel writes to a clean
            % directory like CFS_LM/ instead of CFS_C3 - mean(A1,A2)/.
            channelList      = app.ChannelList;
            channelListSafe  = cell(size(channelList));
            for ii = 1:numel(channelList)
                spec = channelList{ii};
                eq = strfind(spec, '=');
                if isempty(eq)
                    outname = strtrim(spec);
                else
                    outname = strtrim(spec(1:eq(1)-1));
                end
                channelListSafe{ii} = app.fixFilename(outname,'');
            end

            % Pre-create every output subdirectory that enabled analysis steps
            % will write to. mkdir is idempotent but each call costs a syscall,
            % so doing this once per (channel) rather than per (channel x runner)
            % saves O(N_channels * N_runners) mkdir calls per batch.
            outDir = app.OutputDirEditField.Value;
            for ii = 1:numel(channelListSafe)
                chanDir = fullfile(outDir, channelListSafe{ii});
                if app.SavePeakStatsCheckBox.Value || app.SaveSOPHsCheckBox.Value
                    mkdir(fullfile(chanDir, 'TFpeaks'));
                    mkdir(fullfile(chanDir, 'SOPHs'));
                end
                if app.SaveDataSummaryCheckBox.Value
                    mkdir(fullfile(chanDir, 'figures', 'summary'));
                end
                if app.SaveParamBasisCheckBox.Value
                    mkdir(fullfile(chanDir, 'param_basis'));
                    mkdir(fullfile(chanDir, 'figures', 'param_basis'));
                end
                if app.SaveSplineBasisCheckBox.Value
                    mkdir(fullfile(chanDir, 'spline_basis'));
                    mkdir(fullfile(chanDir, 'figures', 'spline_basis'));
                end
                if app.SaveAuxDataCheckBox.Value
                    mkdir(fullfile(chanDir, 'auxiliary_data'));
                end
            end

            t_batch = tic;
            for jj = 1:length(dataList)

                % --- Per-subject setup (formerly inside the channel loop) ---
                [~, app.input_fbase, ext] = fileparts(dataList{jj});
                % For .edf.gz / .edf.zst inputs fileparts returns
                % "<name>.edf" as the basename and ".gz" / ".zst" as
                % the ext — strip the trailing ".edf" so output
                % filenames don't carry it.
                if (strcmpi(ext, '.gz') || strcmpi(ext, '.zst')) ...
                        && endsWith(app.input_fbase, '.edf', 'IgnoreCase', true)
                    app.input_fbase = app.input_fbase(1:end-4);
                end

                % Subject-level stop check before incurring the EDF read
                if app.isStopBatchButtonPushed == true
                    haltMsg = sprintf('Run halted by user before subject %d/%d (%s).', ...
                        jj, nFiles, app.input_fbase);
                    try, app.writeLog([haltMsg, newline]); catch, end
                    try, fprintf('\n%s\n', haltMsg); catch, end
                    warning(warnState);
                    set(0, 'DefaultFigureVisible', 'on');
                    app.stopLogConsoleTimer();
                    app.updateLogConsole();
                    if ~isempty(app.consolelog_fid) && app.consolelog_fid > 0, fclose(app.consolelog_fid); app.consolelog_fid = []; end
                    diary off;
                    if ~isempty(app.runlog_fid) && app.runlog_fid > 0, fclose(app.runlog_fid); app.runlog_fid = []; end
                    try
                        if ~isempty(app.RunLogger_), app.RunLogger_.close(); end
                    catch
                    end
                    app.RunLogger_ = [];
                    app.RunBatchButton.Enabled  = true;
                    app.StopBatchButton.Enabled = false;
                    app.set_rundefault;
                    app.ProgressBar.reset();
                    app.ProgressBar.Enabled = false;
                    return
                end

                % --- Bulk EDF + staging read for this subject ---
                % All channels in one read_EDF pass so the EDF/staging
                % files are touched once per subject (was once per
                % (subject, channel)). On remote storage this collapses
                % nFiles*nChannels full-file transfers into nFiles, and
                % reference derivations (mean(), A-B, etc.) get computed
                % once and shared across every output that uses them.
                fprintf('\n=== Subject: %s (%d/%d) ===\n', app.input_fbase, jj, nFiles);
                app.TextArea.addnl(sprintf('=== Subject: %s (%d/%d) ===', ...
                    app.input_fbase, jj, nFiles));
                app.TextArea.addnl(sprintf('Loading staging and EDF data (%d channel(s))...', nChannels));

                bulk_data        = [];
                bulk_Fs          = [];
                bulk_stage_times = [];
                bulk_stage_vals  = [];
                subject_loaded_ok    = false;
                channel_load_failed  = false(1, nChannels);
                t_load = tic;
                try
                    [bulk_data, bulk_Fs, bulk_stage_times, bulk_stage_vals] = load_data( ...
                        dataList{jj}, ...
                        stagingList{jj}, ...
                        app.StagesColumnEditField.Value, ...
                        app.TimesColumnEditField.Value, ...
                        channelList, ...
                        'References',  app.ReferenceList, ...
                        'header_lines', app.HeaderRowsEditField.Value, ...
                        'delimiter',    app.delimeter, ...
                        'stage_vals_in', { app.ArtifactUserInput, app.WakeUserInput, ...
                        app.REMUserInput,      app.N1UserInput, ...
                        app.N2UserInput,       app.N3UserInput, ...
                        app.UnknownUserInput });

                    % Resample once for every column. With References
                    % defined, load_data's read_EDF call already pushes
                    % TargetFs in and bulk_Fs returns uniformly at the
                    % target rate, making this a no-op — kept for the
                    % References-empty path where read_EDF returned
                    % native rates.
                    if app.ResampleSwitch.Value
                        target_fs = app.ResampleFsEditField.Value;
                        if any(abs(bulk_Fs - target_fs) > 1e-9)
                            msg = sprintf('Resampling from %g Hz to %g Hz...', bulk_Fs(1), target_fs);
                            fprintf('%s\n', msg);
                            app.TextArea.addnl(['   ' msg]);
                            drawnow;
                            [pp, qq]  = rat(target_fs / bulk_Fs(1));
                            bulk_data = resample(bulk_data, pp, qq);
                            bulk_Fs   = repmat(target_fs, 1, size(bulk_data, 2));
                        end
                    end

                    % use_no_stages override (after resample so length
                    % reflects final Fs).
                    if app.use_no_stages
                        bulk_stage_times = [0, size(bulk_data, 1) / bulk_Fs(1)];
                        bulk_stage_vals  = [2, 2];
                    end

                    subject_loaded_ok = true;
                catch e_load
                    is_oom = strcmpi(e_load.identifier, 'MATLAB:nomem') ...
                          || strcmpi(e_load.identifier, 'MATLAB:array:SizeLimitExceeded') ...
                          || contains(lower(e_load.message), 'out of memory') ...
                          || contains(lower(e_load.message), 'requested array exceeds');

                    if is_oom && nChannels > 1
                        % Out-of-memory on the bulk read: fall back to
                        % loading one channel at a time, stitching the
                        % columns into bulk_data as we go. Channels that
                        % still fail individually are flagged in
                        % channel_load_failed so the inner loop skips
                        % them but processes the survivors.
                        msg = sprintf( ...
                            'Out of memory on bulk read of %d channel(s). Reverting to channel-by-channel load to save memory.', ...
                            nChannels);
                        app.TextArea.addnl(['   ' msg]);
                        fprintf('\n%s\n', msg);
                        try, app.writeLog([msg, newline]); catch, end
                        drawnow;

                        % Free anything the failed bulk read may have
                        % partially allocated before retrying.
                        bulk_data = []; bulk_Fs = [];
                        bulk_stage_times = []; bulk_stage_vals = [];

                        per_ch_ok = false(1, nChannels);
                        for ii_fb = 1:nChannels
                            try
                                [d_ii, f_ii, st_ii, sv_ii] = load_data( ...
                                    dataList{jj}, ...
                                    stagingList{jj}, ...
                                    app.StagesColumnEditField.Value, ...
                                    app.TimesColumnEditField.Value, ...
                                    channelList(ii_fb), ...
                                    'References',  app.ReferenceList, ...
                                    'header_lines', app.HeaderRowsEditField.Value, ...
                                    'delimiter',    app.delimeter, ...
                                    'stage_vals_in', { app.ArtifactUserInput, app.WakeUserInput, ...
                                    app.REMUserInput,      app.N1UserInput, ...
                                    app.N2UserInput,       app.N3UserInput, ...
                                    app.UnknownUserInput });
                                if app.ResampleSwitch.Value
                                    target_fs = app.ResampleFsEditField.Value;
                                    if any(abs(f_ii - target_fs) > 1e-9)
                                        [pp, qq] = rat(target_fs / f_ii(1));
                                        d_ii = resample(d_ii, pp, qq);
                                        f_ii = repmat(target_fs, 1, size(d_ii, 2));
                                    end
                                end
                                if isempty(bulk_data)
                                    bulk_data        = nan(size(d_ii, 1), nChannels);
                                    bulk_Fs          = nan(1, nChannels);
                                    bulk_stage_times = st_ii;
                                    bulk_stage_vals  = sv_ii;
                                end
                                bulk_data(:, ii_fb) = d_ii;
                                bulk_Fs(ii_fb)      = f_ii(1);
                                per_ch_ok(ii_fb)    = true;
                            catch e_ch
                                channel_load_failed(ii_fb) = true;
                                chFailMsg = sprintf( ...
                                    'Channel %s: per-channel fallback load failed (%s).', ...
                                    channelList{ii_fb}, e_ch.message);
                                app.TextArea.addnl(['   ' chFailMsg]);
                                fprintf('   %s\n', chFailMsg);
                                try, app.writeLog([chFailMsg, newline]); catch, end
                            end
                        end

                        if any(per_ch_ok)
                            if app.use_no_stages
                                first_ok_ii = find(per_ch_ok, 1);
                                bulk_stage_times = [0, size(bulk_data, 1) / bulk_Fs(first_ok_ii)];
                                bulk_stage_vals  = [2, 2];
                            end
                            subject_loaded_ok = true;
                        else
                            allFailMsg = sprintf( ...
                                'Subject %s: bulk read OOM and every per-channel retry also failed. All %d channel(s) skipped.', ...
                                app.input_fbase, nChannels);
                            app.TextArea.addnl(allFailMsg);
                            fprintf('\nERROR — %s\n', allFailMsg);
                            try, app.writeLog([allFailMsg, newline]); catch, end
                        end
                    else
                        loadFailMsg = sprintf( ...
                            'Subject %s: load failed. All %d channel(s) skipped.', ...
                            app.input_fbase, nChannels);
                        app.TextArea.addnl(loadFailMsg);
                        fprintf('\nERROR — %s\n%s\n', loadFailMsg, getReport(e_load, 'basic'));
                        app.writeLog(sprintf('%s\n%s\n', loadFailMsg, e_load.message));
                    end
                    drawnow;
                end

                for ii = 1:length(channelList)
                    app.channel = channelListSafe{ii};

                    % Update the progress-bar label so the user can see
                    % which subject/channel is currently running. The bar
                    % itself is ticked at the end of this iteration.
                    try
                        app.ProgressBar.LabelPrefix = sprintf( ...
                            'Subject %d/%d, Channel %d/%d', ...
                            jj, nFiles, ii, nChannels);
                    catch
                        % progress bar UI errors must never abort the batch
                    end

                    % Honor stop request before starting each new iteration
                    if app.isStopBatchButtonPushed == true
                        haltMsg = sprintf('Run halted by user before subject %d/%d, channel %d/%d (%s | %s).', ...
                            jj, nFiles, ii, nChannels, ...
                            app.input_fbase, app.channel);
                        try, app.writeLog([haltMsg, newline]); catch, end
                        try, fprintf('\n%s\n', haltMsg); catch, end
                        warning(warnState);
                        set(0, 'DefaultFigureVisible', 'on');
                        app.stopLogConsoleTimer();
                        app.updateLogConsole();
                        if ~isempty(app.consolelog_fid) && app.consolelog_fid > 0, fclose(app.consolelog_fid); app.consolelog_fid = []; end
                        diary off;
                        if ~isempty(app.runlog_fid) && app.runlog_fid > 0, fclose(app.runlog_fid); app.runlog_fid = []; end
                        try
                            if ~isempty(app.RunLogger_), app.RunLogger_.close(); end
                        catch
                        end
                        app.RunLogger_ = [];
                        app.RunBatchButton.Enabled  = true;
                        app.StopBatchButton.Enabled = false;
                        app.set_rundefault;
                        app.ProgressBar.reset();
                        app.ProgressBar.Enabled = false;
                        return
                    end

                    app.anything_run = 0;
                    app.partial_failures = {};
                    % Clear cached compute state from any prior channel.
                    app.SOPHs            = [];
                    app.stats_table      = [];
                    app.auxiliary_data   = [];
                    app.Fs               = [];

                    fprintf('\n--- Subject: %s | Channel: %s ---\n', app.input_fbase, app.channel);
                    app.TextArea.addnl(sprintf('--- Subject: %s | Channel: %s ---', ...
                        app.input_fbase, app.channel));

                    stage_failures = {};
                    t_iter = tic;

                    if ~subject_loaded_ok || channel_load_failed(ii)
                        % Either the whole subject failed to load, or
                        % we fell back to per-channel mode and this
                        % particular channel still failed. Either way,
                        % log load_failed and tick the progress bar so
                        % totals stay consistent with the planned work
                        % units.
                        if ~isempty(app.RunLogger_)
                            try
                                app.RunLogger_.recordSubject( ...
                                    app.input_fbase, app.channel, ...
                                    'InputFile',  dataList{jj}, ...
                                    'Components', {}, ...
                                    'Failures',   {'load'}, ...
                                    'Status',     'load_failed', ...
                                    'DurationSec', toc(t_load));
                            catch
                            end
                        end
                        try
                            app.curr_iteration = app.curr_iteration + 1;
                            app.ProgressBar.updateIteration(app.curr_iteration);
                        catch
                        end
                        continue
                    end

                    % Slice this channel from the bulk read.
                    app.data        = bulk_data(:, ii);
                    app.Fs          = bulk_Fs(ii);
                    app.stage_times = bulk_stage_times;
                    app.stage_vals  = bulk_stage_vals;

                    % ---- Run selected analysis steps (each isolated) ----
                    % Each stage gets its own try/catch. On failure, log the
                    % specific stage and continue with subsequent stages.
                    stages = {};
                    if app.SavePeakStatsCheckBox.Value || app.SaveSOPHsCheckBox.Value
                        stages{end+1} = struct('name','TF-peaks / SOPH', 'fcn',@() runStatsTable(app));
                    end
                    if app.SaveDataSummaryCheckBox.Value
                        stages{end+1} = struct('name','data summary figure', 'fcn',@() runDataSummaryFigure(app));
                    end
                    if app.SaveParamBasisCheckBox.Value
                        stages{end+1} = struct('name','parametric basis fit', 'fcn',@() runParamBasis(app));
                    end
                    if app.SaveSplineBasisCheckBox.Value
                        stages{end+1} = struct('name','spline basis fit', 'fcn',@() runSplineBasis(app));
                    end
                    if app.SaveAuxDataCheckBox.Value
                        stages{end+1} = struct('name','auxiliary data', 'fcn',@() saveAuxData(app));
                    end

                    for ss = 1:numel(stages)
                        try
                            stages{ss}.fcn();
                        catch e_stage
                            stage_failures{end+1} = stages{ss}.name; %#ok<AGROW>
                            app.TextArea.addnl(['   [ERROR] ', stages{ss}.name, ...
                                ' failed — see log for details.']);
                            fprintf('\nERROR — Subject %s, channel %s, stage "%s": %s\n', ...
                                app.input_fbase, app.channel, stages{ss}.name, ...
                                getReport(e_stage, 'basic'));
                            app.writeLog(sprintf( ...
                                'Subject %s, channel %s: stage "%s" failed: %s\n', ...
                                app.input_fbase, app.channel, stages{ss}.name, e_stage.message));
                        end
                    end

                    % ---- Per-subject summary ----
                    % Stage-level failures (whole stage threw) and sub-step
                    % failures (e.g. one of power/phase fits returned empty)
                    % both count toward "partially run".
                    all_failures = [stage_failures, app.partial_failures];
                    if isempty(all_failures)
                        if app.anything_run
                            app.TextArea.addnl([   'Successfully run subject ', ...
                                app.input_fbase,', channel ',app.channel,'.']);
                            app.writeLog(sprintf('Subject %s, channel %s: run successfully.\n', ...
                                app.input_fbase, app.channel));
                        else
                            % Nothing new to compute: all outputs already existed
                            app.writeLog(sprintf( ...
                                'Subject %s, channel %s: all files already exist. Subject skipped.\n', ...
                                app.input_fbase, app.channel));
                        end
                    else
                        failed_str = strjoin(all_failures, ', ');
                        app.TextArea.addnl(['Subject ',app.input_fbase, ...
                            ', channel ',app.channel,' partially run. Failed: ',failed_str,'.']);
                        app.writeLog(sprintf( ...
                            'Subject %s, channel %s: partially run. Failed: %s.\n', ...
                            app.input_fbase, app.channel, failed_str));
                    end

                    % Append a structured (subject, channel) event to the
                    % per-run JSONL log so dynamo_index_runs can find it
                    % later without walking the output directory tree.
                    if ~isempty(app.RunLogger_)
                        attempted = {};
                        if app.SavePeakStatsCheckBox.Value, attempted{end+1} = 'TFpeaks';  end
                        if app.SaveSOPHsCheckBox.Value,     attempted{end+1} = 'SOPHs';    end
                        if app.SaveDataSummaryCheckBox.Value,attempted{end+1} = 'summary'; end
                        if app.SaveParamBasisCheckBox.Value, attempted{end+1} = 'paramfit';end
                        if app.SaveSplineBasisCheckBox.Value,attempted{end+1} = 'spline';  end
                        if app.SaveAuxDataCheckBox.Value,    attempted{end+1} = 'aux';     end
                        failed_components = {};
                        for fi = 1:numel(all_failures)
                            switch all_failures{fi}
                                case 'TF-peaks / SOPH'
                                    failed_components = [failed_components, {'TFpeaks','SOPHs'}]; %#ok<AGROW>
                                case 'data summary figure',  failed_components{end+1} = 'summary';   %#ok<AGROW>
                                case 'parametric basis fit', failed_components{end+1} = 'paramfit';  %#ok<AGROW>
                                case 'spline basis fit',     failed_components{end+1} = 'spline';    %#ok<AGROW>
                                case 'auxiliary data',       failed_components{end+1} = 'aux';       %#ok<AGROW>
                                otherwise,                   failed_components{end+1} = all_failures{fi}; %#ok<AGROW>
                            end
                        end
                        succeeded = setdiff(attempted, failed_components, 'stable');
                        if ~isempty(all_failures), status_s = 'partial';
                        elseif app.anything_run,   status_s = 'ok';
                        else,                      status_s = 'skipped';
                        end
                        try
                            app.RunLogger_.recordSubject( ...
                                app.input_fbase, app.channel, ...
                                'InputFile',   dataList{jj}, ...
                                'Components',  succeeded, ...
                                'Failures',    failed_components, ...
                                'Status',      status_s, ...
                                'DurationSec', toc(t_iter));
                        catch
                        end
                    end
                    drawnow;

                    % Tick the progress bar once per (file, channel) pair.
                    % N was set to nFiles*nChannels so curr_iteration tracks
                    % the total channel-subject work units completed.
                    try
                        app.curr_iteration = app.curr_iteration + 1;
                        app.ProgressBar.updateIteration(app.curr_iteration);
                    catch e
                        warning(warnState);
                        set(0, 'DefaultFigureVisible', 'on');
                        disp(e);
                        app.stopLogConsoleTimer();
                        app.updateLogConsole();
                        if ~isempty(app.consolelog_fid) && app.consolelog_fid > 0, fclose(app.consolelog_fid); app.consolelog_fid = []; end
                        diary off;
                        if ~isempty(app.runlog_fid) && app.runlog_fid > 0, fclose(app.runlog_fid); app.runlog_fid = []; end
                        try
                            if ~isempty(app.RunLogger_), app.RunLogger_.close(); end
                        catch
                        end
                        app.RunLogger_ = [];
                        app.set_rundefault;
                        app.ProgressBar.reset();
                        app.ProgressBar.Enabled = false;
                        % Restore the run/stop button state so the user can
                        % start another batch. Without these, RUN stays
                        % disabled and STOP stays enabled, leaving the GUI
                        % stuck — the only escape is restarting the app.
                        app.RunBatchButton.Enabled  = true;
                        app.StopBatchButton.Enabled = false;
                        return;
                    end

                end % channel loop

            end % file loop

            % ---------------------------------------------------------------
            %   CLEANUP
            % ---------------------------------------------------------------
            warning(warnState);
            set(0, 'DefaultFigureVisible', 'on');
            app.ProgressBar.complete();
            drawnow
            app.ProgressBar.Enabled = false;

            % Total elapsed time for the whole batch — printed to the
            % UI textarea, the run log, and stdout/diary so it's easy
            % to compare runs across machines / network conditions.
            batchElapsed = toc(t_batch);
            hh = floor(batchElapsed / 3600);
            mm = floor(mod(batchElapsed, 3600) / 60);
            ss_t = mod(batchElapsed, 60);
            if hh > 0
                batchTimeStr = sprintf('%dh %02dm %05.2fs', hh, mm, ss_t);
            elseif mm > 0
                batchTimeStr = sprintf('%dm %05.2fs', mm, ss_t);
            else
                batchTimeStr = sprintf('%.2fs', ss_t);
            end
            totalMsg = sprintf( ...
                'Batch run complete. Total time: %s (%d subject(s) x %d channel(s) = %d run unit(s)).', ...
                batchTimeStr, nFiles, nChannels, nFiles * nChannels);
            app.TextArea.addnl(totalMsg);
            try, app.writeLog([totalMsg, newline]); catch, end
            fprintf('\n%s\n', totalMsg);
            drawnow;
            app.stopLogConsoleTimer();
            app.updateLogConsole();  % final capture of any remaining diary output
            if ~isempty(app.consolelog_fid) && app.consolelog_fid > 0, fclose(app.consolelog_fid); app.consolelog_fid = []; end
            diary off;
            if ~isempty(app.runlog_fid) && app.runlog_fid > 0, fclose(app.runlog_fid); app.runlog_fid = []; end
            try
                if ~isempty(app.RunLogger_), app.RunLogger_.close(); end
            catch
            end
            app.RunLogger_ = [];
            app.RunBatchButton.Enabled  = true;
            app.StopBatchButton.Enabled = false;
            app.set_rundefault;
            drawnow
        end % runBatch

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

        function set_running(app)
            % set_running  Swap the RUN button into its "running" state:
            % an animated SVG bar-graph icon and the label "RUNNING".
            % Also overrides the default Enabled=false visual (50%
            % opacity fade) so the button reads as actively running
            % rather than greyed-out unavailable: full-opacity light
            % green background, full-strength text, no shadows. The
            % button is still pointer-events:none from the .css-
            % disabled rule, so it remains untouchable.
            app.RunBatchButton.Icon = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 135 140" fill="currentColor"><rect y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.5s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.5s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="30" y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.25s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.25s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="60" width="15" height="140" rx="6"><animate attributeName="height" begin="0s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="90" y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.25s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.25s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="120" y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.5s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.5s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect></svg>';
            app.RunBatchButton.Text = 'RUNNING';
            app.RunBatchButton.CSS = [ ...
                '.css-control{background-color:#ABFFCD !important;}' ...
                '.css-disabled{opacity:1 !important;}' ...
                '.css-disabled *{opacity:1 !important;color:inherit !important;' ...
                'text-shadow:none !important;box-shadow:none !important;' ...
                'filter:none !important;}'];
            drawnow;
        end

        function set_rundefault(app)
            % set_rundefault  Restore the RUN button to its idle state
            % (play-triangle icon, label "RUN"). Called on completion,
            % stop, or error of a batch. Clears the running-state CSS
            % override so future Enabled=false transitions get the
            % normal greyed-out visual again.
            app.RunBatchButton.Icon = '<path d="M8 5v14l11-7z"/>';
            app.RunBatchButton.Text = 'RUN';
            app.RunBatchButton.CSS  = '';
            drawnow;
        end

    end% private methods

    methods (Static)
        % Pure file-format writer for the parametric-fit CSV — exposed so
        % external scripts (and the equivalence-test harness) can write
        % the same comment-headered CSV that runParamBasis writes.
        writeParamfitCsv(filename, PF, axis_kind, freq_bins, so_bins);
    end

    methods (Static, Access=protected)
        function svg_html = make_logo_svg(varargin)
            % Set up the input parser
            p = inputParser;
            addParameter(p, 'width', []);
            addParameter(p, 'height', []);

            % Parse the inputs
            parse(p, varargin{:});

            % Initial string
            svg_html = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 554.42 282.62"';

            % Check for width and concatenate
            if ~isempty(p.Results.width)
                svg_html = [svg_html, ' width = ', num2str(p.Results.width)];
            end

            % Check for height and concatenate
            if ~isempty(p.Results.height)
                svg_html = [svg_html, ' height = ', num2str(p.Results.height)];
            end

            svg_html = [svg_html '><defs><style>.cls-1,.cls-2{fill:none;}.cls-3,.cls-4{fill:#010101;}.cls-5,.cls-6{fill:#1971b9;}.cls-5,.cls-6,.cls-4{font-family:Saira-Regular, Saira;}.cls-6,.cls-4{font-size:118.08px;}.cls-7{font-size:36px;}.cls-8{font-size:23px;}.cls-2{stroke:#1372ba;stroke-linejoin:round;stroke-width:4.93px;}</style></defs><polyline class="cls-2" points="14.88 59.48 158.69 59.48 159.16 58.62 159.64 57.79 160.12 57.01 160.59 56.32 161.06 55.73 161.54 55.27 162.01 54.94 162.48 54.78 162.96 54.77 163.43 54.94 163.9 55.26 164.38 55.74 164.85 56.36 165.33 57.1 165.8 57.95 166.28 58.87 166.75 59.84 167.22 60.82 167.7 61.78 168.17 62.69 168.65 63.51 169.12 64.22 169.59 64.77 170.07 65.16 170.54 65.35 171.02 65.34 171.49 65.11 171.96 64.67 172.44 64.03 172.91 63.2 173.39 62.2 173.86 61.06 174.34 59.82 174.81 58.52 175.28 57.2 175.76 55.91 176.23 54.7 176.7 53.61 177.18 52.69 177.65 51.98 178.12 51.52 178.6 51.33 179.08 51.44 179.55 51.84 180.03 52.54 180.5 53.52 180.97 54.76 181.45 56.24 181.92 57.88 182.39 59.66 183.34 63.35 183.81 65.13 184.29 66.77 184.76 68.21 185.24 69.39 185.71 70.25 186.19 70.75 186.66 70.86 187.14 70.55 187.61 69.83 188.08 68.69 188.56 67.17 189.03 65.31 189.5 63.16 189.98 60.8 190.45 58.3 190.93 55.75 191.4 53.23 191.87 50.86 192.35 48.71 192.83 46.88 193.3 45.45 193.77 44.48 194.25 44.02 194.72 44.12 195.19 44.77 195.67 46 196.14 47.76 196.62 50 197.09 52.67 197.56 55.68 198.04 58.92 198.52 62.3 198.99 65.67 199.46 68.94 199.94 71.96 200.41 74.62 200.88 76.82 201.36 78.45 201.83 79.44 202.3 79.72 202.78 79.28 203.25 78.11 203.73 76.22 204.2 73.66 204.68 70.52 205.15 66.88 205.63 62.86 206.1 58.62 206.57 54.28 207.05 50.01 207.52 45.97 207.99 42.31 208.47 39.18 208.94 36.7 209.42 34.98 209.89 34.11 210.36 34.13 210.84 35.08 211.32 36.94 211.79 39.66 212.26 43.17 212.74 47.35 213.21 52.08 213.68 57.19 214.16 62.5 214.63 67.83 215.11 72.99 215.58 77.77 216.05 81.99 216.53 85.5 217 88.15 217.48 89.81 217.95 90.41 218.43 89.91 218.9 88.3 219.37 85.61 219.85 81.92 220.32 77.34 220.8 72.02 221.27 66.14 221.74 59.9 222.22 53.52 222.69 47.24 223.16 41.27 223.64 35.85 224.12 31.18 224.59 27.44 225.06 24.79 225.54 23.34 226.01 23.17 226.48 24.3 226.96 26.73 227.43 30.38 227.91 35.13 228.38 40.85 228.85 47.34 229.33 54.36 229.8 61.69 230.28 69.06 230.75 76.2 231.23 82.86 231.7 88.77 232.17 93.72 232.65 97.52 233.12 100 233.59 101.06 234.07 100.64 234.54 98.74 235.02 95.39 235.49 90.71 235.96 84.84 236.44 77.98 236.92 70.36 237.39 62.24 237.86 53.92 238.34 45.69 238.81 37.86 239.28 30.7 239.76 24.48 240.23 19.44 240.71 15.79 241.18 13.65 241.65 13.13 242.13 14.28 242.6 17.06 243.08 21.39 243.55 27.13 244.03 34.1 244.5 42.06 244.97 50.72 245.45 59.79 245.92 68.93 246.4 77.83 246.87 86.16 247.34 93.62 247.82 99.92 248.29 104.83 248.76 108.16 249.24 109.78 249.72 109.61 250.19 107.65 250.66 103.93 251.14 98.6 251.61 91.83 252.09 83.84 252.56 74.91 253.03 65.37 253.51 55.53 253.98 45.77 254.45 36.43 254.93 27.84 255.4 20.34 255.88 14.17 256.35 9.59 256.83 6.76 257.3 5.8 257.77 6.75 258.25 9.6 258.72 14.24 259.2 20.53 259.67 28.25 260.14 37.12 260.62 46.84 261.09 57.06 261.56 67.42 262.04 77.54 262.51 87.07 262.99 95.65 263.46 102.98 263.94 108.78 264.41 112.85 264.89 115.03 265.36 115.23 265.83 113.44 266.31 109.72 266.78 104.2 267.25 97.05 267.73 88.55 268.2 78.98 268.67 68.7 269.15 58.05 269.62 47.44 270.1 37.22 270.57 27.78 271.05 19.45 271.52 12.54 272 7.29 272.47 3.89 272.94 2.46 273.42 3.08 273.89 5.7 274.36 10.24 274.84 16.54 275.31 24.38 275.79 33.47 276.26 43.49 276.73 54.08 277.21 64.87 277.68 75.47 278.16 85.49 278.63 94.58 279.11 102.41 279.58 108.72 280.05 113.26 280.53 115.88 281 116.49 281.48 115.07 281.95 111.67 282.42 106.42 282.9 99.5 283.37 91.17 283.84 81.74 284.32 71.52 284.79 60.91 285.26 50.26 285.74 39.97 286.22 30.41 286.69 21.9 287.17 14.76 287.64 9.23 288.11 5.51 288.59 3.73 289.06 3.93 289.53 6.1 290.01 10.17 290.48 15.98 290.95 23.3 291.43 31.89 291.9 41.41 292.38 51.54 292.85 61.9 293.32 72.12 293.8 81.84 294.27 90.71 294.75 98.43 295.22 104.71 295.7 109.36 296.17 112.21 296.64 113.15 297.12 112.2 297.59 109.37 298.07 104.79 298.54 98.62 299.01 91.11 299.49 82.53 299.96 73.18 300.43 63.42 300.91 53.59 301.39 44.04 301.86 35.12 302.33 27.13 302.81 20.35 303.28 15.02 303.75 11.31 304.23 9.34 304.7 9.17 305.17 10.79 305.65 14.13 306.12 19.03 306.6 25.34 307.07 32.79 307.54 41.12 308.02 50.03 308.5 59.17 308.97 68.24 309.44 76.9 309.92 84.85 310.39 91.82 310.86 97.57 311.34 101.9 311.81 104.68 312.29 105.82 312.76 105.31 313.23 103.17 313.71 99.51 314.18 94.47 314.65 88.26 315.13 81.1 315.61 73.26 316.08 65.03 316.55 56.71 317.03 48.6 317.5 40.98 317.98 34.11 318.45 28.25 318.92 23.56 319.4 20.22 319.87 18.31 320.34 17.89 320.82 18.96 321.29 21.44 321.76 25.24 322.24 30.19 322.72 36.1 323.19 42.75 323.67 49.89 324.14 57.26 324.61 64.59 325.09 71.62 325.56 78.1 326.03 83.82 326.51 88.58 326.98 92.23 327.45 94.65 327.93 95.79 328.4 95.62 328.88 94.17 329.35 91.52 329.83 87.78 330.3 83.1 330.78 77.68 331.25 71.72 331.72 65.43 332.2 59.05 332.67 52.82 333.14 46.94 333.62 41.62 334.09 37.04 334.57 33.35 335.04 30.66 335.51 29.05 335.99 28.54 336.46 29.15 336.93 30.81 337.41 33.45 337.89 36.96 338.36 41.19 338.83 45.97 339.31 51.12 339.78 56.45 340.26 61.77 340.73 66.88 341.2 71.61 341.68 75.79 342.15 79.3 342.62 82.02 343.1 83.87 343.57 84.82 344.04 84.85 344.52 83.98 344.99 82.26 345.47 79.78 345.94 76.64 346.42 72.98 346.89 68.95 347.37 64.67 347.84 60.34 348.31 56.09 348.79 52.07 349.26 48.44 349.73 45.29 350.21 42.74 350.68 40.85 351.16 39.67 351.63 39.23 352.1 39.52 352.58 40.51 353.06 42.14 353.53 44.33 354 46.99 354.48 50.01 354.95 53.28 355.42 56.66 355.9 60.03 356.37 63.28 356.84 66.28 357.32 68.95 357.79 71.2 358.27 72.96 358.74 74.18 359.21 74.84 359.69 74.93 360.16 74.47 360.64 73.5 361.11 72.07 361.59 70.24 362.06 68.09 362.53 65.72 363.01 63.21 363.48 60.66 363.96 58.16 364.43 55.79 364.9 53.64 365.38 51.78 365.85 50.27 366.32 49.13 366.8 48.4 367.27 48.09 367.75 48.2 368.22 48.7 368.7 49.56 369.17 50.74 369.65 52.19 370.12 53.83 370.59 55.61 371.54 59.29 372.01 61.07 372.49 62.72 372.96 64.19 373.43 65.43 373.91 66.42 374.38 67.11 374.86 67.52 375.34 67.62 375.81 67.43 376.28 66.97 376.76 66.26 377.23 65.35 377.7 64.26 378.18 63.05 378.65 61.76 379.12 60.44 379.6 59.13 380.07 57.89 380.55 56.75 381.02 55.76 381.49 54.92 381.97 54.28 382.45 53.84 382.92 53.62 383.39 53.61 383.87 53.8 384.34 54.18 384.81 54.74 385.29 55.44 385.76 56.27 386.24 57.17 386.71 58.13 387.18 59.12 387.66 60.08 388.13 61.01 388.6 61.86 389.08 62.6 389.56 63.22 390.03 63.7 390.5 64.02 390.98 64.18 391.45 64.18 391.92 64.01 392.4 63.69 392.87 63.22 393.35 62.63 393.82 61.94 394.29 61.17 394.77 60.33 395.24 59.47 538.88 59.47"/><text class="cls-6" transform="translate(469.76 210.42)"><tspan x="0" y="0">O</tspan></text><path class="cls-3" d="m7.02,59.44c0-4.49,3.64-8.12,8.13-8.12s8.12,3.64,8.12,8.12-3.64,8.13-8.12,8.13-8.13-3.64-8.13-8.13Z"/><path class="cls-3" d="m530.63,59.44c0-4.49,3.64-8.12,8.12-8.12s8.13,3.64,8.13,8.12-3.64,8.13-8.13,8.13-8.12-3.64-8.12-8.13Z"/><rect class="cls-1" x="36.88" y="217.3" width="510.8" height="50.05"/><text class="cls-5" transform="translate(52.54 245.98)"><tspan class="cls-7"><tspan x="0" y="0">dynamic oscillation toolbox</tspan></tspan></text><text class="cls-4" transform="translate(0 210.42)"><tspan x="0" y="0">DYNAM-</tspan></text></svg>'];
        end

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
