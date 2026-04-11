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
        HelpMenu                        matlab.ui.container.Menu        % Top-level 'Help' menu
        HelpMenuItem                    matlab.ui.container.Menu        % Menu item: show usage instructions
        AboutMenu                       matlab.ui.container.Menu        % Menu item: show About dialog

        % --- Top-Level Tab Group ---
        ProjectTabGroup                 matlab.ui.container.TabGroup    % Outer tab group (Setup / Analysis)
        DYNAMOSetupTab                  matlab.ui.container.Tab         % Main setup tab

        % --- Top-Level Layout Grids ---
        FullDYNAMOSetupGrid             matlab.ui.container.GridLayout  % Root grid inside DYNAMOSetupTab
        HelpButton                      % CSSuiButton                   % Opens help dialog
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
        anything_run                    % Flag indicating at least one analysis was executed this iteration
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

            sc = get(0, 'ScreenSize');
            app.WindowWidth             = min(app.WindowWidth, sc(3));   % Default figure width in pixels
            app.WindowHeight            = min(app.WindowHeight, sc(4));

            % Build all UI components
            createComponents(app, p.Results.Title, p.Results.Position);
            app.enforceMinSize;
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
            % Get screen size
            screenSize = get(0, 'ScreenSize');  % [left bottom width height]

            % Compute centered position
            x = (screenSize(3) - app.WindowWidth) / 2;
            y = (screenSize(4) - app.WindowHeight) / 2;

            % Set figure position
            app.UIFigure.Position = [x, y, app.WindowWidth, app.WindowHeight];
            app.UIFigure.Name = 'DYNAM-O File Manager';
            app.UIFigure.AutoResizeChildren = 'off';   % grid handles it, not figure

            % Set the callback ON THE PANEL, not the figure
            app.UIFigure.SizeChangedFcn = @(src, event) app.enforceMinSize;

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
            % ---- Top-level grid fills the figure automatically ----
            rootGrid = uigridlayout(app.UIFigure, [1 1]);
            rootGrid.Padding  = [0 0 0 0];
            rootGrid.RowHeight   = {'1x'};
            rootGrid.ColumnWidth = {'1x'};

            % ---- Tab group lives inside the grid, NOT positioned manually ----
            app.ProjectTabGroup = uitabgroup(rootGrid); % parent = grid, not figure

            % ---- DYNAM-O Setup Tab ----
            app.DYNAMOSetupTab       = uitab(app.ProjectTabGroup);
            app.DYNAMOSetupTab.Title = 'DYNAM-O Batch Setup';

            % Root grid: 1 column × 3 rows (instructions | main content | bottom bar)
            app.FullDYNAMOSetupGrid             = uigridlayout(app.DYNAMOSetupTab);
            app.FullDYNAMOSetupGrid.ColumnWidth = {'1x'};
            app.FullDYNAMOSetupGrid.RowHeight   = {'20x', '3x'};
            app.FullDYNAMOSetupGrid.RowSpacing  = 0;
            app.FullDYNAMOSetupGrid.ColumnSpacing  = 0;
            app.FullDYNAMOSetupGrid.Padding  = 5;
            % app.FullDYNAMOSetupGrid.BackgroundColor = 'blue';

            % ---- Inner Tab Group (File Selection | DYNAM-O Settings) ----
            app.BatchRunTabGroup                = uitabgroup(app.FullDYNAMOSetupGrid);
            app.BatchRunTabGroup.Layout.Row     = 1;
            app.BatchRunTabGroup.Layout.Column  = 1;

            app.FileSelectionTab       = uitab(app.BatchRunTabGroup);
            app.FileSelectionTab.Title = 'File Selection';

            % Two-column grid: left = file + staging lists, right = runtime options
            app.FileSelectionGrid                   = uigridlayout(app.FileSelectionTab);
            app.FileSelectionGrid.ColumnWidth       = {'1x', 450};
            app.FileSelectionGrid.RowHeight         = {'1x'};
            app.FileSelectionGrid.ColumnSpacing     = 5;
            % app.FileSelectionGrid.BackgroundColor = 'green';

            % The left column is further broken into two columns
            % 3-row grid: title + instruction | list boxes | action buttons
            icon_only_width = '60px';
            filelist_icon_size = '1.25em';
            button_height = 70;

            app.FileInputGrid                   = uigridlayout(app.FileSelectionGrid);
            app.FileInputGrid.ColumnWidth       = {'1x', '1x'};
            app.FileInputGrid.RowHeight         = {30, 20, '1x', button_height};
            app.FileInputGrid.ColumnSpacing     = 15;
            app.FileInputGrid.RowSpacing        = 0;
            app.FileInputGrid.Padding           = [5 0 10 0];
            app.FileInputGrid.Layout.Row        = 1;
            app.FileInputGrid.Layout.Column     = 1;
            % app.FileInputGrid.BackgroundColor = 'red';

            % ============================================================
            %   FILE SELECTION (left column)
            % ============================================================

            app.DataLabel = CSSuiLabel(app.FileInputGrid, ...
                'Style', 'shadow', ...
                'FontWeight', '700', ...
                'FontSize', app.FontSizeTitle, ...
                'Text', 'DATA (0 Files)', ...
                'HorizontalAlignment','left',...
                'VerticalAlignment','top'...
                );
            app.DataLabel.Layout.Row    = 1;
            app.DataLabel.Layout.Column = 1;

            app.DataFileInstructionText = CSSuiLabel(app.FileInputGrid, ...
                'Style', 'shadow', ...
                'FontSize', '11.5px', ...
                'FontWeight', '700', ...
                'Text', 'ADD PSG FILES (.edf). DOUBLE-CLICK FILE FOR HEADER INFO.' ...
                );
            app.DataFileInstructionText.Row    = 2;
            app.DataFileInstructionText.Column = 1;

            % Double-click opens the EDF header viewer
            app.DataListBox = uilistbox(app.FileInputGrid);
            app.DataListBox.Items            = {};
            app.DataListBox.Multiselect      = 'on';
            app.DataListBox.Layout.Row       = 3;
            app.DataListBox.Layout.Column    = 1;
            app.DataListBox.DoubleClickedFcn = createCallbackFcn(app, @ShowHeader, true);
            app.DataListBox.Value            = {};
            app.DataListBox.Tooltip          = 'Double-click a file to view the header';

            % ---- Data File Action Buttons ----
            app.DataFileButtonGrid                  = uigridlayout(app.FileInputGrid);
            app.DataFileButtonGrid.ColumnWidth      = {'1x', '1x', '1x', '1x', '1x', '1x', '1x'};
            app.DataFileButtonGrid.RowHeight        = {button_height};
            app.DataFileButtonGrid.ColumnSpacing    = 5;
            app.DataFileButtonGrid.Padding          = [5 0 5 0];
            app.DataFileButtonGrid.Layout.Row       = 4;
            app.DataFileButtonGrid.Layout.Column    = 1;

            % -- Add single EDF file --
            app.DataAddFileButton = CSSuiButton(app.DataFileButtonGrid, ...
                'Style','shadow', ...
                'Text', 'Add File', ...
                'MaxWidth', '120px',...
                'ButtonPushedFcn', createCallbackFcn(app, @DataAddFileButtonPushed, true), ...
                'IconPosition', 'top', ...
                'IconSize', filelist_icon_size,...
                'IconOnlyWidth', icon_only_width,...
                'Icon',     '<path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8l-6-6zm-1 7V3.5L18.5 9H13z M11 13h2v-2h2v2h2v2h-2v2h-2v-2h-2z"/>' ...
                );
            app.DataAddFileButton.Row    = 1;
            app.DataAddFileButton.Column = 2;
            app.DataAddFileButton.HTMLComponent.Tooltip       = 'Add single EDF file';

            % -- Add EDF folder --
            app.DataAddFolderButton = CSSuiButton(app.DataFileButtonGrid, ...
                'Style','shadow', ...
                'Text', 'Add Folder', ...
                'MaxWidth', '120px',...
                'ButtonPushedFcn',  createCallbackFcn(app, @DataAddFolderButtonPushed, true), ...
                'IconPosition', 'top', ...
                'IconSize', filelist_icon_size,...
                'IconOnlyWidth', icon_only_width,...
                'Icon', '<path d="M10 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"/><path d="M13 14h-2v-2h-2v2H7v2h2v2h2v-2h2v-2z" fill="white" opacity="0.9"/>' ...
                );
            app.DataAddFolderButton.Row    = 1;
            app.DataAddFolderButton.Column = 3;
            app.DataAddFolderButton.HTMLComponent.Tooltip       = 'Add all EDF files in folder';

            % -- Remove selected EDF file --
            app.DataRemoveButton = CSSuiButton(app.DataFileButtonGrid, ...
                'Style','shadow', ...
                'Text', 'Delete File', ...
                'MaxWidth', '120px',...
                'ButtonPushedFcn',  createCallbackFcn(app, @DataRemoveButtonPushed, true), ...
                'IconPosition', 'top', ...
                'IconSize', filelist_icon_size,...
                'IconOnlyWidth', icon_only_width,...
                'Icon', '<path d="M3 6h18v2H3V6zm2 2h14l-1.5 14h-11L5 8zm5 2v8h2v-8h-2zm4 0v8h2v-8h-2zM8 4h8v2H8V4z"/>' ...
                );
            app.DataRemoveButton.Row    = 1;
            app.DataRemoveButton.Column = 4;
            app.DataRemoveButton.HTMLComponent.Tooltip       = 'Remove selected EDF file';

            % -- Move EDF file up --
            app.DataMoveUpButton = CSSuiButton(app.DataFileButtonGrid, ...
                'Style', 'shadow', ...
                'Text', 'Move Up', ...
                'MaxWidth', '120px',...
                'ButtonPushedFcn', createCallbackFcn(app, @DataMoveUpButtonPushed, true), ...
                'Padding', '15px', ...
                'IconPosition', 'top', ...
                'IconSize', filelist_icon_size,...
                'IconOnlyWidth', icon_only_width,...
                'Icon', '<path d="M12 5l-7 9h5v8h4v-8h5z"/>' ...
                );
            app.DataMoveUpButton.Row    = 1;
            app.DataMoveUpButton.Column = 5;
            app.DataMoveUpButton.HTMLComponent.Tooltip = 'Move current EDF file up';

            % -- Move EDF file down --
            app.DataMoveDownButton = CSSuiButton(app.DataFileButtonGrid, ...
                'Style', 'shadow', ...
                'Text', 'Move Down', ...
                'MaxWidth', '120px',...
                'ButtonPushedFcn', createCallbackFcn(app, @DataMoveDownButtonPushed, true), ...
                'Padding', '15px', ...
                'IconPosition', 'top', ...
                'IconSize', filelist_icon_size,...
                'IconOnlyWidth', icon_only_width,...
                'Icon', '<path d="M12 19l-7-9h5v-8h4v8h5z"/>' ...
                );
            app.DataMoveDownButton.Row    = 1;
            app.DataMoveDownButton.Column = 6;
            app.DataMoveDownButton.HTMLComponent.Tooltip = 'Move current EDF file down';

            % =========================================================================
            %  STAGING SELECTION (middle column)
            % =========================================================================

            app.StagingLabel = CSSuiLabel(app.FileInputGrid, ...
                'Style', 'shadow', ...
                'FontWeight', '700', ...
                'FontSize', app.FontSizeTitle, ...
                'VerticalAlignment', 'top',...
                'HorizontalAlignment', 'left', 'Text', 'STAGING (0 Files)' ...
                );
            app.StagingLabel.Layout.Row    = 1;
            app.StagingLabel.Layout.Column = 2;

            app.StagingFileInstructionText = CSSuiLabel(app.FileInputGrid, ...
                'Style', 'shadow', ...
                'FontSize', '11.5px', ...
                'FontWeight', '700', ...
                'Text', 'ADD STAGING FILES (.csv/.txt). MATCH PSG FILE ORDER.' ...
                );
            app.StagingFileInstructionText.Layout.Row    = 2;
            app.StagingFileInstructionText.Layout.Column = 2;

            app.StagingListBox = uilistbox(app.FileInputGrid);
            app.StagingListBox.Items         = {};
            app.StagingListBox.Multiselect   = 'on';
            app.StagingListBox.Layout.Row    = 3;
            app.StagingListBox.Layout.Column = 2;
            app.StagingListBox.Value         = {};

            % ---- Staging File Action Buttons ----
            app.StagingFileButtonGrid             = uigridlayout(app.FileInputGrid);
            app.StagingFileButtonGrid.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1x', '1x'};
            app.StagingFileButtonGrid.RowHeight   = {button_height};
            app.StagingFileButtonGrid.ColumnSpacing = 5;
            app.StagingFileButtonGrid.Padding     = [5 0 5 0];
            app.StagingFileButtonGrid.Layout.Row  = 4;
            app.StagingFileButtonGrid.Layout.Column = 2;

            % -- Add single staging file --
            app.StagingAddFileButton = CSSuiButton(app.StagingFileButtonGrid, ...
                'Style','shadow', ...
                'Text', 'Add File', ...
                'MaxWidth', '120px',...
                'ButtonPushedFcn', createCallbackFcn(app, @StagingAddFileButtonPushed, true), ...
                'IconPosition', 'top', ...
                'IconSize', filelist_icon_size,...
                'IconOnlyWidth', icon_only_width,...
                'Icon',     '<path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8l-6-6zm-1 7V3.5L18.5 9H13z M11 13h2v-2h2v2h2v2h-2v2h-2v-2h-2z"/>' ...
                );
            app.StagingAddFileButton.Row    = 1;
            app.StagingAddFileButton.Column = 2;
            app.StagingAddFileButton.HTMLComponent.Tooltip       = 'Add single EDF file';

            app.StagingAddFolderButton = CSSuiButton(app.StagingFileButtonGrid, ...
                'Style','shadow', ...
                'Text', 'Add Folder', ...
                'MaxWidth', '120px',...
                'ButtonPushedFcn',  createCallbackFcn(app, @StagingAddFolderButtonPushed, true), ...
                'IconPosition', 'top', ...
                'IconSize', filelist_icon_size,...
                'IconOnlyWidth', icon_only_width,...
                'Icon', '<path d="M10 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"/><path d="M13 14h-2v-2h-2v2H7v2h2v2h2v-2h2v-2z" fill="white" opacity="0.9"/>' ...
                );
            app.StagingAddFolderButton.Row    = 1;
            app.StagingAddFolderButton.Column = 3;
            app.StagingAddFolderButton.HTMLComponent.Tooltip       = 'Add all staging files in folder';

            % -- Remove selected staging file --
            app.StagingRemoveButton = CSSuiButton(app.StagingFileButtonGrid, ...
                'Style','shadow', ...
                'Text', 'Delete File', ...
                'MaxWidth', '120px',...
                'ButtonPushedFcn',  createCallbackFcn(app, @StagingRemoveButtonPushed, true), ...
                'IconPosition', 'top', ...
                'IconSize', filelist_icon_size,...
                'IconOnlyWidth', icon_only_width,...
                'Icon', '<path d="M3 6h18v2H3V6zm2 2h14l-1.5 14h-11L5 8zm5 2v8h2v-8h-2zm4 0v8h2v-8h-2zM8 4h8v2H8V4z"/>' ...
                );
            app.StagingRemoveButton.Row    = 1;
            app.StagingRemoveButton.Column = 4;
            app.StagingRemoveButton.HTMLComponent.Tooltip       = 'Remove selected staging file';

            % -- Move staging file up --
            app.StagingMoveUpButton = CSSuiButton(app.StagingFileButtonGrid, ...
                'Style','shadow', ...
                'Text', 'Move Up', ...
                'MaxWidth', '120px',...
                'ButtonPushedFcn',  createCallbackFcn(app, @StagingMoveUpButtonPushed, true), ...
                'IconPosition', 'top', ...
                'IconSize', filelist_icon_size,...
                'IconOnlyWidth', icon_only_width,...
                'Icon', '<path d="M12 5l-7 9h5v8h4v-8h5z"/>' ...
                );
            app.StagingMoveUpButton.Row    = 1;
            app.StagingMoveUpButton.Column = 5;
            app.StagingMoveUpButton.HTMLComponent.Tooltip       = 'Move current staging file up';

            % -- Move staging file down --
            app.StagingMoveDownButton = CSSuiButton(app.StagingFileButtonGrid, ...
                'Style','shadow', ...
                'Text', 'Move Down', ...
                'MaxWidth', '120px',...
                'ButtonPushedFcn',  createCallbackFcn(app, @StagingMoveDownButtonPushed, true), ...
                'IconPosition', 'top', ...
                'IconSize', filelist_icon_size,...
                'IconOnlyWidth', icon_only_width,...
                'Icon', '<path d="M12 19l-7-9h5v-8h4v8h5z"/>' ...
                );
            app.StagingMoveDownButton.Row    = 1;
            app.StagingMoveDownButton.Column = 6;
            app.StagingMoveDownButton.HTMLComponent.Tooltip       = 'Move current staging file down';

            % ============================================================
            %   RUNTIME OPTIONS (right column)
            % ============================================================

            % Three-row right column: channel options | staging options | saving options
            app.RuntimeOptionsGrid                  = uigridlayout(app.FileSelectionGrid);
            app.RuntimeOptionsGrid.ColumnWidth      = {'1x'};
            app.RuntimeOptionsGrid.RowHeight        = {50, 35, 280, '1x', 270};
            app.RuntimeOptionsGrid.ColumnSpacing    = 0;
            app.RuntimeOptionsGrid.RowSpacing       = 0;
            app.RuntimeOptionsGrid.Padding          = [0 6 0 0];
            app.RuntimeOptionsGrid.Layout.Row       = 1;
            app.RuntimeOptionsGrid.Layout.Column    = 2;
            % app.RuntimeOptionsGrid.BackgroundColor = 'black';

            %Runtime Label
            app.RuntimeOptionsLabel = CSSuiLabel(app.RuntimeOptionsGrid, ...
                'Style', 'shadow', ...
                'FontWeight', '700', ...
                'FontSize', app.FontSizeTitle, ...
                'Text', 'INPUT SETTINGS', ...
                'VerticalAlignment','top'...
                );
            app.RuntimeOptionsLabel.Layout.Row    = 1;
            app.RuntimeOptionsLabel.Layout.Column = 1;

            % ---- Channel Selection (Row 1) ----
            app.ChannelInputGrid                   = uigridlayout(app.RuntimeOptionsGrid);
            app.ChannelInputGrid.ColumnWidth       = {'2x', '7x', '2x'};
            app.ChannelInputGrid.RowHeight         = {'1x'};
            app.ChannelInputGrid.Padding           = [0 0 0 0];
            app.ChannelInputGrid.Layout.Row        = 2;
            app.ChannelInputGrid.Layout.Column     = 1;

            app.ChannelEditFieldLabel = CSSuiLabel(app.ChannelInputGrid, ...
                'Style', 'shadow', ...
                'Text', 'Channel(s)' ...
                );
            app.ChannelEditFieldLabel.Layout.Row    = 1;
            app.ChannelEditFieldLabel.Layout.Column = 1;

            app.ChannelEditField               = CSSuiEditField(app.ChannelInputGrid, ...
                'Style','shadow', ...
                'Value', 'Enter comma-separated channel labels' ...
                );
            app.ChannelEditField.Layout.Row    = 1;
            app.ChannelEditField.Layout.Column = 2;

            % Info button: opens dialog listing all channels present in loaded EDFs
            app.ViewChannelsButton = CSSuiButton(app.ChannelInputGrid, ...
                'Style', 'shadow', ...
                'Text', 'Select' ...
                );
            app.ViewChannelsButton.Row    = 1;
            app.ViewChannelsButton.Column = 3;
            app.ViewChannelsButton.ButtonPushedFcn = createCallbackFcn(app, @viewChannelsButtonPushed, true);

            % ---- Staging Options (Row 2) ----
            % Two-sub-column panel: left = stage label identifiers, right = file format inputs
            app.StagingOptionsPanelGrid                 = uigridlayout(app.RuntimeOptionsGrid);
            app.StagingOptionsPanelGrid.ColumnWidth     = {'2x', '4x', '3x', '2x'} ;
            app.StagingOptionsPanelGrid.RowHeight       = {'1x','1x','1x','1x','1x','1x','1x'};
            app.StagingOptionsPanelGrid.ColumnSpacing   = 10;
            app.StagingOptionsPanelGrid.RowSpacing      = 0;
            app.StagingOptionsPanelGrid.Padding         = [0 5 0 5];
            app.StagingOptionsPanelGrid.Layout.Row      = 3;
            app.StagingOptionsPanelGrid.Layout.Column   = 1;

            % Artifact stage identifiers
            app.ArtifactEditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Text', 'Artifact' ...
                );
            app.ArtifactEditFieldLabel.Layout.Row    = 1;
            app.ArtifactEditFieldLabel.Layout.Column = 1;

            app.ArtifactEditField = CSSuiEditField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Value', 'artifact, A, 6' ...
                );
            app.ArtifactEditField.Layout.Row    = 1;
            app.ArtifactEditField.Layout.Column = 2;

            % Wake stage identifiers
            app.WakeEditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Text', 'Wake' ...
                );
            app.WakeEditFieldLabel.Layout.Row    = 2;
            app.WakeEditFieldLabel.Layout.Column = 1;

            app.WakeEditField = CSSuiEditField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Value', 'wake, W, 5' ...
                );
            app.WakeEditField.Layout.Row    = 2;
            app.WakeEditField.Layout.Column = 2;

            % REM stage identifiers
            app.REMEditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Text', 'REM' ...
                );
            app.REMEditFieldLabel.Layout.Row    = 3;
            app.REMEditFieldLabel.Layout.Column = 1;

            app.REMEditField = CSSuiEditField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Value', 'REM, R, 4' ...
                );
            app.REMEditField.Layout.Row    = 3;
            app.REMEditField.Layout.Column = 2;

            % N1 stage identifiers
            app.N1EditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Text', 'N1' ...
                );
            app.N1EditFieldLabel.Layout.Row    = 4;
            app.N1EditFieldLabel.Layout.Column = 1;

            app.N1EditField = CSSuiEditField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Value', 'N1, Stage 1, 1' ...
                );
            app.N1EditField.Layout.Row    = 4;
            app.N1EditField.Layout.Column = 2;

            % N2 stage identifiers
            app.N2EditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Text', 'N2' ...
                );
            app.N2EditFieldLabel.Layout.Row    = 5;
            app.N2EditFieldLabel.Layout.Column = 1;

            app.N2EditField = CSSuiEditField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Value', 'N2, Stage 2, 2' ...
                );
            app.N2EditField.Layout.Row    = 5;
            app.N2EditField.Layout.Column = 2;

            % N3 stage identifiers
            app.N3EditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Text', 'N3' ...
                );
            app.N3EditFieldLabel.Layout.Row    = 6;
            app.N3EditFieldLabel.Layout.Column = 1;

            app.N3EditField = CSSuiEditField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Value', 'N3, Stage 3, 3' ...
                );
            app.N3EditField.Layout.Row    = 6;
            app.N3EditField.Layout.Column = 2;

            % Unknown stage identifiers
            app.UnknownEditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Text', 'Unknown' ...
                );
            app.UnknownEditFieldLabel.Layout.Row    = 7;
            app.UnknownEditFieldLabel.Layout.Column = 1;

            app.UnknownEditField = CSSuiEditField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Value', 'Unk, U, Unknown' ...
                );
            app.UnknownEditField.Layout.Row    = 7;
            app.UnknownEditField.Layout.Column = 2;

            % Stages column index
            app.StagesColumnEditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Text', 'Stages Column' ...
                );
            app.StagesColumnEditFieldLabel.Layout.Row    = 3;
            app.StagesColumnEditFieldLabel.Layout.Column = 3;

            app.StagesColumnEditField = CSSuiNumericField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Min', 0 ...
                );
            app.StagesColumnEditField.Layout.Row    = 3;
            app.StagesColumnEditField.Layout.Column = 4;

            % Times column index
            app.TimesColumnEditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Text', 'Times Column' ...
                );
            app.TimesColumnEditFieldLabel.Row    = 4;
            app.TimesColumnEditFieldLabel.Column = 3;

            app.TimesColumnEditField = CSSuiNumericField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Min', 0 ...
                );
            app.TimesColumnEditField.Row    = 4;
            app.TimesColumnEditField.Column = 4;

            % Header rows count
            app.HeaderRowsEditFieldLabel = CSSuiLabel(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Text', 'Header Rows' ...
                );
            app.HeaderRowsEditFieldLabel.Row    = 5;
            app.HeaderRowsEditFieldLabel.Column = 3;

            app.HeaderRowsEditField = CSSuiNumericField(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Min', 0 ...
                );
            app.HeaderRowsEditField.Row    = 5;
            app.HeaderRowsEditField.Column = 4;

            % File delimiter dropdown
            app.DelimeterOptionField = CSSuiDropdown(app.StagingOptionsPanelGrid, ...
                'Style', 'shadow', ...
                'Label', 'File Delimiter', ...
                'Items', {'Comma', 'Tab', 'Space', 'Semicolon'}, ...
                'Value', 'Comma', ...
                'FontWeight', 'normal' ...
                );
            app.DelimeterOptionField.Row    = 1;
            app.DelimeterOptionField.Column = [3 4];

            % ---- Saving Options and File Formats (Row 3) ----
            app.SavingOptionsTabGroupGrid                   = uigridlayout(app.RuntimeOptionsGrid);
            app.SavingOptionsTabGroupGrid.ColumnWidth       = {'1x'};
            app.SavingOptionsTabGroupGrid.RowHeight         = {'1x'};
            app.SavingOptionsTabGroupGrid.Padding           = [0 0 5 0];  % dedicated grid to add padding
            app.SavingOptionsTabGroupGrid.Layout.Row        = 5;
            app.SavingOptionsTabGroupGrid.Layout.Column     = 1;

            app.SavingOptionsTabGroup                   = uitabgroup(app.SavingOptionsTabGroupGrid);
            app.SavingOptionsTabGroup.Layout.Row        = 1;
            app.SavingOptionsTabGroup.Layout.Column     = 1;

            % ============================================================
            %   SAVING OPTIONS TAB
            % ============================================================

            app.SavingOptionsTab       = uitab(app.SavingOptionsTabGroup);
            app.SavingOptionsTab.Title = 'Saving Options';
            app.SavingOptionsTabGroup.SelectedTab = app.SavingOptionsTab;

            app.SavingOptionsTabGrid             = uigridlayout(app.SavingOptionsTab);
            app.SavingOptionsTabGrid.ColumnWidth = {'1x'};
            app.SavingOptionsTabGrid.RowHeight   = {'3x', '1x'};
            app.SavingOptionsTabGrid.RowSpacing  = 0;
            app.SavingOptionsTabGrid.Padding     = [10 0 5 2];

            % Six-row, two-column grid of save checkboxes
            app.SavingOptionsCheckBoxGrid             = uigridlayout(app.SavingOptionsTabGrid);
            app.SavingOptionsCheckBoxGrid.ColumnWidth = {'1x', '1x'};
            app.SavingOptionsCheckBoxGrid.RowHeight   = {'1x','1x','1x','1x','1x','1x'};
            app.SavingOptionsCheckBoxGrid.Padding     = [3 5 3 5];
            app.SavingOptionsCheckBoxGrid.Layout.Row  = 1;
            app.SavingOptionsCheckBoxGrid.Layout.Column = 1;

            % Column headers
            app.DatatoSaveLabel = CSSuiLabel(app.SavingOptionsCheckBoxGrid, ...
                'Style', 'shadow', ...
                'FontWeight', '700', ...
                'Text', 'DATA TO SAVE' ...
                );
            app.DatatoSaveLabel.Layout.Row    = 1;
            app.DatatoSaveLabel.Layout.Column = 1;

            app.FigurestoSaveLabel = CSSuiLabel(app.SavingOptionsCheckBoxGrid, ...
                'Style', 'shadow', ...
                'FontWeight', '700', ...
                'Text', 'FIGURES TO SAVE' ...
                );
            app.FigurestoSaveLabel.Layout.Row    = 1;
            app.FigurestoSaveLabel.Layout.Column = 2;

            % --- Data Tables (Left Column) ---
            app.SavePeakStatsCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, ...
                'Style','shadow', ...
                'Text', 'Peak Stats Tables', ...
                'Value', 1 ...
                );
            app.SavePeakStatsCheckBox.Row    = 2;
            app.SavePeakStatsCheckBox.Column = 1;
            app.SavePeakStatsCheckBox.HTMLComponent.Tooltip       = 'Save TFpeak stats tables, which store individual peak features for all detected TFpeaks';

            app.SaveSOPHsCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, ...
                'Style', 'shadow', ...
                'Text', 'SO-Power Histogram', ...
                'Value', 1 ...
                );
            app.SaveSOPHsCheckBox.Row    = 3;
            app.SaveSOPHsCheckBox.Column = 1;
            app.SaveSOPHsCheckBox.HTMLComponent.Tooltip       = 'Save SO-power and SO-phase histograms';

            app.SaveParamBasisCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, ...
                'Style', 'shadow', ...
                'Text', 'Parametric Basis', ...
                'Value', 1 ...
                );
            app.SaveParamBasisCheckBox.Row    = 4;
            app.SaveParamBasisCheckBox.Column = 1;
            app.SaveParamBasisCheckBox.HTMLComponent.Tooltip       = 'Save tables of estimated mode feature parameters for SO-power and SO-phase histograms';

            app.SaveSplineBasisCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, ...
                'Style', 'shadow', ...
                'Text', 'Spline Basis', ...
                'Value', 1 ...
                );
            app.SaveSplineBasisCheckBox.Row    = 5;
            app.SaveSplineBasisCheckBox.Column = 1;
            app.SaveSplineBasisCheckBox.HTMLComponent.Tooltip       = 'Save matrix of spline knot parameters';

            app.SaveAuxDataCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, ...
                'Style', 'shadow', ...
                'Text', 'Auxiliary Data', ...
                'Value', 1 ...
                );
            app.SaveAuxDataCheckBox.Row    = 6;
            app.SaveAuxDataCheckBox.Column = 1;
            app.SaveAuxDataCheckBox.HTMLComponent.Tooltip       = 'Save auxiliary data helpful for rapid recomputation and figure generation without accessing the raw data';

            % --- Figure Save Checkboxes (Right Column) ---
            app.SaveDataSummaryCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, ...
                'Style', 'shadow', ...
                'Text', 'Data Summary', ...
                'Value', 1 ...
                );
            app.SaveDataSummaryCheckBox.Row    = 2;
            app.SaveDataSummaryCheckBox.Column = 2;
            app.SaveDataSummaryCheckBox.HTMLComponent.Tooltip       = 'Save DYNAM-O summary figures, showing spectrogram, SO-power, detected peaks, and SO-power/phase histograms';

            app.SaveParamImagesCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, ...
                'Style', 'shadow', ...
                'Text', 'Parametric Basis', ...
                'Value', 1 ...
                );
            app.SaveParamImagesCheckBox.Row    = 3;
            app.SaveParamImagesCheckBox.Column = 2;
            app.SaveParamImagesCheckBox.HTMLComponent.Tooltip       = 'Save the output figures for parametric fits';

            app.SaveSplineImagesCheckBox = CSSuiSwitch(app.SavingOptionsCheckBoxGrid, ...
                'Style', 'shadow', ...
                'Text', 'Spline Basis', ...
                'Value', 1 ...
                );
            app.SaveSplineImagesCheckBox.Row    = 4;
            app.SaveSplineImagesCheckBox.Column = 2;
            app.SaveSplineImagesCheckBox.HTMLComponent.Tooltip       = 'Save the output figures for spline fits';

            % ---- Output Directory Row ----
            app.SavingDirectoryGrid             = uigridlayout(app.SavingOptionsTabGrid);
            app.SavingDirectoryGrid.ColumnWidth = {'8x', '2x'};
            app.SavingDirectoryGrid.RowHeight   = {'2x', '4x'};
            app.SavingDirectoryGrid.RowSpacing  = 0;
            app.SavingDirectoryGrid.Padding     = [5 5 5 0];
            app.SavingDirectoryGrid.Layout.Row  = 2;
            app.SavingDirectoryGrid.Layout.Column = 1;

            app.OutputDirLabel = CSSuiLabel(app.SavingDirectoryGrid, ...
                'Style', 'shadow', ...
                'FontSize', '12px', ...
                'Text', 'Select output directory:' ...
                );
            app.OutputDirLabel.Layout.Row    = 1;
            app.OutputDirLabel.Layout.Column = 1;

            app.OutputDirButton = CSSuiButton(app.SavingDirectoryGrid, ...
                'Style', 'shadow', ...
                'Text', 'Browse', ...
                'ButtonPushedFcn', @(src,event) browseOutputDir(app) ...
                );
            app.OutputDirButton.Row    = 2;
            app.OutputDirButton.Column = 2;

            % Placeholder label under the edit field (edit field renders on top)
            app.EditFieldLabel = CSSuiLabel(app.SavingDirectoryGrid, 'Text', 'Edit Field');
            app.EditFieldLabel.Layout.Row    = 2;
            app.EditFieldLabel.Layout.Column = 1;

            app.OutputDirEditField = CSSuiEditField(app.SavingDirectoryGrid, 'style','shadow');
            app.OutputDirEditField.Layout.Row    = 2;
            app.OutputDirEditField.Layout.Column = 1;
            app.OutputDirEditField.HTMLComponent.Tooltip = 'Select the root directory from which to generate the output file structure';

            % ============================================================
            %   FILE FORMAT TAB
            % ============================================================

            app.FileFormatTab       = uitab(app.SavingOptionsTabGroup);
            app.FileFormatTab.Title = 'File Formats';
            app.SavingOptionsTabGroup.SelectedTab = app.FileFormatTab;

            app.FileFormatCheckBoxGrid                = uigridlayout(app.FileFormatTab);
            app.FileFormatCheckBoxGrid.ColumnWidth    = {'1x', '1x', '1x', '1x'};
            app.FileFormatCheckBoxGrid.RowHeight = {30,30,30,30,30,30,30};
            app.FileFormatCheckBoxGrid.ColumnSpacing      = 0;

            % ----- Column headers -----
            app.DataFileFormatLabel = CSSuiLabel(app.FileFormatCheckBoxGrid, ...
                'Style', 'shadow', ...
                'FontWeight', '700', ...
                'Text', 'DATA FILE FORMAT' ...
                );
            app.DataFileFormatLabel.Layout.Row    = 1;
            app.DataFileFormatLabel.Layout.Column = [1 2];

            app.FigureFileFormatLabel = CSSuiLabel(app.FileFormatCheckBoxGrid, ...
                'Style', 'shadow', ...
                'FontWeight', '700', ...
                'Text', 'FIGURE FILE FORMAT' ...
                );
            app.FigureFileFormatLabel.Layout.Row    = 1;
            app.FigureFileFormatLabel.Layout.Column = [3 4];

            % ----- Data column dropdowns (col 1) -----
            lab = CSSuiLabel(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'Text' , 'Peak Stats Table' ...
                );
            lab.Row    = 2;
            lab.Column = 1;

            app.PeakStatsTableDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'DropdownWidth', '4.25em', ...
                'Items',         {'--', '.csv', '.mat', 'All'}, ...
                'Value',         '.csv' ...
                );
            app.PeakStatsTableDropDown.Row    = 2;
            app.PeakStatsTableDropDown.Column = 2;

            lab = CSSuiLabel(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'Text' , 'SO Histograms' ...
                );
            lab.Row    = 3;
            lab.Column = 1;

            app.SOPowerHistogramsDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'DropdownWidth', '4.25em', ...
                'Items',         {'--', '.tiff', '.mat', 'All'}, ...
                'Value',         '.tiff' ...
                );
            app.SOPowerHistogramsDropDown.Row    = 3;
            app.SOPowerHistogramsDropDown.Column = 2;

            lab = CSSuiLabel(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'Text' , 'Parametric Basis' ...
                );
            lab.Row    = 4;
            lab.Column = 1;

            app.ParametricBasisDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'DropdownWidth', '4.25em', ...
                'Items',         {'--', '.csv', '.mat', 'All'}, ...
                'Value',         '.csv' ...
                );
            app.ParametricBasisDropDown.Row    = 4;
            app.ParametricBasisDropDown.Column = 2;

            lab = CSSuiLabel(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'Text' , 'Spline Basis' ...
                );
            lab.Row    = 5;
            lab.Column = 1;

            app.SplineBasisDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'DropdownWidth', '4.25em', ...
                'Items',         {'--', '.tiff', '.mat', 'All'}, ...
                'Value',         '.mat' ...
                );
            app.SplineBasisDropDown.Row    = 5;
            app.SplineBasisDropDown.Column = 2;

            lab = CSSuiLabel(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'Text' , 'Auxiliary Data' ...
                );
            lab.Row    = 6;
            lab.Column = 1;

            app.AuxiliaryDataDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'DropdownWidth', '4.25em', ...
                'Items',         {'.mat', '--'}, ...
                'Value',         '.mat' ...
                );
            app.AuxiliaryDataDropDown.Row    = 6;
            app.AuxiliaryDataDropDown.Column = 2;

            % ----- Figure column dropdowns (col 2) -----
            lab = CSSuiLabel(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'Text' , 'Data Summaries' ...
                );
            lab.Row    = 2;
            lab.Column = 3;

            app.DataSummaryDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'DropdownWidth', '4.25em', ...
                'Items',         {'--', '.png', '.jpg', '.jpeg'}, ...
                'Value',         '.png' ...
                );
            app.DataSummaryDropDown.Row    = 2;
            app.DataSummaryDropDown.Column = 4;

            lab = CSSuiLabel(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'Text' , 'Parametric Fits' ...
                );
            lab.Row    = 3;
            lab.Column = 3;

            app.ParametricFiguresDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'DropdownWidth', '4.25em', ...
                'Items',         {'--', '.png', '.jpg', '.jpeg'}, ...
                'Value',         '.png' ...
                );
            app.ParametricFiguresDropDown.Row    = 3;
            app.ParametricFiguresDropDown.Column = 4;

            lab = CSSuiLabel(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'Text' , 'Spline Fits' ...
                );
            lab.Row    = 4;
            lab.Column = 3;

            app.SplineFiguresDropDown = CSSuiDropdown(app.FileFormatCheckBoxGrid, ...
                'Style','shadow', ...
                'DropdownWidth', '4.25em', ...
                'Items',         {'--', '.png', '.jpg', '.jpeg'}, ...
                'Value',         '.png' ...
                );
            app.SplineFiguresDropDown.Row    = 4;
            app.SplineFiguresDropDown.Column = 4;

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
            app.BottomGrid.ColumnWidth = {'1x', '2x', '1x'};
            app.BottomGrid.RowHeight = {'1x'};   % ~4 stacked buttons tall
            app.BottomGrid.ColumnSpacing = 0;
            app.BottomGrid.RowSpacing  = 0;
            app.BottomGrid.Layout.Row  = 2;
            app.BottomGrid.Layout.Column = 1;

            % ---- Column 1: Status text ----
            app.StatusTextGrid             = uigridlayout(app.BottomGrid);
            app.StatusTextGrid.ColumnWidth = {'1x'};
            app.StatusTextGrid.RowHeight = {'1x', '4x'};
            app.StatusTextGrid.ColumnSpacing = 0;
            app.StatusTextGrid.RowSpacing  = 0;
            app.StatusTextGrid.Padding     = [0 0 0 0];
            app.StatusTextGrid.Layout.Row  = 1;
            app.StatusTextGrid.Layout.Column = 1;

            app.StatusLabel = CSSuiLabel(app.StatusTextGrid, ...
                'Style', 'shadow', ...
                'FontSize', '13px', ...
                'Text', 'STATUS:' ...
                );
            app.StatusLabel.Layout.Row    = 1;
            app.StatusLabel.Layout.Column = 1;

            app.TextArea = CSSuiTextArea(app.StatusTextGrid, ...
                'Style', 'shadow', ...
                'Editable', false, ...
                'Color', '#414c57',...
                'FontWeight','600'...
                );
            app.TextArea.Row   = 2;
            app.TextArea.Column = 1;
            app.TextArea.Value = {'Add files, select settings, and press ''Run Batch'' to run'};

            % ---- Column 2: Run / Stop buttons ----
            buttonicon_size = '1.5em';

            app.RunBatchGrid             = uigridlayout(app.BottomGrid);
            app.RunBatchGrid.ColumnWidth = {'1x', '1x','1x', 500, '1x'};
            app.RunBatchGrid.RowHeight   = {'1x'};
            app.RunBatchGrid.ColumnSpacing = 0;
            app.RunBatchGrid.Padding = [0 0 0 0];
            app.RunBatchGrid.Layout.Row  = 1;
            app.RunBatchGrid.Layout.Column = 2;

            app.StopBatchButton = CSSuiButton(app.RunBatchGrid, ...
                'Style', 'shadow', ...
                'Shape','circle',...
                'Text', 'STOP', ...
                'MaxHeight', '100px',...
                'BackgroundColor', '#f5e8e9', ...
                'ButtonPushedFcn', createCallbackFcn(app, @StopBatchButtonPushed, true), ...
                'Icon', '<rect x="5" y="5" width="14" height="14"/>', ...
                'IconPosition', 'top', ...
                'IconSize',buttonicon_size, ...
                'Padding','10px',...
                'Height', '80%',...
                'Width', '80%',...
                'FontSize', '15px', ...
                'IconOnlyWidth', '80px',...
                'Enabled', false ...
                );
            app.StopBatchButton.Row    = 1;
            app.StopBatchButton.Column = 2;
            app.StopBatchButton.HTMLComponent.Tooltip = 'Stop batch run after completion of current file';

            app.RunBatchButton = CSSuiButton(app.RunBatchGrid, ...
                'Style', 'shadow', ...
                'Shape','circle',...
                'Text', 'RUN', ...
                'MaxHeight', '100px',...
                'ButtonPushedFcn', createCallbackFcn(app, @RunBatchButtonPushed, true), ...
                'Icon', '<path d="M8 5v14l11-7z"/>', ...
                'IconPosition', 'top', ...
                'IconSize',buttonicon_size, ...
                'BackgroundColor', '#e8f5e9', ...
                'Padding','10px',...
                'Height', '80%',...
                'Width', '80%',...
                'IconOnlyWidth', '80px',...
                'FontSize', '15px', ...
                'Enabled', true ...
                );
            app.RunBatchButton.Row    = 1;
            app.RunBatchButton.Column = 3;
            app.RunBatchButton.HTMLComponent.Tooltip = 'Batch run DYNAM-O';

            % Switches: 4-row inner grid, spacers on rows 1 & 4 push
            % the two switches to the vertical centre.
            % NOTE: 'fit' cannot be used with uihtml-based components —
            % explicit pixel heights are required instead.
            app.RunBatchOptionsGrid             = uigridlayout(app.RunBatchGrid);
            app.RunBatchOptionsGrid.ColumnWidth = {500};
            app.RunBatchOptionsGrid.RowHeight   = {'1x', '1x', '1x', '1x'};
            app.RunBatchOptionsGrid.RowSpacing  = 4;
            app.RunBatchOptionsGrid.Padding     = [10 0 10 0];
            app.RunBatchOptionsGrid.Layout.Row  = 1;
            app.RunBatchOptionsGrid.Layout.Column = 4;

            app.RunInReverse = CSSuiSwitch(app.RunBatchOptionsGrid, ...
                'Style','shadow', ...
                'Text', 'Reverse', ...
                'Enabled', true ...
                );
            app.RunInReverse.Row    = 2;
            app.RunInReverse.Column = 1;
            app.RunInReverse.HTMLComponent.Tooltip = 'Check to run through batch files from bottom to top. This is useful when running two instances of the manager in parallel on the same dataset';

            app.OverwriteExistingFilesCheckBox = CSSuiSwitch(app.RunBatchOptionsGrid, ...
                'Style','shadow', ...
                'Text', 'Overwrite', ...
                'Enabled', true ...
                );
            app.OverwriteExistingFilesCheckBox.Row    = 3;
            app.OverwriteExistingFilesCheckBox.Column = 1;
            app.OverwriteExistingFilesCheckBox.HTMLComponent.Tooltip = 'By default, output files will automatically be skipped if already generated. Check to overwrite all files.';

            % Progress bar occupies the right sub-column, full height
            app.TimeEstimateGrid             = uigridlayout(app.BottomGrid);
            app.TimeEstimateGrid.ColumnWidth = {'1x',100};
            app.TimeEstimateGrid.RowHeight   = {'1x'};
            app.TimeEstimateGrid.ColumnSpacing = 30;
            app.TimeEstimateGrid.Padding     = [5 5 5 5];
            app.TimeEstimateGrid.Layout.Row  = 1;
            app.TimeEstimateGrid.Layout.Column = 3;

            app.HelpButton = CSSuiButton(app.TimeEstimateGrid, ...
                'Style', 'shadow', ...
                'Text', 'Help', ...
                'Height', '60px',...
                'Icon', ['<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z' ...
                'M13 19h-2v-2h2v2z' ...
                'M15.07 11.25l-.9.92C13.45 12.9 13 13.5 13 15h-2v-.5c0-1.1.45-2.1 1.17-2.83' ...
                'l1.24-1.26c.37-.36.59-.86.59-1.41 0-1.1-.9-2-2-2s-2 .9-2 2H8' ...
                'c0-2.21 1.79-4 4-4s4 1.79 4 4c0 .88-.36 1.68-.93 2.25z"/>'],...
                'IconPosition','left',...
                'IconSize','1.5em',...
                'ButtonPushedFcn', @(src,event) showHelpButtonPushed(app) ...
                );
            app.HelpButton.Row    = 1;
            app.HelpButton.Column = 2;

            app.ProgressBar = SmoothProgressBar(app.TimeEstimateGrid);
            app.ProgressBar.N = 0;
            app.ProgressBar.BarHeight = .4;
            app.ProgressBar.refresh

            app.ProgressBar.Layout.Row = 1;
            app.ProgressBar.Layout.Column = 1;

            % ============================================================
            %   DYNAM-O SETTINGS (sub-app embedded in its tab)
            % ============================================================

            createDYNAMOSettingsTab(app);

            % ---- Help Menu (created last so it appears rightmost) ----
            app.HelpMenu      = uimenu(app.UIFigure);
            app.HelpMenu.Text = 'Help';

            app.HelpMenuItem = uimenu(app.HelpMenu);
            app.HelpMenuItem.MenuSelectedFcn = @(~,~) showHelpButtonPushed(app);
            app.HelpMenuItem.Text = 'Help';

            app.AboutMenu = uimenu(app.HelpMenu);
            app.AboutMenu.MenuSelectedFcn = createCallbackFcn(app, @AboutMenuSelected, true);
            app.AboutMenu.Text = 'About DYNAM-O...';
            app.AboutMenu.Separator = 'on';

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
            lblSkipped = CSSuiLabel(win,'Text','Skipped (missing) files:','Position',[20 360 200 20]); %#ok<*NASGU>
            listSkipped = uilistbox(win,'Items',cellstr(invalidLines),'Position',[20 180 360 180],'Multiselect','off');

            % Duplicate files listbox
            lblDup = CSSuiLabel(win,'Text','Duplicate files removed:','Position',[400 360 200 20]);
            listDup = uilistbox(win,'Items',cellstr(duplicateLines),'Position',[400 180 360 180],'Multiselect','off');

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
            CSSuiButton(d, ...
                'Text', 'Accept', ...
                'Position', [40 20 100 35], ...
                'ButtonPushedFcn', @(btn,event) acceptCallback());

            % Cancel button
            CSSuiButton(d, ...
                'Text', 'Cancel', ...
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

            app.run_error_list = {};  % Clear before re-validating

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

            if strcmpi(app.ChannelEditField.Value, 'Enter comma-separated channel labels') | isempty(app.ChannelEditField.Value)
                app.run_error_list(end+1) = {'- No channels selected.'};
            end

            % Check that every file in both lists actually exists on disk
            missing = {};
            allFiles = [app.DataList(:); app.StagingList(:)];
            for f = allFiles'
                if ~isfile(f{1}), missing{end+1} = f{1}; end %#ok<AGROW>
            end

            if ~isempty(missing)
                app.run_error_list{end+1} = sprintf('Missing files:\n%s', strjoin(missing, '\n'));
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

            % Build existence-check paths covering all possible saved formats
            stats_csv    = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                '/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.csv');
            stats_mat    = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                '/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.mat');
            SOPH_mat     = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                '/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat');
            SOPH_tiff    = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                '/SOPHs/',app.input_fbase,'_SOPHs_power_',app.channel,'.tiff');
            stats_exists = exist(stats_csv,'file') || exist(stats_mat,'file');
            SOPH_exists  = exist(SOPH_mat,'file')  || exist(SOPH_tiff,'file');

            % Run DYNAMO only if outputs are missing or overwrite is requested
            if app.OverwriteExistingFilesCheckBox.Value || ~stats_exists || ~SOPH_exists

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
                                '/SOPHs/',app.input_fbase,'_SOPHs_power_',app.channel,'.tiff');
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
                    app.stats_table = load(matPath,'stats_table').stats_table;
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
                switch app.DataSummaryDropDown.Value
                    case {'.jpg','.jpeg'}, fig_driver = '-djpeg';
                    otherwise,            fig_driver = '-dpng';
                end
                print(fh, fig_driver, '-r300', app.output_fig_name);
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
                app.anything_run = 1;
                app.output_param_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                    '/figures/param_basis/',app.input_fbase,'_param_basis_figure_', ...
                    app.channel, app.ParametricFiguresDropDown.Value);
                app.TextArea.Value = strcat('Saving parameter basis fit summary figure on subject ',{' '}, ...
                    app.input_fbase,', channel ',{' '},app.channel,'.');
                switch app.ParametricFiguresDropDown.Value
                    case {'.jpg','.jpeg'}, fig_driver = '-djpeg';
                    otherwise,            fig_driver = '-dpng';
                end
                print(fh, fig_driver, '-r300', app.output_param_name);
            end
            close all;

            % Save parametric fit data according to chosen format
            if ~strcmp(app.ParametricBasisDropDown.Value,'--')
                switch app.ParametricBasisDropDown.Value
                    case '.csv'
                        SOpower_params = app.SOPHs.SOpower_paramfit.params;
                        SOphase_params = app.SOPHs.SOphase_paramfit.params;
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
                        SOphase_paramfit = app.SOPHs.SOphase_paramfit;
                        app.output_paramfit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/param_basis/',app.input_fbase,'_SOpower_paramfit_',app.channel,'.mat');
                        app.output_paramfit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/param_basis/',app.input_fbase,'_SOphase_paramfit_',app.channel,'.mat');
                        save(app.output_paramfit_power_name,'SOpower_paramfit');
                        save(app.output_paramfit_phase_name,'SOphase_paramfit');
                    case 'All'
                        % Save both csv params and full mat structs
                        SOpower_params = app.SOPHs.SOpower_paramfit.params;
                        SOphase_params = app.SOPHs.SOphase_paramfit.params;
                        app.output_paramfit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/param_basis/',app.input_fbase,'_SOpower_paramfit_',app.channel,'.csv');
                        app.output_paramfit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel, ...
                            '/param_basis/',app.input_fbase,'_SOphase_paramfit_',app.channel,'.csv');
                        app.TextArea.Value = strcat('Updating saved SOPH on subject ',{' '}, ...
                            app.input_fbase,', channel ',{' '},app.channel,'.');
                        writematrix(SOpower_params, app.output_paramfit_power_name);
                        writematrix(SOphase_params, app.output_paramfit_phase_name);

                        SOpower_paramfit = app.SOPHs.SOpower_paramfit;
                        SOphase_paramfit = app.SOPHs.SOphase_paramfit;
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
                app.RunBatchButton.Enabled  = 'off';
                app.StopBatchButton.Enabled = 'on';
            else
                uialert(app.UIFigure, sprintf('%s\n', app.run_error_list{:}), ...
                    'Run Error', 'Icon', 'error');
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

        function AboutMenuSelected(app, ~, ~)
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

            app.TextArea.Value  = {'Beginning run...'};
            app.curr_datetime   = char(datetime('now','Format','yyMMdd_HHmmSS'));
            app.set_running;

            % Create required output subdirectories
            if ~exist(strcat(app.OutputDirEditField.Value,'/settings/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/settings/'))
            end
            if ~exist(strcat(app.OutputDirEditField.Value,'/logs/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/logs/'))
            end

            % Build DYNAMO options struct from current GUI settings
            app.TextArea.Value = {'Updating advanced options...'};
            drawnow;
            createOptionsStruct(app)

            % Initialise run and console logs
            app.TextArea.Value = {'Creating run log...'};
            drawnow;
            createRunLog(app)
            app.TextArea.Value = {'Creating console log...'};
            drawnow;
            createConsoleLog(app)

            % Parse channel list from edit field
            app.TextArea.Value = {'Processing channel inputs.'};
            updateChannelInput(app)
            drawnow;

            % Initialize the progress bar widget
            app.ProgressBar.N = length(app.DataList);
            app.ProgressBar.refresh;
            app.ProgressBar.start;

            % ---------------------------------------------------------------
            %   MAIN BATCH LOOP
            %   Outer: EDF files | Inner: channels
            % ---------------------------------------------------------------
            app.curr_iteration = 0;

            for jj = 1:length(app.DataList)

                for ii = 1:length(app.ChannelList)
                    app.channel = app.ChannelList{ii};

                    % Honor stop request before starting each new iteration
                    if app.isStopBatchButtonPushed == true
                        fclose(app.consolelog_fid);
                        diary off;
                        fclose(app.runlog_fid);
                        app.RunBatchButton.Enabled  = 'on';
                        app.StopBatchButton.Enabled = 'off';
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
                        drawnow;
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
                        drawnow;

                    catch e
                        % ---- Log error and continue to next iteration ----
                        app.TextArea.Value = strcat('Error on subject ',{' '},app.input_fbase, ...
                            ', channel ',{' '},app.channel,'. Check log for details.');
                        fprintf(app.runlog_fid, 'Subject %s, channel %s: not run. Error: %s\n', ...
                            app.input_fbase, app.channel, e.message);

                        app.set_rundefault;
                        app.ProgressBar.refresh;
                        drawnow;
                    end

                    % Update progress bar (wrapped in try-catch to avoid aborting on UI errors)
                    try
                        app.curr_iteration = app.curr_iteration + 1;
                        app.ProgressBar.updateIteration(app.curr_iteration);
                    catch e
                        disp(e);
                        app.set_rundefault;
                        fclose(app.consolelog_fid);
                        diary off;
                        fclose(app.runlog_fid);
                        app.RunBatchButton.Enabled  = 'on';
                        app.StopBatchButton.Enabled = 'off';
                        app.ProgressBar.refresh();
                        return;
                    end

                end % channel loop

            end % file loop

            % ---------------------------------------------------------------
            %   CLEANUP
            % ---------------------------------------------------------------
            app.ProgressBar.complete();
            fclose(app.consolelog_fid);
            diary off;
            fclose(app.runlog_fid);
            app.RunBatchButton.Enabled  = 'on';
            app.StopBatchButton.Enabled = 'off';

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
            % pos = app.UIFigure.Position;
            %
            % % Enforce minimum width
            % if pos(3) < app.MinWidth
            %     pos(3) = app.MinWidth;
            % end
            %
            % % Enforce minimum height
            % if pos(4) < app.MinHeight
            %     pos(4) = app.MinHeight;
            % end
            %
            % app.UIFigure.Position = pos;

            % 1. Cap the distance between the buttons
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
                    % disp('capping')
                end
            else
                % Otherwise, let all five be equal '1x'
                if ~isequal(g.ColumnWidth, {'1x', '1x', '1x', '1x', '1x'})
                    g.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
                end
            end
        end

        function set_running(app)
            app.RunBatchButton.Icon = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 135 140" fill="currentColor"><rect y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.5s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.5s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="30" y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.25s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.25s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="60" width="15" height="140" rx="6"><animate attributeName="height" begin="0s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="90" y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.25s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.25s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="120" y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.5s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.5s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect></svg>';
            app.RunBatchButton.Text = 'RUNNING';
            drawnow;
        end

        function set_rundefault(app)
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
    end % static methods
end % classdef
