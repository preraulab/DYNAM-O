classdef DYNAMOFileManager < matlab.apps.AppBase & DYNAMO
    
    properties (Access = public)
        UIFigure matlab.ui.Figure
        
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
        
        % Output options panel components
        OutputPanel matlab.ui.container.Panel
        OutputLabel matlab.ui.control.Label
        OutputDirEditField matlab.ui.control.EditField
        OutputDirButton matlab.ui.control.Button
        OutputDirLabel matlab.ui.control.Label
        SavePeakStatsCheckBox matlab.ui.control.CheckBox
        SaveDataSummaryCheckBox matlab.ui.control.CheckBox
        SaveParamBasisCheckBox matlab.ui.control.CheckBox
        SaveParamImagesCheckBox matlab.ui.control.CheckBox
        SaveSplineBasisCheckBox matlab.ui.control.CheckBox
        SaveSplineImagesCheckBox matlab.ui.control.CheckBox
        SaveDateTimeCheckBox matlab.ui.control.CheckBox
        
        % Main control
        RunBatchButton matlab.ui.control.Button
        
        % Callback handles
        BatchProcessCallback function_handle
        FileValidationCallback function_handle

    end
    
    properties (Access = private)
        DataList cell = {}
        StagingList cell = {}

        % Misc for processing
        input_fbase = ''
        output_fig_name = ''
        output_stats_name = ''
        output_SOPH_name = '' 
        output_param_name = ''
        output_spline_name = ''
        date_time_save = ''
        
        % UI dimensions
        WindowWidth = 1200
        WindowHeight = 650
        PanelMargin = 20
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

            app.open; % Opens updateFileOptions app

        end
        
        function addDataFiles(app, filePaths)
            if ~iscell(filePaths), filePaths={filePaths}; end
            app.DataList = [app.DataList, filePaths];
            updateDataListBox(app);
            updateRunBatchButton(app);
        end
        
        function addStagingFiles(app, filePaths)
            if ~iscell(filePaths), filePaths={filePaths}; end
            app.StagingList = [app.StagingList, filePaths];
            updateStagingListBox(app);
            updateRunBatchButton(app);
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
            updateRunBatchButton(app);
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
            app.UIFigure = uifigure('Position',position,'Name',windowTitle, ...
                'Resize','on'); %'SizeChangedFcn',@app.onWindowResize);
            
            % Summary label
            app.SummaryLabel = uilabel(app.UIFigure,'Text',...
                'Add data and staging files, select output directory, choose options, then run batch.',...
                'Position',[app.PanelMargin,app.WindowHeight-40,app.WindowWidth-150,30],...
                'FontWeight','bold','HorizontalAlignment','center');
            
            % Help button
            app.HelpButton = uibutton(app.UIFigure,'push','Text','Help','Position',[app.WindowWidth-120,app.WindowHeight-35,100,25],...
                'ButtonPushedFcn',@(src,event) showHelp(app));
            
            createDataPanel(app);
            createStagingPanel(app);
            createOutputPanel(app);
            createMainControls(app);
            
            updateRunBatchButton(app);
        end
        
        function createDataPanel(app)
            panelWidth = (app.WindowWidth-4*app.PanelMargin)/3;
            app.DataPanel = uipanel(app.UIFigure,'Title','',...
                'Position',[app.PanelMargin,80,panelWidth,app.WindowHeight-150]);
            
            app.DataLabel = uilabel(app.DataPanel,'Text','Data (0 Files)',...
                'FontWeight','bold','HorizontalAlignment','center',...
                'Position',[10,app.WindowHeight-180,panelWidth-20,20]);
            
            % Direction label
            app.DataDirectionLabel = uilabel(app.DataPanel,'Text','Add your primary data files (EDF format). Use buttons to remove/reorder.',...
                'Position',[10,app.WindowHeight-210,panelWidth-20,20],'FontAngle','italic','FontSize',10);
            
            app.DataListBox = uilistbox(app.DataPanel,'Position',[10,50,panelWidth-20,app.WindowHeight-260],...
                'Multiselect','on','Items',{},'Value',{});
            
            app.DataButtonGroup = uibuttongroup(app.DataPanel,'Position',[15,10,panelWidth-30,35],'BorderType','none');
            buttonWidth = (panelWidth-50)/4;
            uibutton(app.DataButtonGroup,'push','Position',[5,5,buttonWidth,app.ButtonHeight],...
                'Text','Add','ButtonPushedFcn',@app.DataAddButtonPushed);
            uibutton(app.DataButtonGroup,'push','Position',[buttonWidth+10,5,buttonWidth,app.ButtonHeight],...
                'Text','Remove','ButtonPushedFcn',@app.DataRemoveButtonPushed);
            uibutton(app.DataButtonGroup,'push','Position',[2*buttonWidth+15,5,buttonWidth,app.ButtonHeight],...
                'Text','Up','ButtonPushedFcn',@app.DataMoveUpButtonPushed);
            uibutton(app.DataButtonGroup,'push','Position',[3*buttonWidth+20,5,buttonWidth,app.ButtonHeight],...
                'Text','Down','ButtonPushedFcn',@app.DataMoveDownButtonPushed);
        end
        
        function createStagingPanel(app)
            panelWidth = (app.WindowWidth-4*app.PanelMargin)/3;
            xPos = 2*app.PanelMargin+panelWidth;
            
            app.StagingPanel = uipanel(app.UIFigure,'Title','',...
                'Position',[xPos,80,panelWidth,app.WindowHeight-150]);
            
            app.StagingLabel = uilabel(app.StagingPanel,'Text','Staging (0 Files)',...
                'FontWeight','bold','HorizontalAlignment','center',...
                'Position',[10,app.WindowHeight-180,panelWidth-20,20]);
            
            % Direction label
            app.StagingDirectionLabel = uilabel(app.StagingPanel,'Text','Add staging files (CSV/TXT). Ensure order matches data files.',...
                'Position',[10,app.WindowHeight-210,panelWidth-20,20],'FontAngle','italic','FontSize',10);
            
            app.StagingListBox = uilistbox(app.StagingPanel,'Position',[10,50,panelWidth-20,app.WindowHeight-260],...
                'Multiselect','on','Items',{},'Value',{});
            
            app.StagingButtonGroup = uibuttongroup(app.StagingPanel,'Position',[15,10,panelWidth-30,35],'BorderType','none');
            buttonWidth = (panelWidth-50)/4;
            uibutton(app.StagingButtonGroup,'push','Position',[5,5,buttonWidth,app.ButtonHeight],'Text','Add','ButtonPushedFcn',@app.StagingAddButtonPushed);
            uibutton(app.StagingButtonGroup,'push','Position',[buttonWidth+10,5,buttonWidth,app.ButtonHeight],'Text','Remove','ButtonPushedFcn',@app.StagingRemoveButtonPushed);
            uibutton(app.StagingButtonGroup,'push','Position',[2*buttonWidth+15,5,buttonWidth,app.ButtonHeight],'Text','Up','ButtonPushedFcn',@app.StagingMoveUpButtonPushed);
            uibutton(app.StagingButtonGroup,'push','Position',[3*buttonWidth+20,5,buttonWidth,app.ButtonHeight],'Text','Down','ButtonPushedFcn',@app.StagingMoveDownButtonPushed);
        end
        
        function createOutputPanel(app)
            panelWidth = (app.WindowWidth-4*app.PanelMargin)/3;
            xPos = 3*app.PanelMargin+2*panelWidth;
            
            app.OutputPanel = uipanel(app.UIFigure,'Title','',...
                'Position',[xPos,80,panelWidth,app.WindowHeight-150]);
            
            app.OutputLabel = uilabel(app.OutputPanel,'Text','Output Options','FontWeight','bold',...
                'HorizontalAlignment','center','Position',[10,app.WindowHeight-180,panelWidth-20,20]);
            
            % Direction label
            app.OutputDirLabel = uilabel(app.OutputPanel,'Text','Select output directory and choose what to save.',...
                'Position',[10,app.WindowHeight-210,panelWidth-20,20],'FontAngle','italic','FontSize',10);
            
            app.OutputDirEditField = uieditfield(app.OutputPanel,'text','Position',[10,app.WindowHeight-240,panelWidth-90,25],...
                'ValueChangedFcn',@(src,event) outputDirChanged(app));
            app.OutputDirButton = uibutton(app.OutputPanel,'push','Text','Browse','Position',[panelWidth-70,app.WindowHeight-240,60,25],...
                'ButtonPushedFcn',@(src,event) browseOutputDir(app));
            
            yPos = app.WindowHeight-280; spacing = 30;
            app.SavePeakStatsCheckBox = uicheckbox(app.OutputPanel,'Text','Peak Stats Tables','Position',[10,yPos,panelWidth-20,22]);
            app.SaveDataSummaryCheckBox = uicheckbox(app.OutputPanel,'Text','Data Summary Images','Position',[10,yPos-spacing,panelWidth-20,22]);
            app.SaveParamBasisCheckBox = uicheckbox(app.OutputPanel,'Text','Parametric Basis','Position',[10,yPos-2*spacing,panelWidth-20,22]);
            app.SaveParamImagesCheckBox = uicheckbox(app.OutputPanel,'Text','Parametric Basis Images','Position',[10,yPos-3*spacing,panelWidth-20,22]);
            app.SaveSplineBasisCheckBox = uicheckbox(app.OutputPanel,'Text','Spline Basis','Position',[10,yPos-4*spacing,panelWidth-20,22]);
            app.SaveSplineImagesCheckBox = uicheckbox(app.OutputPanel,'Text','Spline Basis Images','Position',[10,yPos-5*spacing,panelWidth-20,22]);
        end
        
        function createMainControls(app)
            app.RunBatchButton = uibutton(app.UIFigure,'push',...
                'Position',[app.WindowWidth/2-60,20,120,40],...
                'Text','Run Batch','Enable','off','FontWeight','bold','FontSize',12,...
                'ButtonPushedFcn',@app.RunBatchButtonPushed);
        end
        
        %% ================== HELP ==================
        function showHelp(app)
            msg = ['Instructions:' newline ...
                '1. Add Data files (EDF) and Staging files (CSV/TXT).' newline ...
                '2. Make sure the file counts match and order corresponds.' newline ...
                '3. Choose an output directory and select save options.' newline ...
                '4. Click Run Batch to process files.'];
            uialert(app.UIFigure,msg,'Help','Icon','info');
        end
        
        %% ================== BUTTON CALLBACKS ==================
        function DataAddButtonPushed(app,~,~)
            files = selectFiles(app,'Select Data Files','data');
            if ~isempty(files)
                app.DataList = [app.DataList, files];
                updateDataListBox(app);
                updateRunBatchButton(app);
            end
        end
        
        function DataRemoveButtonPushed(app,~,~)
            selected = app.DataListBox.Value;
            if isempty(selected), return; end
            app.DataList = setdiff(app.DataList,selected,'stable');
            updateDataListBox(app);
            updateRunBatchButton(app);
        end
        
        function DataMoveUpButtonPushed(app,~,~)
            moveListItems(app,'data','up');
        end
        
        function DataMoveDownButtonPushed(app,~,~)
            moveListItems(app,'data','down');
        end
        
        function StagingAddButtonPushed(app,~,~)
            files = selectFiles(app,'Select Staging Files','staging');
            if ~isempty(files)
                app.StagingList = [app.StagingList, files];
                updateStagingListBox(app);
                updateRunBatchButton(app);
            end
        end
        
        function StagingRemoveButtonPushed(app,~,~)
            selected = app.StagingListBox.Value;
            if isempty(selected), return; end
            app.StagingList = setdiff(app.StagingList,selected,'stable');
            updateStagingListBox(app);
            updateRunBatchButton(app);
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
                        validFiles{end+1}=files{i};
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
            if isempty(pathStr), updateRunBatchButton(app); return; end
            if ~isfolder(pathStr)
                selection = uiconfirm(app.UIFigure,...
                    sprintf('Directory does not exist:\n%s\nCreate it?',pathStr),...
                    'Create Directory?','Options',{'Yes','No'},'DefaultOption',2);
                if strcmp(selection,'Yes'), mkdir(pathStr);
                else, app.OutputDirEditField.Value=''; end
            end
            updateRunBatchButton(app);
        end
        
        %% ================== WINDOW RESIZE ==================
        function onWindowResize(app,~,~)
            newPos = app.UIFigure.Position;
            app.WindowWidth=newPos(3); app.WindowHeight=newPos(4);
            
            panelWidth = (app.WindowWidth-4*app.PanelMargin)/3;
            % Summary & Help
            app.SummaryLabel.Position=[app.PanelMargin,app.WindowHeight-40,app.WindowWidth-150,30];
            app.HelpButton.Position=[app.WindowWidth-120,app.WindowHeight-35,100,25];
            
            % Panels
            app.DataPanel.Position=[app.PanelMargin,80,panelWidth,app.WindowHeight-150];
            app.DataLabel.Position=[10,app.WindowHeight-180,panelWidth-20,20];
            app.DataDirectionLabel.Position=[10,app.WindowHeight-210,panelWidth-20,20];
            app.DataListBox.Position=[10,50,panelWidth-20,app.WindowHeight-260];
            app.DataButtonGroup.Position=[15,10,panelWidth-30,35];
            
            xPos = 2*app.PanelMargin+panelWidth;
            app.StagingPanel.Position=[xPos,80,panelWidth,app.WindowHeight-150];
            app.StagingLabel.Position=[10,app.WindowHeight-180,panelWidth-20,20];
            app.StagingDirectionLabel.Position=[10,app.WindowHeight-210,panelWidth-20,20];
            app.StagingListBox.Position=[10,50,panelWidth-20,app.WindowHeight-260];
            app.StagingButtonGroup.Position=[15,10,panelWidth-30,35];
            
            xPos = 3*app.PanelMargin+2*panelWidth;
            app.OutputPanel.Position=[xPos,80,panelWidth,app.WindowHeight-150];
            app.OutputLabel.Position=[10,app.WindowHeight-180,panelWidth-20,20];
            app.OutputDirLabel.Position=[10,app.WindowHeight-210,panelWidth-20,20];
            app.OutputDirEditField.Position=[10,app.WindowHeight-240,panelWidth-90,25];
            app.OutputDirButton.Position=[panelWidth-70,app.WindowHeight-240,60,25];
            
            yPos = app.WindowHeight-280; spacing = 30;
            app.SavePeakStatsCheckBox.Position=[10,yPos,panelWidth-20,22];
            app.SaveDataSummaryCheckBox.Position=[10,yPos-spacing,panelWidth-20,22];
            app.SaveParamBasisCheckBox.Position=[10,yPos-2*spacing,panelWidth-20,22];
            app.SaveParamImagesCheckBox.Position=[10,yPos-3*spacing,panelWidth-20,22];
            app.SaveSplineBasisCheckBox.Position=[10,yPos-4*spacing,panelWidth-20,22];
            app.SaveSplineImagesCheckBox.Position=[10,yPos-5*spacing,panelWidth-20,22];
            
            % Run button
            app.RunBatchButton.Position=[app.WindowWidth/2-60,20,120,40];
        end
        
        %% ================== RUN BATCH ==================
        function RunBatchButtonPushed(app,~,~)
            if length(app.DataList) ~= length(app.StagingList)
                uialert(app.UIFigure,sprintf('Number of data files (%d) does not match staging files (%d)',...
                    length(app.DataList),length(app.StagingList)),'File Count Mismatch','Icon','error');
                return;
            end
            missing={};
            for f=[app.DataList,app.StagingList]
                if ~isfile(f{1}), missing{end+1}=f{1}; end
            end
            if ~isempty(missing)
                uialert(app.UIFigure,sprintf('Missing files:\n%s',strjoin(missing,'\n')),'File Missing','Icon','error');
                return;
            end
            uialert(app.UIFigure,'All files exist and counts match. Ready to process.','Success','Icon','success');
            
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

            % % Loop through objects
            for ii = 1:length(app.DataList)

                [~,app.input_fbase] = fileparts(app.DataList{ii});
                
                %% TO-DO: MAKE THE COLUMNS PART OF THE GUI
                 [app.data, app.Fs, app.stage_times, app.stage_vals] = load_data(app.DataList{ii},app.StagingList{ii},2,1,{'EEG'},'header_lines',1);
                %% TO-DO: GET RID OF HARD-CODED TIME RANGE VALUE ( THIS IS JUST FOR TESTING )
                app.time_range = [0 5000];

                % If Stats Table Requested
                if app.SavePeakStatsCheckBox.Value
                    
                    % Check if location exists
                    if ~exist(strcat(app.OutputDirEditField.Value,'/results/'),'dir')
                        mkdir(strcat(app.OutputDirEditField.Value,'/results/'))
                        %app.output_stats_name = strcat(app.OutputDirEditField.Value,'/results/',app.input_fbase,'_stats_table.mat');
                    end

                    app.run();

                    app.output_stats_name = strcat(app.OutputDirEditField.Value,'/results/',app.input_fbase,'_stats_table.mat');
                    app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/results/',app.input_fbase,'_SOPHs.mat');

                    stats_table = app.stats_table;
                    SOPHs = app.SOPHs;

                    save(app.output_stats_name,'stats_table');
                    save(app.output_SOPH_name,'SOPHs');
                    
                end

                % If Data Summary Image Requested
                if  app.SaveDataSummaryCheckBox.Value

                    if ~exist(strcat(app.OutputDirEditField.Value,'/summary_figures/'),'dir')
                        mkdir(strcat(app.OutputDirEditField.Value,'/summary_figures/'))
                    end

                    fh = app.displaySummaryPlot;

                    app.output_fig_name = strcat(app.OutputDirEditField.Value,'/summary_figures/',app.input_fbase,'_summary_figure.png');
                    print(fh,'-dpng','-r300',app.output_fig_name);
                    %exportgraphics(fh,app.output_fig_name,'Resolution',300);
                    close all;
                end

                % If Param Basis Requested
                if app.SaveParamBasisCheckBox.Value

                    if ~exist(strcat(app.OutputDirEditField.Value,'/summary_figures/'),'dir')
                        mkdir(strcat(app.OutputDirEditField.Value,'/summary_figures/'))
                    end
                    
                    if isempty(app.SOPHs)
                        app.run();
                    end
                  

                    app.fitParamBasis();
                    fh = gcf;
                    if app.SaveParamImagesCheckBox.Value
                        app.output_param_name = strcat(app.OutputDirEditField.Value,'/summary_figures/',app.input_fbase,'_param_basis_figure.png');
                        exportgraphics(fh,app.output_param_name,'Resolution',300);
                    end
                    close all;

                    app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/results/',app.input_fbase,'_SOPHs.mat');
                    SOPHs = app.SOPHs;
                    save(app.output_SOPH_name,'SOPHs');

                end

                % If Spline Basis Requested
                if app.SaveSplineBasisCheckBox.Value

                    if ~exist(strcat(app.OutputDirEditField.Value,'/summary_figures/'),'dir')
                        mkdir(strcat(app.OutputDirEditField.Value,'/summary_figures/'))
                    end
                    
                    if isempty(app.SOPHs)
                        app.run();
                    end

                    app.fitSplineBasis();
                    fh = gcf;
                    if app.SaveSplineImagesCheckBox.Value
                        app.output_spline_name = strcat(app.OutputDirEditField.Value,'/summary_figures/',app.input_fbase,'_spline_basis_figure.png');
                        exportgraphics(fh,app.output_spline_name,'Resolution',300);
                    end
                    close all;

                    app.output_SOPH_name = strcat(app.OutputDirEditField.Value,'/results/',app.input_fbase,'_SOPHs.mat');
                    SOPHs = app.SOPHs;
                    save(app.output_SOPH_name,'SOPHs');

                end


            end
     
        end

    end
end
