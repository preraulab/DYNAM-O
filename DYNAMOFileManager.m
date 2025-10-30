classdef DYNAMOFileManager < matlab.apps.AppBase & DYNAMO
    
    properties (Access = public)
        UIFigure matlab.ui.Figure
        TabGroup matlab.ui.container.TabGroup
        FileSelectionTab matlab.ui.container.Tab
        OutputOptionsTab matlab.ui.container.Tab
        DYNAMOOptionsTab matlab.ui.container.Tab
        
        % Summary Label
        SummaryLabel matlab.ui.control.Label
        HelpButton matlab.ui.control.Button
        
        % Data panel components
        DataPanel matlab.ui.container.Panel
        DataLabel matlab.ui.control.Label
        DataListBox matlab.ui.control.ListBox
        DataButtonGroup matlab.ui.container.ButtonGroup
        DataDirectionLabel matlab.ui.control.Label
        
        % Staging panel components  
        StagingPanel matlab.ui.container.Panel
        StagingLabel matlab.ui.control.Label
        StagingListBox matlab.ui.control.ListBox
        StagingButtonGroup matlab.ui.container.ButtonGroup
        StagingDirectionLabel matlab.ui.control.Label
        
        % Staging options panel components
        StagingOptionsPanel matlab.ui.container.Panel
        StagingOptionsLabel matlab.ui.control.Label
        ChannelEditField matlab.ui.control.EditField
        ChannelEditFieldLabel matlab.ui.control.Label
        DelimeterOptionField matlab.ui.control.DropDown
        DelimeterOptionFieldLabel matlab.ui.control.Label
        HeaderRowsEditField matlab.ui.control.NumericEditField
        HeaderRowsEditFieldLabel matlab.ui.control.Label
        TimesColumnEditField matlab.ui.control.NumericEditField
        TimesColumnEditFieldLabel matlab.ui.control.Label
        StagesColumnEditField_2 matlab.ui.control.NumericEditField
        HeaderrowsLabel matlab.ui.control.Label
        UnknownEditField        matlab.ui.control.EditField
        UnknownEditFieldLabel   matlab.ui.control.Label
        N3EditField             matlab.ui.control.EditField
        N3EditFieldLabel        matlab.ui.control.Label
        N2EditField             matlab.ui.control.EditField
        N2EditFieldLabel        matlab.ui.control.Label
        N1EditField             matlab.ui.control.EditField
        N1EditFieldLabel        matlab.ui.control.Label
        REMEditField            matlab.ui.control.EditField
        REMEditFieldLabel       matlab.ui.control.Label
        WakeEditField           matlab.ui.control.EditField
        WakeEditFieldLabel      matlab.ui.control.Label
        ArtifactEditField       matlab.ui.control.EditField
        ArtifactEditFieldLabel  matlab.ui.control.Label

        % TO;DO, make neater
        RightPanelTop matlab.ui.container.Panel
        RightPanelMid matlab.ui.container.Panel
        RightPanelBottom matlab.ui.container.Panel
        
        % Output options panel components
        OutputPanel matlab.ui.container.Panel
        OutputLabel matlab.ui.control.Label
        OutputDirEditField matlab.ui.control.EditField
        OutputDirButton matlab.ui.control.Button
        OutputDirLabel matlab.ui.control.Label

        % TO-DO
        SavePeakStatsCheckBox matlab.ui.control.CheckBox
        SaveDataSummaryCheckBox matlab.ui.control.CheckBox
        SaveParamBasisCheckBox matlab.ui.control.CheckBox
        SaveParamImagesCheckBox matlab.ui.control.CheckBox
        SaveSplineBasisCheckBox matlab.ui.control.CheckBox
        SaveSplineImagesCheckBox matlab.ui.control.CheckBox
        SaveDateTimeCheckBox matlab.ui.control.CheckBox

        OverwriteExistingFilesCheckBox matlab.ui.control.CheckBox
        
        % Main control
        RunBatchButton matlab.ui.control.Button
        %RunReverseButton matlab.ui.control.Button
        RunInReverse matlab.ui.control.CheckBox
        
        % Callback handles
        BatchProcessCallback function_handle
        FileValidationCallback function_handle

    end
    
    properties (Access = private)
        DataList cell = {}
        StagingList cell = {}
        run_error_list cell = {''};

        % Misc for processing
        input_fbase = ''
        output_fig_name = ''
        output_stats_name = ''
        output_SOPH_name = '' 
        output_param_name = ''
        output_spline_name = ''
        date_time_save = ''

        % Misc for saving
        structs
        struct_names
        delimeter

        % TO-DO
        ArtifactUserInput
        N1UserInput
        N2UserInput
        N3UserInput
        REMUserInput
        WakeUserInput
        UnknownUserInput

        ChannelList
        anything_run
        header_lines
        
        % UI dimensions
        WindowWidth = 1400
        WindowHeight = 850
        PanelMargin = 20
        PanelMarginVertical = 50
        PanelMarginHorizontal = 20
        ButtonHeight = 30
    end
    
    methods (Access = public)
        function app = DYNAMOFileManager(varargin)
            p = inputParser;
            addParameter(p,'BatchCallback',[],@(x) isempty(x)||isa(x,'function_handle'));
            addParameter(p,'ValidationCallback',[],@(x) isempty(x)||isa(x,'function_handle'));
            addParameter(p,'Title','DYNAM-O Batch File Manager',@ischar);
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
            %updateRunBatchButton(app);
        end
        
        function addStagingFiles(app, filePaths)
            if ~iscell(filePaths), filePaths={filePaths}; end
            app.StagingList = [app.StagingList, filePaths];
            updateStagingListBox(app);
            %updateRunBatchButton(app);
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
            %updateRunBatchButton(app);
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
            % app.OutputOptionsTab = uitab(app.TabGroup,'Title','Output Options');
            
            createFileSelectionTab(app);
            createOutputOptionsTab(app);
            createMainControls(app);
            
            %updateRunBatchButton(app);
        end
        
        function createFileSelectionTab(app)
            % Get tab dimensions
            tabWidth = app.WindowWidth - 2*app.PanelMargin;
            tabHeight = app.WindowHeight - 120;
            
            % Three equal panels for Data, Staging, and Staging Options
            panelWidth = (tabWidth - 4*app.PanelMarginHorizontal)/3;
            panelHeight = tabHeight - 2*app.PanelMarginVertical;
            
            % Data Panel
            app.DataPanel = uipanel(app.FileSelectionTab,'Title','',...
                'Position',[app.PanelMarginHorizontal,app.PanelMarginVertical,panelWidth,panelHeight]);
            
            app.DataLabel = uilabel(app.DataPanel,'Text','Data (0 Files)',...
                'FontWeight','bold','HorizontalAlignment','center',...
                'Position',[10,panelHeight-40,panelWidth-20,20]);
            
            app.DataDirectionLabel = uilabel(app.DataPanel,'Text','Add your primary data files (EDF format). Use buttons to remove/reorder.',...
                'Position',[10,panelHeight-70,panelWidth-20,20],'FontAngle','italic','FontSize',10);
            
            app.DataListBox = uilistbox(app.DataPanel,'Position',[10,50,panelWidth-20,panelHeight-120],...
                'Multiselect','on','Items',{},'Value',{});
            
            icon_filepath = '/autofs/vast/preraugp/users/ss097/DYNAM-O_dev/icons/'; %% TO-DO: MAKE THIS PORTABLE

            app.DataButtonGroup = uibuttongroup(app.DataPanel,'Position',[15,10,panelWidth-30,35],'BorderType','none');
            buttonWidth = (panelWidth-60)/5;
            uibutton(app.DataButtonGroup,'push','Position',[5,5,buttonWidth,app.ButtonHeight],...
                'Text','','Icon',strcat(icon_filepath,'add_file.png'),'ButtonPushedFcn',@app.DataAddFileButtonPushed);
            uibutton(app.DataButtonGroup,'push','Position',[buttonWidth+10,5,buttonWidth,app.ButtonHeight],...
                'Text','','Icon',strcat(icon_filepath,'add_folder.png'),'ButtonPushedFcn',@app.DataAddFolderButtonPushed);
            uibutton(app.DataButtonGroup,'push','Position',[2*buttonWidth+15,5,buttonWidth,app.ButtonHeight],...
                'Text','','Icon',strcat(icon_filepath,'garbage.png'),'ButtonPushedFcn',@app.DataRemoveButtonPushed);
            uibutton(app.DataButtonGroup,'push','Position',[3*buttonWidth+20,5,buttonWidth,app.ButtonHeight],...
                'Text','','Icon',strcat(icon_filepath,'up_arrow.png'),'ButtonPushedFcn',@app.DataMoveUpButtonPushed);
            uibutton(app.DataButtonGroup,'push','Position',[4*buttonWidth+25,5,buttonWidth,app.ButtonHeight],...
                'Text','','Icon',strcat(icon_filepath,'down_arrow.png'),'ButtonPushedFcn',@app.DataMoveDownButtonPushed);
            
            % Staging Panel
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
            
            app.StagingButtonGroup = uibuttongroup(app.StagingPanel,'Position',[15,10,panelWidth-30,35],'BorderType','none');
            buttonWidth = (panelWidth-60)/5;
            %% TO-DO: FIGURE OUT WHY TEXT IS NECESSARY
            uibutton(app.StagingButtonGroup,'push','Position',[5,5,buttonWidth,app.ButtonHeight],'Text','','Icon',strcat(icon_filepath,'add_file.png'),'ButtonPushedFcn',@app.StagingAddFileButtonPushed);
            uibutton(app.StagingButtonGroup,'push','Position',[buttonWidth+10,5,buttonWidth,app.ButtonHeight],'Text','','Icon',strcat(icon_filepath,'add_folder.png'),'ButtonPushedFcn',@app.StagingAddFolderButtonPushed);
            uibutton(app.StagingButtonGroup,'push','Position',[2*buttonWidth+15,5,buttonWidth,app.ButtonHeight],'Text','','Icon',strcat(icon_filepath,'garbage.png'),'ButtonPushedFcn',@app.StagingRemoveButtonPushed);
            uibutton(app.StagingButtonGroup,'push','Position',[3*buttonWidth+20,5,buttonWidth,app.ButtonHeight],'Text','','Icon',strcat(icon_filepath,'up_arrow.png'),'ButtonPushedFcn',@app.StagingMoveUpButtonPushed);
            uibutton(app.StagingButtonGroup,'push','Position',[4*buttonWidth+25,5,buttonWidth,app.ButtonHeight],'Text','','Icon',strcat(icon_filepath,'down_arrow.png'),'ButtonPushedFcn',@app.StagingMoveDownButtonPushed);
            
            % Staging Options Panel
            xPos = 3*app.PanelMarginHorizontal + 2*panelWidth;
            app.StagingOptionsPanel = uipanel(app.FileSelectionTab,'Title','',...
                'Position',[xPos,app.PanelMarginVertical,panelWidth,panelHeight]);
            
            app.StagingOptionsLabel = uilabel(app.StagingOptionsPanel,'Text','Options',...
                'FontWeight','bold','HorizontalAlignment','center',...
                'Position',[10,panelHeight-40,panelWidth-20,20]);

            % SUBPANELS
            % TO-DO: CLEAN THIS UP
            app.RightPanelTop = uipanel(app.StagingOptionsPanel);
            app.RightPanelTop.Title = 'Output Options';
            app.RightPanelTop.Position = [0 panelHeight-271 panelWidth panelHeight-431];

            app.RightPanelMid = uipanel(app.StagingOptionsPanel);
            app.RightPanelMid.Title = 'Staging Options';
            app.RightPanelMid.Position = [0 104 panelWidth 261];

            app.RightPanelBottom = uipanel(app.StagingOptionsPanel);
            app.RightPanelBottom.Title = 'Output Directory';
            app.RightPanelBottom.Position = [0 0 panelWidth 105];

            yPos = app.RightPanelTop.Position(4)-50; spacing = 30;
            app.SavePeakStatsCheckBox = uicheckbox(app.RightPanelTop,'Text','Peak Stats Tables','Position',[10,yPos,panelWidth-20,22]);
            app.SaveDataSummaryCheckBox = uicheckbox(app.RightPanelTop,'Text','Data Summary Images','Position',[10,yPos-spacing,panelWidth-20,22]);
            app.SaveParamBasisCheckBox = uicheckbox(app.RightPanelTop,'Text','Parametric Basis','Position',[10,yPos-2*spacing,panelWidth-20,22]);
            app.SaveParamImagesCheckBox = uicheckbox(app.RightPanelTop,'Text','Parametric Basis Images','Position',[panelWidth/2,yPos,panelWidth-20,22]);
            app.SaveSplineBasisCheckBox = uicheckbox(app.RightPanelTop,'Text','Spline Basis','Position',[panelWidth/2,yPos-spacing,panelWidth-20,22]);
            app.SaveSplineImagesCheckBox = uicheckbox(app.RightPanelTop,'Text','Spline Basis Images','Position',[panelWidth/2,yPos-2*spacing,panelWidth-20,22]);
            
            app.OverwriteExistingFilesCheckBox = uicheckbox(app.RightPanelTop,'Text','Overwrite Existing Files','Position',[panelWidth/2-((panelWidth-20)/2),yPos-3.25*spacing,panelWidth-20,22]);
            
            % Create ChannelEditFieldLabel
            app.ChannelEditFieldLabel = uilabel(app.RightPanelTop);
            app.ChannelEditFieldLabel.HorizontalAlignment = 'right';
            app.ChannelEditFieldLabel.Position = [105 20 60 22];
            app.ChannelEditFieldLabel.Text = 'Channel(s)';

            % Create ChannelEditField
            app.ChannelEditField = uieditfield(app.RightPanelTop, 'text');
            app.ChannelEditField.Position = [170 20 100 22];
            
            %% CHECK
            yPos = app.RightPanelMid.Position(4)-60; spacing = 30;

            % Create DelimeterLabel
            app.DelimeterOptionFieldLabel = uilabel(app.RightPanelMid,'HorizontalAlignment','right');
            app.DelimeterOptionFieldLabel.Position = [(panelWidth/2 - 5) yPos 90 22];
            app.DelimeterOptionFieldLabel.Text = 'File Delimeter';

            app.DelimeterOptionField = uidropdown(app.RightPanelMid,'Items',{'Comma','Tab','Space','Semicolon'});
            app.DelimeterOptionField.Position = [(panelWidth/2 + 95) yPos 100 22];

            % Create HeaderrowsLabel
            app.HeaderrowsLabel = uilabel(app.RightPanelMid,'HorizontalAlignment','right');
            app.HeaderrowsLabel.Position = [(panelWidth/2 - 5) yPos-spacing*2 90 22];
            app.HeaderrowsLabel.Text = 'Stages Column';

            % Create StagesColumnEditField_2
            app.StagesColumnEditField_2 = uieditfield(app.RightPanelMid, 'numeric');
            app.StagesColumnEditField_2.AllowEmpty = 'on';
            app.StagesColumnEditField_2.Value = [];
            app.StagesColumnEditField_2.RoundFractionalValues = 'on';
            app.StagesColumnEditField_2.Limits = [0 Inf];
            app.StagesColumnEditField_2.Position = [(panelWidth/2 + 95) yPos-spacing*2 100 22];

            % Create TimesColumnEditFieldLabel
            app.TimesColumnEditFieldLabel = uilabel(app.RightPanelMid,'HorizontalAlignment','right');
            app.TimesColumnEditFieldLabel.Position = [(panelWidth/2 - 5) yPos-spacing*3 90 22];
            app.TimesColumnEditFieldLabel.Text = 'Times Column';

            % Create TimesColumnEditField
            app.TimesColumnEditField = uieditfield(app.RightPanelMid, 'numeric');
            app.TimesColumnEditField.AllowEmpty = 'on';
            app.TimesColumnEditField.Value = [];
            app.TimesColumnEditField.RoundFractionalValues = 'on';
            app.TimesColumnEditField.Limits = [0 Inf];
            app.TimesColumnEditField.Position = [(panelWidth/2 + 95) yPos-spacing*3 100 22];

            % Create HeaderRowsEditFieldLabel
            app.HeaderRowsEditFieldLabel = uilabel(app.RightPanelMid,'HorizontalAlignment','right');
            app.HeaderRowsEditFieldLabel.Position = [(panelWidth/2 - 5) yPos-spacing*4 90 22];
            app.HeaderRowsEditFieldLabel.Text = 'Header Rows';

            % Create HeaderRowsEditField
            app.HeaderRowsEditField = uieditfield(app.RightPanelMid,'numeric');
            app.HeaderRowsEditField.AllowEmpty = 'on';
            app.HeaderRowsEditField.Value = [];
            app.HeaderRowsEditField.RoundFractionalValues = 'on';
            app.HeaderRowsEditField.Limits = [0 Inf];
            app.HeaderRowsEditField.Position = [(panelWidth/2 + 95) yPos-spacing*4 100 22];

            % Create UIFigure and hide until all components are created
            % app.UIFigure = uifigure('Visible', 'off');
            % app.UIFigure.Position = [100 100 640 480];
            % app.UIFigure.Name = 'MATLAB App';

            % Create ArtifactEditFieldLabel
            app.ArtifactEditFieldLabel = uilabel(app.RightPanelMid,'HorizontalAlignment','right');
            app.ArtifactEditFieldLabel.Position = [20,yPos,50,22];
            app.ArtifactEditFieldLabel.Text = 'Artifact';

            % Create ArtifactEditField
            app.ArtifactEditField = uieditfield(app.RightPanelMid, 'text');
            app.ArtifactEditField.Position = [80 yPos 100 22];
            app.ArtifactEditField.Value = 'art, artifact, A, 6';

            % Create WakeEditFieldLabel
            app.WakeEditFieldLabel = uilabel(app.RightPanelMid,'HorizontalAlignment','right');
            app.WakeEditFieldLabel.Position = [20,yPos-spacing,50,22];
            app.WakeEditFieldLabel.Text = 'Wake';

            % Create WakeEditField
            app.WakeEditField = uieditfield(app.RightPanelMid, 'text');
            app.WakeEditField.Position = [80 yPos-spacing 100 22];
            app.WakeEditField.Value = 'wake, W, 5';

            % Create REMEditFieldLabel
            app.REMEditFieldLabel = uilabel(app.RightPanelMid,'HorizontalAlignment','right');
            app.REMEditFieldLabel.Position = [20 yPos-spacing*2 50 22];
            app.REMEditFieldLabel.Text = 'REM';

            % Create REMEditField
            app.REMEditField = uieditfield(app.RightPanelMid, 'text');
            app.REMEditField.Position = [80 yPos-spacing*2 100 22];
            app.REMEditField.Value = 'REM, R, 4';

            % Create N1EditFieldLabel
            app.N1EditFieldLabel = uilabel(app.RightPanelMid,'HorizontalAlignment','right');
            app.N1EditFieldLabel.Position = [20 yPos-spacing*3 50 22];
            app.N1EditFieldLabel.Text = 'N1';

            % Create N1EditField
            app.N1EditField = uieditfield(app.RightPanelMid, 'text');
            app.N1EditField.Position = [80 yPos-spacing*3 100 22];
            app.N1EditField.Value = 'N1, Stage 1, 1';

            % Create N2EditFieldLabel
            app.N2EditFieldLabel = uilabel(app.RightPanelMid,'HorizontalAlignment','right');
            app.N2EditFieldLabel.Position = [20 yPos-spacing*4 50 22];
            app.N2EditFieldLabel.Text = 'N2';

            % Create N2EditField
            app.N2EditField = uieditfield(app.RightPanelMid, 'text');
            app.N2EditField.Position = [80 yPos-spacing*4 100 22];
            app.N2EditField.Value = 'N2, Stage 2, 2';

            % Create N3EditFieldLabel
            app.N3EditFieldLabel = uilabel(app.RightPanelMid,'HorizontalAlignment','right');
            app.N3EditFieldLabel.Position = [20 yPos-spacing*5 50 22];
            app.N3EditFieldLabel.Text = 'N3';

            % Create N3EditField
            app.N3EditField = uieditfield(app.RightPanelMid, 'text');
            app.N3EditField.Position = [80 yPos-spacing*5 100 22];
            app.N3EditField.Value = 'N3, Stage 3, 3';

            % Create UnknownEditFieldLabel
            app.UnknownEditFieldLabel = uilabel(app.RightPanelMid,'HorizontalAlignment','right');
            app.UnknownEditFieldLabel.Position = [10 yPos-spacing*6 60 22];
            app.UnknownEditFieldLabel.Text = 'Unknown';

            % Create UnknownEditField
            app.UnknownEditField = uieditfield(app.RightPanelMid, 'text');
            app.UnknownEditField.Position = [80 yPos-spacing*6 100 22];
            app.UnknownEditField.Value = 'Unk, U, Unknown, 0';

            %% BOTTOM PANEL
            % app.OutputLabel = uilabel(app.RightPanelBottom,'Text','Output Options','FontWeight','bold',...
            %     'HorizontalAlignment','center','Position',[25 50 panelWidth-20 22]);
            % 
            app.OutputDirLabel = uilabel(app.RightPanelBottom,'Text','Select output directory and choose what to save.',...
                'Position',[20 50 panelWidth-20 22],'FontAngle','italic','FontSize',10);
            
            app.OutputDirEditField = uieditfield(app.RightPanelBottom,'text','Position',[20 20 panelWidth-110 25],...
                'ValueChangedFcn',@(src,event) outputDirChanged(app));
            app.OutputDirButton = uibutton(app.RightPanelBottom,'push','Text','Browse','Position',[panelWidth-80 20 60 25],...
                'ButtonPushedFcn',@(src,event) browseOutputDir(app));

            %% OUTSIDE
            app.RunInReverse = uicheckbox(app.UIFigure,'Text','Run in Reverse','FontSize',14,'Position',[app.WindowWidth/2+20,30,200,20]);
            

        end
        
        function createOutputOptionsTab(app)
            % Get tab dimensions
            tabWidth = app.WindowWidth - 2*app.PanelMargin;
            tabHeight = app.WindowHeight - 120;
            
            % Single centered panel for output options
            panelWidth = min(600, tabWidth - 2*app.PanelMarginHorizontal);
            panelHeight = tabHeight - 2*app.PanelMarginVertical;
            xPos = (tabWidth - panelWidth)/2;
            
            % app.OutputPanel = uipanel(app.OutputOptionsTab,'Title','',...
            %     'Position',[xPos,app.PanelMarginVertical,panelWidth,panelHeight]);
            
            % app.OutputLabel = uilabel(app.OutputPanel,'Text','Output Options','FontWeight','bold',...
            %     'HorizontalAlignment','center','Position',[10,panelHeight-40,panelWidth-20,20]);
            % 
            % app.OutputDirLabel = uilabel(app.OutputPanel,'Text','Select output directory and choose what to save.',...
            %     'Position',[10,panelHeight-70,panelWidth-20,20],'FontAngle','italic','FontSize',10);
            % 
            % app.OutputDirEditField = uieditfield(app.OutputPanel,'text','Position',[10,panelHeight-100,panelWidth-90,25],...
            %     'ValueChangedFcn',@(src,event) outputDirChanged(app));
            % app.OutputDirButton = uibutton(app.OutputPanel,'push','Text','Browse','Position',[panelWidth-70,panelHeight-100,60,25],...
            %     'ButtonPushedFcn',@(src,event) browseOutputDir(app));
            
            % yPos = panelHeight-140; spacing = 30;
            % app.SavePeakStatsCheckBox = uicheckbox(app.RightPannelTop,'Text','Peak Stats Tables','Position',[10,yPos,panelWidth-20,22]);
            % app.SaveDataSummaryCheckBox = uicheckbox(app.RightPannelTop,'Text','Data Summary Images','Position',[10,yPos-spacing,panelWidth-20,22]);
            % app.SaveParamBasisCheckBox = uicheckbox(app.RightPannelTop,'Text','Parametric Basis','Position',[10,yPos-2*spacing,panelWidth-20,22]);
            % app.SaveParamImagesCheckBox = uicheckbox(app.RightPannelTop,'Text','Parametric Basis Images','Position',[10,yPos-3*spacing,panelWidth-20,22]);
            % app.SaveSplineBasisCheckBox = uicheckbox(app.RightPannelTop,'Text','Spline Basis','Position',[10,yPos-4*spacing,panelWidth-20,22]);
            % app.SaveSplineImagesCheckBox = uicheckbox(app.RightPannelTop,'Text','Spline Basis Images','Position',[10,yPos-5*spacing,panelWidth-20,22]);
        end
        
        function createMainControls(app)
            app.RunBatchButton = uibutton(app.UIFigure,'push',...
                'Position',[app.WindowWidth/2-140,20,120,40],...
                'Text','Run Batch','Enable','on','FontWeight','bold','FontSize',12,...
                'tooltip','Testing123','ButtonPushedFcn',@app.RunBatchButtonPushed);

            % app.RunReverseButton = uibutton(app.UIFigure,'push',...
            %     'Position',[app.WindowWidth/2+20,20,120,40],...
            %     'Text','Run Reverse','Enable','on','FontWeight','bold','FontSize',12,...
            %     'ButtonPushedFcn',@app.RunReverseButtonPushed);
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
        function DataAddFileButtonPushed(app,~,~)
            files = selectFiles(app,'Select Data Files','data');
            if ~isempty(files)
                app.DataList = [app.DataList, files];
                updateDataListBox(app);
                %updateRunBatchButton(app);
            end
        end

        function DataAddFolderButtonPushed(app,~,~)
            folder = uigetdir(pwd,'Select Data Folder');
            S = dir(strcat(folder,'/*.edf'));
            files = strcat({S.folder},'/',{S.name});
            if ~isempty(files)
                app.DataList = [app.DataList, files];
                updateDataListBox(app);
                %updateRunBatchButton(app);
            end
        end
        
        function DataRemoveButtonPushed(app,~,~)
            selected = app.DataListBox.Value;
            if isempty(selected), return; end
            app.DataList = setdiff(app.DataList,selected,'stable');
            updateDataListBox(app);
            %updateRunBatchButton(app);
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
                %updateRunBatchButton(app);
            end
        end

        %% TO-DO: UPDATE THIS TO USE MIKE'S FILE SELECT
        function StagingAddFolderButtonPushed(app,~,~)
            folder = uigetdir(pwd,'Select Staging Folder');
            S = dir(strcat(folder,'/*.csv'));
            if size(S,1)==0
                S = dir(strcat(folder,'/*.txt'));
            end
            files = strcat({S.folder},'/',{S.name});
            if ~isempty(files)
                app.StagingList = [app.StagingList, files];
                updateStagingListBox(app);
                %updateRunBatchButton(app);
            end
        end
        
        function StagingRemoveButtonPushed(app,~,~)
            selected = app.StagingListBox.Value;
            if isempty(selected), return; end
            app.StagingList = setdiff(app.StagingList,selected,'stable');
            updateStagingListBox(app);
            %updateRunBatchButton(app);
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
        
        function updateRunBatchButton(app)
            hasData = ~isempty(app.DataList);
            hasStaging = ~isempty(app.StagingList);
            validOutput = ~isempty(app.OutputDirEditField.Value);
            app.RunBatchButton.Enable = hasData && hasStaging && validOutput;
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
            %if isempty(pathStr), updateRunBatchButton(app); return; end
            if ~isfolder(pathStr)
                selection = uiconfirm(app.UIFigure,...
                    sprintf('Directory does not exist:\n%s\nCreate it?',pathStr),...
                    'Create Directory?','Options',{'Yes','No'},'DefaultOption',2);
                if strcmp(selection,'Yes'), mkdir(pathStr);
                else, app.OutputDirEditField.Value=''; end
            end
            %updateRunBatchButton(app);
        end
        
        %% ================== RUN BATCH ==================
        % function RunReverseButtonPushed(app,~,~)
        %     app.DataList = app.DataList(end:-1:1);
        %     app.StagingList = app.StagingList(end:-1:1);
        %     RunBatchButtonPushed(app);
        % end

        function RunBatchButtonPushed(app,~,~)
            
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

            if isempty(app.StagesColumnEditField_2.Value)
                app.run_error_list(end+1) = {'- No staging column given in the staging file.'};
            end

            if isempty(app.TimesColumnEditField.Value)
                app.run_error_list(end+1) = {'- No times column given in the staging file.'};
            end

            if isempty(app.HeaderRowsEditField.Value)
                app.run_error_list(end+1) = {'- No header rows given in the staging file.'};
            end

            % if ~(strcmp(app.HeaderRowsEditField.Value,'Auto') || ~isnumeric(app.HeaderRowsEditField.Value))
            %     app.run_error_list(end+1) = {'- Unrecognized header rows value. Must be either "Auto" or an integer.'};
            % end

            
            %% TO-DO: CLEAN THIS SECTION
            % if length(app.DataList) ~= length(app.StagingList)
            %     uialert(app.UIFigure,sprintf('Number of data files (%d) does not match staging files (%d)',...
            %         length(app.DataList),length(app.StagingList)),'File Count Mismatch','Icon','error');
            %     return;
            % end

            missing={};
            for f=[app.DataList,app.StagingList]
                if ~isfile(f{1}), missing{end+1}=f{1}; end %#ok<AGROW>
            end

            %% TO-DO: TEST THIS ONE
            if ~isempty(missing)
                app.run_error_list{end} = strcat('Missing files:\n%s',strjoin(missing,'\n'));
            end
            % if ~isempty(missing)
            %     uialert(app.UIFigure,sprintf('Missing files:\n%s',strjoin(missing,'\n')),'File Missing','Icon','error');
            %     return;
            % end

            if isempty(app.run_error_list)
                uialert(app.UIFigure,'All files exist and counts match. Ready to process.','Success','Icon','success');
            else
                uialert(app.UIFigure,sprintf('%s\n',app.run_error_list{:}),'Run Error','Icon','error');
                app.run_error_list = {};
                return;
            end

            %% HERE
            if app.RunInReverse.Value
                app.DataList = app.DataList(end:-1:1);
                app.StagingList = app.StagingList(end:-1:1);
            end
            
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

        function runBatch(app,~)

            % SAVE SETTINGS
            if ~exist(strcat(app.OutputDirEditField.Value,'/settings/'),'dir')
                mkdir(strcat(app.OutputDirEditField.Value,'/settings/'))
            end

            app.struct_names = {'SOPH_options','baseline_options','detection_options','param_basis_power_options','param_basis_phase_options','spline_basis_power_options','spline_basis_phase_options'};
            app.structs{1} = app.SOPH_options;
            app.structs{2} = app.baseline_options;
            app.structs{3} = app.detection_options;
            app.structs{4} = app.param_basis_power_options;
            app.structs{5} = app.param_basis_phase_options;
            app.structs{6} = app.spline_basis_power_options;
            app.structs{7} = app.spline_basis_phase_options;
            generate_run_log(app.structs, app.struct_names,'file_path',strcat(app.OutputDirEditField.Value,'/settings/'));
            
            %% TO-DO: CLEAN UP AND INTEGRATE INTO CLASS
            if ~exist(strcat(app.OutputDirEditField.Value,'/settings/file_log.txt'),'file')
                fname = strcat('file_log_',char(datetime('now','Format','yyMMdd_HHmmSS')),'.txt');
                file_path = strcat(app.OutputDirEditField.Value,'/settings/');
                fid = fopen(fullfile(file_path,fname), 'w');

                fprintf(fid, 'Files run: \n\n');
            else
                %% TO-DO: ASK MIKE IF THERES A BETTER WAY TO DO THIS
                all_file_logs = {dir(strcat(app.OutputDirEditField.Value,'/settings/')).name}';
                to_remove = startsWith(all_file_logs,'.');
                all_file_logs(to_remove) = [];
                curr_file_log = length(all_file_logs); % One extra file for run_settings so don't have to add one each time
                fname = strcat('file_log_',num2str(curr_file_log),'_',char(datetime('now','Format','yyMMdd_HHmmSS')),'.txt');
                file_path = strcat(app.OutputDirEditField.Value,'/settings/');
                fid = fopen(fullfile(file_path,fname), 'w');
                fprintf(fid, 'Files run: \n\n');
            end

            app.ChannelList = textscan(app.ChannelEditField.Value,'%s','Delimiter',',');
            app.ChannelList = app.ChannelList{1,1};

            % Loop through objects
            for jj = 1:length(app.ChannelList)
                
                channel = app.ChannelList{jj};

                for ii = 1:length(app.DataList)
    
                    app.anything_run = 0;

                    [~,app.input_fbase] = fileparts(app.DataList{ii});
                    
                    %% TO-DO: MAKE THE COLUMNS PART OF THE GUI
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

                    try
    
                        % if ~strcmp(app.HeaderRowsEditField.Value,'Auto') && isnumeric(app.HeaderRowsEditField.Value)
                        %     app.header_lines = str2double(app.HeaderRowsEditField.Value);
                        % else 
                        %     app.header_lines = [];
                        % end
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

                       [app.data, app.Fs, app.stage_times, app.stage_vals] = load_data(app.DataList{ii},app.StagingList{ii},app.StagesColumnEditField_2.Value,app.TimesColumnEditField.Value,channel,'header_lines',app.HeaderRowsEditField.Value,'delimeter',app.delimeter,'stage_vals_in',{app.ArtifactUserInput,app.WakeUserInput,app.REMUserInput,app.N1UserInput,app.N2UserInput,app.N3UserInput,app.UnknownUserInput}); %#ok<ST2NM>
                        
                        % if ischar(app.data)
                        %     fprintf(fid, 'Subject %s, channel %s: not run. Error: %s',app.input_fbase,channel,app.data);
                        %     continue
                        % end
                        
                        %% TO-DO: GET RID OF HARD-CODED TIME RANGE VALUE ( THIS IS JUST FOR TESTING )
                        app.time_range = [0 5000];
        
                        % If Stats Table Requested
                        if app.SavePeakStatsCheckBox.Value
                            
                            % Check if locations exist
                            if ~exist(strcat(app.OutputDirEditField.Value,'/',channel,'/results/TFpeaks/'),'dir')
                                mkdir(strcat(app.OutputDirEditField.Value,'/',channel,'/results/TFpeaks/'))
                            end
                            if ~exist(strcat(app.OutputDirEditField.Value,'/',channel,'/results/SOPHs/'),'dir')
                                mkdir(strcat(app.OutputDirEditField.Value,'/',channel,'/results/SOPHs/'))
                            end
        
                            app.output_stats_name = strcat(app.OutputDirEditField.Value,'/',channel,'/results/TFpeaks/',app.input_fbase,'_stats_table_',channel,'.mat');
                            app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/',channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',channel,'.mat');
        
                            if app.OverwriteExistingFilesCheckBox.Value || (~exist(app.output_stats_name,'file') && ~exist(app.output_SOPH_name,'file'))
                                app.anything_run = 1;
                                
                                app.run();
    
                                stats_table = app.stats_table;
                                SOPHs = app.SOPHs;
            
                                save(app.output_stats_name,'stats_table');
                                save(app.output_SOPH_name,'SOPHs');

                            end
                            
                        end
        
                        % If Data Summary Image Requested
                        if  app.SaveDataSummaryCheckBox.Value
        
                            if ~exist(strcat(app.OutputDirEditField.Value,'/',channel,'/figures/summary/'),'dir')
                                mkdir(strcat(app.OutputDirEditField.Value,'/',channel,'/figures/summary/'))
                            end
        
                            app.output_fig_name = strcat(app.OutputDirEditField.Value,'/',channel,'/figures/summary/',app.input_fbase,'_summary_figure_',channel,'.png');
                            
                            if app.OverwriteExistingFilesCheckBox.Value || ~exist(app.output_fig_name,'file')
                                app.anything_run = 1;
                                fh = app.displaySummaryPlot;
                                print(fh,'-dpng','-r300',app.output_fig_name);
                                close all;
                            end
                            
                        end
        
                        % If Param Basis Requested
                        if app.SaveParamBasisCheckBox.Value
        
                            if ~exist(strcat(app.OutputDirEditField.Value,'/',channel,'/figures/param_basis/'),'dir')
                                mkdir(strcat(app.OutputDirEditField.Value,'/',channel,'/figures/param_basis/'))
                            end
                            
                            if isempty(app.SOPHs)
                                app.anything_run = 1;
                                app.run();
                            end
                          

                            app.fitParamBasis();
                            fh = gcf;
                            if app.SaveParamImagesCheckBox.Value
                                app.anything_run = 1;
                                app.output_param_name = strcat(app.OutputDirEditField.Value,'/',channel,'/figures/param_basis/',app.input_fbase,'_param_basis_figure_',channel,'.png');
                                print(fh,'-dpng','-r300',app.output_param_name);
                            end
                            close all;
        
                            app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/',channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',channel,'.mat');
                            SOPHs = app.SOPHs;
                            save(app.output_SOPH_name,'SOPHs');
        
                        end
        
                        % If Spline Basis Requested
                        if app.SaveSplineBasisCheckBox.Value
        
                            if ~exist(strcat(app.OutputDirEditField.Value,'/',channel,'/figures/spline_basis/'),'dir')
                                mkdir(strcat(app.OutputDirEditField.Value,'/',channel,'/figures/spline_basis/'))
                            end
                            
                            if isempty(app.SOPHs)
                                app.anything_run = 1;
                                app.run();
                            end
        
                            app.fitSplineBasis();
                            fh = gcf;
                            if app.SaveSplineImagesCheckBox.Value
                                app.anything_run = 1;
                                app.output_spline_name = strcat(app.OutputDirEditField.Value,'/',channel,'/figures/spline_basis/',app.input_fbase,'_spline_basis_figure_',channel,'.png');
                                print(fh,'-dpng','-r300',app.output_spline_name);
                            end
                            close all;
        
                            app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/',channel,'/results/SOPHs/',app.input_fbase,'_SOPHs_',channel,'.mat');
                            SOPHs = app.SOPHs;
                            save(app.output_SOPH_name,'SOPHs');
        
                        end

                        if app.anything_run
                            fprintf(fid, 'Subject %s, channel %s: run successfully.\n',app.input_fbase,channel);
                        else
                            fprintf(fid, 'Subject %s, channel %s: all files already exist. Subject skipped.\n',app.input_fbase,channel);
                        end

                    catch e
    
                        fprintf(fid, 'Subject %s, channel %s: not run. Error: %s\n',app.input_fbase,channel,e.message);

                    end

                end

            end
     
        end

    end
end