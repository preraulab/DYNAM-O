classdef DYNAMOFileManager < matlab.apps.AppBase & DYNAMO
% Add documentation on how to open this GUI

    properties (Access = public)

        %% TO-DO: ORGANIZE AND COMMENT THIS LIST
        UIFigure                        matlab.ui.Figure
        FileMenu                        matlab.ui.container.Menu
        LoadEDFFileListMenu             matlab.ui.container.Menu
        LoadStagingFileListMenu         matlab.ui.container.Menu
        ProjectTabGroup                 matlab.ui.container.TabGroup
        DYNAMOSetupTab                  matlab.ui.container.Tab
        FullDYNAMOSetupGrid             matlab.ui.container.GridLayout
        TopTextGrid                     matlab.ui.container.GridLayout
        HelpButton                      matlab.ui.control.Button
        InstructionText                 matlab.ui.control.Label
        BottomGrid                      matlab.ui.container.GridLayout
        TimeEstimateGrid                matlab.ui.container.GridLayout
        RunBatchGrid                    matlab.ui.container.GridLayout
        RunBatchOptionsGrid             matlab.ui.container.GridLayout
        OverwriteExistingFilesCheckBox  matlab.ui.control.CheckBox
        RunInReverse                    matlab.ui.control.CheckBox
        RunBatchButton                  matlab.ui.control.Button
        StopBatchButton                 matlab.ui.control.Button
        StatusTextGrid                  matlab.ui.container.GridLayout
        StatusLabel                     matlab.ui.control.Label
        TextArea                        matlab.ui.control.TextArea
        BatchRunTabGroup                matlab.ui.container.TabGroup
        FileSelectionTab                matlab.ui.container.Tab
        FileSelectionGrid               matlab.ui.container.GridLayout
        RuntimeOptionsGrid              matlab.ui.container.GridLayout
        SavingOptionsTabGroup           matlab.ui.container.TabGroup
        SavingOptionsTab                matlab.ui.container.Tab
        SavingOptionsTabGrid            matlab.ui.container.GridLayout
        SavingDirectoryGrid             matlab.ui.container.GridLayout
        OutputDirEditField              matlab.ui.control.EditField
        EditFieldLabel                  matlab.ui.control.Label
        OutputDirButton                 matlab.ui.control.Button
        OutputDirLabel                  matlab.ui.control.Label
        SavingOptionsCheckBoxGrid       matlab.ui.container.GridLayout
        SaveSplineImagesCheckBox        matlab.ui.control.CheckBox
        SaveParamImagesCheckBox         matlab.ui.control.CheckBox
        SaveDataSummaryCheckBox         matlab.ui.control.CheckBox
        SaveAuxDataCheckBox             matlab.ui.control.CheckBox
        SaveSplineBasisCheckBox         matlab.ui.control.CheckBox
        SaveParamBasisCheckBox          matlab.ui.control.CheckBox
        SaveSOPHsCheckBox               matlab.ui.control.CheckBox
        SavePeakStatsCheckBox           matlab.ui.control.CheckBox
        FigurestoSaveLabel              matlab.ui.control.Label
        DatatoSaveLabel                 matlab.ui.control.Label
        AdvancedTab                     matlab.ui.container.Tab
        AdvancedTabGrid                 matlab.ui.container.GridLayout
        AdvancedCheckBoxGrid            matlab.ui.container.GridLayout
        SplineFiguresGrid               matlab.ui.container.GridLayout
        SplineFiguresDropDown           matlab.ui.control.DropDown
        SplineFiguresDropDownLabel      matlab.ui.control.Label
        ParametricFiguresGrid           matlab.ui.container.GridLayout
        ParametricFiguresDropDown       matlab.ui.control.DropDown
        ParametricFiguresDropDownLabel  matlab.ui.control.Label
        DataSummaryGrid                 matlab.ui.container.GridLayout
        DataSummaryDropDown             matlab.ui.control.DropDown
        DataSummaryDropDownLabel        matlab.ui.control.Label
        AuxiliaryDataGrid               matlab.ui.container.GridLayout
        AuxiliaryDataDropDown           matlab.ui.control.DropDown
        AuxiliaryDataDropDownLabel      matlab.ui.control.Label
        SplineBasisGrid                 matlab.ui.container.GridLayout
        SplineBasisDropDown             matlab.ui.control.DropDown
        SplineBasisDropDownLabel        matlab.ui.control.Label
        ParametricBasisGrid             matlab.ui.container.GridLayout
        ParametricBasisDropDown         matlab.ui.control.DropDown
        ParametricBasisDropDownLabel    matlab.ui.control.Label
        SOPowerHistogramsGrid           matlab.ui.container.GridLayout
        SOPowerHistogramsDropDown       matlab.ui.control.DropDown
        SOPowerHistogramsDropDownLabel  matlab.ui.control.Label
        PeakStatsTableGrid              matlab.ui.container.GridLayout
        PeakStatsTableDropDown          matlab.ui.control.DropDown
        PeakStatsTableDropDownLabel     matlab.ui.control.Label
        FigureFileFormatLabel           matlab.ui.control.Label
        DataFileFormatLabel             matlab.ui.control.Label
        StagingOptionsGrid              matlab.ui.container.GridLayout
        StagingOptionsLabel             matlab.ui.control.Label
        StagingOptionsPanelGrid         matlab.ui.container.GridLayout
        StagingOptionsPanelGridRight    matlab.ui.container.GridLayout
        StagingOptionsInstructions      matlab.ui.control.Label
        StagingOptionsGridRightTop      matlab.ui.container.GridLayout
        DelimeterOptionField            matlab.ui.control.DropDown
        FileDelimiterDropDownLabel      matlab.ui.control.Label
        HeaderRowsEditField             matlab.ui.control.NumericEditField
        HeaderRowsEditFieldLabel        matlab.ui.control.Label
        TimesColumnEditField            matlab.ui.control.NumericEditField
        TimesColumnEditFieldLabel       matlab.ui.control.Label
        StagesColumnEditField           matlab.ui.control.NumericEditField
        StagesColumnEditFieldLabel      matlab.ui.control.Label
        StagingOptionsPanelGridLeft     matlab.ui.container.GridLayout
        UnknownEditField                matlab.ui.control.EditField
        UnknownEditFieldLabel           matlab.ui.control.Label
        N3EditField                     matlab.ui.control.EditField
        N3EditFieldLabel                matlab.ui.control.Label
        N2EditField                     matlab.ui.control.EditField
        N2EditFieldLabel                matlab.ui.control.Label
        N1EditField                     matlab.ui.control.EditField
        N1EditFieldLabel                matlab.ui.control.Label
        REMEditField                    matlab.ui.control.EditField
        REMEditFieldLabel               matlab.ui.control.Label
        WakeEditField                   matlab.ui.control.EditField
        WakeEditFieldLabel              matlab.ui.control.Label
        ArtifactEditField               matlab.ui.control.EditField
        ArtifactEditFieldLabel          matlab.ui.control.Label
        RuntimeOptionsTopGrid           matlab.ui.container.GridLayout
        ChannelOptionsGrid              matlab.ui.container.GridLayout
        ChannelOptionsInstructionsLabel  matlab.ui.control.Label
        RuntimeOptionsLabel             matlab.ui.control.Label
        ChannelInputGrid                matlab.ui.container.GridLayout
        ChannelEditField               matlab.ui.control.EditField
        ChannelEditFieldLabel          matlab.ui.control.Label
        FileInputGrid                   matlab.ui.container.GridLayout
        StagingFileTopGrid              matlab.ui.container.GridLayout
        StagingFileTitleGrid            matlab.ui.container.GridLayout
        StagingLabel                    matlab.ui.control.Label
        StagingFileInstructionText      matlab.ui.control.Label
        DataFileTopGrid                 matlab.ui.container.GridLayout
        DataFileTitleGrid               matlab.ui.container.GridLayout
        DataLabel                  matlab.ui.control.Label
        ViewChannelsButton              matlab.ui.control.Button
        DataFileInstructionText         matlab.ui.control.Label
        StagingListBox                  matlab.ui.control.ListBox
        DataListBox                     matlab.ui.control.ListBox
        StagingFileButtonGrid           matlab.ui.container.GridLayout
        StagingMoveDownButton           matlab.ui.control.Button
        StagingMoveUpBotton             matlab.ui.control.Button
        StagingRemoveButton             matlab.ui.control.Button
        StagingAddFolderButton          matlab.ui.control.Button
        StagingAddFileButton            matlab.ui.control.Button
        DataFileButtonGrid              matlab.ui.container.GridLayout
        DataMoveDownButton              matlab.ui.control.Button
        DataMoveUpButton                matlab.ui.control.Button
        DataRemoveButton                matlab.ui.control.Button
        DataAddFolderButton             matlab.ui.control.Button
        DataAddFileButton               matlab.ui.control.Button
        DYNAMOSettingsTab               matlab.ui.container.Tab
        DYNAMOSettingsGrid              matlab.ui.container.GridLayout
        AnalysisTab                     matlab.ui.container.Tab

        % Callback handles
        BatchProcessCallback    function_handle
        FileValidationCallback  function_handle

    end

    properties (Access = private)

        % File storing
        DataList cell = {}
        StagingList cell = {}

        % File names
        input_fbase = ''
        output_fig_name = ''
        output_stats_name = ''
        output_SOPH_name = ''
        output_aux_name = ''
        output_paramfit_power_name = ''
        output_paramfit_phase_name = ''
        output_splinefit_power_name = ''
        output_splinefit_phase_name = ''
        output_param_name = ''
        output_spline_name = ''
        date_time_save = ''
        icon_filepath = strrep(which('DYNAMOFileManager'),'DYNAMOFileManager.m','icons/')

        % Header fig
        header_fig
        uitable_header
        uitable_signal

        % User inputs
        channel
        ChannelList

        ArtifactUserInput
        N1UserInput
        N2UserInput
        N3UserInput
        REMUserInput
        WakeUserInput
        UnknownUserInput

        delimeter

        % Misc for saving
        options_structs
        struct_names
        auxiliary_data

        % Misc for internal processing
        run_error_list = {};
        isStopBatchButtonPushed = false
        anything_run
        ypos
        curr_datetime
        curr_iteration

        % Output logs info
        runlog_fname
        runlog_fpath
        runlog_fid
        consolelog_fname
        consolelog_fpath
        consolelog_fid

        % Misc UI
        progress_bar % progress bar

        % UI dimensions
        WindowWidth = 1400
        WindowHeight = 850
        PanelMargin = 20
        PanelMarginVertical = 50
        PanelMarginHorizontal = 20
        ButtonHeight = 30
        ButtonWidth
    end

    methods (Access = public)

        function app = DYNAMOFileManager(varargin)
            p = inputParser;
            addParameter(p,'BatchCallback',[],@(x) isempty(x)||isa(x,'function_handle'));
            addParameter(p,'ValidationCallback',[],@(x) isempty(x)||isa(x,'function_handle'));
            addParameter(p,'Title','DYNAM-O Toolbox',@ischar);
            addParameter(p,'Position',[],@isnumeric);
            parse(p,varargin{:});

            if ~isempty(p.Results.BatchCallback), app.BatchProcessCallback = p.Results.BatchCallback; end
            if ~isempty(p.Results.ValidationCallback), app.FileValidationCallback = p.Results.ValidationCallback; end

            createComponents(app,p.Results.Title,p.Results.Position);

        end

        function addDataFiles(app, filePaths)
            if ~iscell(filePaths), filePaths={filePaths}; end
            app.DataList = [app.DataList, filePaths];
            updateDataListBox(app);
        end

        function addStagingFiles(app, filePaths)
            if ~iscell(filePaths), filePaths={filePaths}; end
            app.StagingList = [app.StagingList, filePaths];
            updateStagingListBox(app);
        end

        function [dataFiles, stagingFiles] = getFileLists(app)
            dataFiles = app.DataList;
            stagingFiles = app.StagingList;
        end

        function clearAllLists(app)
            app.DataList = {};
            app.StagingList = {};
            updateDataListBox(app);
            updateStagingListBox(app);
        end

        function setEnabled(app, enabled)
            app.UIFigure.Visible = matlab.lang.OnOffSwitchState(enabled);
        end
    end

    methods (Access = private)

        function createComponents(app,~,~)

            %% TO-DO: ORGANIZE AND COMMENT THESE INTO SECTIONS FOR EASE

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [260 115 1400 850];
            app.UIFigure.Name = 'DYNAM-O File Manager';

            % Create FileMenu
            app.FileMenu = uimenu(app.UIFigure);
            app.FileMenu.Text = 'File';

            % Create LoadEDFFileListMenu
            app.LoadEDFFileListMenu = uimenu(app.FileMenu);
            app.LoadEDFFileListMenu.Text = 'Load EDF File List...';

            % Create LoadStagingFileListMenu
            app.LoadStagingFileListMenu = uimenu(app.FileMenu);
            app.LoadStagingFileListMenu.Text = 'Load Staging File List...';

            % Create ProjectTabGroup
            app.ProjectTabGroup = uitabgroup(app.UIFigure);
            app.ProjectTabGroup.Position = [1 1 1400 850];

            % Create DYNAMOSetupTab
            app.DYNAMOSetupTab = uitab(app.ProjectTabGroup);
            app.DYNAMOSetupTab.Title = 'DYNAM-O Set-up';

            % Create FullDYNAMOSetupGrid
            app.FullDYNAMOSetupGrid = uigridlayout(app.DYNAMOSetupTab);
            app.FullDYNAMOSetupGrid.ColumnWidth = {'2.97x'};
            app.FullDYNAMOSetupGrid.RowHeight = {'1x', '20x', '3x'};
            app.FullDYNAMOSetupGrid.RowSpacing = 0;

            % Create BatchRunTabGroup
            app.BatchRunTabGroup = uitabgroup(app.FullDYNAMOSetupGrid);
            app.BatchRunTabGroup.Layout.Row = 2;
            app.BatchRunTabGroup.Layout.Column = 1;

            % Create FileSelectionTab
            app.FileSelectionTab = uitab(app.BatchRunTabGroup);
            app.FileSelectionTab.Title = 'File Selection';

            % Create FileSelectionGrid
            app.FileSelectionGrid = uigridlayout(app.FileSelectionTab);
            app.FileSelectionGrid.ColumnWidth = {'2x', '1x'};
            app.FileSelectionGrid.RowHeight = {'1x'};

            % Create FileInputGrid
            app.FileInputGrid = uigridlayout(app.FileSelectionGrid);
            app.FileInputGrid.RowHeight = {'3x', '20x', '2x'};
            app.FileInputGrid.RowSpacing = 0;
            app.FileInputGrid.Padding = [10 0 10 0];
            app.FileInputGrid.Layout.Row = 1;
            app.FileInputGrid.Layout.Column = 1;

            % Create DataFileButtonGrid
            app.DataFileButtonGrid = uigridlayout(app.FileInputGrid);
            app.DataFileButtonGrid.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
            app.DataFileButtonGrid.RowHeight = {'1x'};
            app.DataFileButtonGrid.ColumnSpacing = 5;
            app.DataFileButtonGrid.Padding = [60 0 60 6];
            app.DataFileButtonGrid.Layout.Row = 3;
            app.DataFileButtonGrid.Layout.Column = 1;

            % Create DataAddFileButton
            app.DataAddFileButton = uibutton(app.DataFileButtonGrid, 'push');
            app.DataAddFileButton.ButtonPushedFcn = createCallbackFcn(app, @DataAddFileButtonPushed, true);
            app.DataAddFileButton.Icon = strcat(app.icon_filepath, 'add_file.png');
            app.DataAddFileButton.IconAlignment = 'center';
            app.DataAddFileButton.Layout.Row = 1;
            app.DataAddFileButton.Layout.Column = 1;
            app.DataAddFileButton.Text = '';

            % Create DataAddFolderButton
            app.DataAddFolderButton = uibutton(app.DataFileButtonGrid, 'push');
            app.DataAddFolderButton.ButtonPushedFcn = createCallbackFcn(app, @DataAddFolderButtonPushed, true);
            app.DataAddFolderButton.Icon = strcat(app.icon_filepath, 'add_folder.png');
            app.DataAddFolderButton.IconAlignment = 'center';
            app.DataAddFolderButton.Layout.Row = 1;
            app.DataAddFolderButton.Layout.Column = 2;
            app.DataAddFolderButton.Text = '';

            % Create DataRemoveButton
            app.DataRemoveButton = uibutton(app.DataFileButtonGrid, 'push');
            app.DataRemoveButton.ButtonPushedFcn = createCallbackFcn(app, @DataRemoveButtonPushed, true);
            app.DataRemoveButton.Icon = strcat(app.icon_filepath, 'garbage.png');
            app.DataRemoveButton.IconAlignment = 'center';
            app.DataRemoveButton.Layout.Row = 1;
            app.DataRemoveButton.Layout.Column = 3;
            app.DataRemoveButton.Text = '';

            % Create DataMoveUpButton
            app.DataMoveUpButton = uibutton(app.DataFileButtonGrid, 'push');
            app.DataMoveUpButton.ButtonPushedFcn = createCallbackFcn(app, @DataMoveUpButtonPushed, true);
            app.DataMoveUpButton.Icon = strcat(app.icon_filepath, 'up_arrow.png');
            app.DataMoveUpButton.IconAlignment = 'center';
            app.DataMoveUpButton.Layout.Row = 1;
            app.DataMoveUpButton.Layout.Column = 4;
            app.DataMoveUpButton.Text = '';

            % Create DataMoveDownButton
            app.DataMoveDownButton = uibutton(app.DataFileButtonGrid, 'push');
            app.DataMoveDownButton.ButtonPushedFcn = createCallbackFcn(app, @DataMoveDownButtonPushed, true);
            app.DataMoveDownButton.Icon = strcat(app.icon_filepath, 'down_arrow.png');
            app.DataMoveDownButton.IconAlignment = 'center';
            app.DataMoveDownButton.Layout.Row = 1;
            app.DataMoveDownButton.Layout.Column = 5;
            app.DataMoveDownButton.Text = '';

            % Create StagingFileButtonGrid
            app.StagingFileButtonGrid = uigridlayout(app.FileInputGrid);
            app.StagingFileButtonGrid.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
            app.StagingFileButtonGrid.RowHeight = {'1x'};
            app.StagingFileButtonGrid.ColumnSpacing = 5;
            app.StagingFileButtonGrid.Padding = [60 0 60 6];
            app.StagingFileButtonGrid.Layout.Row = 3;
            app.StagingFileButtonGrid.Layout.Column = 2;

            % Create StagingAddFileButton
            app.StagingAddFileButton = uibutton(app.StagingFileButtonGrid, 'push');
            app.StagingAddFileButton.ButtonPushedFcn = createCallbackFcn(app, @StagingAddFileButtonPushed, true);
            app.StagingAddFileButton.Icon = strcat(app.icon_filepath, 'add_file.png');
            app.StagingAddFileButton.IconAlignment = 'center';
            app.StagingAddFileButton.Layout.Row = 1;
            app.StagingAddFileButton.Layout.Column = 1;
            app.StagingAddFileButton.Text = '';

            % Create StagingAddFolderButton
            app.StagingAddFolderButton = uibutton(app.StagingFileButtonGrid, 'push');
            app.StagingAddFolderButton.ButtonPushedFcn = createCallbackFcn(app, @StagingAddFolderButtonPushed, true);
            app.StagingAddFolderButton.Icon = strcat(app.icon_filepath, 'add_folder.png');
            app.StagingAddFolderButton.IconAlignment = 'center';
            app.StagingAddFolderButton.Layout.Row = 1;
            app.StagingAddFolderButton.Layout.Column = 2;
            app.StagingAddFolderButton.Text = '';

            % Create StagingRemoveButton
            app.StagingRemoveButton = uibutton(app.StagingFileButtonGrid, 'push');
            app.StagingRemoveButton.ButtonPushedFcn = createCallbackFcn(app, @StagingRemoveButtonPushed, true);
            app.StagingRemoveButton.Icon = strcat(app.icon_filepath, 'garbage.png');
            app.StagingRemoveButton.IconAlignment = 'center';
            app.StagingRemoveButton.Layout.Row = 1;
            app.StagingRemoveButton.Layout.Column = 3;
            app.StagingRemoveButton.Text = '';

            % Create StagingMoveUpBotton
            app.StagingMoveUpBotton = uibutton(app.StagingFileButtonGrid, 'push');
            app.StagingMoveUpBotton.ButtonPushedFcn = createCallbackFcn(app, @StagingMoveUpButtonPushed, true);
            app.StagingMoveUpBotton.Icon = strcat(app.icon_filepath, 'up_arrow.png');
            app.StagingMoveUpBotton.IconAlignment = 'center';
            app.StagingMoveUpBotton.Layout.Row = 1;
            app.StagingMoveUpBotton.Layout.Column = 4;
            app.StagingMoveUpBotton.Text = '';

            % Create StagingMoveDownButton
            app.StagingMoveDownButton = uibutton(app.StagingFileButtonGrid, 'push');
            app.StagingMoveDownButton.ButtonPushedFcn = createCallbackFcn(app, @StagingMoveDownButtonPushed, true);
            app.StagingMoveDownButton.Icon = strcat(app.icon_filepath, 'down_arrow.png');
            app.StagingMoveDownButton.IconAlignment = 'center';
            app.StagingMoveDownButton.Layout.Row = 1;
            app.StagingMoveDownButton.Layout.Column = 5;
            app.StagingMoveDownButton.Text = '';

            % Create DataListBox
            app.DataListBox = uilistbox(app.FileInputGrid);
            app.DataListBox.Items = {''};
            app.DataListBox.Multiselect = 'on';
            app.DataListBox.Layout.Row = 2;
            app.DataListBox.Layout.Column = 1;
            app.DataListBox.DoubleClickedFcn = createCallbackFcn(app, @ShowHeader, true);
            app.DataListBox.Value = {''};

            % Create StagingListBox
            app.StagingListBox = uilistbox(app.FileInputGrid);
            app.StagingListBox.Items = {''};
            app.StagingListBox.Multiselect = 'on';
            app.StagingListBox.Layout.Row = 2;
            app.StagingListBox.Layout.Column = 2;
            app.StagingListBox.Value = {''};

            % Create DataFileTopGrid
            app.DataFileTopGrid = uigridlayout(app.FileInputGrid);
            app.DataFileTopGrid.ColumnWidth = {'1x'};
            app.DataFileTopGrid.RowHeight = {'2x', '1x'};
            app.DataFileTopGrid.ColumnSpacing = 0;
            app.DataFileTopGrid.RowSpacing = 0;
            app.DataFileTopGrid.Padding = [0 0 0 0];
            app.DataFileTopGrid.Layout.Row = 1;
            app.DataFileTopGrid.Layout.Column = 1;

            % Create DataFileInstructionText
            app.DataFileInstructionText = uilabel(app.DataFileTopGrid);
            app.DataFileInstructionText.FontSize = 13;
            app.DataFileInstructionText.FontAngle = 'italic';
            app.DataFileInstructionText.Layout.Row = 2;
            app.DataFileInstructionText.Layout.Column = 1;
            app.DataFileInstructionText.Text = 'Add your PSG data files (EDF format). Use buttons to remove/reorder.';

            % Create DataFileTitleGrid
            app.DataFileTitleGrid = uigridlayout(app.DataFileTopGrid);
            app.DataFileTitleGrid.ColumnWidth = {'2x', '5x', '2x'};
            app.DataFileTitleGrid.RowHeight = {'1x'};
            app.DataFileTitleGrid.Padding = [0 12 0 12];
            app.DataFileTitleGrid.Layout.Row = 1;
            app.DataFileTitleGrid.Layout.Column = 1;

            % Create DataLabel
            app.DataLabel = uilabel(app.DataFileTitleGrid);
            app.DataLabel.HorizontalAlignment = 'center';
            app.DataLabel.FontWeight = 'bold';
            app.DataLabel.Layout.Row = 1;
            app.DataLabel.Layout.Column = 2;
            app.DataLabel.FontSize = 15;
            app.DataLabel.Text = 'Data (0 Files)';

            % Create StagingFileTopGrid
            app.StagingFileTopGrid = uigridlayout(app.FileInputGrid);
            app.StagingFileTopGrid.ColumnWidth = {'1x'};
            app.StagingFileTopGrid.RowHeight = {'2x', '1x'};
            app.StagingFileTopGrid.ColumnSpacing = 0;
            app.StagingFileTopGrid.RowSpacing = 0;
            app.StagingFileTopGrid.Padding = [0 0 0 0];
            app.StagingFileTopGrid.Layout.Row = 1;
            app.StagingFileTopGrid.Layout.Column = 2;

            % Create StagingFileInstructionText
            app.StagingFileInstructionText = uilabel(app.StagingFileTopGrid);
            app.StagingFileInstructionText.FontSize = 13;
            app.StagingFileInstructionText.FontAngle = 'italic';
            app.StagingFileInstructionText.Layout.Row = 2;
            app.StagingFileInstructionText.Layout.Column = 1;
            app.StagingFileInstructionText.Text = 'Add staging files (CSV/TXT). Ensure order matches data files.';

            % Create StagingFileTitleGrid
            app.StagingFileTitleGrid = uigridlayout(app.StagingFileTopGrid);
            app.StagingFileTitleGrid.ColumnWidth = {'2x', '5x', '2x'};
            app.StagingFileTitleGrid.RowHeight = {'1x'};
            app.StagingFileTitleGrid.Padding = [0 12 0 12];
            app.StagingFileTitleGrid.Layout.Row = 1;
            app.StagingFileTitleGrid.Layout.Column = 1;

            % Create StagingLabel
            app.StagingLabel = uilabel(app.StagingFileTitleGrid);
            app.StagingLabel.HorizontalAlignment = 'center';
            app.StagingLabel.FontWeight = 'bold';
            app.StagingLabel.Layout.Row = 1;
            app.StagingLabel.Layout.Column = 2;
            app.StagingLabel.FontSize = 15;
            app.StagingLabel.Text = 'Staging (0 Files)';

            % Create RuntimeOptionsGrid
            app.RuntimeOptionsGrid = uigridlayout(app.FileSelectionGrid);
            app.RuntimeOptionsGrid.ColumnWidth = {'1x'};
            app.RuntimeOptionsGrid.RowHeight = {'1x', '2.2x', '2.2x'};
            app.RuntimeOptionsGrid.ColumnSpacing = 0;
            app.RuntimeOptionsGrid.RowSpacing = 0;
            app.RuntimeOptionsGrid.Padding = [0 0 0 0];
            app.RuntimeOptionsGrid.Layout.Row = 1;
            app.RuntimeOptionsGrid.Layout.Column = 2;

            % Create RuntimeOptionsTopGrid
            app.RuntimeOptionsTopGrid = uigridlayout(app.RuntimeOptionsGrid);
            app.RuntimeOptionsTopGrid.ColumnWidth = {'1x'};
            app.RuntimeOptionsTopGrid.RowHeight = {'4x', '2x', '2x', '1x'};
            app.RuntimeOptionsTopGrid.ColumnSpacing = 0;
            app.RuntimeOptionsTopGrid.RowSpacing = 0;
            app.RuntimeOptionsTopGrid.Padding = [0 0 0 0];
            app.RuntimeOptionsTopGrid.Layout.Row = 1;
            app.RuntimeOptionsTopGrid.Layout.Column = 1;

            % Create ChannelInputGrid
            app.ChannelInputGrid = uigridlayout(app.RuntimeOptionsTopGrid);
            app.ChannelInputGrid.ColumnWidth = {'1x', '3x', '12x', '2x', '1x'};
            app.ChannelInputGrid.RowHeight = {'1x'};
            app.ChannelInputGrid.Padding = [0 0 0 0];
            app.ChannelInputGrid.Layout.Row = 3;
            app.ChannelInputGrid.Layout.Column = 1;

            % Create ChannelEditFieldLabel
            app.ChannelEditFieldLabel = uilabel(app.ChannelInputGrid);
            app.ChannelEditFieldLabel.HorizontalAlignment = 'right';
            app.ChannelEditFieldLabel.Layout.Row = 1;
            app.ChannelEditFieldLabel.Layout.Column = 2;
            app.ChannelEditFieldLabel.Text = 'Channel(s):';

            % Create ChannelEditField
            app.ChannelEditField = uieditfield(app.ChannelInputGrid, 'text');
            app.ChannelEditField.Layout.Row = 1;
            app.ChannelEditField.Layout.Column = 3;

            % Create ViewChannelsButton
            app.ViewChannelsButton = uibutton(app.ChannelInputGrid, 'push');
            app.ViewChannelsButton.ButtonPushedFcn = createCallbackFcn(app, @viewChannelsButtonPushed, true);
            app.ViewChannelsButton.Icon = 'info';
            app.ViewChannelsButton.IconAlignment = 'center';
            app.ViewChannelsButton.Layout.Row = 1;
            app.ViewChannelsButton.Layout.Column = 4;
            app.ViewChannelsButton.Text = '';

            % Create RuntimeOptionsLabel
            app.RuntimeOptionsLabel = uilabel(app.RuntimeOptionsTopGrid);
            app.RuntimeOptionsLabel.HorizontalAlignment = 'center';
            app.RuntimeOptionsLabel.FontWeight = 'bold';
            app.RuntimeOptionsLabel.Layout.Row = 1;
            app.RuntimeOptionsLabel.Layout.Column = 1;
            app.RuntimeOptionsLabel.FontSize = 15;
            app.RuntimeOptionsLabel.Text = 'Runtime Options';

            % Create ChannelOptionsGrid
            app.ChannelOptionsGrid = uigridlayout(app.RuntimeOptionsTopGrid);
            app.ChannelOptionsGrid.ColumnWidth = {'1x', '4x'};
            app.ChannelOptionsGrid.RowHeight = {'1x'};
            app.ChannelOptionsGrid.Padding = [0 0 0 0];
            app.ChannelOptionsGrid.Layout.Row = 2;
            app.ChannelOptionsGrid.Layout.Column = 1;

            % Create ChannelOptionsInstructionsLabel
            app.ChannelOptionsInstructionsLabel = uilabel(app.ChannelOptionsGrid);
            app.ChannelOptionsInstructionsLabel.VerticalAlignment = 'bottom';
            app.ChannelOptionsInstructionsLabel.FontSize = 13;
            app.ChannelOptionsInstructionsLabel.FontAngle = 'italic';
            app.ChannelOptionsInstructionsLabel.Layout.Row = 1;
            app.ChannelOptionsInstructionsLabel.Layout.Column = 2;
            app.ChannelOptionsInstructionsLabel.Text = 'Enter a comma-separated list of channels to be run.';

            % Create StagingOptionsGrid
            app.StagingOptionsGrid = uigridlayout(app.RuntimeOptionsGrid);
            app.StagingOptionsGrid.ColumnWidth = {'1x'};
            app.StagingOptionsGrid.RowHeight = {'1x', '10x'};
            app.StagingOptionsGrid.ColumnSpacing = 0;
            app.StagingOptionsGrid.RowSpacing = 0;
            app.StagingOptionsGrid.Padding = [0 0 0 0];
            app.StagingOptionsGrid.Layout.Row = 2;
            app.StagingOptionsGrid.Layout.Column = 1;

            % Create StagingOptionsPanelGrid
            app.StagingOptionsPanelGrid = uigridlayout(app.StagingOptionsGrid);
            app.StagingOptionsPanelGrid.RowHeight = {'1x'};
            app.StagingOptionsPanelGrid.ColumnSpacing = 20;
            app.StagingOptionsPanelGrid.RowSpacing = 0;
            app.StagingOptionsPanelGrid.Padding = [0 0 0 0];
            app.StagingOptionsPanelGrid.Layout.Row = 2;
            app.StagingOptionsPanelGrid.Layout.Column = 1;

            % Create StagingOptionsPanelGridLeft
            app.StagingOptionsPanelGridLeft = uigridlayout(app.StagingOptionsPanelGrid);
            app.StagingOptionsPanelGridLeft.ColumnWidth = {'4x', '5x'};
            app.StagingOptionsPanelGridLeft.RowHeight = {'1x', '1x', '1x', '1x', '1x', '1x', '1x'};
            app.StagingOptionsPanelGridLeft.Padding = [0 10 10 10];
            app.StagingOptionsPanelGridLeft.Layout.Row = 1;
            app.StagingOptionsPanelGridLeft.Layout.Column = 1;

            % Create ArtifactEditFieldLabel
            app.ArtifactEditFieldLabel = uilabel(app.StagingOptionsPanelGridLeft);
            app.ArtifactEditFieldLabel.HorizontalAlignment = 'right';
            app.ArtifactEditFieldLabel.Layout.Row = 1;
            app.ArtifactEditFieldLabel.Layout.Column = 1;
            app.ArtifactEditFieldLabel.Text = 'Artifact';

            % Create ArtifactEditField
            app.ArtifactEditField = uieditfield(app.StagingOptionsPanelGridLeft, 'text');
            app.ArtifactEditField.Layout.Row = 1;
            app.ArtifactEditField.Layout.Column = 2;
            app.ArtifactEditField.Value = 'art, artifact, A, 6';

            % Create WakeEditFieldLabel
            app.WakeEditFieldLabel = uilabel(app.StagingOptionsPanelGridLeft);
            app.WakeEditFieldLabel.HorizontalAlignment = 'right';
            app.WakeEditFieldLabel.Layout.Row = 2;
            app.WakeEditFieldLabel.Layout.Column = 1;
            app.WakeEditFieldLabel.Text = 'Wake';

            % Create WakeEditField
            app.WakeEditField = uieditfield(app.StagingOptionsPanelGridLeft, 'text');
            app.WakeEditField.Layout.Row = 2;
            app.WakeEditField.Layout.Column = 2;
            app.WakeEditField.Value = 'wake, W, 5';

            % Create REMEditFieldLabel
            app.REMEditFieldLabel = uilabel(app.StagingOptionsPanelGridLeft);
            app.REMEditFieldLabel.HorizontalAlignment = 'right';
            app.REMEditFieldLabel.Layout.Row = 3;
            app.REMEditFieldLabel.Layout.Column = 1;
            app.REMEditFieldLabel.Text = 'REM';

            % Create REMEditField
            app.REMEditField = uieditfield(app.StagingOptionsPanelGridLeft, 'text');
            app.REMEditField.Layout.Row = 3;
            app.REMEditField.Layout.Column = 2;
            app.REMEditField.Value = 'REM, R, 4';

            % Create N1EditFieldLabel
            app.N1EditFieldLabel = uilabel(app.StagingOptionsPanelGridLeft);
            app.N1EditFieldLabel.HorizontalAlignment = 'right';
            app.N1EditFieldLabel.Layout.Row = 4;
            app.N1EditFieldLabel.Layout.Column = 1;
            app.N1EditFieldLabel.Text = 'N1';

            % Create N1EditField
            app.N1EditField = uieditfield(app.StagingOptionsPanelGridLeft, 'text');
            app.N1EditField.Layout.Row = 4;
            app.N1EditField.Layout.Column = 2;
            app.N1EditField.Value = 'N1, Stage 1, 1';

            % Create N2EditFieldLabel
            app.N2EditFieldLabel = uilabel(app.StagingOptionsPanelGridLeft);
            app.N2EditFieldLabel.HorizontalAlignment = 'right';
            app.N2EditFieldLabel.Layout.Row = 5;
            app.N2EditFieldLabel.Layout.Column = 1;
            app.N2EditFieldLabel.Text = 'N2';

            % Create N2EditField
            app.N2EditField = uieditfield(app.StagingOptionsPanelGridLeft, 'text');
            app.N2EditField.Layout.Row = 5;
            app.N2EditField.Layout.Column = 2;
            app.N2EditField.Value = 'N2, Stage 2, 2';

            % Create N3EditFieldLabel
            app.N3EditFieldLabel = uilabel(app.StagingOptionsPanelGridLeft);
            app.N3EditFieldLabel.HorizontalAlignment = 'right';
            app.N3EditFieldLabel.Layout.Row = 6;
            app.N3EditFieldLabel.Layout.Column = 1;
            app.N3EditFieldLabel.Text = 'N3';

            % Create N3EditField
            app.N3EditField = uieditfield(app.StagingOptionsPanelGridLeft, 'text');
            app.N3EditField.Layout.Row = 6;
            app.N3EditField.Layout.Column = 2;
            app.N3EditField.Value = 'N3, Stage 3, 3';

            % Create UnknownEditFieldLabel
            app.UnknownEditFieldLabel = uilabel(app.StagingOptionsPanelGridLeft);
            app.UnknownEditFieldLabel.HorizontalAlignment = 'right';
            app.UnknownEditFieldLabel.Layout.Row = 7;
            app.UnknownEditFieldLabel.Layout.Column = 1;
            app.UnknownEditFieldLabel.Text = 'Unknown';

            % Create UnknownEditField
            app.UnknownEditField = uieditfield(app.StagingOptionsPanelGridLeft, 'text');
            app.UnknownEditField.Layout.Row = 7;
            app.UnknownEditField.Layout.Column = 2;
            app.UnknownEditField.Value = 'Unk, U, Unknown';

            % Create StagingOptionsPanelGridRight
            app.StagingOptionsPanelGridRight = uigridlayout(app.StagingOptionsPanelGrid);
            app.StagingOptionsPanelGridRight.ColumnWidth = {'1x'};
            app.StagingOptionsPanelGridRight.RowHeight = {'5x', '2x'};
            app.StagingOptionsPanelGridRight.ColumnSpacing = 0;
            app.StagingOptionsPanelGridRight.RowSpacing = 0;
            app.StagingOptionsPanelGridRight.Padding = [0 0 0 0];
            app.StagingOptionsPanelGridRight.Layout.Row = 1;
            app.StagingOptionsPanelGridRight.Layout.Column = 2;

            % Create StagingOptionsGridRightTop
            app.StagingOptionsGridRightTop = uigridlayout(app.StagingOptionsPanelGridRight);
            app.StagingOptionsGridRightTop.ColumnWidth = {'4x', '5x'};
            app.StagingOptionsGridRightTop.RowHeight = {'1x', '1x', '1x', '1x', '1x'};
            app.StagingOptionsGridRightTop.Padding = [0 10 10 10];
            app.StagingOptionsGridRightTop.Layout.Row = 1;
            app.StagingOptionsGridRightTop.Layout.Column = 1;

            % Create StagesColumnEditFieldLabel
            app.StagesColumnEditFieldLabel = uilabel(app.StagingOptionsGridRightTop);
            app.StagesColumnEditFieldLabel.HorizontalAlignment = 'right';
            app.StagesColumnEditFieldLabel.Layout.Row = 3;
            app.StagesColumnEditFieldLabel.Layout.Column = 1;
            app.StagesColumnEditFieldLabel.Text = 'Stages Column';

            % Create StagesColumnEditField
            app.StagesColumnEditField = uieditfield(app.StagingOptionsGridRightTop, 'numeric');
            app.StagesColumnEditField.Limits = [0 Inf];
            app.StagesColumnEditField.RoundFractionalValues = 'on';
            app.StagesColumnEditField.AllowEmpty = 'on';
            app.StagesColumnEditField.Layout.Row = 3;
            app.StagesColumnEditField.Layout.Column = 2;
            app.StagesColumnEditField.Value = [];

            % Create TimesColumnEditFieldLabel
            app.TimesColumnEditFieldLabel = uilabel(app.StagingOptionsGridRightTop);
            app.TimesColumnEditFieldLabel.HorizontalAlignment = 'right';
            app.TimesColumnEditFieldLabel.Layout.Row = 4;
            app.TimesColumnEditFieldLabel.Layout.Column = 1;
            app.TimesColumnEditFieldLabel.Text = 'Times Column';

            % Create TimesColumnEditField
            app.TimesColumnEditField = uieditfield(app.StagingOptionsGridRightTop, 'numeric');
            app.TimesColumnEditField.Limits = [0 Inf];
            app.TimesColumnEditField.RoundFractionalValues = 'on';
            app.TimesColumnEditField.AllowEmpty = 'on';
            app.TimesColumnEditField.Layout.Row = 4;
            app.TimesColumnEditField.Layout.Column = 2;
            app.TimesColumnEditField.Value = [];

            % Create HeaderRowsEditFieldLabel
            app.HeaderRowsEditFieldLabel = uilabel(app.StagingOptionsGridRightTop);
            app.HeaderRowsEditFieldLabel.HorizontalAlignment = 'right';
            app.HeaderRowsEditFieldLabel.Layout.Row = 5;
            app.HeaderRowsEditFieldLabel.Layout.Column = 1;
            app.HeaderRowsEditFieldLabel.Text = 'Header Rows';

            % Create HeaderRowsEditField
            app.HeaderRowsEditField = uieditfield(app.StagingOptionsGridRightTop, 'numeric');
            app.HeaderRowsEditField.Limits = [0 Inf];
            app.HeaderRowsEditField.RoundFractionalValues = 'on';
            app.HeaderRowsEditField.AllowEmpty = 'on';
            app.HeaderRowsEditField.Layout.Row = 5;
            app.HeaderRowsEditField.Layout.Column = 2;
            app.HeaderRowsEditField.Value = [];

            % Create FileDelimiterDropDownLabel
            app.FileDelimiterDropDownLabel = uilabel(app.StagingOptionsGridRightTop);
            app.FileDelimiterDropDownLabel.HorizontalAlignment = 'right';
            app.FileDelimiterDropDownLabel.Layout.Row = 1;
            app.FileDelimiterDropDownLabel.Layout.Column = 1;
            app.FileDelimiterDropDownLabel.Text = 'File Delimiter';

            % Create DelimeterOptionField
            app.DelimeterOptionField = uidropdown(app.StagingOptionsGridRightTop);
            app.DelimeterOptionField.Items = {'Comma', 'Tab', 'Space', 'Semicolon'};
            app.DelimeterOptionField.Layout.Row = 1;
            app.DelimeterOptionField.Layout.Column = 2;
            app.DelimeterOptionField.Value = 'Comma';

            % Create StagingOptionsInstructions
            app.StagingOptionsInstructions = uilabel(app.StagingOptionsPanelGridRight);
            app.StagingOptionsInstructions.HorizontalAlignment = 'center';
            app.StagingOptionsInstructions.WordWrap = 'on';
            app.StagingOptionsInstructions.FontSize = 13;
            app.StagingOptionsInstructions.FontAngle = 'italic';
            app.StagingOptionsInstructions.Layout.Row = 2;
            app.StagingOptionsInstructions.Layout.Column = 1;
            app.StagingOptionsInstructions.Text = 'Stages should be comma separated lists of all valid stage identifiers in the scoring/annotations file.';

            % Create StagingOptionsLabel
            app.StagingOptionsLabel = uilabel(app.StagingOptionsGrid);
            app.StagingOptionsLabel.Layout.Row = 1;
            app.StagingOptionsLabel.Layout.Column = 1;
            app.StagingOptionsLabel.Text = 'Staging Options';

            % Create SavingOptionsTabGroup
            app.SavingOptionsTabGroup = uitabgroup(app.RuntimeOptionsGrid);
            app.SavingOptionsTabGroup.Layout.Row = 3;
            app.SavingOptionsTabGroup.Layout.Column = 1;

            % Create SavingOptionsTab
            app.SavingOptionsTab = uitab(app.SavingOptionsTabGroup);
            app.SavingOptionsTab.Title = 'Saving Options';

            % Create SavingOptionsTabGrid
            app.SavingOptionsTabGrid = uigridlayout(app.SavingOptionsTab);
            app.SavingOptionsTabGrid.ColumnWidth = {'1x'};
            app.SavingOptionsTabGrid.RowHeight = {'4x', '1x'};
            app.SavingOptionsTabGrid.RowSpacing = 0;
            app.SavingOptionsTabGrid.Padding = [10 0 10 2];

            % Create SavingOptionsCheckBoxGrid
            app.SavingOptionsCheckBoxGrid = uigridlayout(app.SavingOptionsTabGrid);
            app.SavingOptionsCheckBoxGrid.RowHeight = {'1x', '1x', '1x', '1x', '1x', '1x'};
            app.SavingOptionsCheckBoxGrid.Padding = [3 10 3 10];
            app.SavingOptionsCheckBoxGrid.Layout.Row = 1;
            app.SavingOptionsCheckBoxGrid.Layout.Column = 1;

            % Create DatatoSaveLabel
            app.DatatoSaveLabel = uilabel(app.SavingOptionsCheckBoxGrid);
            app.DatatoSaveLabel.Layout.Row = 1;
            app.DatatoSaveLabel.Layout.Column = 1;
            app.DatatoSaveLabel.FontWeight = 'bold';
            app.DatatoSaveLabel.Text = 'Data to Save';

            % Create FigurestoSaveLabel
            app.FigurestoSaveLabel = uilabel(app.SavingOptionsCheckBoxGrid);
            app.FigurestoSaveLabel.Layout.Row = 1;
            app.FigurestoSaveLabel.Layout.Column = 2;
            app.FigurestoSaveLabel.FontWeight = 'bold';
            app.FigurestoSaveLabel.Text = 'Figures to Save';

            % Create SavePeakStatsCheckBox
            app.SavePeakStatsCheckBox = uicheckbox(app.SavingOptionsCheckBoxGrid);
            app.SavePeakStatsCheckBox.Text = 'Peak Stats Tables';
            app.SavePeakStatsCheckBox.Layout.Row = 2;
            app.SavePeakStatsCheckBox.Layout.Column = 1;

            % Create SaveSOPHsCheckBox
            app.SaveSOPHsCheckBox = uicheckbox(app.SavingOptionsCheckBoxGrid);
            app.SaveSOPHsCheckBox.Text = 'SO-Power Histogram';
            app.SaveSOPHsCheckBox.Layout.Row = 3;
            app.SaveSOPHsCheckBox.Layout.Column = 1;

            % Create SaveParamBasisCheckBox
            app.SaveParamBasisCheckBox = uicheckbox(app.SavingOptionsCheckBoxGrid);
            app.SaveParamBasisCheckBox.Text = 'Parametric Basis';
            app.SaveParamBasisCheckBox.Layout.Row = 4;
            app.SaveParamBasisCheckBox.Layout.Column = 1;

            % Create SaveSplineBasisCheckBox
            app.SaveSplineBasisCheckBox = uicheckbox(app.SavingOptionsCheckBoxGrid);
            app.SaveSplineBasisCheckBox.Text = 'Spline Basis';
            app.SaveSplineBasisCheckBox.Layout.Row = 5;
            app.SaveSplineBasisCheckBox.Layout.Column = 1;

            % Create SaveAuxDataCheckBox
            app.SaveAuxDataCheckBox = uicheckbox(app.SavingOptionsCheckBoxGrid);
            app.SaveAuxDataCheckBox.Text = 'Auxiliary Data';
            app.SaveAuxDataCheckBox.Layout.Row = 6;
            app.SaveAuxDataCheckBox.Layout.Column = 1;

            % Create SaveDataSummaryCheckBox
            app.SaveDataSummaryCheckBox = uicheckbox(app.SavingOptionsCheckBoxGrid);
            app.SaveDataSummaryCheckBox.Text = 'Data Summary Figures';
            app.SaveDataSummaryCheckBox.Layout.Row = 2;
            app.SaveDataSummaryCheckBox.Layout.Column = 2;

            % Create SaveParamImagesCheckBox
            app.SaveParamImagesCheckBox = uicheckbox(app.SavingOptionsCheckBoxGrid);
            app.SaveParamImagesCheckBox.Text = 'Parametric Basis Figures';
            app.SaveParamImagesCheckBox.Layout.Row = 3;
            app.SaveParamImagesCheckBox.Layout.Column = 2;

            % Create SaveSplineImagesCheckBox
            app.SaveSplineImagesCheckBox = uicheckbox(app.SavingOptionsCheckBoxGrid);
            app.SaveSplineImagesCheckBox.Text = 'Spline Basis Figures';
            app.SaveSplineImagesCheckBox.Layout.Row = 4;
            app.SaveSplineImagesCheckBox.Layout.Column = 2;

            % Create SavingDirectoryGrid
            app.SavingDirectoryGrid = uigridlayout(app.SavingOptionsTabGrid);
            app.SavingDirectoryGrid.ColumnWidth = {'5x', '1x'};
            app.SavingDirectoryGrid.RowHeight = {'2x', '3x'};
            app.SavingDirectoryGrid.RowSpacing = 0;
            app.SavingDirectoryGrid.Padding = [5 5 10 1];
            app.SavingDirectoryGrid.Layout.Row = 2;
            app.SavingDirectoryGrid.Layout.Column = 1;

            % Create OutputDirLabel
            app.OutputDirLabel = uilabel(app.SavingDirectoryGrid);
            app.OutputDirLabel.FontSize = 13;
            app.OutputDirLabel.FontAngle = 'italic';
            app.OutputDirLabel.Layout.Row = 1;
            app.OutputDirLabel.Layout.Column = 1;
            app.OutputDirLabel.Text = ' Select output directory and choose what to save.';

            % Create OutputDirButton
            app.OutputDirButton = uibutton(app.SavingDirectoryGrid, 'push','ButtonPushedFcn',@(src,event) browseOutputDir(app));
            app.OutputDirButton.Layout.Row = 2;
            app.OutputDirButton.Layout.Column = 2;
            app.OutputDirButton.Text = 'Browse';

            % Create EditFieldLabel
            app.EditFieldLabel = uilabel(app.SavingDirectoryGrid);
            app.EditFieldLabel.HorizontalAlignment = 'right';
            app.EditFieldLabel.Layout.Row = 2;
            app.EditFieldLabel.Layout.Column = 1;
            app.EditFieldLabel.Text = 'Edit Field';

            % Create OutputDirEditField
            app.OutputDirEditField = uieditfield(app.SavingDirectoryGrid, 'text');
            app.OutputDirEditField.Layout.Row = 2;
            app.OutputDirEditField.Layout.Column = 1;

            % Create AdvancedTab
            app.AdvancedTab = uitab(app.SavingOptionsTabGroup);
            app.AdvancedTab.Title = 'Advanced';

            % Create AdvancedTabGrid
            app.AdvancedTabGrid = uigridlayout(app.AdvancedTab);
            app.AdvancedTabGrid.ColumnWidth = {'1x'};
            app.AdvancedTabGrid.RowHeight = {'4x', '1x'};

            % Create AdvancedCheckBoxGrid
            app.AdvancedCheckBoxGrid = uigridlayout(app.AdvancedTabGrid);
            app.AdvancedCheckBoxGrid.RowHeight = {'1x', '1x', '1x', '1x', '1x', '1x'};
            app.AdvancedCheckBoxGrid.Padding = [0 10 0 10];
            app.AdvancedCheckBoxGrid.Layout.Row = 1;
            app.AdvancedCheckBoxGrid.Layout.Column = 1;

            % Create DataFileFormatLabel
            app.DataFileFormatLabel = uilabel(app.AdvancedCheckBoxGrid);
            app.DataFileFormatLabel.Layout.Row = 1;
            app.DataFileFormatLabel.Layout.Column = 1;
            app.DataFileFormatLabel.Text = 'Data File Format';

            % Create FigureFileFormatLabel
            app.FigureFileFormatLabel = uilabel(app.AdvancedCheckBoxGrid);
            app.FigureFileFormatLabel.Layout.Row = 1;
            app.FigureFileFormatLabel.Layout.Column = 2;
            app.FigureFileFormatLabel.Text = 'Figure File Format';

            % Create PeakStatsTableGrid
            app.PeakStatsTableGrid = uigridlayout(app.AdvancedCheckBoxGrid);
            app.PeakStatsTableGrid.ColumnWidth = {'2.3x', '1x'};
            app.PeakStatsTableGrid.RowHeight = {'1x'};
            app.PeakStatsTableGrid.ColumnSpacing = 0;
            app.PeakStatsTableGrid.Padding = [0 0 0 0];
            app.PeakStatsTableGrid.Layout.Row = 2;
            app.PeakStatsTableGrid.Layout.Column = 1;

            % Create PeakStatsTableDropDownLabel
            app.PeakStatsTableDropDownLabel = uilabel(app.PeakStatsTableGrid);
            app.PeakStatsTableDropDownLabel.Layout.Row = 1;
            app.PeakStatsTableDropDownLabel.Layout.Column = 1;
            app.PeakStatsTableDropDownLabel.Text = 'Peak Stats Table';

            % Create PeakStatsTableDropDown
            app.PeakStatsTableDropDown = uidropdown(app.PeakStatsTableGrid);
            app.PeakStatsTableDropDown.Items = {'--', '.csv', '.mat', 'All'};
            app.PeakStatsTableDropDown.Layout.Row = 1;
            app.PeakStatsTableDropDown.Layout.Column = 2;
            app.PeakStatsTableDropDown.Value = '.csv';

            % Create SOPowerHistogramsGrid
            app.SOPowerHistogramsGrid = uigridlayout(app.AdvancedCheckBoxGrid);
            app.SOPowerHistogramsGrid.ColumnWidth = {'2.3x', '1x'};
            app.SOPowerHistogramsGrid.RowHeight = {'1x'};
            app.SOPowerHistogramsGrid.ColumnSpacing = 0;
            app.SOPowerHistogramsGrid.Padding = [0 0 0 0];
            app.SOPowerHistogramsGrid.Layout.Row = 3;
            app.SOPowerHistogramsGrid.Layout.Column = 1;

            % Create SOPowerHistogramsDropDownLabel
            app.SOPowerHistogramsDropDownLabel = uilabel(app.SOPowerHistogramsGrid);
            app.SOPowerHistogramsDropDownLabel.Layout.Row = 1;
            app.SOPowerHistogramsDropDownLabel.Layout.Column = 1;
            app.SOPowerHistogramsDropDownLabel.Text = 'SO-Power Histograms';

            % Create SOPowerHistogramsDropDown
            app.SOPowerHistogramsDropDown = uidropdown(app.SOPowerHistogramsGrid);
            app.SOPowerHistogramsDropDown.Items = {'--', '.tiff', '.mat', 'All'};
            app.SOPowerHistogramsDropDown.Layout.Row = 1;
            app.SOPowerHistogramsDropDown.Layout.Column = 2;
            app.SOPowerHistogramsDropDown.Value = '.tiff';

            % Create ParametricBasisGrid
            app.ParametricBasisGrid = uigridlayout(app.AdvancedCheckBoxGrid);
            app.ParametricBasisGrid.ColumnWidth = {'2.3x', '1x'};
            app.ParametricBasisGrid.RowHeight = {'1.5x'};
            app.ParametricBasisGrid.ColumnSpacing = 0;
            app.ParametricBasisGrid.Padding = [0 0 0 0];
            app.ParametricBasisGrid.Layout.Row = 4;
            app.ParametricBasisGrid.Layout.Column = 1;

            % Create ParametricBasisDropDownLabel
            app.ParametricBasisDropDownLabel = uilabel(app.ParametricBasisGrid);
            app.ParametricBasisDropDownLabel.Layout.Row = 1;
            app.ParametricBasisDropDownLabel.Layout.Column = 1;
            app.ParametricBasisDropDownLabel.Text = 'Parametric Basis';

            % Create ParametricBasisDropDown
            app.ParametricBasisDropDown = uidropdown(app.ParametricBasisGrid);
            app.ParametricBasisDropDown.Items = {'--', '.csv', '.mat', 'All'};
            app.ParametricBasisDropDown.Layout.Row = 1;
            app.ParametricBasisDropDown.Layout.Column = 2;
            app.ParametricBasisDropDown.Value = '.csv';

            % Create SplineBasisGrid
            app.SplineBasisGrid = uigridlayout(app.AdvancedCheckBoxGrid);
            app.SplineBasisGrid.ColumnWidth = {'2.3x', '1x'};
            app.SplineBasisGrid.RowHeight = {'1x'};
            app.SplineBasisGrid.ColumnSpacing = 0;
            app.SplineBasisGrid.Padding = [0 0 0 0];
            app.SplineBasisGrid.Layout.Row = 5;
            app.SplineBasisGrid.Layout.Column = 1;

            % Create SplineBasisDropDownLabel
            app.SplineBasisDropDownLabel = uilabel(app.SplineBasisGrid);
            app.SplineBasisDropDownLabel.Layout.Row = 1;
            app.SplineBasisDropDownLabel.Layout.Column = 1;
            app.SplineBasisDropDownLabel.Text = 'Spline Basis';

            % Create SplineBasisDropDown
            app.SplineBasisDropDown = uidropdown(app.SplineBasisGrid);
            app.SplineBasisDropDown.Items = {'--', '.tiff', '.mat', 'All'};
            app.SplineBasisDropDown.Layout.Row = 1;
            app.SplineBasisDropDown.Layout.Column = 2;
            app.SplineBasisDropDown.Value = '.mat';

            % Create AuxiliaryDataGrid
            app.AuxiliaryDataGrid = uigridlayout(app.AdvancedCheckBoxGrid);
            app.AuxiliaryDataGrid.ColumnWidth = {'2.3x', '1x'};
            app.AuxiliaryDataGrid.RowHeight = {'1x'};
            app.AuxiliaryDataGrid.ColumnSpacing = 0;
            app.AuxiliaryDataGrid.Padding = [0 0 0 0];
            app.AuxiliaryDataGrid.Layout.Row = 6;
            app.AuxiliaryDataGrid.Layout.Column = 1;

            % Create AuxiliaryDataDropDownLabel
            app.AuxiliaryDataDropDownLabel = uilabel(app.AuxiliaryDataGrid);
            app.AuxiliaryDataDropDownLabel.Layout.Row = 1;
            app.AuxiliaryDataDropDownLabel.Layout.Column = 1;
            app.AuxiliaryDataDropDownLabel.Text = 'Auxiliary Data';

            % Create AuxiliaryDataDropDown
            app.AuxiliaryDataDropDown = uidropdown(app.AuxiliaryDataGrid);
            app.AuxiliaryDataDropDown.Items = {'.mat', '--'};
            app.AuxiliaryDataDropDown.Layout.Row = 1;
            app.AuxiliaryDataDropDown.Layout.Column = 2;
            app.AuxiliaryDataDropDown.Value = '.mat';

            % Create DataSummaryGrid
            app.DataSummaryGrid = uigridlayout(app.AdvancedCheckBoxGrid);
            app.DataSummaryGrid.ColumnWidth = {'2.2x', '1x'};
            app.DataSummaryGrid.RowHeight = {'1x'};
            app.DataSummaryGrid.ColumnSpacing = 0;
            app.DataSummaryGrid.Padding = [0 0 0 0];
            app.DataSummaryGrid.Layout.Row = 2;
            app.DataSummaryGrid.Layout.Column = 2;

            % Create DataSummaryDropDownLabel
            app.DataSummaryDropDownLabel = uilabel(app.DataSummaryGrid);
            app.DataSummaryDropDownLabel.Layout.Row = 1;
            app.DataSummaryDropDownLabel.Layout.Column = 1;
            app.DataSummaryDropDownLabel.Text = 'Data Summary';

            % Create DataSummaryDropDown
            app.DataSummaryDropDown = uidropdown(app.DataSummaryGrid);
            app.DataSummaryDropDown.Items = {'--', '.png', '.jpg', '.jpeg'};
            app.DataSummaryDropDown.Layout.Row = 1;
            app.DataSummaryDropDown.Layout.Column = 2;
            app.DataSummaryDropDown.Value = '.png';

            % Create ParametricFiguresGrid
            app.ParametricFiguresGrid = uigridlayout(app.AdvancedCheckBoxGrid);
            app.ParametricFiguresGrid.ColumnWidth = {'2.2x', '1x'};
            app.ParametricFiguresGrid.RowHeight = {'1x'};
            app.ParametricFiguresGrid.ColumnSpacing = 0;
            app.ParametricFiguresGrid.Padding = [0 0 0 0];
            app.ParametricFiguresGrid.Layout.Row = 3;
            app.ParametricFiguresGrid.Layout.Column = 2;

            % Create ParametricFiguresDropDownLabel
            app.ParametricFiguresDropDownLabel = uilabel(app.ParametricFiguresGrid);
            app.ParametricFiguresDropDownLabel.Layout.Row = 1;
            app.ParametricFiguresDropDownLabel.Layout.Column = 1;
            app.ParametricFiguresDropDownLabel.Text = 'Parametric Figures';

            % Create ParametricFiguresDropDown
            app.ParametricFiguresDropDown = uidropdown(app.ParametricFiguresGrid);
            app.ParametricFiguresDropDown.Items = {'--', '.png', '.jpg', '.jpeg'};
            app.ParametricFiguresDropDown.Layout.Row = 1;
            app.ParametricFiguresDropDown.Layout.Column = 2;
            app.ParametricFiguresDropDown.Value = '.png';

            % Create SplineFiguresGrid
            app.SplineFiguresGrid = uigridlayout(app.AdvancedCheckBoxGrid);
            app.SplineFiguresGrid.ColumnWidth = {'2.2x', '1x'};
            app.SplineFiguresGrid.RowHeight = {'1x'};
            app.SplineFiguresGrid.ColumnSpacing = 0;
            app.SplineFiguresGrid.Padding = [0 0 0 0];
            app.SplineFiguresGrid.Layout.Row = 4;
            app.SplineFiguresGrid.Layout.Column = 2;

            % Create SplineFiguresDropDownLabel
            app.SplineFiguresDropDownLabel = uilabel(app.SplineFiguresGrid);
            app.SplineFiguresDropDownLabel.Layout.Row = 1;
            app.SplineFiguresDropDownLabel.Layout.Column = 1;
            app.SplineFiguresDropDownLabel.Text = 'Spline Figures';

            % Create SplineFiguresDropDown
            app.SplineFiguresDropDown = uidropdown(app.SplineFiguresGrid);
            app.SplineFiguresDropDown.Items = {'--', '.png', '.jpg', '.jpeg'};
            app.SplineFiguresDropDown.Layout.Row = 1;
            app.SplineFiguresDropDown.Layout.Column = 2;
            app.SplineFiguresDropDown.Value = '.png';

            % Create DYNAMOSettingsTab
            app.DYNAMOSettingsTab = uitab(app.BatchRunTabGroup);
            app.DYNAMOSettingsTab.Title = 'DYNAM-O Settings';

            % Create DYNAMOSettingsGrid
            app.DYNAMOSettingsGrid = uigridlayout(app.DYNAMOSettingsTab);
            app.DYNAMOSettingsGrid.ColumnWidth = {'1x'};
            app.DYNAMOSettingsGrid.RowHeight = {'1x'};
            app.DYNAMOSettingsGrid.Padding = [1 1 1 1];

            % Create BottomGrid
            app.BottomGrid = uigridlayout(app.FullDYNAMOSetupGrid);
            app.BottomGrid.ColumnWidth = {'2x', '3x', '2x'};
            app.BottomGrid.RowHeight = {'1x'};
            app.BottomGrid.Layout.Row = 3;
            app.BottomGrid.Layout.Column = 1;

            % Create StatusTextGrid
            app.StatusTextGrid = uigridlayout(app.BottomGrid);
            app.StatusTextGrid.ColumnWidth = {'1x'};
            app.StatusTextGrid.RowHeight = {'1x', '3x'};
            app.StatusTextGrid.ColumnSpacing = 0;
            app.StatusTextGrid.RowSpacing = 0;
            app.StatusTextGrid.Padding = [0 0 80 0];
            app.StatusTextGrid.Layout.Row = 1;
            app.StatusTextGrid.Layout.Column = 1;

            % Create TextArea
            app.TextArea = uitextarea(app.StatusTextGrid);
            app.TextArea.Editable = 'off';
            app.TextArea.Layout.Row = 2;
            app.TextArea.Layout.Column = 1;
            app.TextArea.Value = {'Add files, select settings, and press ''Run Batch'' to run'};

            % Create StatusLabel
            app.StatusLabel = uilabel(app.StatusTextGrid);
            app.StatusLabel.FontSize = 13;
            app.StatusLabel.Layout.Row = 1;
            app.StatusLabel.Layout.Column = 1;
            app.StatusLabel.Text = 'Status:';

            % Create RunBatchGrid
            app.RunBatchGrid = uigridlayout(app.BottomGrid);
            app.RunBatchGrid.ColumnWidth = {'1x', '2x', '3x'};
            app.RunBatchGrid.RowHeight = {'1x'};
            app.RunBatchGrid.ColumnSpacing = 30;
            app.RunBatchGrid.Padding = [80 15 60 15];
            app.RunBatchGrid.Layout.Row = 1;
            app.RunBatchGrid.Layout.Column = 2;

            % Create StopBatchButton
            app.StopBatchButton = uibutton(app.RunBatchGrid, 'push');
            app.StopBatchButton.ButtonPushedFcn = createCallbackFcn(app, @StopBatchButtonPushed, true);
            app.StopBatchButton.Icon = strcat(app.icon_filepath, 'stop.png');
            app.StopBatchButton.IconAlignment = 'center';
            app.StopBatchButton.Layout.Row = 1;
            app.StopBatchButton.Layout.Column = 1;
            app.StopBatchButton.Text = '';

            % Create RunBatchButton
            app.RunBatchButton = uibutton(app.RunBatchGrid, 'push');
            app.RunBatchButton.ButtonPushedFcn = createCallbackFcn(app, @RunBatchButtonPushed, true);
            app.RunBatchButton.FontSize = 15;
            app.RunBatchButton.FontWeight = 'bold';
            app.RunBatchButton.Layout.Row = 1;
            app.RunBatchButton.Layout.Column = 2;
            app.RunBatchButton.Text = 'Run Batch';

            % Create RunBatchOptionsGrid
            app.RunBatchOptionsGrid = uigridlayout(app.RunBatchGrid);
            app.RunBatchOptionsGrid.ColumnWidth = {'1x'};
            app.RunBatchOptionsGrid.Padding = [0 0 0 0];
            app.RunBatchOptionsGrid.Layout.Row = 1;
            app.RunBatchOptionsGrid.Layout.Column = 3;

            % Create RunInReverse
            app.RunInReverse = uicheckbox(app.RunBatchOptionsGrid);
            app.RunInReverse.Text = 'Run in Reverse';
            app.RunInReverse.FontSize = 14;
            app.RunInReverse.Layout.Row = 1;
            app.RunInReverse.Layout.Column = 1;

            % Create OverwriteExistingFilesCheckBox
            app.OverwriteExistingFilesCheckBox = uicheckbox(app.RunBatchOptionsGrid);
            app.OverwriteExistingFilesCheckBox.Text = 'Overwrite Existing Files';
            app.OverwriteExistingFilesCheckBox.FontSize = 14;
            app.OverwriteExistingFilesCheckBox.Layout.Row = 2;
            app.OverwriteExistingFilesCheckBox.Layout.Column = 1;

            % Create TimeEstimateGrid
            app.TimeEstimateGrid = uigridlayout(app.BottomGrid);
            app.TimeEstimateGrid.RowHeight = {'1x'};
            app.TimeEstimateGrid.Layout.Row = 1;
            app.TimeEstimateGrid.Layout.Column = 3;

            % Create TopTextGrid
            app.TopTextGrid = uigridlayout(app.FullDYNAMOSetupGrid);
            app.TopTextGrid.ColumnWidth = {'1x', '9x', '1x'};
            app.TopTextGrid.RowHeight = {'1x'};
            app.TopTextGrid.ColumnSpacing = 50;
            app.TopTextGrid.Padding = [20 5 20 5];
            app.TopTextGrid.Layout.Row = 1;
            app.TopTextGrid.Layout.Column = 1;

            % Create InstructionText
            app.InstructionText = uilabel(app.TopTextGrid);
            app.InstructionText.HorizontalAlignment = 'center';
            app.InstructionText.FontSize = 13;
            app.InstructionText.FontWeight = 'bold';
            app.InstructionText.Layout.Row = 1;
            app.InstructionText.Layout.Column = 2;
            app.InstructionText.Text = 'Add data and staging files, select output directory, choose options, then run batch.';

            % Create HelpButton
            app.HelpButton = uibutton(app.TopTextGrid, 'push','ButtonPushedFcn',@(src,event) showHelpButtonPushed(app));
            %app.HelpButton.ButtonPushedFcn = createCallbackFcn(app, @showHelpButtonPushed, true);
            app.HelpButton.Layout.Row = 1;
            app.HelpButton.Layout.Column = 3;
            app.HelpButton.Text = 'Help';

            % Create AnalysisTab
            app.AnalysisTab = uitab(app.ProjectTabGroup);
            app.AnalysisTab.Title = 'Analysis';

            % Create DYNAMOSettingsTab
            createDYNAMOSettingsTab(app);

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';

        end
        
        function createDYNAMOSettingsTab(app)
            app.DYNAMOOptionsApp(false, app.UIFigure, app.DYNAMOSettingsGrid, false);
        end
        
        %% ================== BUTTON CALLBACKS ==================
        function showHelpButtonPushed(app)

            uialert(app.UIFigure,sprintf('Instructions:\n1. In File Selection tab: Add Data files (EDF) and Staging files (CSV/TXT).\n2. Make sure the file counts match and order corresponds.\n3. In Output Options tab: Choose an output directory and select save options.\n4. Click Run Batch to process files.'),'Help','Icon','info');

        end
        
        function loadFileListCallback(app,varargin)
            % uialert(app.UIFigure, 'Load EDF File List Selected.', 'Load');

            %Have the user select the base directory
            [filename, filepath] = uigetfile( ...
                {'*.txt;*.csv;*.tsv;*.dat;*.lst', 'Text Files (*.txt, *.csv, *.tsv, *.dat, *.lst)'; ...
                '*.*', 'All Files (*.*)'}, ...
                'Select EDF File Path/Name List');

            if filename==0
                return;
            end

            %Grab all files recursively from the base directory
            temp = fileread([filepath,filename]);
            app.DataList = regexp(temp, '\r\n|\r|\n', 'split');
            app.updateDataListBox;

        end

        function loadStagingListCallback(app,varargin)
            % uialert(app.UIFigure, 'Load EDF File List Selected.', 'Load');

            %Have the user select the base directory
            [filename, filepath] = uigetfile( ...
                {'*.txt;*.csv;*.tsv;*.dat;*.lst', 'Text Files (*.txt, *.csv, *.tsv, *.dat, *.lst)'; ...
                '*.*', 'All Files (*.*)'}, ...
                'Select Stage File Path/Name List');

            if filename==0
                return;
            end

            %Grab all files recursively from the base directory
            temp = fileread([filepath,filename]);
            app.StagingList = regexp(temp, '\r\n|\r|\n', 'split');
            app.updateStagingListBox;

        end

        function DataAddFileButtonPushed(app,~,~)
            files = selectFiles(app,'Select Data Files','data');
            if ~isempty(files)
                app.DataList = [app.DataList, files];
                updateDataListBox(app);
            end
        end

        function DataAddFolderButtonPushed(app,~,~)
            folder = uigetdir(pwd,'Select Data Folder');
            if folder == 0
                return;
            end

            S = dir(strcat(folder,'/*.edf'));
            files = strcat({S.folder},'/',{S.name});
            if ~isempty(files)
                app.DataList = [app.DataList, files];
                updateDataListBox(app);
            end
        end

        function DataRemoveButtonPushed(app,~,~)
            selected = app.DataListBox.Value;
            if isempty(selected), return; end
            app.DataList = setdiff(app.DataList,selected,'stable');
            updateDataListBox(app);
        end

        function DataMoveUpButtonPushed(app,~,~)
            moveListItems(app,'data','up');
        end

        function DataMoveDownButtonPushed(app,~,~)
            moveListItems(app,'data','down');
        end

        function StagingAddFileButtonPushed(app,~,~)
            files = selectFiles(app,'Select Staging Files','staging');
            if ~isempty(files)
                app.StagingList = [app.StagingList, files];
                updateStagingListBox(app);
            end
        end

        function StagingAddFolderButtonPushed(app,~,~)
            folder = uigetdir(pwd,'Select Staging Folder');

            if folder == 0
                return;
            end

            S = dir(strcat(folder,'/*.csv'));
            if size(S,1)==0
                S = dir(strcat(folder,'/*.txt'));
            end
            files = strcat({S.folder},'/',{S.name});
            if ~isempty(files)
                app.StagingList = [app.StagingList, files];
                updateStagingListBox(app);
            end
        end

        function StagingRemoveButtonPushed(app,~,~)
            selected = app.StagingListBox.Value;
            if isempty(selected), return; end
            app.StagingList = setdiff(app.StagingList,selected,'stable');
            updateStagingListBox(app);
        end

        function StagingMoveUpButtonPushed(app,~,~)
            moveListItems(app,'staging','up');
        end

        function StagingMoveDownButtonPushed(app,~,~)
            moveListItems(app,'staging','down');
        end
        
        function viewChannelsButtonPushed(app,~,~)
            %app.viewChannelText = {};
            %app.run_error_list(end+1) = {'- Data list empty. Need edf files to run.'}
            %app.channel_counts = cell(2,1);
            for ii = 1:length(app.DataList)
                [~,signalHeader] = read_EDF(app.DataList{ii});
                signal_labels{ii} = {signalHeader.signal_labels};
            end
            signal_labels = unique(horzcat(signal_labels{:}));
            uialert(app.UIFigure,sprintf('%s\n',signal_labels{:}),'List of all available channels in dataset','Icon','info');
        end

        function app = ShowHeader(app,varargin)
            if isempty(app.DataList) || isempty(app.DataListBox.Value)
                return
            end
            curr_file = app.DataListBox.Value{:};
            if ~exist(curr_file,'file')
                uialert(app.UIFigure,'File %s does not exist',curr_file,'Error','Icon','Error');
                return
            end
            [header,signalHeader] = read_EDF(curr_file);
            if isempty(app.header_fig) | (~isempty(app.header_fig) && ~ishandle(app.header_fig))
                [~,~,app.header_fig,app.uitable_header,app.uitable_signal] = header_gui(header,signalHeader);
            else
                [header_tbl,signal_tbl] = header_gui(header,signalHeader,'CreateGUI',false);
                app.uitable_header.Data = header_tbl;
                app.uitable_signal.Data = signal_tbl;
            end
        end

        function moveListItems(app,listType,direction)
            switch listType
                case 'data', currentList = app.DataList; lb = app.DataListBox;
                case 'staging', currentList = app.StagingList; lb = app.StagingListBox;
            end
            selected = lb.Value;
            if isempty(selected), return; end
            idx = find(ismember(currentList,selected));
            newList = currentList;
            if strcmp(direction,'up') && idx(1)>1
                for i=1:length(idx)
                    tmp=newList{idx(i)}; newList{idx(i)}=newList{idx(i)-1}; newList{idx(i)-1}=tmp;
                end
            elseif strcmp(direction,'down') && idx(end)<length(newList)
                for i=length(idx):-1:1
                    tmp=newList{idx(i)}; newList{idx(i)}=newList{idx(i)+1}; newList{idx(i)+1}=tmp;
                end
            end
            switch listType
                case 'data', app.DataList = newList; updateDataListBox(app); lb.Value=selected;
                case 'staging', app.StagingList = newList; updateStagingListBox(app); lb.Value=selected;
            end
        end

        %% ================== FILE SELECTION ==================
        function files = selectFiles(app,title,type)
            switch type
                case 'data', filter={'*.edf','EDF Files (*.edf)';'*.*','All Files'};
                case 'staging', filter={'*.csv','CSV (*.csv)';'*.txt','Text (*.txt)';'*.*','All Files'};
                otherwise, filter={'*.*','All Files'};
            end
            [f,p] = uigetfile(filter,title,'MultiSelect','on');
            if isequal(f,0), files={}; return; end
            if ~iscell(f), f={f}; end
            files = strcat(p,f);
            if ~isempty(app.FileValidationCallback)
                validFiles={};
                for i=1:length(files)
                    if app.FileValidationCallback(files{i})
                        validFiles{end+1}=files{i}; %#ok<AGROW>
                    end
                end
                files = validFiles;
            end
        end

        %% ================== UPDATE METHODS ==================
        function updateDataListBox(app)
            app.DataListBox.Items = app.DataList;
            app.DataLabel.Text = sprintf('Data (%d Files)',length(app.DataList),'FontSize',15);
        end

        function updateStagingListBox(app)
            app.StagingListBox.Items = app.StagingList;
            app.StagingLabel.Text = sprintf('Staging (%d Files)',length(app.StagingList),'FontSize',15);
        end

        function updateRunErrorList(app)

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
                app.run_error_list(end+1) = {strcat('- Number of data files (',num2str(length(app.DataList)),') does not match staging files (',num2str(length(app.StagingList)),').')};
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

            missing={};
            for f=[app.DataList,app.StagingList]
                if ~isfile(f{1}), missing{end+1}=f{1}; end %#ok<AGROW>
            end

            %% TO-DO: TEST THIS ONE
            if ~isempty(missing)
                app.run_error_list{end} = strcat('Missing files:\n%s',strjoin(missing,'\n'));
            end

        end

        %% ================== OUTPUT DIRECTORY ==================
        function browseOutputDir(app)
            folder = uigetdir;
            if folder~=0
                app.OutputDirEditField.Value = folder;
                outputDirChanged(app);
            end
        end

        function outputDirChanged(app)
            pathStr = app.OutputDirEditField.Value;
            if ~isfolder(pathStr)
                selection = uiconfirm(app.UIFigure,...
                    sprintf('Directory does not exist:\n%s\nCreate it?',pathStr),...
                    'Create Directory?','Options',{'Yes','No'},'DefaultOption',2);
                if strcmp(selection,'Yes'), mkdir(pathStr);
                else, app.OutputDirEditField.Value=''; end
            end
        end

        %% ================== LOGGING ==================
        function createRunLog(app)
            generate_run_log(app.options_structs, app.struct_names,'run_start',app.curr_datetime,'file_path',strcat(app.OutputDirEditField.Value,'/settings/'));
            app.runlog_fname = strcat('file_log_',app.curr_datetime,'.txt');
            app.runlog_fpath = strcat(app.OutputDirEditField.Value,'/logs/');
            app.runlog_fid = fopen(fullfile(app.runlog_fpath,app.runlog_fname), 'w');

            fprintf(app.runlog_fid, 'Date and time of run start: %s\n',app.curr_datetime);
            fprintf(app.runlog_fid, 'Run with settings file: %s\n\n',strcat('run_settings_',app.curr_datetime,'.txt'));
            fprintf(app.runlog_fid, 'Files run: \n\n');
        end

        function createConsoleLog(app)
            app.consolelog_fname = strcat('console_log_',app.curr_datetime,'.txt');
            app.consolelog_fpath = strcat(app.OutputDirEditField.Value,'/logs/');
            app.consolelog_fid = fopen(fullfile(app.consolelog_fpath,app.consolelog_fname), 'w');

            fprintf(app.consolelog_fid, 'Date and time of run start: %s\n\n',app.curr_datetime);
            diary(fullfile(app.consolelog_fpath,app.consolelog_fname))
        end

        %% ================== PROCESS USER INPUTS ==================
        function createOptionsStruct(app)
            app.struct_names = {'SOPH_options','baseline_options','detection_options','param_basis_power_options','param_basis_phase_options','spline_basis_power_options','spline_basis_phase_options'};
            app.options_structs{1} = app.SOPH_options;
            app.options_structs{2} = app.baseline_options;
            app.options_structs{3} = app.detection_options;
            app.options_structs{4} = app.param_basis_power_options;
            app.options_structs{5} = app.param_basis_phase_options;
            app.options_structs{6} = app.spline_basis_power_options;
            app.options_structs{7} = app.spline_basis_phase_options;
        end

        function updateStagesInput(app)
            app.ArtifactUserInput = textscan(app.ArtifactEditField.Value,'%s','Delimiter',',');
            app.ArtifactUserInput = app.ArtifactUserInput{1,1};
            app.WakeUserInput = textscan(app.WakeEditField.Value,'%s','Delimiter',',');
            app.WakeUserInput = app.WakeUserInput{1,1};
            app.REMUserInput = textscan(app.REMEditField.Value,'%s','Delimiter',',');
            app.REMUserInput = app.REMUserInput{1,1};
            app.N1UserInput = textscan(app.N1EditField.Value,'%s','Delimiter',',');
            app.N1UserInput = app.N1UserInput{1,1};
            app.N2UserInput = textscan(app.N2EditField.Value,'%s','Delimiter',',');
            app.N2UserInput = app.N2UserInput{1,1};
            app.N3UserInput = textscan(app.N3EditField.Value,'%s','Delimiter',',');
            app.N3UserInput = app.N3UserInput{1,1};
            app.UnknownUserInput = textscan(app.UnknownEditField.Value,'%s','Delimiter',',');
            app.UnknownUserInput = app.UnknownUserInput{1,1};
        end

        function updateChannelInput(app)
            app.ChannelList = textscan(app.ChannelEditField.Value,'%s','Delimiter',',');
            app.ChannelList = app.ChannelList{1,1};
        end

        function updateDelimeterInput(app)
            switch app.DelimeterOptionField.Value
                case 'Comma'
                    app.delimeter = ',';
                case 'Tab'
                    app.delimeter = '\t';
                case 'Space'
                    app.delimeter = ' ';
                case 'Semicolon'
                    app.delimeter = ';';
            end
        end

        %% ================== RUN REQUESTED RESULTS ==================
        function runStatsTable(app)

            %% TO-DO: GET RID OF HARD-CODED TIME RANGE VALUE ( THIS IS JUST FOR TESTING )
            % app.time_range = [0 5000];

            % Check if locations exist
            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/TFpeaks/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/TFpeaks/'))
            end
            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/'))
            end

            % Check if file exists already
            if app.OverwriteExistingFilesCheckBox.Value || (~exist(app.output_stats_name,'file') || ~exist(app.output_SOPH_name,'file'))
                app.anything_run = 1;

                % Run subject/channel
                app.TextArea.Value = strcat('Running DYNAMO on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
                app.run();

                stats_table = app.stats_table;
                SOPHs = app.SOPHs;

                % Save stats results
                if app.SavePeakStatsCheckBox.Value
                    app.TextArea.Value = strcat('Saving stats table on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
                    
                    if ~strcmp(app.PeakStatsTableDropDown.Value,'--')
                        switch app.PeakStatsTableDropDown.Value
                            case '.csv'
                                app.output_stats_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.csv');
                                table2csv(stats_table,app.output_stats_name);
                                %% TO-DO: DEBUG THIS
                                save(app.output_stats_name,'stats_table');
                            case '.mat'
                                app.output_stats_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.mat');
                                save(app.output_stats_name,'stats_table');
                            case 'All'
                                % .mat
                                app.output_stats_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.mat');
                                save(app.output_stats_name,'stats_table');
                                % .csv
                                app.output_stats_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.csv');
                                table2csv(stats_table,app.output_stats_name);
                                save(app.output_stats_name,'stats_table');
                        end 
                    end
                end

                if app.SaveSOPHsCheckBox.Value
                    app.TextArea.Value = strcat('Saving SOPHs on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');

                    if ~strcmp(app.SOPowerHistogramsDropDown,'--')

                        switch app.SOPowerHistogramsDropDown
                            case '.tiff'
                                app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.tiff');
                                app.writeTiff(app.output_SOPH_name,SOPHs.SOpower_mat);
                            case '.mat'
                                app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.tiff');
                                save(app.output_SOPH_name,'SOPHs');
                            case 'All'
                                app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.tiff');
                                app.writeTiff(app.output_SOPH_name,SOPHs.SOpower_mat);
                                app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.tiff');
                                save(app.output_SOPH_name,'SOPHs');
                        end
                    end

                    
                end

            end
        end

        function runDataSummaryFigure(app)
            % Check if locations exist
            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/summary/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/summary/'))
            end

            % Check if stats and SOPH exist
            if isempty(app.SOPHs) && ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat'),'file')
                runStatsTable(app);
            elseif isempty(app.SOPHs) && exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat'),'file')
                app.SOPHs = load(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat')).SOPHs;
            end

            if isempty(app.stats_table)
                if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.csv'),'file') && ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.mat'),'file')
                    runStatsTable(app);
                elseif exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.mat'),'file')
                    app.stats_table = load(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.mat'),'stats_table');
                else
                    app.stats_table = csv2table(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.csv'));
                end
            end

            % Create output name
            if ~strcmp(app.DataSummaryDropDown.Value,'--')
                app.output_fig_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/summary/',app.input_fbase,'_summary_figure_',app.channel,app.DataSummaryDropDown.Value);
            end

            % Check if file exists already, it not, run
            if app.OverwriteExistingFilesCheckBox.Value || ~exist(app.output_fig_name,'file')
                app.TextArea.Value = strcat('Saving summary figure on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
                app.anything_run = 1;
                fh = app.displaySummaryPlot;
                print(fh,'-dpng','-r300',app.output_fig_name);
                close all;
            end
        end

        function runParamBasis(app)

            % Check if locations exist
            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/param_basis/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/param_basis/'))
            end

            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/param_basis/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/param_basis/'))
            end

            % Check if SOPHs exist
            if isempty(app.SOPHs) && ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat'),'file')
                app.anything_run = 1;
                app.TextArea.Value = strcat('Running DYNAMO on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
                runStatsTable(app);
            elseif isempty(app.SOPHs) && exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat'),'file')
                app.SOPHs = load(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat')).SOPHs;
            end

            %% TO-DO: Check if param basis already exists
            app.TextArea.Value = strcat('Running parameter basis fit on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
            app.fitParamBasis();
            fh = gcf;
            if app.SaveParamImagesCheckBox.Value
                app.anything_run = 1;
                app.output_param_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/param_basis/',app.input_fbase,'_param_basis_figure_',app.channel,app.DataSummaryDropDown.Value);
                app.TextArea.Value = strcat('Saving parameter basis fit summary figure on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
                print(fh,'-dpng','-r300',app.output_param_name);
            end
            close all;

            % Resave SOPH with param basis
            %% TO-DO: ADD CSV OPTION
            app.output_paramfit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/param_basis/',app.input_fbase,'_SOpower_paramfit_',app.channel,'.mat');
            app.output_paramfit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/param_basis/',app.input_fbase,'_SOphase_paramfit_',app.channel,'.mat');
            SOpower_paramfit = app.SOPHs.SOpower_paramfit;
            SOphase_paramfit = app.SOPHs.SOpower_paramfit;
            app.TextArea.Value = strcat('Updating saved SOPH on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
            save(app.output_paramfit_power_name,'SOpower_paramfit');
            save(app.output_paramfit_phase_name,'SOphase_paramfit');
        end

        function runSplineBasis(app)
            % Check if location exists
            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/spline_basis/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/spline_basis/'))
            end

            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/spline_basis/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/spline_basis/'))
            end

            % Check if SOPHs exist
            if isempty(app.SOPHs) && ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat'),'file')
                app.anything_run = 1;
                app.TextArea.Value = strcat('Running DYNAMO on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
                runStatsTable(app);
            elseif isempty(app.SOPHs) && exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat'),'file')
                app.SOPHs = load(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat')).SOPHs;
            end

            % % Check if SOPH exists
            % if isempty(app.SOPHs)
            %     app.anything_run = 1;
            %     app.TextArea.Value = strcat('Running DYNAMO on subject ',{' '},app.input_fbase,', channel ',app.channel,{' '},'.');
            %     app.run();
            % end

            %% TO-DO: Check if spline already saved
            app.TextArea.Value = strcat('Running spline basis fit on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
            app.fitSplineBasis();
            fh = gcf;
            if app.SaveSplineImagesCheckBox.Value
                app.anything_run = 1;
                app.TextArea.Value = strcat('Saving spline figure for subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
                app.output_spline_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/spline_basis/',app.input_fbase,'_spline_basis_figure_',app.channel,'.png');
                print(fh,'-dpng','-r300',app.output_spline_name);
            end
            close all;

            app.TextArea.Value = strcat('Updating saved SOPH for subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
            
            % Resave SOPH with spline
            if ~strcmp(app.SplineBasisDropDown.Value,'--')

                SOpower_splinefit = app.SOPHs.SOpower_splinefit;
                SOphase_splinefit = app.SOPHs.SOphase_splinefit;

                switch app.SplineBasisDropDown.Value
                    case '.tiff'
                        app.output_splinefit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/spline_basis/',app.input_fbase,'_SOpower_splinefit_',app.channel,'.tiff');
                        app.output_splinefit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/spline_basis/',app.input_fbase,'_SOphase_splinefit_',app.channel,'.tiff');
                        app.writeTiff(app.output_splinefit_power_name,SOpower_splinefit.splinefit)
                        app.writeTiff(app.output_splinefit_phase_name,SOphase_splinefit.splinefit)
                    case '.mat'
                        app.output_splinefit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/spline_basis/',app.input_fbase,'_SOpower_splinefit_',app.channel,'.mat');
                        app.output_splinefit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/spline_basis/',app.input_fbase,'_SOphase_splinefit_',app.channel,'.mat');
                        save(app.output_splinefit_power_name,'SOpower_splinefit');
                        save(app.output_splinefit_phase_name,'SOphase_splinefit');
                    case 'All'
                        app.output_splinefit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/spline_basis/',app.input_fbase,'_SOpower_splinefit_',app.channel,'.tiff');
                        app.output_splinefit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/spline_basis/',app.input_fbase,'_SOphase_splinefit_',app.channel,'.tiff');
                        app.writeTiff(app.output_splinefit_power_name,SOpower_splinefit.splinefit)
                        app.writeTiff(app.output_splinefit_phase_name,SOphase_splinefit.splinefit)
                        app.output_splinefit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/spline_basis/',app.input_fbase,'_SOpower_splinefit_',app.channel,'.mat');
                        app.output_splinefit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/spline_basis/',app.input_fbase,'_SOphase_splinefit_',app.channel,'.mat');
                        save(app.output_splinefit_power_name,'SOpower_splinefit');
                        save(app.output_splinefit_phase_name,'SOphase_splinefit');
                end
            end


        end

        function saveAuxData(app)
            % Check if location exists
            if ~exist(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/auxiliary_data/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/auxiliary_data/'))
            end

            %% TO-DO: ADD EVERYTHING
            app.auxiliary_data.artifacts = app.artifacts;
            app.auxiliary_data.Fs = app.Fs;
            app.auxiliary_data.SOpower_norm_method = app.SOPH_options.SOpower_norm_method;

            auxiliary_data = app.auxiliary_data; %#ok<ADPROP>

            app.TextArea.Value = strcat('Saving auxiliary data on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');

            app.output_aux_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/auxiliary_data/',app.input_fbase,'_auxiliary_data_',app.channel,'.mat');
            save(app.output_aux_name,'auxiliary_data');

        end

        %% ================== RUN BATCH ==================
        function RunBatchButtonPushed(app,~,~)

            % Reset stop batch button if previously pushed
            app.isStopBatchButtonPushed = false;

            % Check to make sure app is able to be run
            updateRunErrorList(app)

            % If any errors exist, output warning, otherwise, output
            % success message and update run button
            if isempty(app.run_error_list)
                uialert(app.UIFigure,'All files exist and counts match. Ready to process.','Success','Icon','success');
                %app.RunBatchButton.Enable="off";
            else
                uialert(app.UIFigure,sprintf('%s\n',app.run_error_list{:}),'Run Error','Icon','error');
                app.run_error_list = {};
                return;
            end

            % Reverse file list if user requests
            if app.RunInReverse.Value
                app.DataList = app.DataList(end:-1:1);
                app.StagingList = app.StagingList(end:-1:1);
            end

            % Create saving options struct
            if ~isempty(app.BatchProcessCallback)
                opts.OutputDir = app.OutputDirEditField.Value;
                opts.SavePeakStats = app.SavePeakStatsCheckBox.Value;
                opts.SaveDataSummary = app.SaveDataSummaryCheckBox.Value;
                opts.SaveParamBasis = app.SaveParamBasisCheckBox.Value;
                opts.SaveParamImages = app.SaveParamImagesCheckBox.Value;
                opts.SaveSplineBasis = app.SaveSplineBasisCheckBox.Value;
                opts.SaveSplineImages = app.SaveSplineImagesCheckBox.Value;
                app.BatchProcessCallback(app.DataList, app.StagingList, opts);
            end

            runBatch(app)
        end

        function StopBatchButtonPushed(app,~,~)
            app.isStopBatchButtonPushed = true;
            uialert(app.UIFigure,'Stop button pushed. Completing current subject then stopping.','Stopping','Icon','Error');
        end

        function runBatch(app,~)

            app.TextArea.Value = {'Beginning run.'};
            app.curr_datetime = char(datetime('now','Format','yyMMdd_HHmmSS'));

            % Settings folder
            if ~exist(strcat(app.OutputDirEditField.Value,'/settings/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/settings/'))
            end

            % Log folder
            if ~exist(strcat(app.OutputDirEditField.Value,'/logs/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/logs/'))
            end

            % Create options struct
            app.TextArea.Value = {'Updating advanced options.'};
            createOptionsStruct(app)

            % Create run log
            app.TextArea.Value = {'Creating run log.'};
            createRunLog(app)

            % Create console log
            app.TextArea.Value = {'Creating console log.'};
            createConsoleLog(app)

            % Update channel from user inputs
            app.TextArea.Value = {'Processing channel inputs.'};
            updateChannelInput(app)

            % Create progress bar
            if isempty(app.progress_bar)
                app.progress_bar = SmoothProgressBar(app.TimeEstimateGrid,length(app.DataList),app.TimeEstimateGrid.Position);
            else
                app.progress_bar.refresh;
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%
            % MAIN LOOP TO RUN DYNAMO %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%

            % Loop through channels
            app.curr_iteration = 0;
            for jj = 1:length(app.DataList)

                % Loop through EDFs
                for ii = 1:length(app.ChannelList)
                    app.channel = app.ChannelList{ii};

                    if app.isStopBatchButtonPushed==true % Quit if user pushed stop batch button
                        return
                    end
                    app.anything_run = 0;
                    [~,app.input_fbase] = fileparts(app.DataList{jj});

                    % Update stages from user inputs
                    app.TextArea.Value = {'Processing stage inputs.'};
                    updateStagesInput(app)

                    %try

                    % Update delimeter from user input
                    app.TextArea.Value = {'Processing delimeter input.'};
                    updateDelimeterInput(app)

                    %% =============== LOAD EDF AND STAGING ===============
                    app.TextArea.Value = strcat('Loading subject',{' '},app.input_fbase,', channel',{' '},app.channel,' staging and EDF data.');
                    [app.data, app.Fs, app.stage_times, app.stage_vals] = load_data(app.DataList{jj},app.StagingList{jj},app.StagesColumnEditField.Value,app.TimesColumnEditField.Value,app.channel,'header_lines',app.HeaderRowsEditField.Value,'delimiter',app.delimeter,'stage_vals_in',{app.ArtifactUserInput,app.WakeUserInput,app.REMUserInput,app.N1UserInput,app.N2UserInput,app.N3UserInput,app.UnknownUserInput});

                    %% =============== RUN REQUESTED RESULTS ===============

                    % If Stats Table Requested
                    if app.SavePeakStatsCheckBox.Value || app.SaveSOPHsCheckBox.Value
                        runStatsTable(app)
                    end

                    % If Data Summary Image Requested
                    if  app.SaveDataSummaryCheckBox.Value
                        runDataSummaryFigure(app)
                    end

                    % If Param Basis Requested
                    if app.SaveParamBasisCheckBox.Value
                        runParamBasis(app)
                    end

                    % If Spline Basis Requested
                    if app.SaveSplineBasisCheckBox.Value
                        runSplineBasis(app)
                    end

                    if app.SaveAuxDataCheckBox.Value
                        saveAuxData(app)
                    end

                    %% =============== UPDATE RUN LOG ===============

                    % Output to run log if anything was run
                    if app.anything_run
                        app.TextArea.Value = strcat('Successfully run subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
                        fprintf(app.runlog_fid, 'Subject %s, channel %s: run successfully.\n',app.input_fbase,app.channel);
                    else
                        fprintf(app.runlog_fid, 'Subject %s, channel %s: all files already exist. Subject skipped.\n',app.input_fbase,app.channel);
                    end

                    % catch e
                    %
                    %     % Output error to run log
                    %     app.TextArea.Value = strcat('Error on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'. Check log for details.');
                    %     fprintf(app.runlog_fid, 'Subject %s, channel %s: not run. Error: %s\n',app.input_fbase,app.channel,e.message);
                    %
                    % end

                    % Update progress bar
                    app.curr_iteration = app.curr_iteration+1;
                    app.progress_bar.updateIteration(app.curr_iteration);

                end

            end

            % Close files and graphics
            app.progress_bar.complete();
            %set(app.pb,'Visible','off');
            fclose(app.consolelog_fid);
            fclose(app.runlog_fid);
            app.RunBatchButton.Enable='on';

        end

    end
end
