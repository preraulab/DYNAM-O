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
    %   See also: DYNAMO, matlab.apps.AppBase

    % ======================================================================
    %   PROPERTIES
    % ======================================================================

    properties (Access = private)

        % --- UI Figure & Menus ---
        UIFigure                        matlab.ui.Figure                % Main application window
        FileMenu                        matlab.ui.container.Menu        % Top-level 'File' menu
        LoadEDFFileListMenu             matlab.ui.container.Menu        % Menu item: load EDF path list
        LoadStagingFileListMenu         matlab.ui.container.Menu        % Menu item: load staging path list

        % --- Top-Level Tab Group ---
        ProjectTabGroup                 matlab.ui.container.TabGroup    % Outer tab group (Setup / Analysis)
        DYNAMOSetupTab                  matlab.ui.container.Tab         % Main setup tab

        % --- Top-Level Layout Grids ---
        FullDYNAMOSetupGrid             matlab.ui.container.GridLayout  % Root grid inside DYNAMOSetupTab
        TopTextGrid                     matlab.ui.container.GridLayout  % Grid for instruction label + help button
        HelpButton                      % CSSuiButton                   % Opens help dialog
        InstructionText                 % CSSuiLabel                    % Top instruction label
        BottomGrid                      matlab.ui.container.GridLayout  % Grid containing status, run buttons, time estimate

        % --- Time Estimate & Run Controls ---
        TimeEstimateGrid                matlab.ui.container.GridLayout  % Holds progress bar widget
        RunBatchGrid                    matlab.ui.container.GridLayout  % Grid for run/stop buttons and options
        RunBatchOptionsGrid             matlab.ui.container.GridLayout  % Sub-grid for run checkbox options
        OverwriteExistingFilesCheckBox  % CSSuiSwitch                   % If checked, overwrite existing output files
        RunInReverse                    % CSSuiSwitch                   % If checked, process files in reverse order
        RunBatchButton                  % CSSuiButton                   % Initiates batch processing
        StopBatchButton                 % CSSuiButton                   % Requests graceful stop after current subject
        RightColumnGrid                 matlab.ui.container.GridLayout

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
        SaveSplineBasisCheckBox         % CSSuiSwitch                   % Save spline basis data
        SaveParamBasisCheckBox          % CSSuiSwitch                   % Save parametric basis data
        SaveSOPHsCheckBox               % CSSuiSwitch                   % Save SO-Power Histograms
        SavePeakStatsCheckBox           % CSSuiSwitch                   % Save TF-peak stats table
        FigurestoSaveLabel              % CSSuiLabel                    % Column header: 'Figures to Save'
        DatatoSaveLabel                 % CSSuiLabel                    % Column header: 'Data to Save'

        % --- FileFormat Saving Tab ---
        FileFormatTab                   matlab.ui.container.Tab         % FileFormat file format options tab
        FileFormatTabGrid               matlab.ui.container.GridLayout  % Grid inside FileFormat tab
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
        StagingOptionsGrid              matlab.ui.container.GridLayout  % Grid for staging options section
        StagingOptionsLabel             % CSSuiLabel                    % Section label: 'Staging Options'
        StagingOptionsPanelGrid         matlab.ui.container.GridLayout  % Two-column panel grid
        StagingOptionsPanelGridRight    matlab.ui.container.GridLayout  % Right column: file format inputs
        StagingOptionsInstructions      % CSSuiLabel                    % Instruction text for stage identifiers
        StagingOptionsGridRightTop      matlab.ui.container.GridLayout  % Grid for delimiter/column/header fields
        DelimeterOptionField            % CSSuiDropdown                 % Delimiter used in staging file
        FileDelimiterDropDownLabel                                      % (unused label placeholder)
        HeaderRowsEditField             % CSSuiNumericField             % Number of header rows to skip
        HeaderRowsEditFieldLabel        % CSSuiLabel
        TimesColumnEditField            % CSSuiNumericField             % Column index for epoch times
        TimesColumnEditFieldLabel       % CSSuiLabel
        StagesColumnEditField           % CSSuiNumericField             % Column index for stage labels
        StagesColumnEditFieldLabel      % CSSuiLabel

        % --- Stage Label Inputs (Left Panel) ---
        StagingOptionsPanelGridLeft     matlab.ui.container.GridLayout  % Grid for stage label text fields
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
        RuntimeOptionsTopGrid           matlab.ui.container.GridLayout  % Grid for channel section
        ChannelOptionsGrid              matlab.ui.container.GridLayout  % Grid for channel instruction text
        ChannelOptionsInstructionsLabel % CSSuiLabel                    % Channel input instruction
        RuntimeOptionsLabel             % CSSuiLabel                    % Section label: 'Runtime Options'
        ChannelInputGrid                matlab.ui.container.GridLayout  % Grid for channel label + field + info button
        ChannelEditField                % CSSuiEditField                % Comma-separated channel names to process
        ChannelEditFieldLabel           % CSSuiLabel
        ViewChannelsButton              % CSSuiButton                   % Opens dialog listing all EDF channels

        % --- File List Panels ---
        FileInputGrid                   matlab.ui.container.GridLayout  % Grid for both file list columns
        StagingFileTopGrid              matlab.ui.container.GridLayout  % Grid for staging list title row
        StagingFileTitleGrid            matlab.ui.container.GridLayout  % Grid centering the staging count label
        StagingLabel                    % CSSuiLabel                    % Displays 'Staging (N Files)'
        StagingFileInstructionText      % CSSuiLabel                    % Instruction text for staging files
        DataFileTopGrid                 matlab.ui.container.GridLayout  % Grid for data list title row
        DataFileTitleGrid               matlab.ui.container.GridLayout  % Grid centering the data count label
        DataLabel                       % CSSuiLabel                    % Displays 'Data (N Files)'
        DataFileInstructionText         % CSSuiLabel                    % Instruction text for data files
        StagingListBox                  matlab.ui.control.ListBox       % Scrollable list of staging file paths
        DataListBox                     matlab.ui.control.ListBox       % Scrollable list of EDF file paths

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
        date_time_save          = ''   % Timestamp string appended to log/settings filenames

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

        % Sleep stage identifier lists (cell arrays of strings from edit fields)
        ArtifactUserInput
        N1UserInput
        N2UserInput
        N3UserInput
        REMUserInput
        WakeUserInput
        UnknownUserInput

        delimeter   % Delimiter character used when reading staging files (e.g. ',' '\t')

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
        anything_run                    % Flag indicating at least one analysis was executed this iteration
        ypos                            % Vertical position tracker (legacy/internal)
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
        %   Miscellaneous UI
        % -------------------------
        progress_bar   % SmoothProgressBar handle displayed in TimeEstimateGrid

        % -------------------------
        %   UI Dimension Constants
        % -------------------------
        WindowWidth             = 1600   % Default figure width in pixels
        WindowHeight            = 1000   % Default figure height in pixels
        ButtonHeight            = 25     % Standard button height in pixels
        ButtonWidth             = 120    % Button width in pixels (used for fixed-width controls)

        % -------------------------
        %   Global Typography
        % -------------------------
        FontName       = 'Helvetica Nue'  % Font applied to every labelled UI control.
        FontSizeBase   = 13   % Body / instruction text font size (px)
        FontSizeTitle  = 15   % Section-header and list-title font size (px)
        FontSizeSmall  = 11   % Supplementary / caption font size (px)
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

            p = inputParser;
            addParameter(p,'BatchCallback',[],@(x) isempty(x)||isa(x,'function_handle'));
            addParameter(p,'ValidationCallback',[],@(x) isempty(x)||isa(x,'function_handle'));
            addParameter(p,'Title','DYNAM-O Toolbox',@ischar);
            addParameter(p,'Position',[],@isnumeric);
            parse(p,varargin{:});

            % Store optional callbacks if provided
            if ~isempty(p.Results.BatchCallback)
                app.BatchProcessCallback = p.Results.BatchCallback;
            end
            if ~isempty(p.Results.ValidationCallback)
                app.FileValidationCallback = p.Results.ValidationCallback;
            end

            % Build all UI components
            createComponents(app, p.Results.Title, p.Results.Position);
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
            %   This function is called once from the constructor. It creates
            %   every UI element (figure, menus, grids, controls) and configures
            %   their properties and callback functions.
            %
            %   NOTE: Components are organised top-down following the visual
            %   hierarchy: figure → menus → outer tabs → inner tabs → controls.

            % ---- Figure ----
            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [260, 115, app.WindowWidth, app.WindowHeight];
            app.UIFigure.Name = 'DYNAM-O File Manager';

            % ---- File Menu ----
            app.FileMenu      = uimenu(app.UIFigure);
            app.FileMenu.Text = 'File';

            % Menu item: load a text file containing EDF paths (one per line)
            app.LoadEDFFileListMenu = uimenu(app.FileMenu);
            app.LoadEDFFileListMenu.MenuSelectedFcn = createCallbackFcn(app, @loadDataFileListCallback, true);
            app.LoadEDFFileListMenu.Text = 'Load EDF File List...';

            % Menu item: load a text file containing staging file paths (one per line)
            app.LoadStagingFileListMenu = uimenu(app.FileMenu);
            app.LoadStagingFileListMenu.MenuSelectedFcn = createCallbackFcn(app, @loadStagingListCallback, true);
            app.LoadStagingFileListMenu.Text = 'Load Staging File List...';

            % ---- Outer Tab Group ----
            app.ProjectTabGroup          = uitabgroup(app.UIFigure);
            app.ProjectTabGroup.Position = [1, 1, app.WindowWidth, app.WindowHeight];

            % ---- DYNAM-O Setup Tab ----
            app.DYNAMOSetupTab       = uitab(app.ProjectTabGroup);
            app.DYNAMOSetupTab.Title = 'DYNAM-O Batch Setup';

            % Root grid: 1 column × 3 rows (instructions | main content | bottom bar)
            app.FullDYNAMOSetupGrid             = uigridlayout(app.DYNAMOSetupTab);
            app.FullDYNAMOSetupGrid.ColumnWidth = {'2.97x'};
            app.FullDYNAMOSetupGrid.RowHeight   = {'1x', '20x', '3x'};
            app.FullDYNAMOSetupGrid.RowSpacing  = 0;

            % ---- Inner Tab Group (File Selection | DYNAM-O Settings) ----
            app.BatchRunTabGroup              = uitabgroup(app.FullDYNAMOSetupGrid);
            app.BatchRunTabGroup.Layout.Row   = 2;
            app.BatchRunTabGroup.Layout.Column = 1;

            % ============================================================
            %   FILE SELECTION TAB
            % ============================================================

            app.FileSelectionTab       = uitab(app.BatchRunTabGroup);
            app.FileSelectionTab.Title = 'File Selection';

            % Two-column grid: left = file lists, right = runtime options
            app.FileSelectionGrid             = uigridlayout(app.FileSelectionTab);
            app.FileSelectionGrid.ColumnWidth = {'2x', '1x'};
            app.FileSelectionGrid.RowHeight   = {'1x'};

            % ---- File Input Grid (left column) ----
            % 3-row grid: title + instruction | list boxes | action buttons
            app.FileInputGrid             = uigridlayout(app.FileSelectionGrid);
            app.FileInputGrid.RowHeight   = {'3x', '20x', '2.3x'};
            app.FileInputGrid.RowSpacing  = 0;
            app.FileInputGrid.Padding     = [0 0 0 0];
            app.FileInputGrid.Layout.Row  = 1;
            app.FileInputGrid.Layout.Column = 1;

            % ---- Data File Action Buttons ----
            app.DataFileButtonGrid             = uigridlayout(app.FileInputGrid);
            app.DataFileButtonGrid.ColumnWidth = {'1x','1x','1x','1x','1x'};
            app.DataFileButtonGrid.RowHeight   = {'1x'};
            app.DataFileButtonGrid.ColumnSpacing = 10;
            app.DataFileButtonGrid.Padding     = [0 0 10 0];
            app.DataFileButtonGrid.Layout.Row  = 3;
            app.DataFileButtonGrid.Layout.Column = 1;

            % -- Add single EDF file --
            app.DataAddFileButton =  CSSuiButton(app.DataFileButtonGrid, ...
                'Text', 'Add File', ...
                'Style','shadow',...
                'ButtonPushedFcn', createCallbackFcn(app, @DataAddFileButtonPushed, true), ...
                'IconPosition', 'left',...
                'Icon',     '<path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8l-6-6zm-1 7V3.5L18.5 9H13z M11 13h2v-2h2v2h2v2h-2v2h-2v-2h-2z"/>' ...
                );
            app.DataAddFileButton.Row    = 1;
            app.DataAddFileButton.Column = 1;
            app.DataAddFileButton.HTMLComponent.Tooltip       = 'Add single EDF file';

            % -- Add EDF folder --
            app.DataAddFolderButton =  CSSuiButton(app.DataFileButtonGrid, ...
                'Text', 'Add Folder', ...
                'Style','shadow',...
                'ButtonPushedFcn',  createCallbackFcn(app, @DataAddFolderButtonPushed, true), ...
                'IconPosition', 'left',...
                'Icon', '<path d="M10 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"/><path d="M13 14h-2v-2h-2v2H7v2h2v2h2v-2h2v-2z" fill="white" opacity="0.9"/>' ...
                );
            app.DataAddFolderButton.Row    = 1;
            app.DataAddFolderButton.Column = 2;
            app.DataAddFolderButton.HTMLComponent.Tooltip       = 'Add all EDF files in folder';

            % -- Remove selected EDF file --
            app.DataRemoveButton =  CSSuiButton(app.DataFileButtonGrid, ...
                'Text', 'Delete File', ...
                'Style','shadow',...
                'ButtonPushedFcn',  createCallbackFcn(app, @DataAddFolderButtonPushed, true), ...
                'IconPosition', 'left',...
                'Icon', '<path d="M3 6h18v2H3V6zm2 2h14l-1.5 14h-11L5 8zm5 2v8h2v-8h-2zm4 0v8h2v-8h-2zM8 4h8v2H8V4z"/>' ...
                );

            app.DataRemoveButton.Row    = 1;
            app.DataRemoveButton.Column = 3;
            app.DataRemoveButton.HTMLComponent.Tooltip       = 'Remove selected EDF file';

            % -- Move EDF file up --
            app.DataMoveUpButton = CSSuiButton(app.DataFileButtonGrid, ...
                'Text', 'Move Up', 'Style', 'shadow', 'Padding', '15px', ...
                'IconPosition', 'left', 'Icon', '<path d="M12 5l-7 9h5v8h4v-8h5z"/>', ...
                'ButtonPushedFcn', createCallbackFcn(app, @DataMoveUpButtonPushed, true));
            app.DataMoveUpButton.Row    = 1;
            app.DataMoveUpButton.Column = 4;
            app.DataMoveUpButton.HTMLComponent.Tooltip = 'Move current EDF file up';

            % -- Move EDF file down --
            app.DataMoveDownButton = CSSuiButton(app.DataFileButtonGrid, ...
                'Text', 'Move Down', 'Style', 'shadow', 'Padding', '15px', ...
                'IconPosition', 'left', 'Icon', '<path d="M12 19l-7-9h5v-8h4v8h5z"/>', ...
                'ButtonPushedFcn', createCallbackFcn(app, @DataMoveDownButtonPushed, true));
            app.DataMoveDownButton.Row    = 1;
            app.DataMoveDownButton.Column = 5;
            app.DataMoveDownButton.HTMLComponent.Tooltip = 'Move current EDF file down';


            % =========================================================================
            %  BLOCK 2 — STAGING FILE ACTION BUTTONS
            % =========================================================================

            % ---- Staging File Action Buttons ----
            app.StagingFileButtonGrid             = uigridlayout(app.FileInputGrid);
            app.StagingFileButtonGrid.ColumnWidth = {'1x','1x','1x','1x','1x'};
            app.StagingFileButtonGrid.RowHeight   = {'1x'};
            app.StagingFileButtonGrid.ColumnSpacing = 3;
            app.StagingFileButtonGrid.Padding     = [10 0 10 0];
            app.StagingFileButtonGrid.Layout.Row  = 3;
            app.StagingFileButtonGrid.Layout.Column = 2;


            % -- Add single staging file --
            app.StagingAddFileButton = CSSuiButton(app.StagingFileButtonGrid, ...
                'Text', 'Add File', ...
                'Style','shadow',...
                'ButtonPushedFcn', createCallbackFcn(app, @StagingAddFileButtonPushed, true), ...
                'IconPosition', 'left',...
                'Icon',     '<path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8l-6-6zm-1 7V3.5L18.5 9H13z M11 13h2v-2h2v2h2v2h-2v2h-2v-2h-2z"/>' ...
                );

            app.StagingAddFileButton.Row    = 1;
            app.StagingAddFileButton.Column = 1;
            app.StagingAddFileButton.HTMLComponent.Tooltip       = 'Add single EDF file';

            app.StagingAddFolderButton = CSSuiButton(app.StagingFileButtonGrid, ...
                'Text', 'Add Folder', ...
                'Style','shadow',...
                'ButtonPushedFcn',  createCallbackFcn(app, @StagingAddFolderButtonPushed, true), ...
                'IconPosition', 'left',...
                'Icon', '<path d="M10 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"/><path d="M13 14h-2v-2h-2v2H7v2h2v2h2v-2h2v-2z" fill="white" opacity="0.9"/>' ...
                );
            app.StagingAddFolderButton.Row    = 1;
            app.StagingAddFolderButton.Column = 2;
            app.StagingAddFolderButton.HTMLComponent.Tooltip       = 'Add all staging files in folder';

            % -- Remove selected staging file --
            app.StagingRemoveButton = CSSuiButton(app.StagingFileButtonGrid, ...
                'Text', 'Delete File', ...
                'Style','shadow',...
                'ButtonPushedFcn',  createCallbackFcn(app, @StagingAddFolderButtonPushed, true), ...
                'IconPosition', 'left',...
                'Icon', '<path d="M3 6h18v2H3V6zm2 2h14l-1.5 14h-11L5 8zm5 2v8h2v-8h-2zm4 0v8h2v-8h-2zM8 4h8v2H8V4z"/>' ...
                );

            app.StagingRemoveButton.Row    = 1;
            app.StagingRemoveButton.Column = 3;
            app.StagingRemoveButton.HTMLComponent.Tooltip       = 'Remove selected staging file';

            % -- Move staging file up --
            app.StagingMoveUpButton = CSSuiButton(app.StagingFileButtonGrid, ...
                'Text', 'Move Up', ...
                'Style','shadow',...
                'ButtonPushedFcn',  createCallbackFcn(app, @StagingMoveUpButtonPushed, true), ...
                'IconPosition', 'left',...
                'Icon', '<path d="M12 5l-7 9h5v8h4v-8h5z"/>' ...
                );

            app.StagingMoveUpButton.Row    = 1;
            app.StagingMoveUpButton.Column = 4;
            app.StagingMoveUpButton.HTMLComponent.Tooltip       = 'Move current staging file up';

            % -- Move staging file down --
            app.StagingMoveDownButton = CSSuiButton(app.StagingFileButtonGrid, ...
                'Text', 'Move Down', ...
                'Style','shadow',...
                'ButtonPushedFcn',  createCallbackFcn(app, @StagingMoveDownButtonPushed, true), ...
                'IconPosition', 'left',...
                'Icon', '<path d="M12 19l-7-9h5v-8h4v8h5z"/>' ...
                );
            app.StagingMoveDownButton.Row    = 1;
            app.StagingMoveDownButton.Column = 5;
            app.StagingMoveDownButton.HTMLComponent.Tooltip       = 'Move current staging file down';


            % ---- Data List Box ----
            % Double-click opens the EDF header viewer
            app.DataListBox = uilistbox(app.FileInputGrid);
            app.DataListBox.Items            = {};
            app.DataListBox.Multiselect      = 'on';
            app.DataListBox.Layout.Row       = 2;
            app.DataListBox.Layout.Column    = 1;
            app.DataListBox.DoubleClickedFcn = createCallbackFcn(app, @ShowHeader, true);
            app.DataListBox.Value            = {};
            app.DataListBox.Tooltip          = 'Double-click a file to view the header';

            % ---- Staging List Box ----
            app.StagingListBox = uilistbox(app.FileInputGrid);
            app.StagingListBox.Items         = {};
            app.StagingListBox.Multiselect   = 'on';
            app.StagingListBox.Layout.Row    = 2;
            app.StagingListBox.Layout.Column = 2;
            app.StagingListBox.Value         = {};

            % ---- Data File Title + Instruction ----
            app.DataFileTopGrid             = uigridlayout(app.FileInputGrid);
            app.DataFileTopGrid.ColumnWidth = {'1x'};
            app.DataFileTopGrid.RowHeight   = {'2x', '1x'};
            app.DataFileTopGrid.ColumnSpacing = 0;
            app.DataFileTopGrid.RowSpacing  = 0;
            app.DataFileTopGrid.Padding     = [0 0 0 0];
            app.DataFileTopGrid.Layout.Row  = 1;
            app.DataFileTopGrid.Layout.Column = 1;

            app.DataFileInstructionText = CSSuiLabel(app.DataFileTopGrid, ...
                'Style', 'shadow', 'FontSize', '13px', 'FontWeight', '700', ...
                'Text', upper('Add PSG files (EDF). Double-click file for header info.'));
            app.DataFileInstructionText.Row    = 2;
            app.DataFileInstructionText.Column = 1;

            % Centred title grid with file count label
            app.DataFileTitleGrid             = uigridlayout(app.DataFileTopGrid);
            app.DataFileTitleGrid.ColumnWidth = {'2x', '5x', '2x'};
            app.DataFileTitleGrid.RowHeight   = {'1x'};
            app.DataFileTitleGrid.Padding     = [0 12 0 12];
            app.DataFileTitleGrid.Layout.Row  = 1;
            app.DataFileTitleGrid.Layout.Column = 1;

            app.DataLabel = CSSuiLabel(app.DataFileTitleGrid, ...
                'Style', 'shadow', 'FontWeight', '700', 'FontSize', app.FontSizeTitle, ...
                'Text', 'DATA (0 Files)');
            app.DataLabel.Layout.Row    = 1;
            app.DataLabel.Layout.Column = 2;

            % ---- Staging File Title + Instruction ----
            app.StagingFileTopGrid             = uigridlayout(app.FileInputGrid);
            app.StagingFileTopGrid.ColumnWidth = {'1x'};
            app.StagingFileTopGrid.RowHeight   = {'2x', '1x'};
            app.StagingFileTopGrid.ColumnSpacing = 0;
            app.StagingFileTopGrid.RowSpacing  = 0;
            app.StagingFileTopGrid.Padding     = [0 0 0 0];
            app.StagingFileTopGrid.Layout.Row  = 1;
            app.StagingFileTopGrid.Layout.Column = 2;

            app.StagingFileInstructionText = CSSuiLabel(app.StagingFileTopGrid, ...
                'Style', 'shadow', 'FontSize', '12px', 'FontWeight', '700', ...
                'Text', upper('Add staging files (CSV/TXT). Ensure order matches data files.'));
            app.StagingFileInstructionText.Layout.Row    = 2;
            app.StagingFileInstructionText.Layout.Column = 1;

            app.StagingFileTitleGrid             = uigridlayout(app.StagingFileTopGrid);
            app.StagingFileTitleGrid.ColumnWidth = {'2x', '5x', '2x'};
            app.StagingFileTitleGrid.RowHeight   = {'1x'};
            app.StagingFileTitleGrid.Padding     = [0 12 0 12];
            app.StagingFileTitleGrid.Layout.Row  = 1;
            app.StagingFileTitleGrid.Layout.Column = 1;

            app.StagingLabel = CSSuiLabel(app.StagingFileTitleGrid, ...
                'Style', 'shadow', 'FontWeight', '700', 'FontSize', app.FontSizeTitle, ...
                'HorizontalAlignment', 'center', 'Text', 'STAGING (0 Files)');
            app.StagingLabel.Layout.Row    = 1;
            app.StagingLabel.Layout.Column = 2;

            % ============================================================
            %   RUNTIME OPTIONS (right column)
            % ============================================================

            % Three-row right column: channel options | staging options | saving options
            app.RuntimeOptionsGrid             = uigridlayout(app.FileSelectionGrid);
            app.RuntimeOptionsGrid.ColumnWidth = {'1x'};
            app.RuntimeOptionsGrid.RowHeight   = {'1x', '2.2x', '2.2x'};
            app.RuntimeOptionsGrid.ColumnSpacing = 0;
            app.RuntimeOptionsGrid.RowSpacing  = 0;
            app.RuntimeOptionsGrid.Padding     = [0 0 0 0];
            app.RuntimeOptionsGrid.Layout.Row  = 1;
            app.RuntimeOptionsGrid.Layout.Column = 2;

            % ---- Channel / Runtime Options (Row 1) ----
            app.RuntimeOptionsTopGrid             = uigridlayout(app.RuntimeOptionsGrid);
            app.RuntimeOptionsTopGrid.ColumnWidth = {'1x'};
            app.RuntimeOptionsTopGrid.RowHeight   = {'4x', '2x', '2x', '1x'};
            app.RuntimeOptionsTopGrid.ColumnSpacing = 0;
            app.RuntimeOptionsTopGrid.RowSpacing  = 0;
            app.RuntimeOptionsTopGrid.Padding     = [0 0 0 0];
            app.RuntimeOptionsTopGrid.Layout.Row  = 1;
            app.RuntimeOptionsTopGrid.Layout.Column = 1;

            % Channel input: label | edit field | info button
            app.ChannelInputGrid             = uigridlayout(app.RuntimeOptionsTopGrid);
            app.ChannelInputGrid.ColumnWidth = {'3x', '10x', '4x'};
            app.ChannelInputGrid.RowHeight   = {'1x'};
            app.ChannelInputGrid.Padding     = [0 0 0 0];
            app.ChannelInputGrid.Layout.Row  = 3;
            app.ChannelInputGrid.Layout.Column = 1;

            app.ChannelEditFieldLabel = CSSuiLabel(app.ChannelInputGrid, ...
                'Style', 'shadow', 'Text', 'Channel(s):');
            app.ChannelEditFieldLabel.Layout.Row    = 1;
            app.ChannelEditFieldLabel.Layout.Column = 1;

            app.ChannelEditField               = CSSuiEditField(app.ChannelInputGrid, 'Style','shadow');
            app.ChannelEditField.Layout.Row    = 1;
            app.ChannelEditField.Layout.Column = 2;

            % Info button: opens dialog listing all channels present in loaded EDFs
            app.ViewChannelsButton = CSSuiButton(app.ChannelInputGrid, ...
                'Text',    'Select', 'Style', 'shadow');
            app.ViewChannelsButton.Row    = 1;
            app.ViewChannelsButton.Column = 3;
            app.ViewChannelsButton.ButtonPushedFcn = createCallbackFcn(app, @viewChannelsButtonPushed, true);

            % Section header
            app.RuntimeOptionsLabel = CSSuiLabel(app.RuntimeOptionsTopGrid, ...
                'Style', 'shadow', 'FontWeight', '700', 'FontSize', app.FontSizeTitle, ...
                'Text', 'RUNTIME OPTIONS');
            app.RuntimeOptionsLabel.Layout.Row    = 1;
            app.RuntimeOptionsLabel.Layout.Column = 1;

            % Instruction text for channel input
            app.ChannelOptionsGrid             = uigridlayout(app.RuntimeOptionsTopGrid);
            app.ChannelOptionsGrid.ColumnWidth = {'4x'};
            app.ChannelOptionsGrid.RowHeight   = {'1x'};
            app.ChannelOptionsGrid.Padding     = [0 0 0 0];
            app.ChannelOptionsGrid.Layout.Row  = 2;
            app.ChannelOptionsGrid.Layout.Column = 1;

            app.ChannelOptionsInstructionsLabel = CSSuiLabel(app.ChannelOptionsGrid, ...
                'Style', 'shadow', 'FontSize', '12px', ...
                'Text', 'Enter comma-separated list of channels or select from files.');
            app.ChannelOptionsInstructionsLabel.Layout.Row    = 1;
            app.ChannelOptionsInstructionsLabel.Layout.Column = 1;

            % ---- Staging Options (Row 2) ----
            % Two-sub-column panel: left = stage label identifiers, right = file format inputs
            app.StagingOptionsGrid             = uigridlayout(app.RuntimeOptionsGrid);
            app.StagingOptionsGrid.ColumnWidth = {'1x'};
            app.StagingOptionsGrid.RowHeight   = {'1x', '10x'};
            app.StagingOptionsGrid.ColumnSpacing = 0;
            app.StagingOptionsGrid.RowSpacing  = 0;
            app.StagingOptionsGrid.Padding     = [0 0 0 0];
            app.StagingOptionsGrid.Layout.Row  = 2;
            app.StagingOptionsGrid.Layout.Column = 1;

            app.StagingOptionsPanelGrid             = uigridlayout(app.RuntimeOptionsGrid);
            app.StagingOptionsPanelGrid.ColumnWidth   = {'2x', '5x', '3x', '2x'} ;
            app.StagingOptionsGrid.RowHeight = {'1x','1x','1x','1x','1x','1x','1x'};
            app.StagingOptionsPanelGrid.ColumnSpacing = 20;
            app.StagingOptionsPanelGrid.RowSpacing  = 0;
            app.StagingOptionsPanelGrid.Padding     = [20 20 0 0];
            app.StagingOptionsPanelGrid.Layout.Row  = 2;
            app.StagingOptionsPanelGrid.Layout.Column = 1;

            % Artifact stage identifiers
            app.ArtifactEditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Text', 'Artifact');
            app.ArtifactEditFieldLabel.Layout.Row    = 1;
            app.ArtifactEditFieldLabel.Layout.Column = 1;

            app.ArtifactEditField = CSSuiEditField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Value', 'art, artifact, A, 6');
            app.ArtifactEditField.Layout.Row    = 1;
            app.ArtifactEditField.Layout.Column = 2;

            % Wake stage identifiers
            app.WakeEditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Text', 'Wake');
            app.WakeEditFieldLabel.Layout.Row    = 2;
            app.WakeEditFieldLabel.Layout.Column = 1;

            app.WakeEditField = CSSuiEditField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Value', 'wake, W, 5');
            app.WakeEditField.Layout.Row    = 2;
            app.WakeEditField.Layout.Column = 2;

            % REM stage identifiers
            app.REMEditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Text', 'REM');
            app.REMEditFieldLabel.Layout.Row    = 3;
            app.REMEditFieldLabel.Layout.Column = 1;

            app.REMEditField = CSSuiEditField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Value', 'REM, R, 4');
            app.REMEditField.Layout.Row    = 3;
            app.REMEditField.Layout.Column = 2;

            % N1 stage identifiers
            app.N1EditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Text', 'N1');
            app.N1EditFieldLabel.Layout.Row    = 4;
            app.N1EditFieldLabel.Layout.Column = 1;

            app.N1EditField = CSSuiEditField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Value', 'N1, Stage 1, 1');
            app.N1EditField.Layout.Row    = 4;
            app.N1EditField.Layout.Column = 2;

            % N2 stage identifiers
            app.N2EditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Text', 'N2');
            app.N2EditFieldLabel.Layout.Row    = 5;
            app.N2EditFieldLabel.Layout.Column = 1;

            app.N2EditField = CSSuiEditField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Value', 'N2, Stage 2, 2');
            app.N2EditField.Layout.Row    = 5;
            app.N2EditField.Layout.Column = 2;

            % N3 stage identifiers
            app.N3EditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Text', 'N3');
            app.N3EditFieldLabel.Layout.Row    = 6;
            app.N3EditFieldLabel.Layout.Column = 1;

            app.N3EditField = CSSuiEditField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Value', 'N3, Stage 3, 3');
            app.N3EditField.Layout.Row    = 6;
            app.N3EditField.Layout.Column = 2;

            % Unknown stage identifiers
            app.UnknownEditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Text', 'Unknown');
            app.UnknownEditFieldLabel.Layout.Row    = 7;
            app.UnknownEditFieldLabel.Layout.Column = 1;

            app.UnknownEditField = CSSuiEditField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Value', 'Unk, U, Unknown');
            app.UnknownEditField.Layout.Row    = 7;
            app.UnknownEditField.Layout.Column = 2;

            % Stages column index
            app.StagesColumnEditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Text', 'Stages Column');
            app.StagesColumnEditFieldLabel.Layout.Row    = 3;
            app.StagesColumnEditFieldLabel.Layout.Column = 3;

            app.StagesColumnEditField = CSSuiNumericField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Min', 0);
            app.StagesColumnEditField.Layout.Row    = 3;
            app.StagesColumnEditField.Layout.Column = 4;

            % Times column index
            app.TimesColumnEditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Text', 'Times Column');
            app.TimesColumnEditFieldLabel.Row    = 4;
            app.TimesColumnEditFieldLabel.Column = 3;

            app.TimesColumnEditField = CSSuiNumericField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Min', 0);
            app.TimesColumnEditField.Row    = 4;
            app.TimesColumnEditField.Column = 4;

            % Header rows count
            app.HeaderRowsEditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Text', 'Header Rows');
            app.HeaderRowsEditFieldLabel.Row    = 5;
            app.HeaderRowsEditFieldLabel.Column = 3;

            app.HeaderRowsEditField = CSSuiNumericField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Min', 0);
            app.HeaderRowsEditField.Row    = 5;
            app.HeaderRowsEditField.Column = 4;

            % File delimiter dropdown
            app.DelimeterOptionField = CSSuiDropdown(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', 'Label', 'File Delimiter', ...
                'Items', {'Comma', 'Tab', 'Space', 'Semicolon'}, 'Value', 'Comma', ...
                'FontWeight', 'normal');
            app.DelimeterOptionField.Row    = 1;
            app.DelimeterOptionField.Column = [3 4];

            % Section header for staging options
            app.StagingOptionsLabel = CSSuiLabel(app.StagingOptionsGrid, ...
                'Style', 'shadow', 'FontWeight', '700', 'Text', 'STAGING OPTIONS');
            app.StagingOptionsLabel.Layout.Row    = 1;
            app.StagingOptionsLabel.Layout.Column = 1;

            % ============================================================
            %   SAVING OPTIONS (Row 3 of RuntimeOptionsGrid)
            % ============================================================

            app.SavingOptionsTabGroup              = uitabgroup(app.RuntimeOptionsGrid);
            app.SavingOptionsTabGroup.Layout.Row   = 3;
            app.SavingOptionsTabGroup.Layout.Column = 1;


            % ---- Basic Saving Options Tab ----
            app.SavingOptionsTab       = uitab(app.SavingOptionsTabGroup);
            app.SavingOptionsTab.Title = 'Saving Options';
            app.SavingOptionsTabGroup.SelectedTab = app.SavingOptionsTab;

            app.SavingOptionsTabGrid             = uigridlayout(app.SavingOptionsTab);
            app.SavingOptionsTabGrid.ColumnWidth = {'1x'};
            app.SavingOptionsTabGrid.RowHeight   = {'3x', '1x'};
            app.SavingOptionsTabGrid.RowSpacing  = 0;
            app.SavingOptionsTabGrid.Padding     = [10 0 10 2];

            % Six-row, two-column grid of save checkboxes
            app.SavingOptionsCheckBoxGrid             = uigridlayout(app.SavingOptionsTabGrid);
            app.SavingOptionsCheckBoxGrid.RowHeight   = {'1x','1x','1x','1x','1x','1x'};
            app.SavingOptionsCheckBoxGrid.Padding     = [3 10 3 10];
            app.SavingOptionsCheckBoxGrid.Layout.Row  = 1;
            app.SavingOptionsCheckBoxGrid.Layout.Column = 1;

            % Column headers
            app.DatatoSaveLabel = CSSuiLabel(app.SavingOptionsCheckBoxGrid, ...
                'Style', 'shadow', 'FontWeight', '700', 'Text', 'DATA TO SAVE');
            app.DatatoSaveLabel.Layout.Row    = 1;
            app.DatatoSaveLabel.Layout.Column = 1;

            app.FigurestoSaveLabel = CSSuiLabel(app.SavingOptionsCheckBoxGrid, ...
                'Style', 'shadow', 'FontWeight', '700', 'Text', 'FIGURES TO SAVE');
            app.FigurestoSaveLabel.Layout.Row    = 1;
            app.FigurestoSaveLabel.Layout.Column = 2;


            % --- Data Tables (Left Column) ---
            app.SavePeakStatsCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, 'Text', 'Peak Stats Tables', 'value', 1,'Style','shadow');
            app.SavePeakStatsCheckBox.Row    = 2;
            app.SavePeakStatsCheckBox.Column = 1;
            app.SavePeakStatsCheckBox.HTMLComponent.Tooltip       = 'Save TFpeak stats tables, which store individual peak features for all detected TFpeaks';

            app.SaveSOPHsCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, 'Text', 'SO-Power Histogram', 'value', 1,'Style','shadow');
            app.SaveSOPHsCheckBox.Row    = 3;
            app.SaveSOPHsCheckBox.Column = 1;
            app.SaveSOPHsCheckBox.HTMLComponent.Tooltip       = 'Save SO-power and SO-phase histograms';

            app.SaveParamBasisCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, 'Text', 'Parametric Basis', 'value', 1,'Style','shadow');
            app.SaveParamBasisCheckBox.Row    = 4;
            app.SaveParamBasisCheckBox.Column = 1;
            app.SaveParamBasisCheckBox.HTMLComponent.Tooltip       = 'Save tables of estimated mode feature parameters for SO-power and SO-phase histograms';

            app.SaveSplineBasisCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, 'Text', 'Spline Basis', 'value', 1,'Style','shadow');
            app.SaveSplineBasisCheckBox.Row    = 5;
            app.SaveSplineBasisCheckBox.Column = 1;
            app.SaveSplineBasisCheckBox.HTMLComponent.Tooltip       = 'Save matrix of spline knot parameters';

            app.SaveAuxDataCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, 'Text', 'Auxiliary Data', 'value', 1,'Style','shadow');
            app.SaveAuxDataCheckBox.Row    = 6;
            app.SaveAuxDataCheckBox.Column = 1;
            app.SaveAuxDataCheckBox.HTMLComponent.Tooltip       = 'Save auxiliary data helpful for rapid recomputation and figure generation without accessing the raw data';

            % --- Figure Save Checkboxes (Right Column) ---
            app.SaveDataSummaryCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, 'Text', 'Data Summary', 'value', 1,'Style','shadow');
            app.SaveDataSummaryCheckBox.Row    = 2;
            app.SaveDataSummaryCheckBox.Column = 2;
            app.SaveDataSummaryCheckBox.HTMLComponent.Tooltip       = 'Save DYNAM-O summary figures, showing spectrogram, SO-power, detected peaks, and SO-power/phase histograms';

            app.SaveParamImagesCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, 'Text', 'Parametric Basis', 'value', 1,'Style','shadow');
            app.SaveParamImagesCheckBox.Row    = 3;
            app.SaveParamImagesCheckBox.Column = 2;
            app.SaveParamImagesCheckBox.HTMLComponent.Tooltip       = 'Save the output figures for parametric fits';

            app.SaveSplineImagesCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, 'Text', 'Spline Basis', 'value', 1,'Style','shadow');
            app.SaveSplineImagesCheckBox.Row    = 4;
            app.SaveSplineImagesCheckBox.Column = 2;
            app.SaveSplineImagesCheckBox.HTMLComponent.Tooltip       = 'Save the output figures for spline fits';

            % ---- Output Directory Row ----
            app.SavingDirectoryGrid             = uigridlayout(app.SavingOptionsTabGrid);
            app.SavingDirectoryGrid.ColumnWidth = {'5x', '1x'};
            app.SavingDirectoryGrid.RowHeight   = {'2x', '3x'};
            app.SavingDirectoryGrid.RowSpacing  = 0;
            app.SavingDirectoryGrid.Padding     = [5 5 10 1];
            app.SavingDirectoryGrid.Layout.Row  = 2;
            app.SavingDirectoryGrid.Layout.Column = 1;

            app.OutputDirLabel = CSSuiLabel(app.SavingDirectoryGrid, ...
                'Style', 'shadow', 'FontSize', '12px', 'Text', ' Select output directory:');
            app.OutputDirLabel.Layout.Row    = 1;
            app.OutputDirLabel.Layout.Column = 1;

            app.OutputDirButton = CSSuiButton(app.SavingDirectoryGrid, ...
                'Text', 'Browse', 'Style', 'shadow', ...
                'ButtonPushedFcn', @(src,event) browseOutputDir(app));
            app.OutputDirButton.Row    = 2;
            app.OutputDirButton.Column = 2;

            % Placeholder label under the edit field (edit field renders on top)
            app.EditFieldLabel = CSSuiLabel(app.SavingDirectoryGrid, 'Text', 'Edit Field');
            app.EditFieldLabel.Layout.Row    = 2;
            app.EditFieldLabel.Layout.Column = 1;

            app.OutputDirEditField = CSSuiEditField(app.SavingDirectoryGrid);
            app.OutputDirEditField.Layout.Row    = 2;
            app.OutputDirEditField.Layout.Column = 1;
            app.OutputDirEditField.HTMLComponent.Tooltip = 'Select the root directory from which to generate the output file structure';

            % ============================================================
            %   FILE FORMAT TAB
            % ============================================================
            pause(1);
            app.FileFormatTab       = uitab(app.SavingOptionsTabGroup);
            app.FileFormatTab.Title = 'File Formats';
            app.SavingOptionsTabGroup.SelectedTab = app.FileFormatTab;

            app.FileFormatCheckBoxGrid                = uigridlayout(app.FileFormatTab);
            app.FileFormatCheckBoxGrid.ColumnWidth    = {'1x', '1x', '1x', '1x'};
            app.FileFormatCheckBoxGrid.RowHeight      = {'1x', '1x','1x','1x','1x','1x','1x'};
            app.FileFormatCheckBoxGrid.ColumnSpacing      = 0;

            % ----- Column headers -----
            app.DataFileFormatLabel = CSSuiLabel(app.FileFormatCheckBoxGrid, ...
                'Style', 'shadow', 'FontWeight', '700', 'Text', 'DATA FILE FORMAT');
            app.DataFileFormatLabel.Layout.Row    = 1;
            app.DataFileFormatLabel.Layout.Column = [1 2];

            app.FigureFileFormatLabel = CSSuiLabel(app.FileFormatCheckBoxGrid, ...
                'Style', 'shadow', 'FontWeight', '700', 'Text', 'FIGURE FILE FORMAT');
            app.FigureFileFormatLabel.Layout.Row    = 1;
            app.FigureFileFormatLabel.Layout.Column = [3 4];

            % ----- Data column dropdowns (col 1) -----
            lab = CSSuiLabel(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'Text' , 'Peak Stats Table');
            lab.Row    = 2;
            lab.Column = 1;

            app.PeakStatsTableDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'DropdownWidth', '4.25em',...
                'Items',         {'--', '.csv', '.mat', 'All'}, ...
                'Value',         '.csv');
            app.PeakStatsTableDropDown.Row    = 2;
            app.PeakStatsTableDropDown.Column = 2;

            lab = CSSuiLabel(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'Text' , 'SO Histograms');
            lab.Row    = 3;
            lab.Column = 1;

            app.SOPowerHistogramsDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'DropdownWidth', '4.25em',...
                'Items',         {'--', '.tiff', '.mat', 'All'}, ...
                'Value',         '.tiff');
            app.SOPowerHistogramsDropDown.Row    = 3;
            app.SOPowerHistogramsDropDown.Column = 2;

            lab = CSSuiLabel(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'Text' , 'Parametric Basis');
            lab.Row    = 4;
            lab.Column = 1;

            app.ParametricBasisDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'DropdownWidth', '4.25em',...
                'Items',         {'--', '.csv', '.mat', 'All'}, ...
                'Value',         '.csv');
            app.ParametricBasisDropDown.Row    = 4;
            app.ParametricBasisDropDown.Column = 2;

            lab = CSSuiLabel(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'Text' , 'Spline Basis');
            lab.Row    = 5;
            lab.Column = 1;

            app.SplineBasisDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'DropdownWidth', '4.25em',...
                'Items',         {'--', '.tiff', '.mat', 'All'}, ...
                'Value',         '.mat');
            app.SplineBasisDropDown.Row    = 5;
            app.SplineBasisDropDown.Column = 2;

            lab = CSSuiLabel(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'Text' , 'Auxiliary Data');
            lab.Row    = 6;
            lab.Column = 1;

            app.AuxiliaryDataDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'DropdownWidth', '4.25em',...
                'Items',         {'.mat', '--'}, ...
                'Value',         '.mat');
            app.AuxiliaryDataDropDown.Row    = 6;
            app.AuxiliaryDataDropDown.Column = 2;

            % ----- Figure column dropdowns (col 2) -----
            lab = CSSuiLabel(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'Text' , 'Data Summaries');
            lab.Row    = 2;
            lab.Column = 3;

            app.DataSummaryDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'DropdownWidth', '4.25em',...
                'Items',         {'--', '.png', '.jpg', '.jpeg'}, ...
                'Value',         '.png');
            app.DataSummaryDropDown.Row    = 2;
            app.DataSummaryDropDown.Column = 4;

            lab = CSSuiLabel(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'Text' , 'Parametric Fits');
            lab.Row    = 3;
            lab.Column = 3;

            app.ParametricFiguresDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'DropdownWidth', '4.25em',...
                'Items',         {'--', '.png', '.jpg', '.jpeg'}, ...
                'Value',         '.png');
            app.ParametricFiguresDropDown.Row    = 3;
            app.ParametricFiguresDropDown.Column = 4;


            lab = CSSuiLabel(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'Text' , 'Spline Fits');
            lab.Row    = 4;
            lab.Column = 3;

            app.SplineFiguresDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid,'Style','shadow', ...
                'DropdownWidth', '4.25em',...
                'Items',         {'--', '.png', '.jpg', '.jpeg'}, ...
                'Value',         '.png');
            app.SplineFiguresDropDown.Row    = 4;
            app.SplineFiguresDropDown.Column = 4;

            pause(1);
            app.SavingOptionsTabGroup.SelectedTab = app.SavingOptionsTab;

            % ============================================================
            %   DYNAM-O SETTINGS TAB
            % ============================================================

            app.DYNAMOSettingsTab       = uitab(app.BatchRunTabGroup);
            app.DYNAMOSettingsTab.Title = 'DYNAM-O Settings';

            app.DYNAMOSettingsGrid         = uigridlayout(app.DYNAMOSettingsTab);
            app.DYNAMOSettingsGrid.ColumnWidth = {'1x'};
            app.DYNAMOSettingsGrid.RowHeight   = {'1x'};


            % ============================================================
            %   BOTTOM BAR (Status | Run buttons | Options + Progress)
            % ============================================================

            % Three columns
            app.BottomGrid             = uigridlayout(app.FullDYNAMOSetupGrid);
            app.BottomGrid.ColumnWidth = {'3x', '2x', '3x'};
            app.BottomGrid.RowHeight = {app.ButtonHeight * 4.5};   % ~4 stacked buttons tall
            app.BottomGrid.Padding     = [5 5 5 5];
            app.BottomGrid.ColumnSpacing = 0;
            app.BottomGrid.RowSpacing  = 0;
            app.BottomGrid.Layout.Row  = 3;
            app.BottomGrid.Layout.Column = 1;

            % ---- Column 1: Status text ----
            app.StatusTextGrid             = uigridlayout(app.BottomGrid);
            app.StatusTextGrid.ColumnWidth = {'1x'};
            app.StatusTextGrid.RowHeight = {app.ButtonHeight, '1x'};
            app.StatusTextGrid.ColumnSpacing = 0;
            app.StatusTextGrid.RowSpacing  = 0;
            app.StatusTextGrid.Padding     = [5 5 5 5];
            app.StatusTextGrid.Layout.Row  = 1;
            app.StatusTextGrid.Layout.Column = 1;

            app.StatusLabel = CSSuiLabel(app.StatusTextGrid, ...
                'Style', 'shadow', 'FontSize', '13px', 'Text', 'STATUS:');
            app.StatusLabel.Layout.Row    = 1;
            app.StatusLabel.Layout.Column = 1;

            app.TextArea = CSSuiTextArea(app.StatusTextGrid, ...
                'Style', 'shadow', 'BackgroundColor', '#EEE', 'Editable', false);
            app.TextArea.Row   = 2;
            app.TextArea.Column = 1;
            app.TextArea.Value = {'Add files, select settings, and press ''Run Batch'' to run'};

            % ---- Column 2: Run / Stop buttons ----
            app.RunBatchGrid             = uigridlayout(app.BottomGrid);
            app.RunBatchGrid.ColumnWidth = {'1x', '1x'};
            app.RunBatchGrid.RowHeight   = {'1x'};
            app.RunBatchGrid.ColumnSpacing = 0;
            app.RunBatchGrid.Padding  = [80 0 80 0];
            app.RunBatchGrid.Layout.Row  = 1;
            app.RunBatchGrid.Layout.Column = 2;

            app.StopBatchButton = CSSuiButton(app.RunBatchGrid, ...
                'Style', 'shadow', 'Text', 'STOP', ...
                'Icon', '<rect x="5" y="5" width="14" height="14"/>', ...
                'BackgroundColor', '#fdecea', 'BorderRadius', '100%', ...
                'FontSize', '15px', 'Enabled', false, ...
                'ButtonPushedFcn', createCallbackFcn(app, @StopBatchButtonPushed, true));
            app.StopBatchButton.Row    = 1;
            app.StopBatchButton.Column = 1;
            app.StopBatchButton.HTMLComponent.Tooltip = 'Stop batch run after completion of current file';

            app.RunBatchButton = CSSuiButton(app.RunBatchGrid, ...
                'Style', 'shadow', 'Text', 'RUN', ...
                'Icon', '<path d="M8 5v14l11-7z"/>', ...
                'BackgroundColor', '#e8f5e9', 'BorderRadius', '100%', ...
                'FontSize', '15px', ...
                'ButtonPushedFcn', createCallbackFcn(app, @RunBatchButtonPushed, true));
            app.RunBatchButton.Row    = 1;
            app.RunBatchButton.Column = 2;
            app.RunBatchButton.HTMLComponent.Tooltip = 'Batch run DYNAM-O';

            % ---- Column 3: Checkboxes (left) + Progress bar (right) ----
            % Two sub-columns side by side, both spanning the full bar height.
            % Checkboxes use the '1x / fit / fit / 1x' spacer pattern to
            % centre vertically within the full bar height.
            app.RightColumnGrid             = uigridlayout(app.BottomGrid);
            app.RightColumnGrid.ColumnWidth = {'1x', '1x'};
            app.RightColumnGrid.RowHeight   = {'1x'};
            app.RightColumnGrid.RowSpacing  = 0;
            app.RightColumnGrid.ColumnSpacing = 0;
            app.RightColumnGrid.Padding     = [0 0 0 0];
            app.RightColumnGrid.Layout.Row  = 1;
            app.RightColumnGrid.Layout.Column = 3;

            % Switches: 4-row inner grid, spacers on rows 1 & 4 push
            % the two switches to the vertical centre.
            % NOTE: 'fit' cannot be used with uihtml-based components —
            % explicit pixel heights are required instead.
            app.RunBatchOptionsGrid             = uigridlayout(app.RightColumnGrid);
            app.RunBatchOptionsGrid.ColumnWidth = {'1x'};
            app.RunBatchOptionsGrid.RowHeight   = {'1x', app.ButtonHeight, app.ButtonHeight, '1x'};
            app.RunBatchOptionsGrid.RowSpacing  = 4;
            app.RunBatchOptionsGrid.Padding     = [10 0 10 0];
            app.RunBatchOptionsGrid.Layout.Row  = 1;
            app.RunBatchOptionsGrid.Layout.Column = 1;

            app.RunInReverse = CSSuiSwitch(app.RunBatchOptionsGrid,'Style','shadow', ...
                'Text',    'Run in Reverse', ...
                'Enabled', true);
            app.RunInReverse.Row    = 2;
            app.RunInReverse.Column = 1;
            app.RunInReverse.HTMLComponent.Tooltip = 'Check to run through batch files from bottom to top. This is useful when running two instances of the manager in parallel on the same dataset';

            app.OverwriteExistingFilesCheckBox = CSSuiSwitch(app.RunBatchOptionsGrid, 'Style','shadow',...
                'Text',    'Overwrite Existing Files', ...
                'Enabled', true);
            app.OverwriteExistingFilesCheckBox.Row    = 3;
            app.OverwriteExistingFilesCheckBox.Column = 1;
            app.OverwriteExistingFilesCheckBox.HTMLComponent.Tooltip = 'By default, output files will automatically be skipped if already generated. Check to overwrite all files.';

            % Progress bar occupies the right sub-column, full height
            app.TimeEstimateGrid             = uigridlayout(app.RightColumnGrid);
            app.TimeEstimateGrid.ColumnWidth = {'1x'};
            app.TimeEstimateGrid.RowHeight   = {'1x'};
            app.TimeEstimateGrid.Padding     = [5 5 5 5];
            app.TimeEstimateGrid.Layout.Row  = 1;
            app.TimeEstimateGrid.Layout.Column = 2;

            % ============================================================
            %   TOP INSTRUCTION BAR
            % ============================================================

            app.TopTextGrid             = uigridlayout(app.FullDYNAMOSetupGrid);
            app.TopTextGrid.ColumnWidth = {'1x', '15x', '2x'};
            app.TopTextGrid.RowHeight   = {'1x'};
            app.TopTextGrid.ColumnSpacing = 50;
            app.TopTextGrid.Padding     = [0 0 0 0];
            app.TopTextGrid.Layout.Row  = 1;
            app.TopTextGrid.Layout.Column = 1;

            app.InstructionText = CSSuiLabel(app.TopTextGrid, ...
                'Style', 'shadow', 'FontSize', app.FontSizeBase, 'FontWeight', '700', ...
                'Text', 'Add data and staging files, select output directory, choose options, then run batch.');
            app.InstructionText.Layout.Row    = 1;
            app.InstructionText.Layout.Column = 2;

            app.HelpButton = CSSuiButton(app.TopTextGrid, ...
                'Style', 'shadow', 'Text', 'Help', ...
                'ButtonPushedFcn', @(src,event) showHelpButtonPushed(app));
            app.HelpButton.Row    = 1;
            app.HelpButton.Column = 3;


            % ============================================================
            %   DYNAM-O SETTINGS (sub-app embedded in its tab)
            % ============================================================
            createDYNAMOSettingsTab(app);

            % Make figure visible now that all components exist
            app.UIFigure.Visible = 'on';
            app.applyFont;   % propagate FontName to all controls

            % ============================================================
            %   TOOLTIPS
            % ============================================================

            app.ChannelEditField.HTMLComponent.Tooltip      = 'Comma-separated list of channels to run. Click ''Select'' button to scan files and select.';
            app.ChannelEditFieldLabel.HTMLComponent.Tooltip = 'Comma-separated list of channels to run. Click ''Select'' button to scan files and select.';

            app.DelimeterOptionField.HTMLComponent.Tooltip       = 'Select delimiter used in the staging file';

            % Apply tooltips to all stage label fields programmatically
            stage_label_list = {'Artifact','Wake','REM','N1','N2','N3','Unknown'};
            for ii = 1:length(stage_label_list)
                tt = ['Comma separated list of labels used to identify ''' stage_label_list{ii} ''' within the staging file'];
                app.([stage_label_list{ii} 'EditField']).HTMLComponent.Tooltip      = tt;
                app.([stage_label_list{ii} 'EditFieldLabel']).HTMLComponent.Tooltip = tt;
            end

            app.StagesColumnEditField.HTMLComponent.Tooltip      = 'Column of the staging CSV containing the stage labels';
            app.StagesColumnEditFieldLabel.HTMLComponent.Tooltip = 'Column of the staging CSV containing the stage labels';
            app.TimesColumnEditField.HTMLComponent.Tooltip       = 'Column of the staging CSV containing the time of each stage';
            app.TimesColumnEditFieldLabel.HTMLComponent.Tooltip  = 'Column of the staging CSV containing time of each stage';
            app.HeaderRowsEditField.HTMLComponent.Tooltip        = 'Number of header rows in the stage file';
            app.HeaderRowsEditFieldLabel.HTMLComponent.Tooltip   = 'Number of header rows in the stage file';

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
            % showHelpButtonPushed  Display a modal help dialog with usage instructions.

            uialert(app.UIFigure, ...
                sprintf(['Instructions:\n' ...
                '1. In File Selection tab: Add Data files (EDF) and Staging files (CSV/TXT).\n' ...
                '2. Make sure the file counts match and order corresponds.\n' ...
                '3. In Output Options tab: Choose an output directory and select save options.\n' ...
                '4. Click Run Batch to process files.']), ...
                'Help', 'Icon', 'info');
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
            lblSkipped = CSSuiLabel(win,'Text','Skipped (missing) files:','Position',[20 360 200 20]);
            listSkipped = uilistbox(win,'Items',cellstr(invalidLines),'Position',[20 180 360 180],'Multiselect','off');

            % Duplicate files listbox
            lblDup = CSSuiLabel(win,'Text','Duplicate files removed:','Position',[400 360 200 20]);
            listDup = uilistbox(win,'Items',cellstr(duplicateLines),'Position',[400 180 360 180],'Multiselect','off');

            % Button to save logfile
            btnSave = CSSuiButton(win,'Text','Save Logfile','Position',[350 50 100 30],...
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
            listSkipped = uilistbox(win,'Items',cellstr(invalidLines),'Position',[20 180 360 180],'Multiselect','off');

            % Duplicate files listbox
            lblDup = CSSuiLabel(win,'Text','Duplicate files removed:','Position',[400 360 200 20]);
            listDup = uilistbox(win,'Items',cellstr(duplicateLines),'Position',[400 180 360 180],'Multiselect','off');

            % Button to save logfile
            btnSave = CSSuiButton(win,'Text','Save Logfile','Position',[350 50 100 30],...
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
            if ~isempty(files)
                app.DataList = [app.DataList, files];
                updateDataListBox(app);
            end
        end

        % ------------------------------------------------------------------

        function DataAddFolderButtonPushed(app, ~, ~)
            % DataAddFolderButtonPushed  Add all *.edf files found in a chosen folder.

            folder = uigetdir(pwd, 'Select Data Folder');
            if folder == 0, return; end  % User cancelled

            S     = dir(strcat(folder, '/*.edf'));
            files = strcat({S.folder}, '/', {S.name});
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

            S = dir(strcat(folder, '/*.csv'));
            if size(S, 1) == 0
                S = dir(strcat(folder, '/*.txt'));  % Fallback to .txt
            end
            files = strcat({S.folder}, '/', {S.name});
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
            % Reads EDF files, extracts channel names, and allows user to select
            % multiple channels via a modal UI list. Outputs comma-separated string.

            % Check data
            if isempty(app.DataList)
                uialert(app.UIFigure, ...
                    'No EDF files loaded. Load at least one file first.', ...
                    'Error', 'Icon', 'error');
                return
            end

            % Progress bar
            h = waitbar(0,'Processing EDF channels...');

            % Collect labels
            signal_labels = cell(1, length(app.DataList));

            for ii = 1:length(app.DataList)
                try
                    [~, signalHeader] = read_EDF(app.DataList{ii});
                    signal_labels{ii} = {signalHeader.signal_labels};
                catch ME
                    warning('Failed to read file: %s\n%s', ...
                        app.DataList{ii}, ME.message);
                    signal_labels{ii} = {};
                end

                waitbar(ii/length(app.DataList), h);
            end

            delete(h);

            % Combine + clean
            all_labels = horzcat(signal_labels{:});
            if isempty(all_labels)
                uialert(app.UIFigure, ...
                    'No channel labels found in loaded EDF files.', ...
                    'Warning', 'Icon', 'warning');
                return
            end

            signal_labels = sort(unique(all_labels));

            % ===============================
            % UI SELECTION DIALOG
            % ===============================

            d = uifigure('Name', 'Select Channels', ...
                'Position', [100 100 320 420], ...
                'WindowStyle', 'modal');

            % Instruction
            CSSuiLabel(d, ...
                'Text', 'Select one or more channels:', ...
                'Position', [20 385 280 20]);

            % Listbox
            lb = uilistbox(d, ...
                'Items', signal_labels, ...
                'Multiselect', 'on', ...
                'Position', [20 80 280 300]);

            % Output variable
            selectedChannels = [];

            % Accept button
            CSSuiButton(d, 'Text', 'Accept', ...
                'Position', [40 20 100 35], ...
                'ButtonPushedFcn', @(btn,event) acceptCallback());

            % Cancel button
            CSSuiButton(d, 'Text', 'Cancel', ...
                'Position', [180 20 100 35], ...
                'ButtonPushedFcn', @(btn,event) cancelCallback());

            % Wait for user action
            uiwait(d);

            % If user cancelled or closed window
            if isempty(selectedChannels)
                return;
            end

            % Convert to comma-separated string
            channelString = strjoin(selectedChannels, ', ');

            % Store in app (optional)
            app.ChannelEditField.Value = channelString;

            % Optional display
            disp(['Selected Channels: ' channelString]);

            % ===============================
            % Nested Callbacks
            % ===============================

            function acceptCallback()
                selectedChannels = lb.Value;

                if isempty(selectedChannels)
                    uialert(d, ...
                        'Please select at least one channel or press Cancel.', ...
                        'No Selection', 'Icon', 'warning');
                    return;
                end

                if isvalid(d)
                    uiresume(d);
                    delete(d);
                end
            end

            function cancelCallback()
                selectedChannels = [];

                if isvalid(d)
                    uiresume(d);
                    delete(d);
                end
            end

        end

        % ------------------------------------------------------------------

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
                uialert(app.UIFigure, 'File %s does not exist', curr_file, 'Error', 'Icon', 'Error');
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
                case 'data',    filter = {'*.edf','EDF Files (*.edf)'; '*.*','All Files'};
                case 'staging', filter = {'*.csv','CSV (*.csv)'; '*.txt','Text (*.txt)'; '*.*','All Files'};
                otherwise,      filter = {'*.*','All Files'};
            end

            [f, p] = uigetfile(filter, title, 'MultiSelect', 'on');
            if isequal(f, 0), files = {}; return; end  % User cancelled

            if ~iscell(f), f = {f}; end  % Wrap single-file selection in a cell
            files = strcat(p, f);

            % Run optional validation callback; keep only files that pass
            if ~isempty(app.FileValidationCallback)
                validFiles = {};
                for i = 1:length(files)
                    if app.FileValidationCallback(files{i})
                        validFiles{end+1} = files{i}; %#ok<AGROW>
                    end
                end
                files = validFiles;
            end
        end

        % ==================================================================
        %   LIST-BOX UPDATE METHODS
        % ==================================================================

        function updateDataListBox(app)
            % updateDataListBox  Refresh the DataListBox items and update the file-count label.

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
            %     - Any listed file does not exist on disk

            if isempty(app.DataList)
                app.run_error_list(end+1) = {'- Data list empty. Need edf files to run.'};
            end

            if isempty(app.StagingList)
                app.run_error_list(end+1) = {'- Staging list empty. Need staging files to run.'};
            end

            if isempty(app.OutputDirEditField.Value)
                app.run_error_list(end+1) = {'- No output directory given. Need somewhere to save files.'};
            end

            if length(app.DataList) ~= length(app.StagingList)
                app.run_error_list(end+1) = {strcat('- Number of data files (', ...
                    num2str(length(app.DataList)), ...
                    ') does not match staging files (', ...
                    num2str(length(app.StagingList)), ').')};
            end

            if isempty(app.StagesColumnEditField.Value)
                app.run_error_list(end+1) = {'- No staging column given in the staging file.'};
            end

            if isempty(app.TimesColumnEditField.Value)
                app.run_error_list(end+1) = {'- No times column given in the staging file.'};
            end

            if isempty(app.HeaderRowsEditField.Value)
                app.run_error_list(end+1) = {'- No header rows given in the staging file.'};
            end

            % Check that every file in both lists actually exists on disk
            missing = {};
            for f = [app.DataList, app.StagingList]
                if ~isfile(f{1}), missing{end+1} = f{1}; end %#ok<AGROW>
            end

            % TO-DO: Test missing-file error formatting
            if ~isempty(missing)
                app.run_error_list{end} = strcat('Missing files:\n%s', strjoin(missing, '\n'));
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
                app.OutputDirEditField.Value = folder;
                outputDirChanged(app);
            end
        end

        % ------------------------------------------------------------------

        function outputDirChanged(app)
            % outputDirChanged  Validate the output directory; offer to create it if absent.
            %
            %   Called whenever the output directory path is modified (either via
            %   the Browse button or direct text entry). Prompts the user before
            %   creating a new directory. Clears the field if the user declines.

            pathStr = app.OutputDirEditField.Value;
            if ~isfolder(pathStr)
                selection = uiconfirm(app.UIFigure, ...
                    sprintf('Directory does not exist:\n%s\nCreate it?', pathStr), ...
                    'Create Directory?', 'Options', {'Yes','No'}, 'DefaultOption', 2);
                if strcmp(selection, 'Yes')
                    mkdir(pathStr);
                else
                    app.OutputDirEditField.Value = '';
                end
            end
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

            generate_run_log(app.options_structs, app.struct_names, ...
                'run_start', app.curr_datetime, ...
                'file_path', strcat(app.OutputDirEditField.Value, '/settings/'));

            app.runlog_fname = strcat('file_log_', app.curr_datetime, '.txt');
            app.runlog_fpath = strcat(app.OutputDirEditField.Value, '/logs/');
            app.runlog_fid   = fopen(fullfile(app.runlog_fpath, app.runlog_fname), 'w');

            fprintf(app.runlog_fid, 'Date and time of run start: %s\n', app.curr_datetime);
            fprintf(app.runlog_fid, 'Run with settings file: %s\n\n', ...
                strcat('run_settings_', app.curr_datetime, '.txt'));
            fprintf(app.runlog_fid, 'Files run: \n\n');
        end

        % ------------------------------------------------------------------

        function createConsoleLog(app)
            % createConsoleLog  Redirect MATLAB diary output to a timestamped console log.
            %
            %   Creates <OutputDir>/logs/console_log_<timestamp>.txt and activates
            %   MATLAB's diary function to capture all subsequent console output.

            app.consolelog_fname = strcat('console_log_', app.curr_datetime, '.txt');
            app.consolelog_fpath = strcat(app.OutputDirEditField.Value, '/logs/');
            app.consolelog_fid   = fopen(fullfile(app.consolelog_fpath, app.consolelog_fname), 'w');

            fprintf(app.consolelog_fid, 'Date and time of run start: %s\n\n', app.curr_datetime);
            diary(fullfile(app.consolelog_fpath, app.consolelog_fname))
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

            % Ensure output directories exist
            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/TFpeaks/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/TFpeaks/'))
            end
            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/SOPHs/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/SOPHs/'))
            end

            % Build output file paths for existence checks
            app.output_stats_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                '/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.mat');
            app.output_SOPH_name  = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                '/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat');

            % Run DYNAMO only if outputs are missing or overwrite is requested
            if app.OverwriteExistingFilesCheckBox.Value || ...
                    (~exist(app.output_stats_name,'file') || ~exist(app.output_SOPH_name,'file'))

                app.anything_run = 1;
                app.TextArea.Value = strcat('Running DYNAMO on subject ',{' '}, ...
                    app.input_fbase,', channel ',{' '},app.channel,'.');
                app.run();

                stats_table = app.stats_table;
                SOPHs       = app.SOPHs;

                % ---- Save stats table ----
                if app.SavePeakStatsCheckBox.Value && ~strcmp(app.PeakStatsTableDropDown.Value,'--')
                    app.TextArea.Value = strcat('Saving stats table on subject ',{' '}, ...
                        app.input_fbase,', channel ',{' '},app.channel,'.');
                    switch app.PeakStatsTableDropDown.Value
                        case '.csv'
                            app.output_stats_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                                '/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.csv');
                            table2csv(stats_table, app.output_stats_name);
                        case '.mat'
                            app.output_stats_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                                '/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.mat');
                            save(app.output_stats_name,'stats_table');
                        case 'All'
                            % Save both formats
                            app.output_stats_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                                '/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.mat');
                            save(app.output_stats_name,'stats_table');
                            app.output_stats_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                                '/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.csv');
                            table2csv(stats_table, app.output_stats_name);
                    end
                end

                % ---- Save SO-Power Histograms ----
                if app.SaveSOPHsCheckBox.Value && ~strcmp(app.SOPowerHistogramsDropDown.Value,'--')
                    app.TextArea.Value = strcat('Saving SOPHs on subject ',{' '}, ...
                        app.input_fbase,', channel ',{' '},app.channel,'.');
                    switch app.SOPowerHistogramsDropDown.Value
                        case '.tiff'
                            app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                                '/SOPHs/',app.input_fbase,'_SOPHs_power_',app.channel,'.tiff');
                            app.writeTiff(app.output_SOPH_name, SOPHs.SOpower_mat);
                            app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                                '/SOPHs/',app.input_fbase,'_SOPHs_phase_',app.channel,'.tiff');
                            app.writeTiff(app.output_SOPH_name, SOPHs.SOphase_mat);
                        case '.mat'
                            app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                                '/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat');
                            save(app.output_SOPH_name,'SOPHs');
                        case 'All'
                            % Save both tiff and mat
                            app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                                '/SOPHs/',app.input_fbase,'_SOPHs_power',app.channel,'.tiff');
                            app.writeTiff(app.output_SOPH_name, SOPHs.SOpower_mat);
                            app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                                '/SOPHs/',app.input_fbase,'_SOPHs_phase_',app.channel,'.tiff');
                            app.writeTiff(app.output_SOPH_name, SOPHs.SOphase_mat);
                            app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                                '/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat');
                            save(app.output_SOPH_name,'SOPHs');
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

            % Ensure output directory exists
            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/summary/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/summary/'))
            end

            % ---- Ensure SOPHs are available ----
            if isempty(app.SOPHs) && ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                    '/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat'),'file')
                runStatsTable(app);   % Compute from scratch
            elseif isempty(app.SOPHs) && exist(strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                    '/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat'),'file')
                app.SOPHs = load(strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                    '/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat')).SOPHs;
            end

            % ---- Ensure stats_table is available ----
            if isempty(app.stats_table)
                csvPath = strcat(app.OutputDirEditField.Value,'/',app.channel,'/TFpeaks/', ...
                    app.input_fbase,'_stats_table_',app.channel,'.csv');
                matPath = strcat(app.OutputDirEditField.Value,'/',app.channel,'/TFpeaks/', ...
                    app.input_fbase,'_stats_table_',app.channel,'.mat');

                if ~exist(csvPath,'file') && ~exist(matPath,'file')
                    runStatsTable(app);      % Compute from scratch
                elseif exist(matPath,'file')
                    app.stats_table = load(matPath,'stats_table');
                else
                    app.stats_table = csv2table(csvPath);
                end
            end

            % Build output file path (format comes from DataSummaryDropDown)
            if ~strcmp(app.DataSummaryDropDown.Value,'--')
                app.output_fig_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                    '/figures/summary/',app.input_fbase,'_summary_figure_', ...
                    app.channel, app.DataSummaryDropDown.Value);
            end

            % Save figure if missing or overwrite requested
            if app.OverwriteExistingFilesCheckBox.Value || ~exist(app.output_fig_name,'file')
                app.TextArea.Value = strcat('Saving summary figure on subject ',{' '}, ...
                    app.input_fbase,', channel ',{' '},app.channel,'.');
                app.anything_run = 1;
                fh = app.displaySummaryPlot;
                print(fh,'-dpng','-r300',app.output_fig_name);
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

            % Ensure output directories exist
            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/param_basis/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/param_basis/'))
            end
            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/param_basis/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/param_basis/'))
            end

            % ---- Ensure SOPHs are available ----
            if isempty(app.SOPHs) && ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                    '/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat'),'file')
                app.anything_run = 1;
                app.TextArea.Value = strcat('Running DYNAMO on subject ',{' '}, ...
                    app.input_fbase,', channel ',{' '},app.channel,'.');
                runStatsTable(app);
            elseif isempty(app.SOPHs) && exist(strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                    '/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat'),'file')
                app.SOPHs = load(strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                    '/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat')).SOPHs;
            end

            % Fit parametric basis model
            % TO-DO: Check if param basis already saved before re-fitting
            app.TextArea.Value = strcat('Running parameter basis fit on subject ',{' '}, ...
                app.input_fbase,', channel ',{' '},app.channel,'.');
            app.fitParamBasis();
            fh = gcf;

            % Optionally save the parametric basis figure
            if app.SaveParamImagesCheckBox.Value
                app.anything_run  = 1;
                app.output_param_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                    '/figures/param_basis/',app.input_fbase,'_param_basis_figure_', ...
                    app.channel, app.DataSummaryDropDown.Value);
                app.TextArea.Value = strcat('Saving parameter basis fit summary figure on subject ',{' '}, ...
                    app.input_fbase,', channel ',{' '},app.channel,'.');
                print(fh,'-dpng','-r300',app.output_param_name);
            end
            close all;

            % Save parametric fit data according to chosen format
            if ~strcmp(app.ParametricBasisDropDown.Value,'--')
                switch app.ParametricBasisDropDown.Value
                    case '.csv'
                        SOpower_params = app.SOPHs.SOpower_paramfit.params;
                        SOphase_params = app.SOPHs.SOpower_paramfit.params;  % Note: currently uses SOpower source
                        app.output_paramfit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/param_basis/',app.input_fbase,'_SOpower_paramfit_',app.channel,'.csv');
                        app.output_paramfit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/param_basis/',app.input_fbase,'_SOphase_paramfit_',app.channel,'.csv');
                        app.TextArea.Value = strcat('Updating saved SOPH on subject ',{' '}, ...
                            app.input_fbase,', channel ',{' '},app.channel,'.');
                        writematrix(SOpower_params, app.output_paramfit_power_name);
                        writematrix(SOphase_params, app.output_paramfit_phase_name);
                    case '.mat'
                        SOpower_paramfit = app.SOPHs.SOpower_paramfit;
                        SOphase_paramfit = app.SOPHs.SOpower_paramfit;  % Note: currently uses SOpower source
                        app.output_paramfit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/param_basis/',app.input_fbase,'_SOpower_paramfit_',app.channel,'.mat');
                        app.output_paramfit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/param_basis/',app.input_fbase,'_SOphase_paramfit_',app.channel,'.mat');
                        save(app.output_paramfit_power_name,'SOpower_paramfit');
                        save(app.output_paramfit_phase_name,'SOphase_paramfit');
                    case 'All'
                        % Save both csv params and full mat structs
                        SOpower_params = app.SOPHs.SOpower_paramfit.params;
                        SOphase_params = app.SOPHs.SOpower_paramfit.params;
                        app.output_paramfit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/param_basis/',app.input_fbase,'_SOpower_paramfit_',app.channel,'.csv');
                        app.output_paramfit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/param_basis/',app.input_fbase,'_SOphase_paramfit_',app.channel,'.csv');
                        app.TextArea.Value = strcat('Updating saved SOPH on subject ',{' '}, ...
                            app.input_fbase,', channel ',{' '},app.channel,'.');
                        writematrix(SOpower_params, app.output_paramfit_power_name);
                        writematrix(SOphase_params, app.output_paramfit_phase_name);

                        SOpower_paramfit = app.SOPHs.SOpower_paramfit;
                        SOphase_paramfit = app.SOPHs.SOpower_paramfit;
                        app.output_paramfit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/param_basis/',app.input_fbase,'_SOpower_paramfit_',app.channel,'.mat');
                        app.output_paramfit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/param_basis/',app.input_fbase,'_SOphase_paramfit_',app.channel,'.mat');
                        save(app.output_paramfit_power_name,'SOpower_paramfit');
                        save(app.output_paramfit_phase_name,'SOphase_paramfit');
                end
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

            % Ensure output directories exist
            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/spline_basis/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/spline_basis/'))
            end
            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/spline_basis/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/spline_basis/'))
            end

            % ---- Ensure SOPHs are available ----
            if isempty(app.SOPHs) && ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                    '/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat'),'file')
                app.anything_run = 1;
                app.TextArea.Value = strcat('Running DYNAMO on subject ',{' '}, ...
                    app.input_fbase,', channel ',{' '},app.channel,'.');
                runStatsTable(app);
            elseif isempty(app.SOPHs) && exist(strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                    '/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat'),'file')
                app.SOPHs = load(strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                    '/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat')).SOPHs;
            end

            % Fit spline basis model
            % TO-DO: Check if spline already saved before re-fitting
            app.TextArea.Value = strcat('Running spline basis fit on subject ',{' '}, ...
                app.input_fbase,', channel ',{' '},app.channel,'.');
            app.fitSplineBasis();
            fh = gcf;

            % Optionally save the spline basis figure
            if app.SaveSplineImagesCheckBox.Value
                app.anything_run = 1;
                app.TextArea.Value = strcat('Saving spline figure for subject ',{' '}, ...
                    app.input_fbase,', channel ',{' '},app.channel,'.');
                app.output_spline_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                    '/figures/spline_basis/',app.input_fbase,'_spline_basis_figure_',app.channel,'.png');
                print(fh,'-dpng','-r300',app.output_spline_name);
            end
            close all;

            app.TextArea.Value = strcat('Updating saved SOPH for subject ',{' '}, ...
                app.input_fbase,', channel ',{' '},app.channel,'.');

            % Save spline fit data according to chosen format
            if ~strcmp(app.SplineBasisDropDown.Value,'--')
                SOpower_splinefit = app.SOPHs.SOpower_splinefit;
                SOphase_splinefit = app.SOPHs.SOphase_splinefit;

                switch app.SplineBasisDropDown.Value
                    case '.tiff'
                        app.output_splinefit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/spline_basis/',app.input_fbase,'_SOpower_splinefit_',app.channel,'.tiff');
                        app.output_splinefit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/spline_basis/',app.input_fbase,'_SOphase_splinefit_',app.channel,'.tiff');
                        app.writeTiff(app.output_splinefit_power_name, SOpower_splinefit.splinefit);
                        app.writeTiff(app.output_splinefit_phase_name, SOphase_splinefit.splinefit);
                    case '.mat'
                        app.output_splinefit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/spline_basis/',app.input_fbase,'_SOpower_splinefit_',app.channel,'.mat');
                        app.output_splinefit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/spline_basis/',app.input_fbase,'_SOphase_splinefit_',app.channel,'.mat');
                        save(app.output_splinefit_power_name,'SOpower_splinefit');
                        save(app.output_splinefit_phase_name,'SOphase_splinefit');
                    case 'All'
                        % Save both tiff and mat formats
                        app.output_splinefit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/spline_basis/',app.input_fbase,'_SOpower_splinefit_',app.channel,'.tiff');
                        app.output_splinefit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/spline_basis/',app.input_fbase,'_SOphase_splinefit_',app.channel,'.tiff');
                        app.writeTiff(app.output_splinefit_power_name, SOpower_splinefit.splinefit);
                        app.writeTiff(app.output_splinefit_phase_name, SOphase_splinefit.splinefit);
                        app.output_splinefit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/spline_basis/',app.input_fbase,'_SOpower_splinefit_',app.channel,'.mat');
                        app.output_splinefit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/spline_basis/',app.input_fbase,'_SOphase_splinefit_',app.channel,'.mat');
                        save(app.output_splinefit_power_name,'SOpower_splinefit');
                        save(app.output_splinefit_phase_name,'SOphase_splinefit');
                end
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

            % Ensure output directory exists
            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/auxiliary_data/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/auxiliary_data/'))
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

            app.TextArea.Value = strcat('Saving auxiliary data on subject ',{' '}, ...
                app.input_fbase,', channel ',{' '},app.channel,'.');

            app.output_aux_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                '/auxiliary_data/',app.input_fbase,'_auxiliary_data_',app.channel,'.mat');
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
                uialert(app.UIFigure, ...
                    'All files exist and counts match. Ready to process.', ...
                    'Success', 'Icon', 'success');
                app.StopBatchButton.Enable = 'on';
            else
                uialert(app.UIFigure, sprintf('%s\n', app.run_error_list{:}), ...
                    'Run Error', 'Icon', 'error');
                app.run_error_list = {};  % Reset for next validation attempt
                return;
            end

            % Optionally reverse file processing order
            if app.RunInReverse.Value
                app.DataList    = app.DataList(end:-1:1);
                app.StagingList = app.StagingList(end:-1:1);
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
                app.BatchProcessCallback(app.DataList, app.StagingList, opts);
            end

            runBatch(app)
            app.StopBatchButton.Enable = 'on';
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
                'Stopping', 'Icon', 'Error');
        end

        % ------------------------------------------------------------------

        function runBatch(app, ~)
            % runBatch  Main batch processing loop: iterates over all files and channels.
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

            app.TextArea.Value  = {'Beginning run.'};
            app.curr_datetime   = char(datetime('now','Format','yyMMdd_HHmmSS'));

            % Create required output subdirectories
            if ~exist(strcat(app.OutputDirEditField.Value,'/settings/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/settings/'))
            end
            if ~exist(strcat(app.OutputDirEditField.Value,'/logs/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/logs/'))
            end

            % Build DYNAMO options struct from current GUI settings
            app.TextArea.Value = {'Updating advanced options.'};
            createOptionsStruct(app)

            % Initialise run and console logs
            app.TextArea.Value = {'Creating run log.'};
            createRunLog(app)
            app.TextArea.Value = {'Creating console log.'};
            createConsoleLog(app)

            % Parse channel list from edit field
            app.TextArea.Value = {'Processing channel inputs.'};
            updateChannelInput(app)

            % Create (or refresh) the progress bar widget
            if isempty(app.progress_bar)
                app.progress_bar = SmoothProgressBar(app.TimeEstimateGrid, ...
                    length(app.DataList), app.TimeEstimateGrid.Position);
            else
                app.progress_bar.refresh;
            end

            % ---------------------------------------------------------------
            %   MAIN BATCH LOOP
            %   Outer: EDF files | Inner: channels
            % ---------------------------------------------------------------
            app.curr_iteration = 0;

            for jj = 1:length(app.DataList)

                for ii = 1:length(app.ChannelList)
                    app.channel = app.ChannelList{ii};

                    % Honour stop request before starting each new iteration
                    if app.isStopBatchButtonPushed == true
                        return
                    end

                    app.anything_run = 0;
                    [~, app.input_fbase] = fileparts(app.DataList{jj});

                    % Parse stage identifiers from UI fields
                    app.TextArea.Value = {'Processing stage inputs.'};
                    updateStagesInput(app)

                    try
                        % Parse delimiter selection
                        app.TextArea.Value = {'Processing delimeter input.'};
                        updateDelimeterInput(app)

                        % ---- Load EDF and staging data ----
                        app.TextArea.Value = strcat('Loading subject',{' '},app.input_fbase, ...
                            ', channel',{' '},app.channel,' staging and EDF data.');
                        [app.data, app.Fs, app.stage_times, app.stage_vals] = load_data( ...
                            app.DataList{jj}, ...
                            app.StagingList{jj}, ...
                            app.StagesColumnEditField.Value, ...
                            app.TimesColumnEditField.Value, ...
                            app.channel, ...
                            'header_lines', app.HeaderRowsEditField.Value, ...
                            'delimiter',    app.delimeter, ...
                            'stage_vals_in', { app.ArtifactUserInput, app.WakeUserInput, ...
                            app.REMUserInput,      app.N1UserInput, ...
                            app.N2UserInput,       app.N3UserInput, ...
                            app.UnknownUserInput });

                        % ---- Run selected analysis steps ----

                        % TF-peak stats table and/or SO-Power Histograms
                        if app.SavePeakStatsCheckBox.Value || app.SaveSOPHsCheckBox.Value
                            runStatsTable(app)
                        end

                        % Data summary figure
                        if app.SaveDataSummaryCheckBox.Value
                            runDataSummaryFigure(app)
                        end

                        % Parametric basis fit
                        if app.SaveParamBasisCheckBox.Value
                            runParamBasis(app)
                        end

                        % Spline basis fit
                        if app.SaveSplineBasisCheckBox.Value
                            runSplineBasis(app)
                        end

                        % Auxiliary data
                        if app.SaveAuxDataCheckBox.Value
                            saveAuxData(app)
                        end

                        % ---- Log success ----
                        if app.anything_run
                            app.TextArea.Value = strcat('Successfully run subject ',{' '}, ...
                                app.input_fbase,', channel ',{' '},app.channel,'.');
                            fprintf(app.runlog_fid, 'Subject %s, channel %s: run successfully.\n', ...
                                app.input_fbase, app.channel);
                        else
                            % Nothing new to compute: all outputs already existed
                            fprintf(app.runlog_fid, ...
                                'Subject %s, channel %s: all files already exist. Subject skipped.\n', ...
                                app.input_fbase, app.channel);
                        end

                    catch e
                        % ---- Log error and continue to next iteration ----
                        app.TextArea.Value = strcat('Error on subject ',{' '},app.input_fbase, ...
                            ', channel ',{' '},app.channel,'. Check log for details.');
                        fprintf(app.runlog_fid, 'Subject %s, channel %s: not run. Error: %s\n', ...
                            app.input_fbase, app.channel, e.message);
                    end

                    % Update progress bar (wrapped in try-catch to avoid aborting on UI errors)
                    try
                        app.curr_iteration = app.curr_iteration + 1;
                        app.progress_bar.updateIteration(app.curr_iteration);
                    catch e
                        disp(e);
                    end

                end % channel loop

            end % file loop

            % ---------------------------------------------------------------
            %   CLEANUP
            % ---------------------------------------------------------------
            app.progress_bar.complete();
            fclose(app.consolelog_fid);   % Also stops diary
            fclose(app.runlog_fid);
            app.z.Enable = 'on';

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
            %   bespoke sizes (FontSizeTitle, FontSizeSmall) are preserved.

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

    end % private methods

end % classdef