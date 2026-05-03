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
        AnalysisTab                     matlab.ui.container.Tab         % Outer tab — analysis views (SO-Histograms, etc.)
        AnalysisTabGroup                matlab.ui.container.TabGroup    % Inner tab group inside AnalysisTab
        SOHistogramsTab                 matlab.ui.container.Tab
        ResultsBrowserPreviewGrid       matlab.ui.container.GridLayout  % Right column of Results Browser — preview pane
        ResultsBrowserPreviewTitle      % CSSuiLabel  — current file path / placeholder
        ResultsBrowserPreviewBody       matlab.ui.container.Panel       % Container for the lazy viewer (axes / table)
        SOHistogramsGrid                matlab.ui.container.GridLayout  % top selector | bottom plot grid
        SOHistogramsSelectorPanel       matlab.ui.container.GridLayout  % wraps the listbox + label
        SOHistogramsChannelLabel        % CSSuiLabel
        SOHistogramsChannelListBox      matlab.ui.control.ListBox       % multi-select channel picker
        SOHistogramsPlotPanel           matlab.ui.container.Panel        % white uipanel hosting figdesign axes
        SOHistogramsPlaceholderAxes     % uiaxes filling the panel when nothing is selected
        SOHist_ChannelInfo_      = []   % struct array: {name, hasPower, hasPhase, powerPath, phasePath}
        SOHist_SuppressFcn_      = false% reentry guard for listbox value change

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

            % Build all UI components
            createComponents(app, p.Results.Title, p.Results.Position);
            app.enforceMinSize;

            % Apply quick-fill inputs (each independent; skip if not given).
            applyQuickFill(app, p.Results);
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
                    app.ChannelEditField.Value = chanStr;
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

        function showHelpButtonPushed(app)
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

        % ------------------------------------------------------------------

        function loadDataFileListCallback(app, ~)
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

            % Store only valid, unique files
            app.DataList = cellstr(uniqueValidLines);
            app.updateDataListBox;

            % Only show dedicated window if there are skipped or duplicate files
            if isempty(invalidLines) && isempty(duplicateLines)
                return
            end

            % --- Create the dedicated window ---
            win = uifigure('Name','File List Issues','Position',[200 200 800 400]);

            % Skipped files listbox
            lblSkipped = CSSuiLabel(win,'Text','Skipped (missing) files:','Position',[20 360 200 20]); %#ok<*NASGU>
            listSkipped = CSSuiListBox(win,'Items',cellstr(invalidLines),'Position',[20 180 360 180],'Multiselect',false,'Style','shadow_light'); %#ok<NASGU>

            % Duplicate files listbox
            lblDup = CSSuiLabel(win,'Text','Duplicate files removed:','Position',[400 360 200 20]);
            listDup = CSSuiListBox(win,'Items',cellstr(duplicateLines),'Position',[400 180 360 180],'Multiselect',false,'Style','shadow_light'); %#ok<NASGU>

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

        % ------------------------------------------------------------------

        function loadStagingListCallback(app, varargin)
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

            % Skipped files listbox
            lblSkipped = CSSuiLabel(win,'Text','Skipped (missing) files:','Position',[20 360 200 20]);
            listSkipped = CSSuiListBox(win,'Items',cellstr(invalidLines),'Position',[20 180 360 180],'Multiselect',false,'Style','shadow_light'); %#ok<NASGU>

            % Duplicate files listbox
            lblDup = CSSuiLabel(win,'Text','Duplicate files removed:','Position',[400 360 200 20]);
            listDup = CSSuiListBox(win,'Items',cellstr(duplicateLines),'Position',[400 180 360 180],'Multiselect',false,'Style','shadow_light'); %#ok<NASGU>

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

        % ------------------------------------------------------------------

        function DataAddFileButtonPushed(app, ~, ~)
            % DataAddFileButtonPushed  Open file picker to add one or more EDF files.

            files = selectFiles(app, 'Select Data Files', 'data');
            files = setdiff(files, app.DataList, 'stable');
            if ~isempty(files)
                app.DataList = [app.DataList, files];
                updateDataListBox(app);
            end
        end

        % ------------------------------------------------------------------

        function DataAddFolderButtonPushed(app, ~, ~)
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

        % ------------------------------------------------------------------

        function DataRemoveButtonPushed(app, ~, ~)
            % DataRemoveButtonPushed  Remove currently selected EDF files from the list.

            selected = app.DataListBox.Value;
            if isempty(selected), return; end
            app.DataList = setdiff(app.DataList, selected, 'stable');
            updateDataListBox(app);
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

        function StagingAddFileButtonPushed(app, ~, ~)
            % StagingAddFileButtonPushed  Open file picker to add one or more staging files.

            files = selectFiles(app, 'Select Staging Files', 'staging');
            files = setdiff(files, app.StagingList, 'stable');
            if ~isempty(files)
                app.StagingList = [app.StagingList, files];
                updateStagingListBox(app);
            end
        end

        % ------------------------------------------------------------------

        function StagingAddFolderButtonPushed(app, ~, ~)
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

        % ------------------------------------------------------------------

        function StagingRemoveButtonPushed(app, ~, ~)
            % StagingRemoveButtonPushed  Remove currently selected staging files from the list.

            selected = app.StagingListBox.Value;
            if isempty(selected), return; end
            app.StagingList = setdiff(app.StagingList, selected, 'stable');
            updateStagingListBox(app);
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
            % viewChannelsButtonPushed
            % Reads EDF files, collects channel name, sampling frequency, and
            % per-file counts. Displays a table for multi-select. Supports
            % adding A-B rereferenced virtual channels via a sub-dialog.

            if isempty(app.DataList)
                uialert(app.UIFigure, ...
                    'No EDF files loaded. Load at least one file first.', ...
                    'Error', 'Icon', 'error');
                return
            end

            nFiles = length(app.DataList);
            h = waitbar(0, 'Processing EDF channels...');

            % chan_map: label -> {file_index_array, fs_array}
            % Tracks which files contain each channel and at what sample rate.
            chan_map = containers.Map('KeyType','char','ValueType','any');

            for ii = 1:nFiles
                try
                    [~, signalHeader] = read_EDF(app.DataList{ii});
                    for jj = 1:length(signalHeader)
                        lbl = strtrim(signalHeader(jj).signal_labels);
                        fs  = signalHeader(jj).sampling_frequency;
                        if isKey(chan_map, lbl)
                            entry = chan_map(lbl);
                            entry{1}(end+1) = ii;
                            entry{2}(end+1) = fs;
                            chan_map(lbl) = entry;
                        else
                            chan_map(lbl) = {ii, fs};
                        end
                    end
                catch ME
                    warning('Failed to read file: %s\n%s', app.DataList{ii}, ME.message);
                end
                waitbar(ii/nFiles, h);
            end
            delete(h);

            if isempty(chan_map)
                uialert(app.UIFigure, ...
                    'No channel labels found in loaded EDF files.', ...
                    'Warning', 'Icon', 'warning');
                return
            end

            % Build sorted table data: {channel, fs_string, file_count_string}
            all_edf_labels = sort(keys(chan_map));
            nChans = numel(all_edf_labels);
            tableData = cell(nChans, 3);
            for ii = 1:nChans
                lbl   = all_edf_labels{ii};
                entry = chan_map(lbl);
                ufreqs  = unique(entry{2});
                freqStr = [strjoin(arrayfun(@(f) sprintf('%g', f), ufreqs, 'UniformOutput', false), ' / ') ' Hz'];
                fileStr = sprintf('%d / %d', numel(entry{1}), nFiles);
                tableData{ii,1} = lbl;
                tableData{ii,2} = freqStr;
                tableData{ii,3} = fileStr;
            end

            % ===============================
            % UI SELECTION DIALOG
            % ===============================
            % Fixed-size dialog: 520 w x 500 h, all positions calculated from
            % bottom (MATLAB convention).  Layout (bottom→top):
            %   12 pad | 42 accept/cancel | 8 gap | 40 add-rereference |
            %   8 gap  | [table fills]    | 6 gap | 24 label | 12 pad
            dW = 520; dH = 500; pad = 12;
            btnH  = 42; rerefH = 40; lblH = 24;

            btnY   = pad;
            rerefY = btnY  + btnH  + 8;
            tableY = rerefY + rerefH + 8;
            lblY   = dH - pad - lblH;
            tableH = lblY - 6 - tableY;
            tableW = dW - 2*pad;

            ss = get(0, 'ScreenSize');
            d = uifigure('Name', 'Select Channels', ...
                'Position', [(ss(3)-dW)/2, (ss(4)-dH)/2, dW, dH], ...
                'WindowStyle', 'modal');

            CSSuiLabel(d, 'Text', 'Select one or more channels:', ...
                'Position', [pad, lblY, tableW, lblH]);

            % Channel col gets all remaining width after Fs (110) and Files (80)
            % columns, minus ~16 px for the vertical scrollbar.
            chanColW = tableW - 110 - 80 - 16;
            t = CSSuiTable(d, ...
                'Data', tableData, ...
                'ColumnName', {'Channel', 'Fs (Hz)', 'Files'}, ...
                'ColumnWidth', [chanColW, 110, 80], ...
                'Position', [pad, tableY, tableW, tableH], ...
                'Style', 'shadow_light', ...
                'SelectionType', 'row', ...
                'SelectionChangedFcn', @(src,evt) onCellSelect(evt));

            % Add Rereference — centered horizontally
            rerefW = 175;
            CSSuiButton(d, 'Style', 'shadow', 'Text', 'Add Rereference', ...
                'Position', [(dW-rerefW)/2, rerefY, rerefW, rerefH], ...
                'ButtonPushedFcn', @(btn,evt) addRereferenceCallback());

            % Accept / Cancel — centered as a pair
            btnW = 165; gap = 10;
            pairW = 2*btnW + gap;
            btnX0 = (dW - pairW) / 2;
            CSSuiButton(d, 'Style', 'shadow', 'Text', 'Add to Batch Run', ...
                'Position', [btnX0,          btnY, btnW, btnH], ...
                'ButtonPushedFcn', @(btn,evt) acceptCallback());
            CSSuiButton(d, 'Style', 'shadow', 'Text', 'Cancel', ...
                'Position', [btnX0+btnW+gap, btnY, btnW, btnH], ...
                'ButtonPushedFcn', @(btn,evt) cancelCallback());

            selectedRows     = [];
            selectedChannels = [];
            rd_handle        = [];
            ddA_handle       = [];
            ddB_handle       = [];

            uiwait(d);

            if isempty(selectedChannels)
                return
            end

            % Warn if any selected channel's sampling rate is far above or
            % below the frequency ranges DYNAMO actually analyzes.
            checkChannelSamplingRates(app, selectedChannels, tableData);

            % Append to existing channels, avoiding duplicates
            existingStr = strtrim(app.ChannelEditField.Value);
            if isempty(existingStr) || strcmpi(existingStr, 'Enter comma-separated channel labels')
                existingChannels = {};
            else
                existingChannels = strtrim(strsplit(existingStr, ','));
                existingChannels = existingChannels(~cellfun(@isempty, existingChannels));
            end
            newChannels = selectedChannels(~ismember(selectedChannels, existingChannels));
            allChannels = [existingChannels(:); newChannels(:)];
            channelString = strjoin(allChannels, ', ');
            app.ChannelEditField.IsError = false;
            app.ChannelEditField.Value   = channelString;
            disp(['Selected Channels: ' channelString]);

            % ===============================
            % Nested Callbacks
            % ===============================

            function onCellSelect(evt)
                % Handle both SelectionChangedFcn (uifigure) and CellSelectionCallback
                try
                    if isfield(evt, 'Selection') && ~isempty(evt.Selection)
                        selectedRows = unique(evt.Selection(:));
                    elseif isfield(evt, 'Indices') && ~isempty(evt.Indices)
                        selectedRows = unique(evt.Indices(:,1));
                    else
                        selectedRows = [];
                    end
                catch
                    selectedRows = [];
                end
            end

            function addRereferenceCallback()
                if numel(all_edf_labels) < 2
                    uialert(d, ...
                        'Need at least two EDF channels to create a rereference.', ...
                        'Not Enough Channels', 'Icon', 'warning');
                    return
                end

                % Sub-dialog: 420 w x 170 h, position-based layout
                rdW = 420; rdH = 170; rdPad = 12;
                rdBtnH = 40; rdDdH = 36; rdLblH = 24;
                rdBtnY = rdPad;
                rdDdY  = rdBtnY + rdBtnH + 10;
                rdLblY = rdDdY  + rdDdH  + 8;

                % Two equal dropdowns with dash in between
                dashW = 28;
                ddW   = (rdW - 2*rdPad - dashW - 8) / 2;  % 8 = 2x4px gaps

                rd_handle = uifigure('Name', 'Add Rereference Channel', ...
                    'Position', [(ss(3)-rdW)/2, (ss(4)-rdH)/2, rdW, rdH], ...
                    'WindowStyle', 'modal');

                CSSuiLabel(rd_handle, 'Text', 'Select channels to rereference:', ...
                    'Position', [rdPad, rdLblY, rdW-2*rdPad, rdLblH]);

                ddA_handle = CSSuiDropdown(rd_handle, 'Style', 'shadow_light', ...
                    'Items', all_edf_labels, ...
                    'Position', [rdPad, rdDdY, ddW, rdDdH]);

                CSSuiLabel(rd_handle, 'Text', '-', ...
                    'FontSize', '18px', 'FontWeight', '700', 'HorizontalAlignment', 'center', ...
                    'Position', [rdPad+ddW+4, rdDdY, dashW, rdDdH]);

                ddB_handle = CSSuiDropdown(rd_handle, 'Style', 'shadow_light', ...
                    'Items', all_edf_labels, ...
                    'Position', [rdPad+ddW+4+dashW+4, rdDdY, ddW, rdDdH]);

                % OK / Cancel centered as a pair
                rdBtnW = 90; rdBtnGap = 10;
                rdPairW = 2*rdBtnW + rdBtnGap;
                rdBtnX0 = (rdW - rdPairW) / 2;
                CSSuiButton(rd_handle, 'Style', 'shadow', 'Text', 'OK', ...
                    'Position', [rdBtnX0,                  rdBtnY, rdBtnW, rdBtnH], ...
                    'ButtonPushedFcn', @(btn,evt) doOkReref());
                CSSuiButton(rd_handle, 'Style', 'shadow', 'Text', 'Cancel', ...
                    'Position', [rdBtnX0+rdBtnW+rdBtnGap,  rdBtnY, rdBtnW, rdBtnH], ...
                    'ButtonPushedFcn', @(btn,evt) doCancelReref());

                uiwait(rd_handle);
            end

            function doOkReref()
                chA = ddA_handle.Value;
                chB = ddB_handle.Value;

                if strcmp(chA, chB)
                    msgbox('Cannot rereference a channel with itself.', 'Invalid Selection', 'error');
                    return
                end

                rerefLabel = [chA '-' chB];

                if any(strcmp(tableData(:,1), rerefLabel))
                    msgbox(sprintf('"%s" is already in the channel list.', rerefLabel), 'Duplicate', 'warn');
                    return
                end

                entryA = chan_map(chA);
                entryB = chan_map(chB);
                [both_files, iA, iB] = intersect(entryA{1}, entryB{1});

                if isempty(both_files)
                    msgbox(sprintf('No files contain both "%s" and "%s".', chA, chB), 'No Overlap', 'warn');
                    return
                end

                fsA_both     = entryA{2}(iA);
                fsB_both     = entryB{2}(iB);
                mismatch_idx = find(fsA_both ~= fsB_both);

                if ~isempty(mismatch_idx)
                    msgLines = cell(1, numel(mismatch_idx));
                    for mm = 1:numel(mismatch_idx)
                        fi = both_files(mismatch_idx(mm));
                        [~, fname] = fileparts(app.DataList{fi});
                        msgLines{mm} = sprintf('  %s: %g Hz vs %g Hz', ...
                            fname, fsA_both(mismatch_idx(mm)), fsB_both(mismatch_idx(mm)));
                    end
                    msgbox(['Sampling rate mismatch between channels:' newline strjoin(msgLines, newline)], ...
                        'Sampling Rate Mismatch', 'error');
                    return
                end

                ufreqs  = unique(fsA_both);
                freqStr = [strjoin(arrayfun(@(f) sprintf('%g', f), ufreqs, 'UniformOutput', false), ' / ') ' Hz'];
                fileStr = sprintf('%d / %d', numel(both_files), nFiles);

                tableData(end+1,:) = {rerefLabel, freqStr, fileStr};
                t.Data = tableData;

                if isvalid(rd_handle)
                    uiresume(rd_handle);
                    delete(rd_handle);
                end
            end

            function doCancelReref()
                if isvalid(rd_handle)
                    uiresume(rd_handle);
                    delete(rd_handle);
                end
            end

            function acceptCallback()
                % Use selectedRows tracked by onCellSelect (most reliable —
                % t.Selection may be stale after button click shifts focus).
                rows = selectedRows;
                if isempty(rows)
                    uialert(d, ...
                        'Please select at least one channel or press Cancel.', ...
                        'No Selection', 'Icon', 'warning');
                    return
                end
                selectedChannels = tableData(rows, 1);
                delete(d);  % deleting the uifigure auto-resumes uiwait
            end

            function cancelCallback()
                selectedChannels = [];
                delete(d);
            end

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

            app.DataListBox.IsError = false;
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
            app.ChannelEditField.IsError      = false;
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

            if strcmpi(app.ChannelEditField.Value, 'Enter comma-separated channel labels') || isempty(app.ChannelEditField.Value)
                app.run_error_list(end+1) = {'- No channels selected.'};
                app.ChannelEditField.IsError = true;
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
            app.aggregateOneChannel(channelDir, aggregatesRoot, categories);
            app.loadResultsBrowserTree();
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
            switch mode
                case 'empty'
                    msg = sprintf(['Select a DYNAM-O results directory above to begin.\n\n' ...
                                   'Use the Browse button or paste a path into the field.']);
                case 'loading'
                    msg = 'Loading directory tree…';
                otherwise
                    msg = 'Click a file in the tree to preview it.';
            end
            app.ResultsBrowserPreviewTitle.Text = 'PREVIEW';
            delete(app.ResultsBrowserPreviewBody.Children);
            ax = uiaxes(app.ResultsBrowserPreviewBody, ...
                'Units','normalized','Position',[0 0 1 1], ...
                'BackgroundColor','white');
            axis(ax,'off');
            text(ax, 0.5, 0.5, msg, ...
                'HorizontalAlignment','center','VerticalAlignment','middle', ...
                'Color',[0.55 0.6 0.65], 'FontSize', 13);
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
                app.styleSOPHAxes(axM, PF.model_SOPH, freq_bins, so_bins, axis_kind);
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
                'Style', 'shadow_light', ...
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
                    'Style', 'shadow_light', ...
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
            % renderResultsBrowserPreviewCsv  Render a CSV as a sortable
            % uitable filling the preview pane.
            delete(app.ResultsBrowserPreviewBody.Children);
            T = readtable(p);
            ut = uitable(app.ResultsBrowserPreviewBody);
            ut.Units    = 'normalized';
            ut.Position = [0 0 1 1];
            ut.Data     = T;
            ut.ColumnSortable = true;
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

        function refreshSOHistogramsAvailability(app)
            % refreshSOHistogramsAvailability  Walk <root>/aggregates/<channel>/SOPHs_*/
            % to determine which channels have aggregate power & phase data.
            % Updates the listbox: every real channel under root is shown, but
            % channels lacking aggregate data are visually marked and
            % filtered out of the selection.
            root = strtrim(char(app.ResultsBrowserOutputDirField.Value));
            chInfo = struct('name',{},'hasPower',{},'hasPhase',{}, ...
                            'powerPath',{},'phasePath',{});
            if ~isempty(root) && isfolder(root)
                entries = dir(root);
                for ii = 1:numel(entries)
                    if ~entries(ii).isdir, continue, end
                    if startsWith(entries(ii).name, '.'), continue, end
                    if ismember(entries(ii).name, {'settings','logs','aggregates'})
                        continue
                    end
                    chDir = fullfile(root, entries(ii).name);
                    if ~(isfolder(fullfile(chDir,'param_basis')) || ...
                         isfolder(fullfile(chDir,'SOPHs')))
                        continue
                    end
                    [pPath, hasPow]   = app.findSOHistAggregate(root, entries(ii).name, 'power');
                    [phPath, hasPhase] = app.findSOHistAggregate(root, entries(ii).name, 'phase');
                    chInfo(end+1) = struct( ...
                        'name',      entries(ii).name, ...
                        'hasPower',  hasPow, ...
                        'hasPhase',  hasPhase, ...
                        'powerPath', pPath, ...
                        'phasePath', phPath); %#ok<AGROW>
                end
            end
            app.SOHist_ChannelInfo_ = chInfo;

            % Display strings: '(no data) <name>' for channels without aggregates.
            items = cell(1, numel(chInfo));
            for ii = 1:numel(chInfo)
                if chInfo(ii).hasPower || chInfo(ii).hasPhase
                    items{ii} = chInfo(ii).name;
                else
                    items{ii} = ['(no data) ' chInfo(ii).name];
                end
            end

            availableNames = {chInfo([chInfo.hasPower] | [chInfo.hasPhase]).name};
            currentVal = app.SOHistogramsChannelListBox.Value;
            if ~iscell(currentVal), currentVal = {currentVal}; end
            currentVal = currentVal(~cellfun(@isempty, currentVal));
            if isempty(currentVal)
                newSelection = availableNames;
            else
                newSelection = intersect(currentVal, availableNames, 'stable');
                if isempty(newSelection)
                    newSelection = availableNames;
                end
            end

            app.SOHist_SuppressFcn_ = true;
            app.SOHistogramsChannelListBox.Items = items;
            if isempty(items)
                app.SOHistogramsChannelListBox.Value = {};
            else
                app.SOHistogramsChannelListBox.Value = newSelection;
            end
            app.SOHist_SuppressFcn_ = false;

            app.redrawSOHistograms();
        end

        % ------------------------------------------------------------------

        function [path, found] = findSOHistAggregate(~, root, channelName, axis_kind)
            % findSOHistAggregate  Locate the aggregate file we should plot
            % for one (channel, axis_kind) pair. Prefers .mat (carries bins)
            % over .tiff (faster but pixel-indexed).
            base = fullfile(root, 'aggregates', channelName, ['SOPHs_' axis_kind], ...
                            [channelName '_aggregate_SOPHs_' axis_kind]);
            if isfile([base '.mat'])
                path = [base '.mat']; found = true; return
            end
            if isfile([base '.tiff'])
                path = [base '.tiff']; found = true; return
            end
            path = ''; found = false;
        end

        % ------------------------------------------------------------------

        function onSOHistogramsSelectionChanged(app)
            % onSOHistogramsSelectionChanged  ListBox change handler for
            % the SO-Histograms tab. Strips any "(no data) ..." entries
            % out of the user's selection before redrawing — those
            % entries are placeholders for channels with no aggregate
            % SOPHs file yet and aren't valid plot targets.
            if app.SOHist_SuppressFcn_, return, end
            sel = app.SOHistogramsChannelListBox.Value;
            if ischar(sel) || isstring(sel), sel = cellstr(sel); end
            keep = sel(~startsWith(sel, '(no data) '));
            if numel(keep) ~= numel(sel)
                app.SOHist_SuppressFcn_ = true;
                app.SOHistogramsChannelListBox.Value = keep;
                app.SOHist_SuppressFcn_ = false;
            end
            app.redrawSOHistograms();
        end

        % ------------------------------------------------------------------

        function redrawSOHistograms(app)
            % redrawSOHistograms  Replace plot-panel children to reflect the
            % current channel selection. Panel itself is persistent (uipanel),
            % so transitions are flicker-light: we delete only its children.
            delete(app.SOHistogramsPlotPanel.Children);

            sel = app.SOHistogramsChannelListBox.Value;
            if ischar(sel) || isstring(sel), sel = cellstr(sel); end
            sel = sel(~startsWith(sel, '(no data) '));
            n = numel(sel);
            if n == 0
                % Restore a single white placeholder axis covering the panel.
                app.SOHistogramsPlaceholderAxes = uiaxes(app.SOHistogramsPlotPanel, ...
                    'Units','normalized', 'Position',[0 0 1 1], ...
                    'BackgroundColor','white');
                axis(app.SOHistogramsPlaceholderAxes,'off');
                text(app.SOHistogramsPlaceholderAxes, 0.5, 0.5, ...
                    'Select one or more channels above', ...
                    'HorizontalAlignment','center','VerticalAlignment','middle', ...
                    'Color',[0.5 0.5 0.5]);
                return
            end

            % Manual N x 2 layout of uiaxes inside the panel — keeps
            % everything in the FileManager window (figdesign forces a
            % standalone figure since it expects a figure handle).
            ax = gobjects(1, n*2);
            top = 0.04; bottom = 0.06; rowSpace = 0.05;
            left = 0.08; midGap = 0.08; right = 0.04;
            colW = (1 - left - midGap - right) / 2;
            usableH = 1 - top - bottom - (n-1)*rowSpace;
            rowH = usableH / n;
            for rr = 1:n
                yBot = bottom + (n - rr) * (rowH + rowSpace);
                ax((rr-1)*2 + 1) = uiaxes(app.SOHistogramsPlotPanel, ...
                    'Units','normalized', 'Position',[left, yBot, colW, rowH], ...
                    'BackgroundColor','white');
                ax((rr-1)*2 + 2) = uiaxes(app.SOHistogramsPlotPanel, ...
                    'Units','normalized', 'Position',[left + colW + midGap, yBot, colW, rowH], ...
                    'BackgroundColor','white');
            end

            for ii = 1:n
                ch = sel{ii};
                idx = find(strcmp({app.SOHist_ChannelInfo_.name}, ch), 1);
                if isempty(idx), continue, end
                info = app.SOHist_ChannelInfo_(idx);

                axP  = ax((ii-1)*2 + 1);
                axPh = ax((ii-1)*2 + 2);

                titleP = sprintf('Mean SO-Power Histogram — %s', ch);
                title(axP, titleP, 'Interpreter','none');
                if info.hasPower
                    app.plotAggregateSOHist(axP, info.powerPath, 'power');
                    app.attachPopOutToolbar(axP, ...
                        @(a) app.plotAggregateSOHist(a, info.powerPath, 'power'), ...
                        titleP);
                else
                    axis(axP,'off');
                    text(axP, 0.5, 0.5, '(no power aggregate)', ...
                         'HorizontalAlignment','center');
                end

                titlePh = sprintf('Mean SO-Phase Histogram — %s', ch);
                title(axPh, titlePh, 'Interpreter','none');
                if info.hasPhase
                    app.plotAggregateSOHist(axPh, info.phasePath, 'phase');
                    app.attachPopOutToolbar(axPh, ...
                        @(a) app.plotAggregateSOHist(a, info.phasePath, 'phase'), ...
                        titlePh);
                else
                    axis(axPh,'off');
                    text(axPh, 0.5, 0.5, '(no phase aggregate)', ...
                         'HorizontalAlignment','center');
                end
            end
        end

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
            if isfield(S, 'freq_bins') && ~isempty(S.freq_bins)
                freq_bins = S.freq_bins(:);
            end
            if isfield(S, binsField) && ~isempty(S.(binsField))
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
            drawnow;
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
                app.ResultsBrowserCache_  = [];
                app.ResultsBrowserTree.Data = ...
                    {struct('text','Invalid DYNAM-O_results folder — see preview pane.', ...
                            'data','', 'isLeaf', true, 'children', {{}})};
                app.renderResultsBrowserPreviewError(root);
                app.logResultsBrowser(sprintf('Load aborted: not a DYNAM-O_results folder: %s', root));
                return
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
            app.renderResultsBrowserPreviewPlaceholder('loading');
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

            app.renderResultsBrowserPreviewPlaceholder();
            app.refreshSOHistogramsAvailability();
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
                    % Sort files by name for stable display
                    [fileNames, sortIdx] = sort(fileNames);
                    filePaths = filePaths(sortIdx);
                    catDirs{is} = struct( ...
                        'name', catName, 'path', catPath, 'isDir', true, ...
                        'dirs', {{}}, ...
                        'files', struct('name', fileNames, 'path', filePaths));
                end

                % Detect non-cataloged subdirs (figures, etc.) via a
                % single dir() at the channel level. Shallow only —
                % their contents populate lazily on user click in a
                % future enhancement; for now they show as empty folders
                % so the user knows they exist.
                extraDirs = app.shallowDirsExcept( ...
                    chanPath, [{'.','..','_runs'}, catNames]);
                for ie = 1:numel(extraDirs)
                    extraName = extraDirs{ie};
                    catDirs{end+1} = struct( ...
                        'name', extraName, ...
                        'path', fullfile(chanPath, extraName), ...
                        'isDir', true, ...
                        'dirs', {{}}, ...
                        'files', struct('name',{},'path',{})); %#ok<AGROW>
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
                allRootDirs{numel(chanDirs)+ie} = struct( ...
                    'name', extraName, ...
                    'path', fullfile(root, extraName), ...
                    'isDir', true, ...
                    'dirs', {{}}, ...
                    'files', struct('name',{},'path',{}));
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

            app.logResultsBrowser('Aggregate: done. Refreshing tree...');
            app.loadResultsBrowserTree();
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

            try
                R = aggregate_DYNAMO_outputs(channelDir, 'Files', files);
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
                'Style',            'shadow_light', ...
                'BackgroundColor',  '#ffffff', ...
                'FontSize',         '12px', ...
                'Color',            '#5f7080', ...
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
            %   the result in app.ChannelList.

            app.ChannelList = textscan(app.ChannelEditField.Value, '%s', 'Delimiter', ',');
            app.ChannelList = app.ChannelList{1,1};
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

            stats_csv    = [statsBase '.csv'];
            stats_mat    = [statsBase '.mat'];
            SOPH_mat     = [sophBase  '.mat'];
            SOPH_tiff    = [sophPowBase '.tiff'];
            stats_exists = isfile(stats_csv) || isfile(stats_mat);
            SOPH_exists  = isfile(SOPH_mat)  || isfile(SOPH_tiff);

            % ---- (1) Make sure SOPHs + stats_table are in memory ----
            % Computing is independent of the SAVE checkboxes / overwrite
            % flag so downstream stages (param/spline/aux) always have
            % SOPHs available even when the user has disabled saving or
            % previous outputs are present in another format on disk.
            need_compute = isempty(app.SOPHs) || isempty(app.stats_table);
            if need_compute && isfile(SOPH_mat) && isfile(stats_mat)
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

            % ---- (2) Save according to user choices and overwrite flag ----
            % Save gates are independent of compute. A re-run that hit
            % the cache above still respects the user's "overwrite" flag.
            save_stats = app.SavePeakStatsCheckBox.Value && ~strcmp(app.PeakStatsTableDropDown.Value,'--') && ...
                (app.OverwriteExistingFilesCheckBox.Value || ~stats_exists);
            save_soph  = app.SaveSOPHsCheckBox.Value && ~strcmp(app.SOPowerHistogramsDropDown.Value,'--') && ...
                (app.OverwriteExistingFilesCheckBox.Value || ~SOPH_exists);

            if save_stats
                app.TextArea.addnl('   Saving stats table...');
                switch app.PeakStatsTableDropDown.Value
                    case '.csv'
                        app.output_stats_name = stats_csv;
                        table2csv(stats_table, app.output_stats_name);
                    case '.mat'
                        app.output_stats_name = stats_mat;
                        save(app.output_stats_name,'stats_table');
                    case 'All'
                        % Save both formats
                        app.output_stats_name = stats_mat;
                        save(app.output_stats_name,'stats_table');
                        app.output_stats_name = stats_csv;
                        table2csv(stats_table, app.output_stats_name);
                end
            end

            if save_soph
                app.TextArea.addnl('   Saving SOPHs');
                powMeta = jsonencode(struct( ...
                    'freq_bins',    SOPHs.freq_bins(:).', ...
                    'SOpower_bins', SOPHs.SOpower_bins(:).'));
                phaMeta = jsonencode(struct( ...
                    'freq_bins',    SOPHs.freq_bins(:).', ...
                    'SOphase_bins', SOPHs.SOphase_bins(:).'));
                switch app.SOPowerHistogramsDropDown.Value
                    case '.tiff'
                        app.output_SOPH_name = [sophPowBase '.tiff'];
                        app.writeTiff(app.output_SOPH_name, SOPHs.SOpower_mat, powMeta);
                        app.output_SOPH_name = [sophPhaBase '.tiff'];
                        app.writeTiff(app.output_SOPH_name, SOPHs.SOphase_mat, phaMeta);
                    case '.mat'
                        app.output_SOPH_name = SOPH_mat;
                        save(app.output_SOPH_name,'SOPHs');
                    case 'All'
                        % Save both tiff and mat
                        app.output_SOPH_name = [sophPowBase '.tiff'];
                        app.writeTiff(app.output_SOPH_name, SOPHs.SOpower_mat, powMeta);
                        app.output_SOPH_name = [sophPhaBase '.tiff'];
                        app.writeTiff(app.output_SOPH_name, SOPHs.SOphase_mat, phaMeta);
                        app.output_SOPH_name = SOPH_mat;
                        save(app.output_SOPH_name,'SOPHs');
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

            % Build output file path (format comes from DataSummaryDropDown)
            if ~strcmp(app.DataSummaryDropDown.Value,'--')
                app.output_fig_name = fullfile(summaryDir, ...
                    [app.input_fbase '_summary_figure_' app.channel app.DataSummaryDropDown.Value]);
            end

            % Save figure if missing or overwrite requested
            if app.OverwriteExistingFilesCheckBox.Value || ~isfile(app.output_fig_name)
                app.anything_run = 1;
                app.TextArea.addnl('   Generating summary figure...');
                fh = app.displaySummaryPlot;
                app.TextArea.addnl('   Saving summary figure...');
                exportgraphics(fh, app.output_fig_name, 'Resolution', 300);
                close all;
            end
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
            % TO-DO: Check if param basis already saved before re-fitting
            app.TextArea.addnl('   Running parametric basis...');
            app.TextArea.addnl('   Generating parametric basis figure...');
            app.fitParamBasis();
            fh = gcf;

            % Optionally save the parametric basis figure
            if app.SaveParamImagesCheckBox.Value
                app.anything_run = 1;
                app.output_param_name = fullfile(paramFigDir, ...
                    [app.input_fbase '_param_basis_figure_' app.channel app.ParametricFiguresDropDown.Value]);
                app.TextArea.addnl('   Saving parametric basis figure...');
                exportgraphics(fh, app.output_param_name, 'Resolution', 300);
            end
            close all;

            % Save parametric fit data according to chosen format. fitParamBasis
            % leaves *_paramfit empty when its sub-fit failed; skip those saves
            % so a failed phase fit doesn't prevent saving the (good) power fit.
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
            if ~strcmp(app.ParametricBasisDropDown.Value,'--')
                switch app.ParametricBasisDropDown.Value
                    case '.csv'
                        app.TextArea.addnl(   'Saving parametric basis as .csv...');
                        if pow_have
                            app.output_paramfit_power_name = [paramPowerBase '.csv'];
                            writetable(app.SOPHs.SOpower_paramfit.params, app.output_paramfit_power_name);
                        end
                        if phase_have
                            app.output_paramfit_phase_name = [paramPhaseBase '.csv'];
                            writetable(app.SOPHs.SOphase_paramfit.params, app.output_paramfit_phase_name);
                        end
                    case '.mat'
                        app.TextArea.addnl(   'Saving parametric basis as .mat...');
                        if pow_have
                            SOpower_paramfit = app.SOPHs.SOpower_paramfit; %#ok<NASGU>
                            app.output_paramfit_power_name = [paramPowerBase '.mat'];
                            save(app.output_paramfit_power_name,'SOpower_paramfit');
                        end
                        if phase_have
                            SOphase_paramfit = app.SOPHs.SOphase_paramfit; %#ok<NASGU>
                            app.output_paramfit_phase_name = [paramPhaseBase '.mat'];
                            save(app.output_paramfit_phase_name,'SOphase_paramfit');
                        end
                    case 'All'
                        app.TextArea.addnl(   'Saving parametric basis as .csv and .mat...');
                        if pow_have
                            app.output_paramfit_power_name = [paramPowerBase '.csv'];
                            writetable(app.SOPHs.SOpower_paramfit.params, app.output_paramfit_power_name);
                            SOpower_paramfit = app.SOPHs.SOpower_paramfit; %#ok<NASGU>
                            app.output_paramfit_power_name = [paramPowerBase '.mat'];
                            save(app.output_paramfit_power_name,'SOpower_paramfit');
                        end
                        if phase_have
                            app.output_paramfit_phase_name = [paramPhaseBase '.csv'];
                            writetable(app.SOPHs.SOphase_paramfit.params, app.output_paramfit_phase_name);
                            SOphase_paramfit = app.SOPHs.SOphase_paramfit; %#ok<NASGU>
                            app.output_paramfit_phase_name = [paramPhaseBase '.mat'];
                            save(app.output_paramfit_phase_name,'SOphase_paramfit');
                        end
                end
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
            % TO-DO: Check if spline already saved before re-fitting
            app.TextArea.addnl(   'Running spline basis...');
            app.TextArea.addnl('   Generating spline basis figure...');
            app.fitSplineBasis();
            fh = gcf;

            % Optionally save the spline basis figure
            if app.SaveSplineImagesCheckBox.Value
                app.anything_run = 1;
                app.TextArea.addnl('   Saving spline figure...');
                app.output_spline_name = fullfile(splineFigDir, ...
                    [app.input_fbase '_spline_basis_figure_' app.channel app.SplineFiguresDropDown.Value]);
                exportgraphics(fh, app.output_spline_name, 'Resolution', 300);
            end
            close all;

            % Save spline fit data according to chosen format. As in
            % runParamBasis, an empty *_splinefit means that sub-fit failed
            % and we skip its save without erroring the surviving one.
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
            if ~strcmp(app.SplineBasisDropDown.Value,'--')
                switch app.SplineBasisDropDown.Value
                    case '.tiff'
                        app.TextArea.addnl('   Saving spline basis is .tiff...');
                        if pow_have
                            app.output_splinefit_power_name = [splinePowerBase '.tiff'];
                            app.writeTiff(app.output_splinefit_power_name, app.SOPHs.SOpower_splinefit.splinefit);
                        end
                        if phase_have
                            app.output_splinefit_phase_name = [splinePhaseBase '.tiff'];
                            app.writeTiff(app.output_splinefit_phase_name, app.SOPHs.SOphase_splinefit.splinefit);
                        end
                    case '.mat'
                        app.TextArea.addnl('   Saving spline basis is .mat...');
                        if pow_have
                            SOpower_splinefit = app.SOPHs.SOpower_splinefit; %#ok<NASGU>
                            app.output_splinefit_power_name = [splinePowerBase '.mat'];
                            save(app.output_splinefit_power_name,'SOpower_splinefit');
                        end
                        if phase_have
                            SOphase_splinefit = app.SOPHs.SOphase_splinefit; %#ok<NASGU>
                            app.output_splinefit_phase_name = [splinePhaseBase '.mat'];
                            save(app.output_splinefit_phase_name,'SOphase_splinefit');
                        end
                    case 'All'
                        app.TextArea.addnl('   Saving spline basis is .tiff and .mat...');
                        if pow_have
                            app.output_splinefit_power_name = [splinePowerBase '.tiff'];
                            app.writeTiff(app.output_splinefit_power_name, app.SOPHs.SOpower_splinefit.splinefit);
                            SOpower_splinefit = app.SOPHs.SOpower_splinefit; %#ok<NASGU>
                            app.output_splinefit_power_name = [splinePowerBase '.mat'];
                            save(app.output_splinefit_power_name,'SOpower_splinefit');
                        end
                        if phase_have
                            app.output_splinefit_phase_name = [splinePhaseBase '.tiff'];
                            app.writeTiff(app.output_splinefit_phase_name, app.SOPHs.SOphase_splinefit.splinefit);
                            SOphase_splinefit = app.SOPHs.SOphase_splinefit; %#ok<NASGU>
                            app.output_splinefit_phase_name = [splinePhaseBase '.mat'];
                            save(app.output_splinefit_phase_name,'SOphase_splinefit');
                        end
                end
            end

            if ~pow_have && ~phase_have
                error('DYNAMOFileManager:runSplineBasis:bothFitsFailed', ...
                    'Both spline power and phase fits failed.');
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

        function RunBatchButtonPushed(app, ~, ~)
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

                app.RunBatchButton.Enabled  = 'off';
                app.StopBatchButton.Enabled = 'on';
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

        % ------------------------------------------------------------------

        function StopBatchButtonPushed(app, ~, ~)
            % StopBatchButtonPushed  Request a graceful stop after the current subject finishes.
            %
            %   Sets the isStopBatchButtonPushed flag, which is checked at the top
            %   of each channel-subject iteration in runBatch.

            app.isStopBatchButtonPushed = true;
            uialert(app.UIFigure, ...
                'Stop button pushed. Completing current subject then stopping.', ...
                'Stopping', 'Icon', 'warning');
        end

        % ------------------------------------------------------------------

        function AboutMenuSelected(app, ~, ~)
            % AboutMenuSelected  Help menu → About handler. Opens a
            % modal-ish uifigure with the toolbox name, version, and
            % links to the lab + documentation.
            fig = uifigure('Name', 'About DYNAM-O', ...
                'Position', [0 0 600 600]);
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
            app.curr_iteration = 0;

            % Cache the channel list (raw names for load_data) and a parallel
            % list of filesystem-safe names (used by analysis runners for paths).
            % Sanitising once up front avoids O(N_channels x N_runners)
            % redundant fixFilename calls during the loop.
            channelList      = app.ChannelList;
            channelListSafe  = cell(size(channelList));
            for ii = 1:numel(channelList)
                channelListSafe{ii} = app.fixFilename(channelList{ii},'');
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

            for jj = 1:length(dataList)

                for ii = 1:length(channelList)
                    app.channel = channelList{ii};

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
                        warning(warnState);
                        set(0, 'DefaultFigureVisible', 'on');
                        app.stopLogConsoleTimer();
                        app.updateLogConsole();
                        if ~isempty(app.consolelog_fid) && app.consolelog_fid > 0, fclose(app.consolelog_fid); end
                        diary off;
                        if ~isempty(app.runlog_fid) && app.runlog_fid > 0, fclose(app.runlog_fid); end
                        if ~isempty(app.RunLogger_), app.RunLogger_.close(); app.RunLogger_ = []; end
                        app.RunBatchButton.Enabled  = 'on';
                        app.StopBatchButton.Enabled = 'off';
                        app.set_rundefault;       % revert icon + "RUNNING" text back to RUN
                        app.ProgressBar.reset();
                        app.ProgressBar.Enabled = false;
                        return
                    end

                    app.anything_run = 0;
                    app.partial_failures = {};
                    % Clear cached compute state from any prior (subject, channel)
                    % so runStatsTable / fallbacks don't reuse the wrong SOPHs.
                    app.SOPHs            = [];
                    app.stats_table      = [];
                    app.auxiliary_data   = [];
                    [~, app.input_fbase, ext] = fileparts(dataList{jj});
                    % For .edf.gz / .edf.zst inputs fileparts returns
                    % "<name>.edf" as the basename and ".gz" / ".zst" as
                    % the ext — strip the trailing ".edf" so output
                    % filenames don't carry it.
                    if (strcmpi(ext, '.gz') || strcmpi(ext, '.zst')) ...
                            && endsWith(app.input_fbase, '.edf', 'IgnoreCase', true)
                        app.input_fbase = app.input_fbase(1:end-4);
                    end

                    % Log per-iteration header so subject/channel is always visible
                    % (fprintf goes to MATLAB console → diary → consolelog file → LogConsoleTextArea)
                    fprintf('\n--- Subject: %s | Channel: %s ---\n', app.input_fbase, app.channel);
                    app.TextArea.addnl(sprintf('--- Subject: %s | Channel: %s ---', ...
                        app.input_fbase, app.channel));
                  

                    % Track per-stage failures so the subject's overall
                        % "run successfully" / "partially run" message reflects
                        % what actually happened. Each stage runs in its own
                        % try/catch — a failure in (e.g.) the SOPH phase fit
                        % no longer aborts spline / aux-data / future subjects.
                    stage_failures = {};
                    t_iter = tic;

                    try
                        % ---- Load EDF and staging data ----
                        app.TextArea.addnl('Loading staging and EDF data...');

                        [app.data, app.Fs, app.stage_times, app.stage_vals] = load_data( ...
                            dataList{jj}, ...
                            stagingList{jj}, ...
                            app.StagesColumnEditField.Value, ...
                            app.TimesColumnEditField.Value, ...
                            app.channel, ...
                            'header_lines', app.HeaderRowsEditField.Value, ...
                            'delimiter',    app.delimeter, ...
                            'stage_vals_in', { app.ArtifactUserInput, app.WakeUserInput, ...
                            app.REMUserInput,      app.N1UserInput, ...
                            app.N2UserInput,       app.N3UserInput, ...
                            app.UnknownUserInput });

                        % Switch to filesystem-safe channel name now that
                        % load_data has consumed the raw EDF label. Analysis
                        % runners use app.channel strictly for output paths.
                        app.channel = channelListSafe{ii};

                        % ---- Resample if requested and Fs differs ----
                        if app.ResampleSwitch.Value
                            target_fs = app.ResampleFsEditField.Value;
                            if app.Fs ~= target_fs
                                msg = sprintf('Resampling from %g Hz to %g Hz...', app.Fs, target_fs);
                                fprintf('%s\n', msg);
                                app.TextArea.addnl(['   ' msg]);
                                drawnow;
                                [p, q]   = rat(target_fs / app.Fs);
                                app.data = resample(app.data, p, q);
                                app.Fs   = target_fs;
                            end
                        end

                        % When running with no stages, treat entire recording as N2
                        % (must be after resampling so data length reflects final Fs)
                        % Use length() rather than size(...,1) so row and column vectors both work
                        if app.use_no_stages
                            app.stage_times = [0, length(app.data) / app.Fs(1)];
                            app.stage_vals  = [2, 2];
                        end

                    catch e_load
                        % Failure in load/resample is fatal for the subject —
                        % no point trying any analysis stages without data.
                        % Tick the bar before continuing so the (file,channel)
                        % work unit is still accounted for in the total.
                        app.TextArea.addnl(['Error loading subject ',app.input_fbase, ...
                            ', channel ',app.channel,'. Check log for details.']);
                        fprintf('\nERROR — Subject %s, channel %s: load failed.\n%s\n', ...
                            app.input_fbase, app.channel, getReport(e_load, 'basic'));
                        app.writeLog(sprintf( ...
                            'Subject %s, channel %s: load failed.\n%s\n', ...
                            app.input_fbase, app.channel, e_load.message));
                        drawnow;
                        if ~isempty(app.RunLogger_)
                            try
                                app.RunLogger_.recordSubject( ...
                                    app.input_fbase, app.channel, ...
                                    'InputFile',  dataList{jj}, ...
                                    'Components', {}, ...
                                    'Failures',   {'load'}, ...
                                    'Status',     'load_failed', ...
                                    'DurationSec', toc(t_iter));
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
                        if ~isempty(app.consolelog_fid) && app.consolelog_fid > 0, fclose(app.consolelog_fid); end
                        diary off;
                        if ~isempty(app.runlog_fid) && app.runlog_fid > 0, fclose(app.runlog_fid); end
                        if ~isempty(app.RunLogger_), app.RunLogger_.close(); app.RunLogger_ = []; end
                        app.set_rundefault;
                        app.ProgressBar.reset();
                        app.ProgressBar.Enabled = false;
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
            app.TextArea.addnl('Batch run complete.');
            drawnow;
            app.stopLogConsoleTimer();
            app.updateLogConsole();  % final capture of any remaining diary output
            if ~isempty(app.consolelog_fid) && app.consolelog_fid > 0, fclose(app.consolelog_fid); end
            diary off;
            if ~isempty(app.runlog_fid) && app.runlog_fid > 0, fclose(app.runlog_fid); end
            if ~isempty(app.RunLogger_), app.RunLogger_.close(); app.RunLogger_ = []; end
            app.RunBatchButton.Enabled  = 'on';
            app.StopBatchButton.Enabled = 'off';
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

        function set_running(app)
            % set_running  Swap the RUN button into its "running" state:
            % an animated SVG bar-graph icon and the label "RUNNING".
            % Called at the start of every batch.
            app.RunBatchButton.Icon = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 135 140" fill="currentColor"><rect y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.5s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.5s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="30" y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.25s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.25s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="60" width="15" height="140" rx="6"><animate attributeName="height" begin="0s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="90" y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.25s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.25s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="120" y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.5s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.5s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect></svg>';
            app.RunBatchButton.Text = 'RUNNING';
            drawnow;
        end

        function set_rundefault(app)
            % set_rundefault  Restore the RUN button to its idle state
            % (play-triangle icon, label "RUN"). Called on completion,
            % stop, or error of a batch.
            app.RunBatchButton.Icon = '<path d="M8 5v14l11-7z"/>';
            app.RunBatchButton.Text = 'RUN';
            drawnow;
        end

    end% private methods

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
