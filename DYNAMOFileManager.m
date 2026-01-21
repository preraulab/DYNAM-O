classdef DYNAMOFileManager < matlab.apps.AppBase & DYNAMO

    properties (Access = public)

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Overall figure structure %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%

        UIFigure            matlab.ui.Figure
        TabGroup            matlab.ui.container.TabGroup
        FileSelectionTab    matlab.ui.container.Tab
        DYNAMOSettingsTab  matlab.ui.container.Tab

        % Summary Label
        SummaryLabel        matlab.ui.control.Label
        HelpButton          matlab.ui.control.Button

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % File selection panel structures and components %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % Data panel components
        DataPanel           matlab.ui.container.Panel
        DataLabel           matlab.ui.control.Label
        FigureLabel         matlab.ui.control.Label
        DataListBox         matlab.ui.control.ListBox
        DataButtonGroup     matlab.ui.container.ButtonGroup
        DataDirectionLabel  matlab.ui.control.Label

        % Staging panel components
        StagingPanel            matlab.ui.container.Panel
        StagingLabel            matlab.ui.control.Label
        StagingListBox          matlab.ui.control.ListBox
        StagingButtonGroup      matlab.ui.container.ButtonGroup
        StagingDirectionLabel   matlab.ui.control.Label

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Runtime options panel components (2 panes + misc) %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % Runtime options panel layout
        RuntimeOptionsPanel         matlab.ui.container.Panel   % full panel
        RuntimeOptionsLabel         matlab.ui.control.Label
        StagingOptionsInputPanel    matlab.ui.container.Panel   % Top pane
        SavingOptionsPanel          matlab.ui.container.Panel
        OutputPanel             matlab.ui.container.Panel       % Bottom pane
        OutputLabel             matlab.ui.control.Label

        % Channel input components
        ChannelHelp             matlab.ui.control.Label
        ChannelEditField        matlab.ui.control.EditField
        ChannelEditFieldLabel   matlab.ui.control.Label

        %%%%%%%% STAGING INPUT PANE %%%%%%%%

        % Staging input components
        ArtifactEditField           matlab.ui.control.EditField
        ArtifactEditFieldLabel      matlab.ui.control.Label
        WakeEditField               matlab.ui.control.EditField
        WakeEditFieldLabel          matlab.ui.control.Label
        REMEditField                matlab.ui.control.EditField
        REMEditFieldLabel           matlab.ui.control.Label
        N1EditField                 matlab.ui.control.EditField
        N1EditFieldLabel            matlab.ui.control.Label
        N2EditField                 matlab.ui.control.EditField
        N2EditFieldLabel            matlab.ui.control.Label
        N3EditField                 matlab.ui.control.EditField
        N3EditFieldLabel            matlab.ui.control.Label
        UnknownEditField            matlab.ui.control.EditField
        UnknownEditFieldLabel       matlab.ui.control.Label

        % Staging file input options
        DelimeterOptionField        matlab.ui.control.DropDown
        DelimeterOptionFieldLabel   matlab.ui.control.Label
        StagesColumnEditField       matlab.ui.control.NumericEditField
        StagesColumnEditFieldLabel  matlab.ui.control.Label
        TimesColumnEditField        matlab.ui.control.NumericEditField
        TimesColumnEditFieldLabel   matlab.ui.control.Label
        HeaderRowsEditField         matlab.ui.control.NumericEditField
        HeaderRowsEditFieldLabel    matlab.ui.control.Label

        % Misc
        StagesHelp                  matlab.ui.control.Label

        %%%%%%%% SAVING OPTIONS PANE %%%%%%%%

        % Computations to run components
        SavePeakStatsCheckBox       matlab.ui.control.CheckBox
        SaveSOPHsCheckBox           matlab.ui.control.CheckBox
        SaveDataSummaryCheckBox     matlab.ui.control.CheckBox
        SaveParamBasisCheckBox      matlab.ui.control.CheckBox
        SaveParamImagesCheckBox     matlab.ui.control.CheckBox
        SaveSplineBasisCheckBox     matlab.ui.control.CheckBox
        SaveAuxDataCheckBox         matlab.ui.control.CheckBox
        SaveSplineImagesCheckBox    matlab.ui.control.CheckBox

        % Saving options panel components
        OutputDirEditField      matlab.ui.control.EditField
        OutputDirButton         matlab.ui.control.Button
        OutputDirLabel          matlab.ui.control.Label
        OutputOptionField       matlab.ui.control.DropDown
        OutputOptionFieldLabel  matlab.ui.control.Label

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % RUNNING COMPONENTS BELOW MAIN PANEL STRUCTURE %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % Main control
        RunBatchButton  matlab.ui.control.Button
        StopBatchButton matlab.ui.control.Button

        % Run misc options
        RunInReverse                    matlab.ui.control.CheckBox
        OverwriteExistingFilesCheckBox  matlab.ui.control.CheckBox

        % Output text
        TextArea       matlab.ui.control.TextArea
        TextAreaLabel  matlab.ui.control.Label

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
        icon_filepath = 'icons/'

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
        %% ================== UI CREATION ==================
        function createComponents(app, windowTitle, position)
            if isempty(position)
                scr = get(0,'ScreenSize');
                x = (scr(3)-app.WindowWidth)/2;
                y = (scr(4)-app.WindowHeight)/2;
                position = [x,y,app.WindowWidth,app.WindowHeight];
            end
            app.UIFigure = uifigure('Position',position,'Name',windowTitle,'Resize','on');

            % Summary label
            app.SummaryLabel = uilabel(app.UIFigure,'Text',...
                'Add data and staging files, select output directory, choose options, then run batch.',...
                'Position',[app.PanelMargin,app.WindowHeight-30,app.WindowWidth-150,20],...
                'FontWeight','bold','HorizontalAlignment','center');

            % Help button
            app.HelpButton = uibutton(app.UIFigure,'push','Text','Help','Icon','Info','Position',[app.WindowWidth-120,app.WindowHeight-28,100,22],...
                'ButtonPushedFcn',@(src,event) showHelp(app));

            % Create Tab Group
            app.TabGroup = uitabgroup(app.UIFigure,'Position',[app.PanelMargin,80,app.WindowWidth-2*app.PanelMargin,app.WindowHeight-120]);

            % Create Tabs
            app.FileSelectionTab = uitab(app.TabGroup,'Title','File Selection');
            app.DYNAMOSettingsTab = uitab(app.TabGroup,'Title','DYNAM-O Settings');

            % Create menu
            mSettings = uimenu(app.UIFigure, 'Text', 'File');

            uimenu(mSettings, 'Text', 'Load EDF File List...', ...
                'MenuSelectedFcn', @(src,event) loadFileListCallback(app));

            uimenu(mSettings, 'Text', 'Load Staging File List...', ...
                'MenuSelectedFcn', @(src,event) loadStagingListCallback(app));

            createFileSelectionTab(app);
            createDYNAMOSettingsTab(app);
            createMainControls(app);

        end

        function createFileSelectionTab(app)

            %%%%%%%%%%%%%%%%%%%%%
            % OVERALL STRUCTURE %
            %%%%%%%%%%%%%%%%%%%%%

            % Get tab dimensions
            tabWidth = app.WindowWidth - 2*app.PanelMargin;
            tabHeight = app.WindowHeight - 120;

            % Three equal panels for Data, Staging, and Staging Options
            panelWidth = (tabWidth - 4*app.PanelMarginHorizontal)/3;
            panelHeight = tabHeight - 2*app.PanelMarginVertical;

            %%%%%%%%%%%%%%%%%%%
            % DATA FILE PANEL %
            %%%%%%%%%%%%%%%%%%%

            app.DataPanel = uipanel(app.FileSelectionTab,'Title','',...
                'Position',[app.PanelMarginHorizontal,app.PanelMarginVertical,panelWidth,panelHeight]);

            app.DataLabel = uilabel(app.DataPanel,'Text','Data (0 Files)',...
                'FontWeight','bold','HorizontalAlignment','center',...
                'Position',[10,panelHeight-40,panelWidth-20,20]);

            app.DataDirectionLabel = uilabel(app.DataPanel,'Text','Add your primary data files (EDF format). Use buttons to remove/reorder.',...
                'Position',[10,panelHeight-70,panelWidth-20,20],'FontAngle','italic','FontSize',10);

            app.DataListBox = uilistbox(app.DataPanel,'Position',[10,50,panelWidth-20,panelHeight-120],...
                'Multiselect','on','Items',{},'Value',{});

            % Interact buttons
            app.DataButtonGroup = uibuttongroup(app.DataPanel,'Position',[15,10,panelWidth-30,35],'BorderType','none');
            app.ButtonWidth = (panelWidth-60)/6;

            uibutton(app.DataButtonGroup,'push','Position',[5,5,app.ButtonWidth,app.ButtonHeight],...
                'Text','','Icon',strcat(app.icon_filepath,'add_file.png'),'tooltip','Add File','ButtonPushedFcn',@app.DataAddFileButtonPushed);
            uibutton(app.DataButtonGroup,'push','Position',[app.ButtonWidth+10,5,app.ButtonWidth,app.ButtonHeight],...
                'Text','','Icon',strcat(app.icon_filepath,'add_folder.png'),'tooltip','Add Folder','ButtonPushedFcn',@app.DataAddFolderButtonPushed);
            uibutton(app.DataButtonGroup,'push','Position',[2*app.ButtonWidth+15,5,app.ButtonWidth,app.ButtonHeight],...
                'Text','','Icon',strcat(app.icon_filepath,'load_file.png'),'tooltip','Load File List','ButtonPushedFcn',@app.loadFileListCallback);
            uibutton(app.DataButtonGroup,'push','Position',[3*app.ButtonWidth+20,5,app.ButtonWidth,app.ButtonHeight],...
                'Text','','Icon',strcat(app.icon_filepath,'garbage.png'),'tooltip','Remove File','ButtonPushedFcn',@app.DataRemoveButtonPushed);
            uibutton(app.DataButtonGroup,'push','Position',[4*app.ButtonWidth+25,5,app.ButtonWidth,app.ButtonHeight],...
                'Text','','Icon',strcat(app.icon_filepath,'up_arrow.png'),'tooltip','Move File Up','ButtonPushedFcn',@app.DataMoveUpButtonPushed);
            uibutton(app.DataButtonGroup,'push','Position',[5*app.ButtonWidth+30,5,app.ButtonWidth,app.ButtonHeight],...
                'Text','','Icon',strcat(app.icon_filepath,'down_arrow.png'),'tooltip','Move File Down','ButtonPushedFcn',@app.DataMoveDownButtonPushed);

            %%%%%%%%%%%%%%%%%%%%%%
            % STAGING FILE PANEL %
            %%%%%%%%%%%%%%%%%%%%%%

            xPos = 2*app.PanelMarginHorizontal + panelWidth;
            app.StagingPanel = uipanel(app.FileSelectionTab,'Title','',...
                'Position',[xPos,app.PanelMarginVertical,panelWidth,panelHeight]);

            app.StagingLabel = uilabel(app.StagingPanel,'Text','Staging (0 Files)',...
                'FontWeight','bold','HorizontalAlignment','center',...
                'Position',[10,panelHeight-40,panelWidth-20,20]);

            app.StagingDirectionLabel = uilabel(app.StagingPanel,'Text','Add staging files (CSV/TXT). Ensure order matches data files.',...
                'Position',[10,panelHeight-70,panelWidth-20,20],'FontAngle','italic','FontSize',10);

            app.StagingListBox = uilistbox(app.StagingPanel,'Position',[10,50,panelWidth-20,panelHeight-120],...
                'Multiselect','on','Items',{},'Value',{});

            % Interact buttons
            app.StagingButtonGroup = uibuttongroup(app.StagingPanel,'Position',[15,10,panelWidth-30,35],'BorderType','none');
            app.ButtonWidth = (panelWidth-60)/6;
            uibutton(app.StagingButtonGroup,'push','Position',[5,5,app.ButtonWidth,app.ButtonHeight], ...
                'Text','','Icon',strcat(app.icon_filepath,'add_file.png'),'tooltip','Add File','ButtonPushedFcn',@app.StagingAddFileButtonPushed);
            uibutton(app.StagingButtonGroup,'push','Position',[app.ButtonWidth+10,5,app.ButtonWidth,app.ButtonHeight], ...
                'Text','','Icon',strcat(app.icon_filepath,'add_folder.png'),'tooltip','Add Folder','ButtonPushedFcn',@app.StagingAddFolderButtonPushed);
            uibutton(app.StagingButtonGroup,'push','Position',[2*app.ButtonWidth+15,5,app.ButtonWidth,app.ButtonHeight], ...
                'Text','','Icon',strcat(app.icon_filepath,'load_file.png'),'tooltip','Load File List','ButtonPushedFcn',@app.loadStagingListCallback);
            uibutton(app.StagingButtonGroup,'push','Position',[3*app.ButtonWidth+20,5,app.ButtonWidth,app.ButtonHeight], ...
                'Text','','Icon',strcat(app.icon_filepath,'garbage.png'),'tooltip','Remove File','ButtonPushedFcn',@app.StagingRemoveButtonPushed);
            uibutton(app.StagingButtonGroup,'push','Position',[4*app.ButtonWidth+25,5,app.ButtonWidth,app.ButtonHeight], ...
                'Text','','Icon',strcat(app.icon_filepath,'up_arrow.png'),'tooltip','Move File Up','ButtonPushedFcn',@app.StagingMoveUpButtonPushed);
            uibutton(app.StagingButtonGroup,'push','Position',[5*app.ButtonWidth+30,5,app.ButtonWidth,app.ButtonHeight], ...
                'Text','','Icon',strcat(app.icon_filepath,'down_arrow.png'),'tooltip','Move File Down','ButtonPushedFcn',@app.StagingMoveDownButtonPushed);

            %%%%%%%%%%%%%%%%%%%%%%%%%
            % RUNTIME OPTIONS PANEL %
            %%%%%%%%%%%%%%%%%%%%%%%%%

            %% TO-DO:
            % Create UIFigure and hide until all components are created
            % app.UIFigure = uifigure('Visible', 'off');
            % app.UIFigure.Position = [100 100 640 480];
            % app.UIFigure.Name = 'MATLAB App';

            % Overall runtime options panel structure
            xPos = 3*app.PanelMarginHorizontal + 2*panelWidth;
            app.RuntimeOptionsPanel = uipanel(app.FileSelectionTab,'Title','',...
                'Position',[xPos,app.PanelMarginVertical,panelWidth,panelHeight]);

            app.RuntimeOptionsLabel = uilabel(app.RuntimeOptionsPanel,'Text','Runtime Options',...
                'FontWeight','bold','HorizontalAlignment','center',...
                'Position',[10,panelHeight-40,panelWidth-20,20]);

            %%%%%%%% SUBPANEL STRUCTURE %%%%%%%%
            app.StagingOptionsInputPanel = uipanel(app.RuntimeOptionsPanel);
            app.StagingOptionsInputPanel.Title = 'Staging Options';
            app.StagingOptionsInputPanel.Position = [0 panelHeight-361 panelWidth panelHeight-371];

            app.SavingOptionsPanel = uipanel(app.RuntimeOptionsPanel);
            app.SavingOptionsPanel.Title = 'Saving Options';
            app.SavingOptionsPanel.Position = [0 panelHeight-300-330 panelWidth 271];

            %%%%%%%% STAGING SUBPANEL %%%%%%%%

            %%% CHANNEL INPUT %%%
            app.ChannelHelp = uilabel(app.RuntimeOptionsPanel,'Text','Enter a comma separated list of channels to be run.',...
                'Position',[100, panelHeight-70, panelWidth-20,20],'FontAngle','italic','FontSize',13);

            % Create ChannelEditFieldLabel
            app.ChannelEditFieldLabel = uilabel(app.RuntimeOptionsPanel);
            app.ChannelEditFieldLabel.HorizontalAlignment = 'right';
            app.ChannelEditFieldLabel.Position = [25 panelHeight-95 65 22];
            app.ChannelEditFieldLabel.Text = 'Channel(s):';
            app.ChannelEditFieldLabel.Tooltip = 'Comma separated list of all channels to be run';

            % Create ChannelEditField
            app.ChannelEditField = uieditfield(app.RuntimeOptionsPanel, 'text');
            app.ChannelEditField.Position = [100 panelHeight-95 300 22];

            %%% STAGING FILE OPTIONS INPUT %%%
            app.ypos = app.StagingOptionsInputPanel.Position(4)-60; spacing = 30;

            % Create DelimeterLabel
            app.DelimeterOptionFieldLabel = uilabel(app.StagingOptionsInputPanel,'HorizontalAlignment','right');
            app.DelimeterOptionFieldLabel.Position = [(panelWidth/2 - 5) app.ypos 90 22];
            app.DelimeterOptionFieldLabel.Text = 'File Delimeter';
            app.DelimeterOptionFieldLabel.Tooltip = 'Character separating values in the staging file';

            app.DelimeterOptionField = uidropdown(app.StagingOptionsInputPanel,'Items',{'Comma','Tab','Space','Semicolon'});
            app.DelimeterOptionField.Position = [(panelWidth/2 + 95) app.ypos 100 22];

            % Create StagesColumnEditFieldLabel
            app.StagesColumnEditFieldLabel = uilabel(app.StagingOptionsInputPanel,'HorizontalAlignment','right');
            app.StagesColumnEditFieldLabel.Position = [(panelWidth/2 - 5) app.ypos-spacing*2 90 22];
            app.StagesColumnEditFieldLabel.Text = 'Stages Column';
            app.StagesColumnEditFieldLabel.Tooltip = 'Column of the staging file containing the stage labels';

            % Create StagesColumnEditField
            app.StagesColumnEditField = uieditfield(app.StagingOptionsInputPanel, 'numeric');
            app.StagesColumnEditField.AllowEmpty = 'on';
            app.StagesColumnEditField.Value = [];
            app.StagesColumnEditField.RoundFractionalValues = 'on';
            app.StagesColumnEditField.Limits = [0 Inf];
            app.StagesColumnEditField.Position = [(panelWidth/2 + 95) app.ypos-spacing*2 100 22];

            % Create TimesColumnEditFieldLabel
            app.TimesColumnEditFieldLabel = uilabel(app.StagingOptionsInputPanel,'HorizontalAlignment','right');
            app.TimesColumnEditFieldLabel.Position = [(panelWidth/2 - 5) app.ypos-spacing*3 90 22];
            app.TimesColumnEditFieldLabel.Text = 'Times Column';
            app.TimesColumnEditFieldLabel.Tooltip = 'Column of the staging file containing the precise time of each label';

            % Create TimesColumnEditField
            app.TimesColumnEditField = uieditfield(app.StagingOptionsInputPanel, 'numeric');
            app.TimesColumnEditField.AllowEmpty = 'on';
            app.TimesColumnEditField.Value = [];
            app.TimesColumnEditField.RoundFractionalValues = 'on';
            app.TimesColumnEditField.Limits = [0 Inf];
            app.TimesColumnEditField.Position = [(panelWidth/2 + 95) app.ypos-spacing*3 100 22];

            % Create HeaderRowsEditFieldLabel
            app.HeaderRowsEditFieldLabel = uilabel(app.StagingOptionsInputPanel,'HorizontalAlignment','right');
            app.HeaderRowsEditFieldLabel.Position = [(panelWidth/2 - 5) app.ypos-spacing*4 90 22];
            app.HeaderRowsEditFieldLabel.Text = 'Header Rows';
            app.HeaderRowsEditFieldLabel.Tooltip = 'Number of rows in the staging file before the scoring values begin (includes column headers)';

            % Create HeaderRowsEditField
            app.HeaderRowsEditField = uieditfield(app.StagingOptionsInputPanel,'numeric');
            app.HeaderRowsEditField.AllowEmpty = 'on';
            app.HeaderRowsEditField.Value = [];
            app.HeaderRowsEditField.RoundFractionalValues = 'on';
            app.HeaderRowsEditField.Limits = [0 Inf];
            app.HeaderRowsEditField.Position = [(panelWidth/2 + 95) app.ypos-spacing*4 100 22];

            %%% STAGE LABELS INPUT %%%

            % Create ArtifactEditFieldLabel
            app.ArtifactEditFieldLabel = uilabel(app.StagingOptionsInputPanel,'HorizontalAlignment','right');
            app.ArtifactEditFieldLabel.Position = [20,app.ypos,50,22];
            app.ArtifactEditFieldLabel.Text = 'Artifact';
            app.ArtifactEditFieldLabel.Tooltip = 'All valid artifact stage identifiers';

            % Create ArtifactEditField
            app.ArtifactEditField = uieditfield(app.StagingOptionsInputPanel, 'text');
            app.ArtifactEditField.Position = [80 app.ypos 100 22];
            app.ArtifactEditField.Value = 'art, artifact, A, 6';

            % Create WakeEditFieldLabel
            app.WakeEditFieldLabel = uilabel(app.StagingOptionsInputPanel,'HorizontalAlignment','right');
            app.WakeEditFieldLabel.Position = [20,app.ypos-spacing,50,22];
            app.WakeEditFieldLabel.Text = 'Wake';
            app.WakeEditFieldLabel.Tooltip = 'All valid wake stage identifiers';

            % Create WakeEditField
            app.WakeEditField = uieditfield(app.StagingOptionsInputPanel, 'text');
            app.WakeEditField.Position = [80 app.ypos-spacing 100 22];
            app.WakeEditField.Value = 'wake, W, 5';

            % Create REMEditFieldLabel
            app.REMEditFieldLabel = uilabel(app.StagingOptionsInputPanel,'HorizontalAlignment','right');
            app.REMEditFieldLabel.Position = [20 app.ypos-spacing*2 50 22];
            app.REMEditFieldLabel.Text = 'REM';
            app.REMEditFieldLabel.Tooltip = 'All valid REM stage identifiers';

            % Create REMEditField
            app.REMEditField = uieditfield(app.StagingOptionsInputPanel, 'text');
            app.REMEditField.Position = [80 app.ypos-spacing*2 100 22];
            app.REMEditField.Value = 'REM, R, 4';

            % Create N1EditFieldLabel
            app.N1EditFieldLabel = uilabel(app.StagingOptionsInputPanel,'HorizontalAlignment','right');
            app.N1EditFieldLabel.Position = [20 app.ypos-spacing*3 50 22];
            app.N1EditFieldLabel.Text = 'N1';
            app.N1EditFieldLabel.Tooltip = 'All valid N1 stage identifiers';

            % Create N1EditField
            app.N1EditField = uieditfield(app.StagingOptionsInputPanel, 'text');
            app.N1EditField.Position = [80 app.ypos-spacing*3 100 22];
            app.N1EditField.Value = 'N1, Stage 1, 1';

            % Create N2EditFieldLabel
            app.N2EditFieldLabel = uilabel(app.StagingOptionsInputPanel,'HorizontalAlignment','right');
            app.N2EditFieldLabel.Position = [20 app.ypos-spacing*4 50 22];
            app.N2EditFieldLabel.Text = 'N2';
            app.N2EditFieldLabel.Tooltip = 'All valid N2 stage identifiers';

            % Create N2EditField
            app.N2EditField = uieditfield(app.StagingOptionsInputPanel, 'text');
            app.N2EditField.Position = [80 app.ypos-spacing*4 100 22];
            app.N2EditField.Value = 'N2, Stage 2, 2';

            % Create N3EditFieldLabel
            app.N3EditFieldLabel = uilabel(app.StagingOptionsInputPanel,'HorizontalAlignment','right');
            app.N3EditFieldLabel.Position = [20 app.ypos-spacing*5 50 22];
            app.N3EditFieldLabel.Text = 'N3';
            app.N3EditFieldLabel.Tooltip = 'All valid N3 stage identifiers';

            % Create N3EditField
            app.N3EditField = uieditfield(app.StagingOptionsInputPanel, 'text');
            app.N3EditField.Position = [80 app.ypos-spacing*5 100 22];
            app.N3EditField.Value = 'N3, Stage 3, 3';

            % Create UnknownEditFieldLabel
            app.UnknownEditFieldLabel = uilabel(app.StagingOptionsInputPanel,'HorizontalAlignment','right');
            app.UnknownEditFieldLabel.Position = [10 app.ypos-spacing*6 60 22];
            app.UnknownEditFieldLabel.Text = 'Unknown';
            app.UnknownEditFieldLabel.Tooltip = 'All valid identifiers for unknown stage';

            % Create UnknownEditField
            app.UnknownEditField = uieditfield(app.StagingOptionsInputPanel, 'text');
            app.UnknownEditField.Position = [80 app.ypos-spacing*6 100 22];
            app.UnknownEditField.Value = 'Unk, U, Unknown, 0';

            app.StagesHelp = uilabel(app.StagingOptionsInputPanel,'Text',{'Stages should be comma separated','lists of all valid stage identifiers in','the scoring/annotations file.'},...
                'Position',[200,0, panelWidth/2,80],'FontAngle','italic','FontSize',13,'HorizontalAlignment','center');


            %%%%%%%% SAVING SUBPANEL %%%%%%%%
            app.ypos = app.SavingOptionsPanel.Position(4)-80; spacing = 30;

            lwidth = 150;

            % Data saving
            app.SavePeakStatsCheckBox = uicheckbox(app.SavingOptionsPanel,'Text','Peak Stats Tables','tooltip','Create table of all detected peaks from the spectrogram','Position',[10,app.ypos,lwidth,22]);
            app.SaveSOPHsCheckBox = uicheckbox(app.SavingOptionsPanel,'Text','SO-Power Histogram','tooltip','Save matrix with a slow oscillation power histogram','Position',[10,app.ypos-spacing,lwidth,22]);
            app.SaveParamBasisCheckBox = uicheckbox(app.SavingOptionsPanel,'Text','Parametric Basis','tooltip','Save table with mode parameters','Position',[10,app.ypos-2*spacing,lwidth,22]);
            app.SaveSplineBasisCheckBox = uicheckbox(app.SavingOptionsPanel,'Text','Spline Basis','tooltip','Save table spline parameters','Position',[10,app.ypos-3*spacing,90,22]);
            app.SaveAuxDataCheckBox = uicheckbox(app.SavingOptionsPanel,'Text','Aux Data','tooltip','Save artifacts, {insert list Sophie}','Position',[10,app.ypos-4*spacing,90,22]);

            % Image saving
            app.SaveDataSummaryCheckBox = uicheckbox(app.SavingOptionsPanel,'Text','Data Summary Figures','tooltip','Create summary figure with spectrogram, peaks, power and phase histograms','Position',[panelWidth/2,app.ypos,lwidth,22]);
            app.SaveParamImagesCheckBox = uicheckbox(app.SavingOptionsPanel,'Text','Parametric Basis Figures','tooltip','ASK MIKE','Position',[panelWidth/2,app.ypos-spacing,lwidth+20,22]);
            app.SaveSplineImagesCheckBox = uicheckbox(app.SavingOptionsPanel,'Text','Spline Basis Figures','tooltip','ASK MIKE','Position',[panelWidth/2,app.ypos-2*spacing,lwidth,22]);

            app.OutputOptionFieldLabel = uilabel(app.SavingOptionsPanel,'HorizontalAlignment','right');
            app.OutputOptionFieldLabel.Position = [(panelWidth/2 + 35) app.ypos-130 90 22];
            app.OutputOptionFieldLabel.Text = 'Output Format:';
            app.OutputOptionFieldLabel.Tooltip = 'File format results will be saved as';

            app.OutputOptionField = uidropdown(app.SavingOptionsPanel,'Items',{'.mat','.csv'});
            app.OutputOptionField.Position = [(panelWidth/2 + 135) app.ypos-130 60 22];


            %% BOTTOM PANEL

            label_height = 220;

            app.DataLabel = uilabel(app.SavingOptionsPanel);
            app.DataLabel.FontSize = 12;
            app.DataLabel.Position = [10 label_height 75 22];
            app.DataLabel.Text = 'Data to Save';

            uipanel(app.SavingOptionsPanel, ...
                'Position', [ app.DataLabel.Position(1),  app.DataLabel.Position(2)-.25,  app.DataLabel.Position(3), 1], ...
                'BackgroundColor',  app.DataLabel.FontColor, ...
                'BorderType', 'none');

            app.FigureLabel = uilabel(app.SavingOptionsPanel);
            app.FigureLabel.FontSize = 12;
            app.FigureLabel.Position = [215 label_height 90 22];
            app.FigureLabel.Text = 'Figures to Save';

            uipanel(app.SavingOptionsPanel, ...
                'Position', [ app.FigureLabel.Position(1),  app.FigureLabel.Position(2)-.25,  app.FigureLabel.Position(3)-.5, 1], ...
                'BackgroundColor',  app.FigureLabel.FontColor, ...
                'BorderType', 'none');

            app.OutputDirLabel = uilabel(app.SavingOptionsPanel,'Text','Select output directory and choose what to save.',...
                'Position',[20 42 panelWidth-20 22],'FontAngle','italic','FontSize',12);

            app.OutputDirEditField = uieditfield(app.SavingOptionsPanel,'text','Position',[20 15 panelWidth-110 25],...
                'ValueChangedFcn',@(src,event) outputDirChanged(app));
            app.OutputDirButton = uibutton(app.SavingOptionsPanel,'push','Text','Browse','tooltip','Search for folder to save results','Position',[panelWidth-80 15 60 25],...
                'ButtonPushedFcn',@(src,event) browseOutputDir(app));

            %% OUTSIDE
            app.RunInReverse = uicheckbox(app.UIFigure,'Text','Run in Reverse','FontSize',14,'tooltip','Run file list from bottom to top','Position',[app.WindowWidth/2+20,42,200,20]);
            app.OverwriteExistingFilesCheckBox = uicheckbox(app.UIFigure,'Text','Overwrite Existing Files','FontSize',14,'tooltip','Save over existing files with the same name','Position',[app.WindowWidth/2+20,18,200,20]);

            % Create TextAreaLabel
            app.TextAreaLabel = uilabel(app.UIFigure);
            app.TextAreaLabel.HorizontalAlignment = 'right';
            app.TextAreaLabel.Position = [0,55,60,22];
            app.TextAreaLabel.Text = 'Status:';

            % Create TextArea
            app.TextArea = uitextarea(app.UIFigure,'Editable','off');
            app.TextArea.Position = [20,15,350,40];
            app.TextArea.Value = {'Add files, select settings, and press ''Run Batch'' to run'};


        end

        function createDYNAMOSettingsTab(app)
            app.DYNAMOOptionsApp(false, app.UIFigure, app.DYNAMOSettingsTab,false)
        end

        function createMainControls(app)
            app.RunBatchButton = uibutton(app.UIFigure,'push',...
                'Position',[app.WindowWidth/2-120,20,120,40],...
                'Text','Run Batch','Enable','on','FontWeight','bold','FontSize',12,...
                'tooltip','Run DYNAMO on files','ButtonPushedFcn',@app.RunBatchButtonPushed);

            % Finishes current subject/channel, then stops
            app.StopBatchButton = uibutton(app.UIFigure,'push',...
                'Position',[app.WindowWidth/2-190,20,50,40],...
                'Text','','Icon',strcat(app.icon_filepath,'stop.png'),...
                'tooltip','Stop current DYNAMO batch','ButtonPushedFcn',@app.StopBatchButtonPushed);
        end

        function createProgressBar(app)
            N = length(app.ChannelList) * length(app.DataList);
            app.progress_bar = SmoothProgressBar(app.UIFigure,N,[app.WindowWidth-250,10,180,60]);
            app.progress_bar.start();
        end

        %% ================== HELP ==================
        function showHelp(app)
            msg = ['Instructions:' newline ...
                '1. In File Selection tab: Add Data files (EDF) and Staging files (CSV/TXT).' newline ...
                '2. Make sure the file counts match and order corresponds.' newline ...
                '3. In Output Options tab: Choose an output directory and select save options.' newline ...
                '4. Click Run Batch to process files.'];
            uialert(app.UIFigure,msg,'Help','Icon','info');
        end

        %% ================== BUTTON CALLBACKS ==================
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
            app.DataLabel.Text = sprintf('Data (%d Files)',length(app.DataList));
        end

        function updateStagingListBox(app)
            app.StagingListBox.Items = app.StagingList;
            app.StagingLabel.Text = sprintf('Staging (%d Files)',length(app.StagingList));
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

            % Create output names
            if strcmp(app.OutputOptionField.Value,'.csv')
                app.output_stats_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.csv');
            else
                app.output_stats_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/TFpeaks/',app.input_fbase,'_stats_table_',app.channel,'.mat');
            end
            app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',app.channel,'.mat');

            % Check if file exists already
            if app.OverwriteExistingFilesCheckBox.Value || (~exist(app.output_stats_name,'file') || ~exist(app.output_SOPH_name,'file'))
                app.anything_run = 1;

                % Run subject/channel
                app.TextArea.Value = strcat('Running DYNAMO on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
                app.run();

                stats_table = app.stats_table;
                SOPHs = app.SOPHs;

                % Save results
                if app.SavePeakStatsCheckBox.Value
                    app.TextArea.Value = strcat('Saving stats table on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
                    if strcmp(app.OutputOptionField.Value,'.csv')
                        table2csv(stats_table,app.output_stats_name);
                    else
                        save(app.output_stats_name,'stats_table');
                    end
                end

                if app.SaveSOPHsCheckBox.Value
                    app.TextArea.Value = strcat('Saving SOPHs on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
                    save(app.output_SOPH_name,'SOPHs');
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
            app.output_fig_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/summary/',app.input_fbase,'_summary_figure_',app.channel,'.png');

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
                app.output_param_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/figures/param_basis/',app.input_fbase,'_param_basis_figure_',app.channel,'.png');
                app.TextArea.Value = strcat('Saving parameter basis fit summary figure on subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
                print(fh,'-dpng','-r300',app.output_param_name);
            end
            close all;

            % Resave SOPH with param basis
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

            % Resave SOPH with spline
            app.output_splinefit_power_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/spline_basis/',app.input_fbase,'_SOpower_splinefit_',app.channel,'.mat');
            app.output_splinefit_phase_name = strcat(app.OutputDirEditField.Value,'/',app.channel,'/results/spline_basis/',app.input_fbase,'_SOphase_splinefit_',app.channel,'.mat');
            SOpower_splinefit = app.SOPHs.SOpower_splinefit;
            SOphase_splinefit = app.SOPHs.SOphase_splinefit;
            app.TextArea.Value = strcat('Updating saved SOPH for subject ',{' '},app.input_fbase,', channel ',{' '},app.channel,'.');
            save(app.output_splinefit_power_name,'SOpower_splinefit');
            save(app.output_splinefit_phase_name,'SOphase_splinefit');
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
                createProgressBar(app)
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