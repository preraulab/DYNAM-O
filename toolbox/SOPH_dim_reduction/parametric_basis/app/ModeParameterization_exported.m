classdef ModeParameterization_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        Toolbar                         matlab.ui.container.Toolbar
        ImportToolButton                matlab.ui.container.toolbar.PushTool
        RunToolButton                   matlab.ui.container.toolbar.PushTool
        GenerateFigureToolButton        matlab.ui.container.toolbar.PushTool
        GridLayout                      matlab.ui.container.GridLayout
        LeftPanel                       matlab.ui.container.Panel
        SelectionMethodDropDown         matlab.ui.control.DropDown
        SelectionMethodDropDownLabel    matlab.ui.control.Label
        GenerateFigureButton            matlab.ui.control.StateButton
        SubjectIndexSlider_2Label       matlab.ui.control.Label
        SubjectIndexSlider              matlab.ui.control.Slider
        IterationsCheckBox              matlab.ui.control.CheckBox
        SubjectIndexEdit                matlab.ui.control.NumericEditField
        StatusLabel                     matlab.ui.control.Label
        VerboseCheckBox                 matlab.ui.control.CheckBox
        LoaddataButton                  matlab.ui.control.Button
        RunButton                       matlab.ui.control.Button
        PhaseParametersPanel            matlab.ui.container.Panel
        FrequencyRangeEditField_2       matlab.ui.control.EditField
        FrequencyRangeEditField_2Label  matlab.ui.control.Label
        BlurFactorEditField             matlab.ui.control.NumericEditField
        BlurFactorEditFieldLabel        matlab.ui.control.Label
        LBDefaultEditField_2            matlab.ui.control.EditField
        LBDefaultEditField_2Label       matlab.ui.control.Label
        UBDefaultEditField_2            matlab.ui.control.EditField
        UBDefaultEditField_2Label       matlab.ui.control.Label
        MaxPeaksEditField_2             matlab.ui.control.NumericEditField
        MaxPeaksEditField_2Label        matlab.ui.control.Label
        MinAmpEditField_2               matlab.ui.control.NumericEditField
        MinAmpEditField_2Label          matlab.ui.control.Label
        MaxOverlapEditField_2           matlab.ui.control.NumericEditField
        MaxOverlapEditField_2Label      matlab.ui.control.Label
        WatershedParamsEditField_2      matlab.ui.control.EditField
        WatershedParamsEditField_2Label  matlab.ui.control.Label
        PowerParametersPanel            matlab.ui.container.Panel
        SOpowerRangeEditField           matlab.ui.control.EditField
        SOpowerRangeEditFieldLabel      matlab.ui.control.Label
        FrequencyRangeEditField         matlab.ui.control.EditField
        FrequencyRangeEditFieldLabel    matlab.ui.control.Label
        LBDefaultEditField              matlab.ui.control.EditField
        LBDefaultEditFieldLabel         matlab.ui.control.Label
        UBDefaultEditField              matlab.ui.control.EditField
        UBDefaultEditFieldLabel         matlab.ui.control.Label
        MaxPeaksEditField               matlab.ui.control.NumericEditField
        MaxPeaksEditFieldLabel          matlab.ui.control.Label
        MinAmpEditField                 matlab.ui.control.NumericEditField
        MinAmpEditFieldLabel            matlab.ui.control.Label
        MaxOverlapEditField             matlab.ui.control.NumericEditField
        MaxOverlapEditFieldLabel        matlab.ui.control.Label
        WatershedParamsEditField        matlab.ui.control.EditField
        WatershedParamsEditFieldLabel   matlab.ui.control.Label
        CenterPanel                     matlab.ui.container.Panel
        CenterGridPanel                 matlab.ui.container.Panel
        GridLayout2                     matlab.ui.container.GridLayout
        UIAxesSOPhH                     matlab.ui.control.UIAxes
        UIAxesSOPhHFit                  matlab.ui.control.UIAxes
        UIAxesPhaseWshed                matlab.ui.control.UIAxes
        UIAxesSOPHFit                   matlab.ui.control.UIAxes
        UIAxesSOPH                      matlab.ui.control.UIAxes
        UIAxesPowWshed                  matlab.ui.control.UIAxes
        RightPanel                      matlab.ui.container.Panel
        GridLayout3                     matlab.ui.container.GridLayout
        PhaseModeParametersLabel        matlab.ui.control.Label
        PowerModeParametersLabel        matlab.ui.control.Label
        UITablePhase                    matlab.ui.control.Table
        UITablePower                    matlab.ui.control.Table
    end

    % Properties that correspond to apps with auto-reflow
    properties (Access = private)
        onePanelWidth = 576;
        twoPanelWidth = 768;
    end


    properties (Access = public)
        SOPH
        SOPhH
        freq_bins
        SOpower_bins
        SOphase_bins
    end

    properties (Access = private)
        addData_fig % Description
        modeParams_fig
        SOPH_obj % Description
        SOPhH_obj
        params_power;
        params_phase;
        wshed_img_power;
        wshed_img_phase;
        SOPH_param;
        SOPhH_param;
        model_power;
        model_phase;
        valid_freqs_power;
        valid_freqs_phase;
        SOP_inds;
    end

    methods (Access = private)

        function onSelectButtonPushed(app, ddlSOPH, ddlSOPhH, ddlFreqBins, ddlSOPowerBins, ddlSOPhaseBins)
            % Get the selected variable names from the dropdowns
            selectedSOPH = ddlSOPH.Value;
            selectedSOPhH = ddlSOPhH.Value;
            selectedFreqBins = ddlFreqBins.Value;
            selectedSOPowerBins = ddlSOPowerBins.Value;
            selectedSOPhaseBins = ddlSOPhaseBins.Value;

            % Retrieve the variables from the base workspace and assign to the app properties
            app.SOPH = evalin('base', selectedSOPH);
            app.SOPhH = evalin('base', selectedSOPhH);
            app.freq_bins = evalin('base', selectedFreqBins);
            app.SOpower_bins = evalin('base', selectedSOPowerBins);
            app.SOphase_bins = evalin('base', selectedSOPhaseBins);

            if ~app.checkData
                return;
            end

            assert(ndims(app.SOPH) == ndims(app.SOPhH), 'Dims must be equal between SOPH and SOPhH');

            if ndims(app.SOPH) == 3 && ndims(app.SOPhH)
                app.SubjectIndexEdit.Visible = true;
                app.SubjectIndexSlider.Visible = true;
                app.SubjectIndexSlider_2Label.Visible = true;
                app.SubjectIndexSlider.Limits = [1 size(app.SOPH,3)];
                app.SubjectIndexEdit.Limits = [1 size(app.SOPH,3)];
            end

            % Close the dialog box
            delete(app.addData_fig);
            app.RunButton.Enable = true;
            app.RunToolButton.Enable = true;
            app.LoaddataButton.Enable = true;
            app.ImportToolButton.Enable = true;
            app.StatusLabel.Text = 'Data succesfully loaded';
        end

        function valid_data = checkData(app)
            msg_str = {};
            if(size(app.SOPH,1)~=length(app.freq_bins))
                msg_str{end+1} = 'Frequency bins must match SOPH rows';
            end
            if size(app.SOPhH,1)~=length(app.freq_bins)
                msg_str{end+1} = 'Frequency bins must match SOPhH rows';
            end
            if size(app.SOPH,2)~=length(app.SOpower_bins)
                msg_str{end+1} = 'SO-power bins must match SOPhH columns';
            end
            if size(app.SOPhH,2)~=length(app.SOphase_bins)
                msg_str{end+1} = 'SO-phase bins must match SOPhH columns';
            end

            if any(app.SOphase_bins>pi) || any(app.SOphase_bins)<-pi
                msg_str{end+1} = 'SO-phase bins must be between -pi and pi';
            end

            if ndims(app.SOPH) ~= ndims(app.SOPhH)
                msg_str{end+1} = 'SOPH and SOPhH must both either be 2D or 3D matrices';
            end

            if ~isempty(msg_str)
                warndlg(msg_str);
            end

            valid_data = isempty(msg_str);
        end

        function populateTables(app, ptable_power, ptable_phase, scatter_power, scatter_phase)
            if ~isempty(ptable_power)
                % Create the first uitable occupying the top half of the figure
                app.UITablePower.Data = ptable_power;
                app.UITablePower.ColumnName =  ptable_power.Properties.VariableNames;

                % Set up the scatter object callbacks
                scatter_power.ButtonDownFcn = @(src, event) onScatterClick(app.UITablePower, scatter_power, event.IntersectionPoint);
                scatter_power.HitTest = 'on';

                % Set up the uitable callbacks
                app.UITablePower.CellSelectionCallback = @(src, event) onTableSelect(scatter_power, event);
            end

            if ~isempty(ptable_phase)
                app.UITablePhase.Data = ptable_phase;
                app.UITablePhase.ColumnName =  ptable_phase.Properties.VariableNames;


                scatter_phase.ButtonDownFcn = @(src, event) onScatterClick(app.UITablePhase, scatter_phase, event.IntersectionPoint);
                scatter_phase.HitTest = 'on';


                app.UITablePhase.CellSelectionCallback = @(src, event) onTableSelect(scatter_phase, event);
            end

            % Function to handle hovering over the scatter plot
            function onScatterClick(uit, scatterObj,intersectionPoint)
                % Find the closest point in the scatter plot
                [minDist, idx] = min(vecnorm([scatterObj.XData; scatterObj.YData] - intersectionPoint(1:2)', 2, 1));
                if minDist < 0.1 % Adjust threshold as needed
                    % Highlight the corresponding row in the table
                    uit.SelectionType = 'row';
                    uit.Selection = idx; % Assumes the first column should be selected
                    highlightScatterPoint(scatterObj, idx);
                end
            end

            % Function to handle selection in the table
            function onTableSelect(scatterObj, event)
                if isempty(event.Indices)
                    return;
                end
                row = event.Indices(1);
                highlightScatterPoint(scatterObj, row);
            end

            % Helper function to highlight a point in the scatter plot
            function highlightScatterPoint(scatterObj, idx)
                resetScatterPoints(scatterObj)
                scatterObj.SizeData(idx) = 200; % Highlight size
                scatterObj.CData(idx,:) = [1 0 1]; % Highlight color (magenta)
            end

            % Helper function to reset scatter points to original state
            function resetScatterPoints(scatterObj)
                N = length(scatterObj.XData);
                scatterObj.SizeData = 60*ones(1,N); % Reset all sizes
                scatterObj.CData(:,:) = repmat([1 0 1],N,1); % Reset all colors
            end
        end

        function createSummaryFigure(app)
            %Parameterize the data
            figure;
            ax = figdesign(2,3,'type','usletter','orient','landscape','margins',[.05 .05 .05 .05 .03]);
            set(gcf,'position',[0.0439    0.0868    0.5526    0.7382]);

            linkaxes(ax(1:3));
            linkaxes(ax(4:6));

            ax_font_size = 18;
            title_font_size = 20;


            axes(ax(1))
            imagesc(ax(1), app.SOpower_bins(app.SOP_inds), app.freq_bins(app.valid_freqs_power), app.wshed_img_power);
            axis(ax(1),'xy');
            ylabel(ax(1),'Frequency (Hz)')
            xlabel(ax(1),'  ')
            set(ax(1),'fontsize',ax_font_size);
            title(ax(1),'Watershed','FontSize',title_font_size);

            axes(ax(2))
            imagesc(ax(2), app.SOpower_bins(app.SOP_inds), app.freq_bins(app.valid_freqs_power), app.SOPH_param);
            axis(ax(2),'xy');
            xlabel(ax(2),'SO-power (dB)')
            ylabel(ax(2),'  ')
            cx = climscale(ax(2),[],false);
            colormap(ax(2),gouldian)
            set(ax(2),'fontsize',ax_font_size);
            title(ax(2),'SO-Power Histogram','FontSize',title_font_size);

            axes(ax(3))
            hold(ax(3),'on');
            imagesc(ax(3), app.SOpower_bins(app.SOP_inds), app.freq_bins(app.valid_freqs_power), app.model_power);
            axis(ax(3),'xy');
            caxis(ax(3),cx);
            xlabel(ax(3),'  ')
            ylabel(ax(3),'  ')
            colormap(ax(3),gouldian)
            axis(ax(3),'tight');
            scatter(ax(3), app.params_power(:,4), app.params_power(:,2),60*ones(1,size(app.params_power,1)),repmat([1 0 1], size(app.params_power,1), 1),'filled','o','MarkerEdgeColor','k');
            colorbar_noresize(ax(3));

            set(ax(3),'fontsize',ax_font_size);
            title(ax(3),'Model','FontSize',title_font_size);

            ylim(ax(1:3),[min(app.freq_bins(app.valid_freqs_power)) max(app.freq_bins(app.valid_freqs_power))]);
            xlim(ax(1:3),[min(app.SOpower_bins(app.SOP_inds)) max(app.SOpower_bins(app.SOP_inds))]);

            axes(ax(4))
            imagesc(ax(4),[app.SOphase_bins-2*pi, app.SOphase_bins, app.SOphase_bins + 2*pi], app.freq_bins(app.valid_freqs_phase), app.wshed_img_phase);
            axis(ax(4),'xy');
            ylabel(ax(4),'Frequency (Hz)')
            xlabel(ax(4),'  ')
            xlim(ax(4),[-pi pi])
            set(ax(4),'fontsize',ax_font_size);
            title(ax(4),'Watershed','FontSize',title_font_size);

            axes(ax(5))
            imagesc(ax(5),app.SOphase_bins, app.freq_bins(app.valid_freqs_phase), app.SOPhH_param);
            axis(ax(5),'xy');
            xlabel(ax(5), 'SO-power (dB)')
            ylabel(ax(5), '  ')
            cx = climscale(ax(5),[],false);
            colormap(ax(5),magma)
            set(ax(5),'fontsize',ax_font_size);
            title(ax(5),'SO-Phase Histogram','FontSize',title_font_size);

            axes(ax(6))
            hold(ax(6),'on');
            imagesc(ax(6),app.SOphase_bins, app.freq_bins(app.valid_freqs_phase), app.model_phase);
            axis(ax(6),'xy');
            caxis(ax(6),cx);
            ylabel(ax(6),'  ');
            xlabel(ax(6),'  ');
            colormap(ax(6),magma)
            scatter(ax(6), app.params_phase(:,4), app.params_phase(:,2),60*ones(1,size(app.params_phase,1)),repmat([1 0 1], size(app.params_phase,1), 1),'filled','o','MarkerEdgeColor','k');
            axis(ax(6),'tight');
            title(ax(6),'Model','FontSize',title_font_size);
            colorbar_noresize(ax(6));

            ylim(ax(4:6),[min(app.freq_bins(app.valid_freqs_phase)) max(app.freq_bins(app.valid_freqs_phase))]);
            xlim(ax(4:6),[-pi pi]);

            set(ax(4:6),'XTick',[-pi -pi/2 0 pi/2 pi],'XTickLabel',{'-\pi', '-\pi/2' '0' '\pi/2' '\pi'})
            set(ax(6),'fontsize',ax_font_size);

            if app.SubjectIndexEdit.Visible
                s= suptitle(['Subject Index: ' num2str(app.SubjectIndexSlider.Value)]);
                s.FontSize = 30;
            end
        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, all_SOPH, all_SOPhH, freq_bins, SOpower_bins, SOphase_bins)

            app.UIFigure.Name = 'DYNAM-O Toolbox Mode Parameterization';
            disableDefaultInteractivity(app.UIAxesSOPHFit);
            disableDefaultInteractivity(app.UIAxesSOPhHFit);
            app.UIAxesSOPHFit.Toolbar = [];
            app.UIAxesSOPhHFit.Toolbar = [];

            %Populate the defaults with the structure defaults
            params_pow = param_basis_opts('power');

            app.LBDefaultEditField.Value = regexprep(value2str(params_pow.LB_default), '\s+', ', ');
            app.UBDefaultEditField.Value  = regexprep(value2str(params_pow.UB_default), '\s+', ', ');
            app.MaxPeaksEditField.Value = params_pow.max_peaks;
            app.MinAmpEditField.Value  = params_pow.min_amp;
            app.MaxOverlapEditField.Value = params_pow.max_overlap;
            app.WatershedParamsEditField.Value = regexprep(value2str(params_pow.watershed_params), '\s+', ', ');
            app.FrequencyRangeEditField.Value = '[2 16]';
            app.SOpowerRangeEditField.Value = '[0 20]';

            param_opts = param_basis_opts('phase');

            app.FrequencyRangeEditField_2.Value = '[2 16]';
            app.LBDefaultEditField_2.Value = regexprep(value2str(param_opts.LB_default), '\s+', ', ');
            app.UBDefaultEditField_2.Value = regexprep(value2str(param_opts.UB_default), '\s+', ', ');
            app.MaxPeaksEditField_2.Value = param_opts.max_peaks;
            app.MinAmpEditField_2.Value  = param_opts.min_amp;
            app.MaxOverlapEditField_2.Value = param_opts.max_overlap;
            app.BlurFactorEditField.Value = param_opts.gauss_filt_std;
            app.WatershedParamsEditField_2.Value = regexprep(value2str(param_opts.watershed_params), '\s+', ', ');

            app.SubjectIndexEdit.Visible = false;
            app.SubjectIndexSlider.Visible = false;
            app.SubjectIndexSlider_2Label.Visible = false;

            %Grab the data
            if nargin>1
                app.SOPH = SOPH;
                app.SOPhH = SOPhH;
                app.freq_bins = freq_bins;
                app.SOpower_bins = SOpower_bins;
                app.SOphase_bins = SOphase_bins;

                if ~app.checkData
                    app.RunButton.Enable = false;
                    app.RunToolButton.Enable = false;
                    app.GenerateFigureButton.Enable = false;
                    app.GenerateFigureToolButton.Enable = false;
                    app.ImportButtonPushed;
                end

            else
                app.RunButton.Enable = false;
                app.RunToolButton.Enable = false;
                app.GenerateFigureButton.Enable = false;
                app.GenerateFigureToolButton.Enable = false;
                app.ImportButtonPushed;
            end

            if ndims(app.SOPH)==3
                app.SubjectIndexEdit.Visible = true;
                app.SubjectIndexSlider.Visible = true;
                app.SubjectIndexSlider_2Label.Visible = true;
            end

        end

        % Callback function: RunButton, RunToolButton
        function ParameterizeModesButtonPushed(app, event)
            %Check that there are valid data
            if isempty(app.SOPH) || isempty(app.SOPhH) || isempty(app.freq_bins) || isempty(app.SOpower_bins) || isempty(app.SOphase_bins)
                app.SelectDatafromWorkspaceButtonPushed;
                return;
            end

            % app.RunButton.Enable = false;
            % app.LoaddataButton.Enable = false;
            %
            % app.RunToolButton.Enable = false;
            % app.ImportToolButton.Enable = false;
            %
            % app.GenerateFigureToolButton.Enable = false;
            % app.GenerateFigureButton.Enable = false;

            if ndims(app.SOPH) == 3
                app.SOPH_param = squeeze(app.SOPH(:,:,app.SubjectIndexSlider.Value));
                app.SOPhH_param = squeeze(app.SOPhH(:,:,app.SubjectIndexSlider.Value));
            else
                app.SOPH_param = app.SOPH;
                app.SOPhH_param = app.SOPhH;
            end



            freq_range_power = str2num(app.FrequencyRangeEditField.Value);
            freq_range_phase = str2num(app.FrequencyRangeEditField_2.Value);
            SOP_range = str2num(app.SOpowerRangeEditField.Value);
            freq_inds_power = app.freq_bins >= freq_range_power(1) & app.freq_bins <= freq_range_power(2);
            freq_inds_phase = app.freq_bins >= freq_range_phase(1) & app.freq_bins <= freq_range_phase(2);
            app.SOP_inds = app.SOpower_bins >= SOP_range(1) & app.SOpower_bins <= SOP_range(2);
            app.valid_freqs_power = ~all(isnan(app.SOPH_param),2) & freq_inds_power';
            app.valid_freqs_phase = ~all(isnan(app.SOPhH_param),2) & freq_inds_phase';
            valid_SOpow = ~all(isnan(app.SOPH_param),1) & app.SOP_inds;

            app.SOPH_param = double(app.SOPH_param(app.valid_freqs_power, valid_SOpow));
            app.SOPhH_param = double(app.SOPhH_param(app.valid_freqs_phase, :));

            %Load the data into the structs
            LB_pow = str2num(app.LBDefaultEditField.Value); %#ok<*ST2NM>
            UB_pow = str2num(app.UBDefaultEditField.Value);
            max_peaks_pow = app.MaxPeaksEditField.Value;
            min_amp_pow = app.MinAmpEditField.Value;
            max_ol_pow = app.MaxOverlapEditField.Value;
            wshed_params =  str2num(app.WatershedParamsEditField.Value);

            if app.IterationsCheckBox.Value
                plot_on = 2;
            else
                plot_on = false;
            end

            opts_power = param_basis_opts('power','UB_default', UB_pow, 'LB_default', LB_pow,'max_peaks',max_peaks_pow,...
                'watershed_params',wshed_params,'min_amp',min_amp_pow,'max_overlap',max_ol_pow,'plot_on',plot_on,'verbose',...
                app.VerboseCheckBox.Value,'criterion',app.SelectionMethodDropDown.Value);

            LB_phase = str2num(app.LBDefaultEditField_2.Value);
            UB_phase = str2num(app.UBDefaultEditField_2.Value);
            max_peaks_phase = app.MaxPeaksEditField_2.Value;
            min_amp_phase = app.MinAmpEditField_2.Value;
            max_ol_phase = app.MaxOverlapEditField_2.Value;
            wshed_params =  str2num(app.WatershedParamsEditField_2.Value);
            gauss_std = app.BlurFactorEditField.Value;

            opts_phase = param_basis_opts('phase','UB_default', UB_phase, 'LB_default', LB_phase,'max_peaks',max_peaks_phase,...
                'watershed_params',wshed_params,'min_amp',min_amp_phase,'max_overlap',max_ol_phase,'gauss_filt_std', gauss_std,...
                'plot_on',plot_on,'verbose',app.VerboseCheckBox.Value,'criterion',app.SelectionMethodDropDown.Value);

            %Parameterize the data
            ax = [app.UIAxesPowWshed app.UIAxesSOPH app.UIAxesSOPHFit app.UIAxesPhaseWshed app.UIAxesSOPhH app.UIAxesSOPhHFit];

            cla(ax)

            linkaxes(ax(1:3));
            linkaxes(ax(4:6));

            ax_font_size = 18;
            title_font_size = 20;

            app.StatusLabel.Text = 'Computing power parameterization...';
            [app.params_power, ~, ~, app.model_power, app.wshed_img_power] = param_basis_power(app.SOPH_param, app.SOpower_bins(app.SOP_inds), app.freq_bins(app.valid_freqs_power), opts_power);

            if ~isempty(app.params_power)
                mode_table_power = array2table(app.params_power,'VariableNames',{'Amplitude','Frequency','SDfreq','SOPower','SDpower','Theta'});
             else
                mode_table_power = [];
            end


            app.StatusLabel.Text = 'Plotting...';
            axes(ax(1))
            imagesc(ax(1), app.SOpower_bins(app.SOP_inds), app.freq_bins(app.valid_freqs_power), app.wshed_img_power);
            axis(ax(1),'xy');
            ylabel(ax(1),'Frequency (Hz)')
            xlabel(ax(1),'  ')
            set(ax(1),'fontsize',ax_font_size);
            title(ax(1),'Watershed','FontSize',title_font_size);

            axes(ax(2))
            imagesc(ax(2), app.SOpower_bins(app.SOP_inds), app.freq_bins(app.valid_freqs_power), app.SOPH_param);
            axis(ax(2),'xy');
            xlabel(ax(2),'SO-power (dB)')
            ylabel(ax(2),'  ')
            cx = climscale(ax(2),[],false);
            colormap(ax(2),gouldian)
            set(ax(2),'fontsize',ax_font_size);
            title(ax(2),'SO-Power Histogram','FontSize',title_font_size);

            axes(ax(3))
            hold(ax(3),'on');
            imagesc(ax(3), app.SOpower_bins(app.SOP_inds), app.freq_bins(app.valid_freqs_power), app.model_power);
            axis(ax(3),'xy');
            caxis(ax(3),cx);
            xlabel(ax(3),'  ')
            ylabel(ax(3),'  ')
            colormap(ax(3),gouldian)
            axis(ax(3),'tight');
            if ~isempty(app.params_power)
                param_points_power =  scatter(ax(3), app.params_power(:,4), app.params_power(:,2),60*ones(1,size(app.params_power,1)),repmat([1 0 1], size(app.params_power,1), 1),'filled','o','MarkerEdgeColor','k');
            else
                param_points_power =[];
            end
            set(ax(3),'fontsize',ax_font_size);
            title(ax(3),'Model','FontSize',title_font_size);

            ylim(ax(1:3),[min(app.freq_bins(app.valid_freqs_power)) max(app.freq_bins(app.valid_freqs_power))]);
            xlim(ax(1:3),[min(app.SOpower_bins(app.SOP_inds)) max(app.SOpower_bins(app.SOP_inds))]);


            app.StatusLabel.Text = 'Computing phase parameterization...';
xow            [app.params_phase, ~, ~, app.model_phase, app.wshed_img_phase] = param_basis_phase(app.SOPhH_param, app.SOphase_bins, app.freq_bins(app.valid_freqs_phase),opts_phase);

            if ~isempty(app.params_phase)
                mode_table_phase = array2table(app.params_phase,'VariableNames',{'Amplitude','Frequency','SDfreq','SOPower','SDpower','Theta'});
            else
                mode_table_phase = [];
            end

            %Update the plots
            app.StatusLabel.Text = 'Plotting...';
            axes(ax(4))
            imagesc(ax(4),[app.SOphase_bins-2*pi, app.SOphase_bins, app.SOphase_bins + 2*pi], app.freq_bins(app.valid_freqs_phase), app.wshed_img_phase);
            axis(ax(4),'xy');
            ylabel(ax(4),'Frequency (Hz)')
            xlabel(ax(4),'  ')
            xlim(ax(4),[-pi pi])
            set(ax(4),'fontsize',ax_font_size);
            title(ax(4),'Watershed','FontSize',title_font_size);

            axes(ax(5))
            imagesc(ax(5),app.SOphase_bins, app.freq_bins(app.valid_freqs_phase), app.SOPhH_param);
            axis(ax(5),'xy');
            xlabel(ax(5), 'SO-power (dB)')
            ylabel(ax(5), '  ')
            cx = climscale(ax(5),[],false);
            colormap(ax(5),magma)
            set(ax(5),'fontsize',ax_font_size);
            title(ax(5),'SO-Phase Histogram','FontSize',title_font_size);

            axes(ax(6))
            hold(ax(6),'on');
            imagesc(ax(6),app.SOphase_bins, app.freq_bins(app.valid_freqs_phase), app.model_phase);
            axis(ax(6),'xy');
            caxis(ax(6),cx);
            ylabel(ax(6),'  ');
            xlabel(ax(6),'  ');
            colormap(ax(6),magma)
            if ~isempty(app.params_phase)
                param_points_phase =  scatter(ax(6), app.params_phase(:,4), app.params_phase(:,2),60*ones(1,size(app.params_phase,1)),repmat([1 0 1], size(app.params_phase,1), 1),'filled','o','MarkerEdgeColor','k');
            else
                param_points_phase =[];
            end
            axis(ax(6),'tight');
            title(ax(6),'Model','FontSize',title_font_size);
            ylim(ax(4:6),[min(app.freq_bins(app.valid_freqs_phase)) max(app.freq_bins(app.valid_freqs_phase))]);
            xlim(ax(4:6),[-pi pi]);

            set(ax(4:6),'XTick',[-pi -pi/2 0 pi/2 pi],'XTickLabel',{'-\pi', '-\pi/2' '0' '\pi/2' '\pi'})
            set(ax(6),'fontsize',ax_font_size);


            app.populateTables(mode_table_power, mode_table_phase, param_points_power, param_points_phase);

            app.RunButton.Enable = true;
            app.LoaddataButton.Enable = true;

            app.RunToolButton.Enable = true;
            app.ImportToolButton.Enable = true;

            app.GenerateFigureToolButton.Enable = true;
            app.GenerateFigureButton.Enable = true;
            app.StatusLabel.Text = 'Parameterization complete.';
            if app.SubjectIndexEdit.Visible
                app.UIFigure.Name = ['DYNAM-O Toolbox Mode Parameterization: Subject ' num2str(app.SubjectIndexSlider.Value)];
            end
        end

        % Callback function
        function SelectDatafromWorkspaceButtonPushed(app, event)



        end

        % Value changing function: SubjectIndexSlider
        function SubjectIndexSliderValueChanging(app, event)
            changingValue = round(event.Value);
            app.SubjectIndexSlider.Value = changingValue;

            app.SubjectIndexEdit.Value = changingValue;
            app.StatusLabel.Text = ['Loading subject ' num2str(changingValue)];
        end

        % Value changed function: SubjectIndexSlider
        function SubjectIndexSliderValueChanged(app, event)
            value = round(app.SubjectIndexEdit.Value);
            limits = app.SubjectIndexSlider.Limits;
            if value<limits(1)
                value = limits(1);
                app.SubjectIndexEdit.Value = value;
                warndlg(['Values must be integers between ' num2str(limits(1)) ' and ' num2str(limits(2))])
            end

            if value>limits(2)
                value=limits(2);
                app.SubjectIndexEdit.Value = value;
                warndlg(['Values must be integers between ' num2str(limits(1)) ' and ' num2str(limits(2))])
            end
            app.SubjectIndexSlider.Value = value;
            app.StatusLabel.Text = ['Loading subject ' num2str(value)];
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            delete(app.addData_fig);
            delete(app)
        end

        % Value changed function: SubjectIndexEdit
        function SubjectIndexEditValueChanged(app, event)
            value = round(app.SubjectIndexEdit.Value);

            app.SubjectIndexSlider.Value = value;
        end

        % Callback function: ImportToolButton, LoaddataButton
        function ImportButtonPushed(app, event)
            app.LoaddataButton.Enable = false;
            app.ImportToolButton.Enable = false;

            app.SubjectIndexEdit.Visible = false;
            app.SubjectIndexSlider.Visible = false;

            app.StatusLabel.Text = 'Select file to load...';
            [filename, pathname] = uigetfile( ...
                {'*.mat', 'All MATLAB Files (*.mat)';
                '*.*',  'All Files (*.*)'}, ...
                'Pick a file');


            if ~(filename)
                app.LoaddataButton.Enable = true;
                app.ImportToolButton.Enable = true;
                return;
            end

            if ~exist(fullfile(pathname, filename),'file')
                errordlg('Bad filename');
                app.LoaddataButton.Enable = true;
                app.ImportToolButton.Enable = true;
                return;
            end

            app.StatusLabel.Text = 'Loading data...';
            data = load(fullfile(pathname, filename));
            % Assign all loaded variables to the base workspace
            varNames = fieldnames(data);
            for i = 1:length(varNames)
                assignin('base', varNames{i}, data.(varNames{i}));
            end

            app.StatusLabel.Text = 'Data Loaded';

            % Create the uifigure dialog box
            if ~isempty(app.addData_fig) && isvalid(app.addData_fig)
                close(app.addData_fig);
                app.LoaddataButton.Enable = true;
                app.ImportToolButton.Enable = true;
            end

            app.addData_fig = uifigure('Name', 'Select Variables from Workspace', 'Position', [100 100 500 350]);

            % Get the variables from the base workspace
            vars = evalin('base','whos');

            % Filter variables for vectors (1D) and 2D/3D matrices
            valid_inds = ismember({vars.class},{'double','single'});
            matrix_inds = cellfun(@(x)all(x>1),{vars.size}) & valid_inds;
            vector_inds = cellfun(@(x)sum(x>1)==1,{vars.size}) & valid_inds;
            vectorVars = {vars(vector_inds).name};
            matrixVars = {vars(matrix_inds).name};

            % Create labels and dropdown menus for each variable.
            %Sort by best guess for each parameter
            uilabel(app.addData_fig, 'Text', 'Select SO-power Histogram:', 'Position', [20 300 170 22]);
            [~, sinds] = sort(contains(matrixVars,{'SOPH'}),'descend');
            SOPHVars =  matrixVars(sinds);
            ddlSOPH = uidropdown(app.addData_fig, 'Items', SOPHVars, 'Position', [180 300 240 22]);

            uilabel(app.addData_fig, 'Text', 'Select SO-phase Histogram:', 'Position', [20 250 170 22]);
            [~, sinds] = sort(contains(matrixVars,{'SOPhH'}),'descend');
            SOPhHVars =  matrixVars(sinds);
            ddlSOPhH = uidropdown(app.addData_fig, 'Items', SOPhHVars, 'Position', [180 250 240 22]);

            uilabel(app.addData_fig, 'Text', 'Select Frequency Bins:', 'Position', [20 200 150 22]);
            [~, sinds] = sort(contains(vectorVars,{'freq'}),'descend');
            freqVars =  vectorVars(sinds);
            ddlFreqBins = uidropdown(app.addData_fig, 'Items', freqVars, 'Position', [180 200 240 22]);

            [~, sinds] = sort(contains(vectorVars,{'pow'}),'descend');
            powVars =  vectorVars(sinds);
            uilabel(app.addData_fig, 'Text', 'Select SO-Power Bins:', 'Position', [20 150 150 22]);
            ddlSOPowerBins = uidropdown(app.addData_fig, 'Items', powVars, 'Position', [180 150 240 22]);

            [~, sinds] = sort(contains(vectorVars,{'phase'}),'descend');
            phaseVars =  vectorVars(sinds);
            uilabel(app.addData_fig, 'Text', 'Select SO-Phase Bins:', 'Position', [20 100 150 22]);
            ddlSOPhaseBins = uidropdown(app.addData_fig, 'Items', phaseVars, 'Position', [180 100 240 22]);

            % Create the button
            uibutton(app.addData_fig, ...
                'Text', 'Select', ...
                'Position', [150 30 100 30], ...
                'ButtonPushedFcn', @(btn, event) onSelectButtonPushed(app, ddlSOPH, ddlSOPhH, ddlFreqBins, ddlSOPowerBins, ddlSOPhaseBins));

            %Disable closing
            app.addData_fig.CloseRequestFcn = [];

            app.StatusLabel.Text = 'Select variables from the workspace';

        end

        % Callback function: GenerateFigureButton, GenerateFigureToolButton
        function ImgenToolButtonClicked(app, event)
            app.createSummaryFigure;
        end

        % Changes arrangement of the app based on UIFigure width
        function updateAppLayout(app, event)
            currentFigureWidth = app.UIFigure.Position(3);
            if(currentFigureWidth <= app.onePanelWidth)
                % Change to a 3x1 grid
                app.GridLayout.RowHeight = {805, 805, 805};
                app.GridLayout.ColumnWidth = {'1x'};
                app.CenterPanel.Layout.Row = 1;
                app.CenterPanel.Layout.Column = 1;
                app.LeftPanel.Layout.Row = 2;
                app.LeftPanel.Layout.Column = 1;
                app.RightPanel.Layout.Row = 3;
                app.RightPanel.Layout.Column = 1;
            elseif (currentFigureWidth > app.onePanelWidth && currentFigureWidth <= app.twoPanelWidth)
                % Change to a 2x2 grid
                app.GridLayout.RowHeight = {805, 805};
                app.GridLayout.ColumnWidth = {'1x', '1x'};
                app.CenterPanel.Layout.Row = 1;
                app.CenterPanel.Layout.Column = [1,2];
                app.LeftPanel.Layout.Row = 2;
                app.LeftPanel.Layout.Column = 1;
                app.RightPanel.Layout.Row = 2;
                app.RightPanel.Layout.Column = 2;
            else
                % Change to a 1x3 grid
                app.GridLayout.RowHeight = {'1x'};
                app.GridLayout.ColumnWidth = {467, '1x', 490};
                app.LeftPanel.Layout.Row = 1;
                app.LeftPanel.Layout.Column = 1;
                app.CenterPanel.Layout.Row = 1;
                app.CenterPanel.Layout.Column = 2;
                app.RightPanel.Layout.Row = 1;
                app.RightPanel.Layout.Column = 3;
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Color = [1 1 1];
            app.UIFigure.Position = [100 100 2169 805];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @updateAppLayout, true);

            % Create Toolbar
            app.Toolbar = uitoolbar(app.UIFigure);

            % Create ImportToolButton
            app.ImportToolButton = uipushtool(app.Toolbar);
            app.ImportToolButton.Tooltip = {'Load data...'};
            app.ImportToolButton.ClickedCallback = createCallbackFcn(app, @ImportButtonPushed, true);
            app.ImportToolButton.Icon = fullfile(pathToMLAPP, 'import.png');

            % Create RunToolButton
            app.RunToolButton = uipushtool(app.Toolbar);
            app.RunToolButton.Tooltip = {'Parameterize Modes'};
            app.RunToolButton.ClickedCallback = createCallbackFcn(app, @ParameterizeModesButtonPushed, true);
            app.RunToolButton.Icon = fullfile(pathToMLAPP, 'run.png');

            % Create GenerateFigureToolButton
            app.GenerateFigureToolButton = uipushtool(app.Toolbar);
            app.GenerateFigureToolButton.Tooltip = {'Generate Figure'};
            app.GenerateFigureToolButton.ClickedCallback = createCallbackFcn(app, @ImgenToolButtonClicked, true);
            app.GenerateFigureToolButton.Icon = fullfile(pathToMLAPP, 'image.png');

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {467, '1x', 490};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Scrollable = 'on';

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            % Create PowerParametersPanel
            app.PowerParametersPanel = uipanel(app.LeftPanel);
            app.PowerParametersPanel.Title = 'Power Parameters';
            app.PowerParametersPanel.BackgroundColor = [1 1 1];
            app.PowerParametersPanel.FontWeight = 'bold';
            app.PowerParametersPanel.FontSize = 18;
            app.PowerParametersPanel.Position = [20 513 429 281];

            % Create WatershedParamsEditFieldLabel
            app.WatershedParamsEditFieldLabel = uilabel(app.PowerParametersPanel);
            app.WatershedParamsEditFieldLabel.HorizontalAlignment = 'right';
            app.WatershedParamsEditFieldLabel.Position = [12 164 107 22];
            app.WatershedParamsEditFieldLabel.Text = 'Watershed Params';

            % Create WatershedParamsEditField
            app.WatershedParamsEditField = uieditfield(app.PowerParametersPanel, 'text');
            app.WatershedParamsEditField.Tooltip = {'Controls the watershed parameters for the SOPH:'; '       merge_thresh: Threshold weight value for stopping the merge'; '       dur_min: Minimum duration allowed for peaks'; '       bw_min: Minimum bandwidth allowed for peaks'; '       height_min: Minimum height allowed for peaks'; '       trim_vol: Fraction of the maximum trimmed volume (from 0 to 1)'};
            app.WatershedParamsEditField.Position = [134 164 283 22];

            % Create MaxOverlapEditFieldLabel
            app.MaxOverlapEditFieldLabel = uilabel(app.PowerParametersPanel);
            app.MaxOverlapEditFieldLabel.HorizontalAlignment = 'right';
            app.MaxOverlapEditFieldLabel.Position = [17 125 73 22];
            app.MaxOverlapEditFieldLabel.Text = 'Max Overlap';

            % Create MaxOverlapEditField
            app.MaxOverlapEditField = uieditfield(app.PowerParametersPanel, 'numeric');
            app.MaxOverlapEditField.Tooltip = {'The maximum overlap in %area allowed for a valid peak'};
            app.MaxOverlapEditField.Position = [139 125 53 22];
            app.MaxOverlapEditField.Value = 0.25;

            % Create MinAmpEditFieldLabel
            app.MinAmpEditFieldLabel = uilabel(app.PowerParametersPanel);
            app.MinAmpEditFieldLabel.HorizontalAlignment = 'right';
            app.MinAmpEditFieldLabel.Position = [37 93 53 22];
            app.MinAmpEditFieldLabel.Text = 'Min Amp';

            % Create MinAmpEditField
            app.MinAmpEditField = uieditfield(app.PowerParametersPanel, 'numeric');
            app.MinAmpEditField.Tooltip = {'Minumum peak amplitude allowed for valid peak'};
            app.MinAmpEditField.Position = [139 93 53 22];
            app.MinAmpEditField.Value = 0.75;

            % Create MaxPeaksEditFieldLabel
            app.MaxPeaksEditFieldLabel = uilabel(app.PowerParametersPanel);
            app.MaxPeaksEditFieldLabel.HorizontalAlignment = 'right';
            app.MaxPeaksEditFieldLabel.Position = [237 125 64 22];
            app.MaxPeaksEditFieldLabel.Text = 'Max Peaks';

            % Create MaxPeaksEditField
            app.MaxPeaksEditField = uieditfield(app.PowerParametersPanel, 'numeric');
            app.MaxPeaksEditField.ValueDisplayFormat = '%.0f';
            app.MaxPeaksEditField.Tooltip = {'Maximum number of peaks to try from watershed results + extra'};
            app.MaxPeaksEditField.Position = [350 125 53 22];
            app.MaxPeaksEditField.Value = 6;

            % Create UBDefaultEditFieldLabel
            app.UBDefaultEditFieldLabel = uilabel(app.PowerParametersPanel);
            app.UBDefaultEditFieldLabel.HorizontalAlignment = 'right';
            app.UBDefaultEditFieldLabel.Position = [24 54 63 22];
            app.UBDefaultEditFieldLabel.Text = 'UB Default';

            % Create UBDefaultEditField
            app.UBDefaultEditField = uieditfield(app.PowerParametersPanel, 'text');
            app.UBDefaultEditField.Tooltip = {'Upper bounds on the SOPH model parameters [amp, freq, freq_std, power, power_std, theta]'};
            app.UBDefaultEditField.Position = [102 54 315 22];

            % Create LBDefaultEditFieldLabel
            app.LBDefaultEditFieldLabel = uilabel(app.PowerParametersPanel);
            app.LBDefaultEditFieldLabel.HorizontalAlignment = 'right';
            app.LBDefaultEditFieldLabel.Position = [26 24 61 22];
            app.LBDefaultEditFieldLabel.Text = 'LB Default';

            % Create LBDefaultEditField
            app.LBDefaultEditField = uieditfield(app.PowerParametersPanel, 'text');
            app.LBDefaultEditField.Tooltip = {'Lower bounds on the SOPH model parameters [amp, freq, freq_std, power, power_std, theta]'};
            app.LBDefaultEditField.Position = [102 24 315 22];

            % Create FrequencyRangeEditFieldLabel
            app.FrequencyRangeEditFieldLabel = uilabel(app.PowerParametersPanel);
            app.FrequencyRangeEditFieldLabel.HorizontalAlignment = 'right';
            app.FrequencyRangeEditFieldLabel.Position = [13 217 99 22];
            app.FrequencyRangeEditFieldLabel.Text = 'Frequency Range';

            % Create FrequencyRangeEditField
            app.FrequencyRangeEditField = uieditfield(app.PowerParametersPanel, 'text');
            app.FrequencyRangeEditField.Position = [127 217 80 22];

            % Create SOpowerRangeEditFieldLabel
            app.SOpowerRangeEditFieldLabel = uilabel(app.PowerParametersPanel);
            app.SOpowerRangeEditFieldLabel.HorizontalAlignment = 'right';
            app.SOpowerRangeEditFieldLabel.Position = [227 217 98 22];
            app.SOpowerRangeEditFieldLabel.Text = 'SO-power Range';

            % Create SOpowerRangeEditField
            app.SOpowerRangeEditField = uieditfield(app.PowerParametersPanel, 'text');
            app.SOpowerRangeEditField.Position = [340 217 80 22];

            % Create PhaseParametersPanel
            app.PhaseParametersPanel = uipanel(app.LeftPanel);
            app.PhaseParametersPanel.Title = 'Phase Parameters';
            app.PhaseParametersPanel.BackgroundColor = [1 1 1];
            app.PhaseParametersPanel.FontWeight = 'bold';
            app.PhaseParametersPanel.FontSize = 18;
            app.PhaseParametersPanel.Position = [25 218 429 281];

            % Create WatershedParamsEditField_2Label
            app.WatershedParamsEditField_2Label = uilabel(app.PhaseParametersPanel);
            app.WatershedParamsEditField_2Label.HorizontalAlignment = 'right';
            app.WatershedParamsEditField_2Label.Position = [12 155 107 22];
            app.WatershedParamsEditField_2Label.Text = 'Watershed Params';

            % Create WatershedParamsEditField_2
            app.WatershedParamsEditField_2 = uieditfield(app.PhaseParametersPanel, 'text');
            app.WatershedParamsEditField_2.Tooltip = {'Controls the watershed parameters for the SOPhH:'; '       merge_thresh: Threshold weight value for stopping the merge'; '       dur_min: Minimum duration allowed for peaks'; '       bw_min: Minimum bandwidth allowed for peaks'; '       height_min: Minimum height allowed for peaks'; '       trim_vol: Fraction of the maximum trimmed volume (from 0 to 1)'};
            app.WatershedParamsEditField_2.Position = [134 155 283 22];

            % Create MaxOverlapEditField_2Label
            app.MaxOverlapEditField_2Label = uilabel(app.PhaseParametersPanel);
            app.MaxOverlapEditField_2Label.HorizontalAlignment = 'right';
            app.MaxOverlapEditField_2Label.Position = [17 116 73 22];
            app.MaxOverlapEditField_2Label.Text = 'Max Overlap';

            % Create MaxOverlapEditField_2
            app.MaxOverlapEditField_2 = uieditfield(app.PhaseParametersPanel, 'numeric');
            app.MaxOverlapEditField_2.Tooltip = {'The maximum overlap in %area allowed for a valid peak'};
            app.MaxOverlapEditField_2.Position = [139 116 53 22];
            app.MaxOverlapEditField_2.Value = 0.1;

            % Create MinAmpEditField_2Label
            app.MinAmpEditField_2Label = uilabel(app.PhaseParametersPanel);
            app.MinAmpEditField_2Label.HorizontalAlignment = 'right';
            app.MinAmpEditField_2Label.Position = [37 84 53 22];
            app.MinAmpEditField_2Label.Text = 'Min Amp';

            % Create MinAmpEditField_2
            app.MinAmpEditField_2 = uieditfield(app.PhaseParametersPanel, 'numeric');
            app.MinAmpEditField_2.Tooltip = {'Minumum peak amplitude allowed for valid peak'};
            app.MinAmpEditField_2.Position = [139 84 53 22];
            app.MinAmpEditField_2.Value = 0.0001;

            % Create MaxPeaksEditField_2Label
            app.MaxPeaksEditField_2Label = uilabel(app.PhaseParametersPanel);
            app.MaxPeaksEditField_2Label.HorizontalAlignment = 'right';
            app.MaxPeaksEditField_2Label.Position = [236 116 64 22];
            app.MaxPeaksEditField_2Label.Text = 'Max Peaks';

            % Create MaxPeaksEditField_2
            app.MaxPeaksEditField_2 = uieditfield(app.PhaseParametersPanel, 'numeric');
            app.MaxPeaksEditField_2.ValueDisplayFormat = '%.0f';
            app.MaxPeaksEditField_2.Tooltip = {'Maximum number of peaks to try from watershed results + extra'};
            app.MaxPeaksEditField_2.Position = [349 116 53 22];
            app.MaxPeaksEditField_2.Value = 6;

            % Create UBDefaultEditField_2Label
            app.UBDefaultEditField_2Label = uilabel(app.PhaseParametersPanel);
            app.UBDefaultEditField_2Label.HorizontalAlignment = 'right';
            app.UBDefaultEditField_2Label.Position = [23 40 63 22];
            app.UBDefaultEditField_2Label.Text = 'UB Default';

            % Create UBDefaultEditField_2
            app.UBDefaultEditField_2 = uieditfield(app.PhaseParametersPanel, 'text');
            app.UBDefaultEditField_2.Tooltip = {'Upper bounds on the SOPhH model parameters [amp, freq, freq_std, phase, phase_std, theta]'};
            app.UBDefaultEditField_2.Position = [101 40 316 22];

            % Create LBDefaultEditField_2Label
            app.LBDefaultEditField_2Label = uilabel(app.PhaseParametersPanel);
            app.LBDefaultEditField_2Label.HorizontalAlignment = 'right';
            app.LBDefaultEditField_2Label.Position = [25 10 61 22];
            app.LBDefaultEditField_2Label.Text = 'LB Default';

            % Create LBDefaultEditField_2
            app.LBDefaultEditField_2 = uieditfield(app.PhaseParametersPanel, 'text');
            app.LBDefaultEditField_2.Tooltip = {'Lower bounds on the SOhPH model parameters [amp, freq, freq_std, phase, phase_std, theta]'};
            app.LBDefaultEditField_2.Position = [101 10 316 22];

            % Create BlurFactorEditFieldLabel
            app.BlurFactorEditFieldLabel = uilabel(app.PhaseParametersPanel);
            app.BlurFactorEditFieldLabel.HorizontalAlignment = 'right';
            app.BlurFactorEditFieldLabel.Position = [236 83 64 22];
            app.BlurFactorEditFieldLabel.Text = 'Blur Factor';

            % Create BlurFactorEditField
            app.BlurFactorEditField = uieditfield(app.PhaseParametersPanel, 'numeric');
            app.BlurFactorEditField.Tooltip = {'The standard deviation of the Gaussian blur applied to the SOPhH, which tends to be noisy and thus disrupts the watershed'};
            app.BlurFactorEditField.Position = [349 83 53 22];
            app.BlurFactorEditField.Value = 2;

            % Create FrequencyRangeEditField_2Label
            app.FrequencyRangeEditField_2Label = uilabel(app.PhaseParametersPanel);
            app.FrequencyRangeEditField_2Label.HorizontalAlignment = 'right';
            app.FrequencyRangeEditField_2Label.Position = [12 210 99 22];
            app.FrequencyRangeEditField_2Label.Text = 'Frequency Range';

            % Create FrequencyRangeEditField_2
            app.FrequencyRangeEditField_2 = uieditfield(app.PhaseParametersPanel, 'text');
            app.FrequencyRangeEditField_2.Position = [126 210 80 22];

            % Create RunButton
            app.RunButton = uibutton(app.LeftPanel, 'push');
            app.RunButton.ButtonPushedFcn = createCallbackFcn(app, @ParameterizeModesButtonPushed, true);
            app.RunButton.FontSize = 14;
            app.RunButton.FontWeight = 'bold';
            app.RunButton.Tooltip = {'Run mode parameterization'};
            app.RunButton.Position = [242 132 120 58];
            app.RunButton.Text = 'Run';
            app.RunButton.Icon = fullfile(pathToMLAPP, 'run.png');

            % Create LoaddataButton
            app.LoaddataButton = uibutton(app.LeftPanel, 'push');
            app.LoaddataButton.ButtonPushedFcn = createCallbackFcn(app, @ImportButtonPushed, true);
            app.LoaddataButton.Tooltip = {'Loads in required data from the workspace:'; 'SOPH, SOPhH, freq_bins, SOpower_bins, SOphase_bins'; ''; 'Fitting cannot occur unless data are loaded'};
            app.LoaddataButton.Position = [84 132 134 57];
            app.LoaddataButton.Text = 'Load data...';
            app.LoaddataButton.Icon = fullfile(pathToMLAPP, 'import.png');

            % Create VerboseCheckBox
            app.VerboseCheckBox = uicheckbox(app.LeftPanel);
            app.VerboseCheckBox.Text = 'Verbose';
            app.VerboseCheckBox.Position = [376 159 66 22];

            % Create StatusLabel
            app.StatusLabel = uilabel(app.LeftPanel);
            app.StatusLabel.FontSize = 14;
            app.StatusLabel.FontWeight = 'bold';
            app.StatusLabel.Position = [9 13 383 22];
            app.StatusLabel.Text = '';

            % Create SubjectIndexEdit
            app.SubjectIndexEdit = uieditfield(app.LeftPanel, 'numeric');
            app.SubjectIndexEdit.ValueDisplayFormat = '%.0f';
            app.SubjectIndexEdit.ValueChangedFcn = createCallbackFcn(app, @SubjectIndexEditValueChanged, true);
            app.SubjectIndexEdit.Position = [23 56 83 22];
            app.SubjectIndexEdit.Value = 1;

            % Create IterationsCheckBox
            app.IterationsCheckBox = uicheckbox(app.LeftPanel);
            app.IterationsCheckBox.Text = 'Iterations';
            app.IterationsCheckBox.Position = [376 138 72 22];

            % Create SubjectIndexSlider
            app.SubjectIndexSlider = uislider(app.LeftPanel);
            app.SubjectIndexSlider.ValueChangedFcn = createCallbackFcn(app, @SubjectIndexSliderValueChanged, true);
            app.SubjectIndexSlider.ValueChangingFcn = createCallbackFcn(app, @SubjectIndexSliderValueChanging, true);
            app.SubjectIndexSlider.Position = [122 75 304 3];

            % Create SubjectIndexSlider_2Label
            app.SubjectIndexSlider_2Label = uilabel(app.LeftPanel);
            app.SubjectIndexSlider_2Label.HorizontalAlignment = 'right';
            app.SubjectIndexSlider_2Label.FontWeight = 'bold';
            app.SubjectIndexSlider_2Label.Position = [19 86 83 22];
            app.SubjectIndexSlider_2Label.Text = 'Subject Index';

            % Create GenerateFigureButton
            app.GenerateFigureButton = uibutton(app.LeftPanel, 'state');
            app.GenerateFigureButton.ValueChangedFcn = createCallbackFcn(app, @ImgenToolButtonClicked, true);
            app.GenerateFigureButton.Tooltip = {'Generate Figure'};
            app.GenerateFigureButton.Text = 'Generate Figure';
            app.GenerateFigureButton.Position = [244 96 117 23];
            app.GenerateFigureButton.Icon = fullfile(pathToMLAPP, 'image.png');

            % Create SelectionMethodDropDownLabel
            app.SelectionMethodDropDownLabel = uilabel(app.LeftPanel);
            app.SelectionMethodDropDownLabel.HorizontalAlignment = 'right';
            app.SelectionMethodDropDownLabel.Position = [122 192 99 22];
            app.SelectionMethodDropDownLabel.Text = 'Selection Method';

            % Create SelectionMethodDropDown
            app.SelectionMethodDropDown = uidropdown(app.LeftPanel);
            app.SelectionMethodDropDown.Items = {'kneedle', 'max', 'mindr2', 'minpctr2'};
            app.SelectionMethodDropDown.Position = [236 192 100 22];
            app.SelectionMethodDropDown.Value = 'minpctr2';

            % Create CenterPanel
            app.CenterPanel = uipanel(app.GridLayout);
            app.CenterPanel.Layout.Row = 1;
            app.CenterPanel.Layout.Column = 2;

            % Create CenterGridPanel
            app.CenterGridPanel = uipanel(app.CenterPanel);
            app.CenterGridPanel.BackgroundColor = [1 1 1];
            app.CenterGridPanel.Position = [0 2 1206 804];

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.CenterGridPanel);
            app.GridLayout2.ColumnWidth = {'1x', '1x', '1x'};
            app.GridLayout2.RowSpacing = 20;
            app.GridLayout2.BackgroundColor = [1 1 1];

            % Create UIAxesPowWshed
            app.UIAxesPowWshed = uiaxes(app.GridLayout2);
            title(app.UIAxesPowWshed, 'Watershed')
            zlabel(app.UIAxesPowWshed, 'Z')
            app.UIAxesPowWshed.FontSize = 18;
            app.UIAxesPowWshed.Layout.Row = 1;
            app.UIAxesPowWshed.Layout.Column = 1;

            % Create UIAxesSOPH
            app.UIAxesSOPH = uiaxes(app.GridLayout2);
            title(app.UIAxesSOPH, 'SO-power Histogram')
            zlabel(app.UIAxesSOPH, 'Z')
            app.UIAxesSOPH.FontSize = 18;
            app.UIAxesSOPH.Layout.Row = 1;
            app.UIAxesSOPH.Layout.Column = 2;

            % Create UIAxesSOPHFit
            app.UIAxesSOPHFit = uiaxes(app.GridLayout2);
            title(app.UIAxesSOPHFit, 'Model Fit')
            zlabel(app.UIAxesSOPHFit, 'Z')
            app.UIAxesSOPHFit.FontSize = 18;
            app.UIAxesSOPHFit.Layout.Row = 1;
            app.UIAxesSOPHFit.Layout.Column = 3;

            % Create UIAxesPhaseWshed
            app.UIAxesPhaseWshed = uiaxes(app.GridLayout2);
            title(app.UIAxesPhaseWshed, 'Watershed')
            zlabel(app.UIAxesPhaseWshed, 'Z')
            app.UIAxesPhaseWshed.FontSize = 18;
            app.UIAxesPhaseWshed.Layout.Row = 2;
            app.UIAxesPhaseWshed.Layout.Column = 1;

            % Create UIAxesSOPhHFit
            app.UIAxesSOPhHFit = uiaxes(app.GridLayout2);
            title(app.UIAxesSOPhHFit, 'Model Fit')
            zlabel(app.UIAxesSOPhHFit, 'Z')
            app.UIAxesSOPhHFit.FontSize = 18;
            app.UIAxesSOPhHFit.Layout.Row = 2;
            app.UIAxesSOPhHFit.Layout.Column = 3;

            % Create UIAxesSOPhH
            app.UIAxesSOPhH = uiaxes(app.GridLayout2);
            title(app.UIAxesSOPhH, 'SO-phase Histogram')
            zlabel(app.UIAxesSOPhH, 'Z')
            app.UIAxesSOPhH.FontSize = 18;
            app.UIAxesSOPhH.Layout.Row = 2;
            app.UIAxesSOPhH.Layout.Column = 2;

            % Create RightPanel
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 3;

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.RightPanel);
            app.GridLayout3.ColumnWidth = {'1x'};
            app.GridLayout3.RowHeight = {'1x', '10x', '1x', '10x'};
            app.GridLayout3.RowSpacing = 20;
            app.GridLayout3.Padding = [10 40 10 10];

            % Create UITablePower
            app.UITablePower = uitable(app.GridLayout3);
            app.UITablePower.ColumnName = {'Amplitude'; 'Frequency'; 'SDfreq'; 'SOPower'; 'SDpower'; 'Theta'};
            app.UITablePower.RowName = {};
            app.UITablePower.Layout.Row = 2;
            app.UITablePower.Layout.Column = 1;

            % Create UITablePhase
            app.UITablePhase = uitable(app.GridLayout3);
            app.UITablePhase.ColumnName = {'Amplitude'; 'Frequency'; 'SDfreq'; 'SOPower'; 'SDpower'; 'Theta'};
            app.UITablePhase.RowName = {};
            app.UITablePhase.Layout.Row = 4;
            app.UITablePhase.Layout.Column = 1;

            % Create PowerModeParametersLabel
            app.PowerModeParametersLabel = uilabel(app.GridLayout3);
            app.PowerModeParametersLabel.HorizontalAlignment = 'center';
            app.PowerModeParametersLabel.FontSize = 18;
            app.PowerModeParametersLabel.FontWeight = 'bold';
            app.PowerModeParametersLabel.Layout.Row = 1;
            app.PowerModeParametersLabel.Layout.Column = 1;
            app.PowerModeParametersLabel.Text = 'Power Mode Parameters';

            % Create PhaseModeParametersLabel
            app.PhaseModeParametersLabel = uilabel(app.GridLayout3);
            app.PhaseModeParametersLabel.HorizontalAlignment = 'center';
            app.PhaseModeParametersLabel.FontSize = 18;
            app.PhaseModeParametersLabel.FontWeight = 'bold';
            app.PhaseModeParametersLabel.Layout.Row = 3;
            app.PhaseModeParametersLabel.Layout.Column = 1;
            app.PhaseModeParametersLabel.Text = 'Phase Mode Parameters';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ModeParameterization_exported(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.UIFigure)

                % Execute the startup function
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            else

                % Focus the running singleton app
                figure(runningApp.UIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end