classdef DYNAMO < handle
    %DYNAMO  Class wrapper for running the DYNAM-O pipeline for time-frequency peak and SO-power/phase histogram analysis
    %
    %   This class provides an object-oriented interface to the DYNAM-O pipeline,
    %   which analyzes transient oscillations in sleep EEG data. It wraps the
    %   runDYNAMO() function and adds convenient methods for re-analysis, option
    %   updates, visualization, and parametric/spline modeling of SO-power/phase
    %   histograms (SOPHs).
    %
    %   Usage:
    %       d = DYNAMO(data, Fs, stage_times, stage_vals, ...)
    %
    %   Required Inputs:
    %       data: [N x 1] vector - EEG time series data
    %       Fs: scalar - sampling frequency in Hz
    %       stage_times: [1 x T] vector - time markers for sleep staging (s)
    %       stage_vals:  [1 x T] vector - corresponding sleep stage values (1-5)
    %
    %   Optional Name-Value Inputs:
    %       time_range: [1 x 2] double - start and end analysis time in seconds
    %       baseline_options: struct - baseline preprocessing options
    %       detection_options: struct - TF-peak detection options
    %       SOPH_options: struct - SO-power/phase histogram options
    %       stats_table: table - precomputed TF peak table (bypass detection)
    %       verbose: logical - flag for printing progress (default: true)
    %       plot_on: logical - whether to show summary figure (default: true)
    %       save_output_image: logical - save summary image to disk (default: false)
    %       output_fname: char - output filename for saved figure
    %       fit_SOPH: logical - compute SOPH model fits (default: true)
    %
    %   Public Properties:
    %       stats_table, SOPHs, spect, stimes, sfreqs, artifacts
    %       data, Fs, stage_times, stage_vals, time_range
    %       baseline_options, detection_options, SOPH_options
    %
    %   Methods:
    %       run(...)               - run pipeline
    %       updateOptions(...)     - update baseline/detection/SOPH options
    %       displaySummaryPlot()   - plot SOPH and TF peak summary figure
    %       displayTFPeaks()       - plot raw spectrogram and overlaid peaks
    %       fitParamBasis()        - fit parametric models to SOPHs
    %       fitSplineBasis()       - fit spline models to SOPHs
    %
    %   Examples:
    %       % Run analysis with defaults
    %       d = DYNAMO(data, Fs, stage_times, stage_vals);
    %       d.run;
    %
    %       % Re-run with a different time window
    %       d.run('time_range', [0 3600]);
    %
    %       % Update detection parameters and reprocess
    %       opts = detection_opts(); opts.peak_power_thresh = 3;
    %       d.updateOptions('detection_options', opts);
    %       d.run();
    %
    %       % Visualize output and fit models
    %       d.displaySummaryPlot();
    %       d.fitParamBasis();
    %       d.fitSplineBasis();
    %
    %   Citation:
    %       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
    %       Robert Stickgold, Michael J Prerau, "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
    %       for Electroencephalographic Phenotyping and Biomarker Identification", *Sleep*, 2022; zsac223.
    %       https://doi.org/10.1093/sleep/zsac223
    %
    %   Copyright 2025 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
    %**************************************************************************

    properties
        data                        % EEG time series
        Fs                          % Sampling frequency
        stage_times                 % Sleep stage timestamps
        stage_vals                  % Sleep stage values
        stats_table                 % Time-frequency peaks table
        SOPHs                       % SO-power/phase histograms structure
        baseline_options            % Options for baseline correction
        detection_options           % Options for peak detection
        SOPH_options                % Options for SOPH computation
        param_basis_power_options
        param_basis_phase_options
        spline_basis_power_options
        spline_basis_phase_options
        time_range                  % Time range for data
        spect
        stimes
        sfreqs
        artifacts
    end

    methods
        function obj = DYNAMO(varargin)
            default_verbose = true;

            % Set up parser
            p = inputParser;
            p.KeepUnmatched = true;

            addRequired(p, 'data', @(x) validateattributes(x, {'numeric'}, {'real','vector'}));
            addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','scalar'}));
            addRequired(p, 'stage_times', @(x) validateattributes(x, {'numeric'}, {'real','finite','nondecreasing','vector'}));
            addRequired(p, 'stage_vals', @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector'}));

            addOptional(p, 'time_range', [], @(x) isempty(x) || (isnumeric(x) && numel(x)==2));

            addOptional(p, 'baseline_options', baseline_opts(), @(x) isstruct(x));
            addOptional(p, 'detection_options', detection_opts(), @(x) isstruct(x));
            addOptional(p, 'SOPH_options', SOpowerphasehist_opts(), @(x) isstruct(x));
            addOptional(p, 'param_basis_power_options', param_basis_opts('power'), @(x) isstruct(x));
            addOptional(p, 'param_basis_phase_options', param_basis_opts('phase'), @(x) isstruct(x));
            addOptional(p, 'spline_basis_power_options', spline_basis_opts('power'), @(x) isstruct(x));
            addOptional(p, 'spline_basis_phase_options', spline_basis_opts('phase'), @(x) isstruct(x));

            addOptional(p, 'stats_table', [], @(x) istable(x) || isempty(x));
            addOptional(p, 'verbose', default_verbose, @(x) islogical(x) || isnumeric(x));
            addOptional(p, 'plot_on', true, @(x) islogical(x) || isnumeric(x));
            addOptional(p, 'save_output_image', false, @(x) islogical(x) || isnumeric(x));
            addOptional(p, 'output_fname', 'DYNAM-O_output', @(x) ischar(x) || isstring(x));
            addOptional(p, 'fit_SOPH', true, @(x) islogical(x) || isnumeric(x));

            % Parse inputs
            parse(p, varargin{:});
            R = p.Results;

            % Assign to object
            obj.data = R.data(:);
            obj.Fs = R.Fs;
            obj.stage_times = R.stage_times;
            obj.stage_vals = single(R.stage_vals);
            obj.baseline_options = R.baseline_options;
            obj.detection_options = R.detection_options;
            obj.param_basis_power_options = R.param_basis_power_options;
            obj.param_basis_phase_options = R.param_basis_phase_options;
            obj.spline_basis_power_options = R.spline_basis_power_options;
            obj.spline_basis_phase_options = R.spline_basis_phase_options;
            obj.SOPH_options = R.SOPH_options;
            obj.time_range = R.time_range;
        end

        function obj = run(obj)
            %RUN  Re-execute the DYNAM-O pipeline
            %
            %   obj = obj.run
            %   Reruns the analysis with updated parameters such as time range, verbosity,
            %   plotting, or whether to save output.

            % Rerun the full DYNAMO pipeline
            assert(obj.isInitialized(), 'DYNAMO object is not fully initialized.');

            [obj.stats_table, obj.SOPHs, obj.spect, obj.stimes, obj.sfreqs, obj.artifacts] = runDYNAMO(...
                obj.data, obj.Fs, obj.stage_times, obj.stage_vals, obj.time_range, obj.baseline_options, obj.detection_options, obj.SOPH_options);

        end

        function obj = updateOptions(obj, varargin)
            %UPDATEOPTIONS  Update internal processing options
            %
            %   obj = obj.updateOptions('detection_options', new_opts, ...)
            %   Modify one or more of: baseline_options, detection_options, SOPH_options.
            %
            %   obj = obj.updateOptions()
            %   Launch GUI for interactive option editing.

            % If no inputs provided, launch GUI
            if nargin == 1
                obj = obj.DYNAMOOptionsApp(false); % Launch GUI with verbose=false
                return;
            end

            % Original updateOptions code for programmatic use
            p = inputParser;
            addParameter(p, 'baseline_options', [], @(x) isstruct(x) || isempty(x));
            addParameter(p, 'detection_options', [], @(x) isstruct(x) || isempty(x));
            addParameter(p, 'SOPH_options', [], @(x) isstruct(x) || isempty(x));
            parse(p, varargin{:});

            if ~isempty(p.Results.baseline_options)
                obj.baseline_options = p.Results.baseline_options;
            end
            if ~isempty(p.Results.detection_options)
                obj.detection_options = p.Results.detection_options;
            end
            if ~isempty(p.Results.SOPH_options)
                obj.SOPH_options = p.Results.SOPH_options;
            end
        end

        function fh = displaySummaryPlot(obj)
            %DISPLAYSUMMARYPLOT  Display the summary figure of SOPHs and peaks
            %
            %   fh = obj.displaySummaryPlot()
            %   Plots the histogram surfaces, detected peaks, and slow oscillation metrics.

            assert(obj.isInitialized(), 'Object not initialized properly.');
            assert(~isempty(obj.stats_table) && ~isempty(obj.SOPHs), 'Run the pipeline first.');

            fh = displaySummaryPlot('stage_times', obj.stage_times, ...
                'stage_vals', obj.stage_vals, ...
                'data', obj.data, ...
                'Fs', obj.Fs, ...
                'time_range', obj.time_range, ...
                'stats_table', obj.stats_table, ...
                'SOpower_norm', obj.SOPHs.SOpower_norm, ...
                'SOpower_times', obj.SOPHs.SOpower_times, ...
                'SOpower_norm_method', obj.SOPH_options.SOpower_norm_method, ...
                'freq_bins', obj.SOPHs.freq_bins, ...
                'SOpower_mat', obj.SOPHs.SOpower_mat, ...
                'SOpower_bins', obj.SOPHs.SOpower_bins, ...
                'SOphase_mat', obj.SOPHs.SOphase_mat, ...
                'SOphase_bins', obj.SOPHs.SOphase_bins);
        end

        function fh = displayTFPeaks(obj)
            %DISPLAYTFPEAKS  Plot raw spectrogram and TF peak overlay
            %
            %   fh = obj.displayTFPeaks()
            %   Useful for validating peak detection and visualizing peak localization.


            % --- Required input checks
            assert(obj.isInitialized(), 'DYNAMO object is not fully initialized.');
            assert(~isempty(obj.stats_table), 'stats_table is empty.');
            assert(~isempty(obj.spect), 'spect is empty.');
            assert(~isempty(obj.stimes), 'stimes is empty.');
            assert(~isempty(obj.sfreqs), 'sfreqs is empty.');

            % --- Compute optional inputs
            if isempty(obj.time_range)
                % Use full data
                data_time_range = obj.data;
                t_time_range = (0:length(obj.data)-1) / obj.Fs;
            else
                % Use time_range subset
                sample_inds = round(obj.time_range(1) * obj.Fs) + 1 : round(obj.time_range(2) * obj.Fs);
                sample_inds = sample_inds(sample_inds >= 1 & sample_inds <= length(obj.data));  % ensure in bounds
                data_time_range = obj.data(sample_inds);
                t_time_range = (sample_inds - 1) / obj.Fs;
            end

            % --- Call the plotting function
            fh = displayTFPeaks(obj.stats_table, obj.spect, obj.stimes, obj.sfreqs,      ...
                'data_time_range', data_time_range, ...
                't_time_range', t_time_range, ...
                'stage_times', obj.stage_times, ...
                'stage_vals', obj.stage_vals, ...
                'artifacts', obj.artifacts);
        end

        function obj = fitParamBasis(obj, plot_on)
            %FITPARAMBASIS  Fit parametric models to SOPH histograms
            %
            %   obj = obj.fitParamBasis()
            %   Computes Gaussian-like mode fits over power and phase histograms using basis
            %   functions and stores results in SOPHs structure.

            if nargin < 2, plot_on = true; end
            assert(obj.isInitialized(), 'Object not initialized properly.');
            assert(~isempty(obj.SOPHs), 'SOPHs not computed.');

            opts_pow = obj.param_basis_power_options;
            opts_pow.plot_on = false;

            opts_phase = obj.param_basis_phase_options;
            opts_phase.plot_on = false;

            [params_pow, fitobj_pow, gof_pow, model_SOPH_pow, power_wshed_img] = ...
                param_basis_power(obj.SOPHs.SOpower_mat, obj.SOPHs.SOpower_bins, obj.SOPHs.freq_bins, ...
                'verbose', false, 'plot_on', false); % plot_off for merged plot
            obj.SOPHs.SOpower_paramfit = obj.createSOPHparamfitStruct(params_pow, fitobj_pow, gof_pow, model_SOPH_pow, power_wshed_img, []);

            [params_phase, fitobj_phase, gof_phase, model_SOPhH_phase, phase_wshed_img] = ...
                param_basis_phase(obj.SOPHs.SOphase_mat, obj.SOPHs.SOphase_bins, obj.SOPHs.freq_bins, ...
                'verbose', false, 'plot_on', false);
            obj.SOPHs.SOphase_paramfit = obj.createSOPHparamfitStruct(params_phase, fitobj_phase, gof_phase, model_SOPhH_phase, phase_wshed_img, []);

            if plot_on
                obj.plot_param_basis( ...
                    obj.SOPHs.SOpower_bins, obj.SOPHs.freq_bins, power_wshed_img, obj.SOPHs.SOpower_mat, model_SOPH_pow, params_pow, opts_pow.SOPH_clim_prctiles, opts_pow.ylimits, ...
                    obj.SOPHs.SOphase_bins, phase_wshed_img, obj.SOPHs.SOphase_mat, model_SOPhH_phase, params_phase, opts_phase.SOPH_clim_prctiles, opts_phase.ylimits, ...
                    obj.SOPHs.SOpower_paramfit.fitobj, obj.SOPHs.SOphase_paramfit.fitobj);
            end

        end

        function obj = fitSplineBasis(obj, plot_on)
            %FITSPLINEBASIS  Fit spline surfaces to SOPH histograms
            %
            %   obj = obj.fitSplineBasis()
            %   Computes flexible B-spline surfaces to characterize SOPH structure.

            % Fit SOPH with spline models and store the result
            assert(obj.isInitialized(), 'Object not initialized properly.');
            assert(~isempty(obj.SOPHs), 'SOPHs not computed.');

            if nargin<2
                plot_on = true;
            end

            opts_pow = obj.spline_basis_power_options;
            opts_pow.plot_on = false;

            opts_phase = obj.spline_basis_phase_options;
            opts_phase.plot_on = false;


            [fit_pow, coefs_pow, s_pow, knots_x_pow, knots_y_pow] = ...
                spline_basis('power', obj.SOPHs.SOpower_mat, obj.SOPHs.SOpower_bins, obj.SOPHs.freq_bins, opts_pow);
            obj.SOPHs.SOpower_splinefit = obj.createSOPHsplinefitStruct(fit_pow, coefs_pow, s_pow, knots_x_pow, knots_y_pow, []);

            [fit_phase, coefs_phase, s_phase, knots_x_phase, knots_y_phase] = ...
                spline_basis('phase', obj.SOPHs.SOphase_mat, obj.SOPHs.SOphase_bins, obj.SOPHs.freq_bins, opts_phase);
            obj.SOPHs.SOphase_splinefit = obj.createSOPHsplinefitStruct(fit_phase, coefs_phase, s_phase, knots_x_phase, knots_y_phase, []);

            if plot_on
                obj.plot_SOPH_splinefits( ...
                    obj.SOPHs.SOpower_mat, obj.SOPHs.SOpower_bins, fit_pow, coefs_pow, knots_x_pow, knots_y_pow, opts_pow, ...
                    obj.SOPHs.SOphase_mat, obj.SOPHs.SOphase_bins, fit_phase, coefs_phase, knots_x_phase, knots_y_phase, opts_phase, ...
                    obj.SOPHs.freq_bins);
            end
        end

        function fh = plot(obj)
            %PLOT  Shortcut for displaying the summary SOPH/TF peak plot
            %
            %   fh = plot(obj)
            %   Overrides the built-in plot() to call displaySummaryPlot().

            fh = obj.displaySummaryPlot();
        end


    end

    methods (Access = private)
        function obj = DYNAMOOptionsApp(obj, verbose)
            % DYNAMOOptionsApp - Simplified GUI for editing DYNAMO pipeline options

            if nargin == 1
                verbose = false;
            end

            % Create main figure
            fig = uifigure('Name', 'DYNAMO Options', 'Position', [100 100 900 650]);
            tabGroup = uitabgroup(fig, 'Position', [10 60 880 580]);

            % Option configurations
            configs = {
                struct('name', 'Detection', 'field', 'detection_options', 'constructor', @detection_opts)
                struct('name', 'Baseline', 'field', 'baseline_options', 'constructor', @baseline_opts)
                struct('name', 'SOPHs', 'field', 'SOPH_options', 'constructor', @SOpowerphasehist_opts)
                struct('name', 'Param Power', 'field', 'param_basis_power_options', 'constructor', @(x)param_basis_opts('power'))
                struct('name', 'Param Phase', 'field', 'param_basis_phase_options', 'constructor', @(x)param_basis_opts('phase'))
                struct('name', 'Spline Power', 'field', 'spline_basis_power_options', 'constructor', @(x)spline_basis_opts('power'))
                struct('name', 'Spline Phase', 'field', 'spline_basis_phase_options', 'constructor', @(x)spline_basis_opts('phase'))
                };

            % Create tabs and tables
            tables = cell(size(configs));
            for jj = 1:length(configs)
                tab = uitab(tabGroup, 'Title', [configs{jj}.name ' Options']);
                tables{jj} = createTable(tab, obj.(configs{jj}.field), configs{jj});
            end

            % Buttons
            uibutton(fig, 'Text', 'Reset All', 'Position', [250 10 130 40], 'ButtonPushedFcn', @resetAll);
            uibutton(fig, 'Text', 'Rerun', 'Position', [390 10 100 40], 'ButtonPushedFcn', @rerunDynamo);
            uibutton(fig, 'Text', 'Close', 'Position', [500 10 100 40], 'ButtonPushedFcn', @(~,~) delete(fig));

            uiwait(fig);

            function tbl = createTable(parent, opts, config)
                % Build table data
                fields = fieldnames(opts);
                numFields = length(fields);

                % Create arrays for each column
                paramNames = cell(numFields, 1);
                descriptions = cell(numFields, 1);
                values = cell(numFields, 1);

                for j = 1:numFields
                    paramNames{j} = fields{j};

                    descriptions{j} = getDescription(paramNames{j}, config.constructor);
                    % Format value appropriately
                    formattedValue = formatValue(fields{j}, opts.(fields{j}), config.constructor);
                    values{j} = formattedValue;
                end

                % Create table data structure
                tableData = table(paramNames, descriptions, values, ...
                    'VariableNames', {'Parameter', 'Description', 'Value'});

                % Create table
                tbl = uitable(parent, 'Data', tableData, ...
                    'ColumnName', {'Parameter', 'Description', 'Value'}, ...
                    'ColumnWidth', {180, 500, 'auto'}, ...
                    'ColumnEditable', [false false true], ...
                    'Position', [10 10 860 540], ...
                    'CellEditCallback', @(src,ev) editCell(src, ev, config), ...
                    'CellSelectionCallback', @(src,ev) selectCell(src, ev, config));
            end

            function editCell(src, event, config)
                if event.Indices(2) ~= 3
                    return
                end

                row = event.Indices(1);
                param = src.Data.Parameter{row};
                value = event.NewData;

                % Handle categorical values (dropdowns)
                if iscategorical(value)
                    value = char(value);
                end

                % Update DYNAMO object
                try
                    newOpts = updateOption(obj.(config.field), param, value, config.constructor);
                    obj.(config.field) = newOpts; % Direct assignment to object property
                    if verbose
                        fprintf('✅ Updated %s.%s = %s\n', config.field, param, mat2str(value));
                    end
                catch ME
                    uialert(fig, ME.message, 'Validation Error');
                    src.Data.Value{row} = event.PreviousData; % Revert
                end
            end

            function selectCell(src, event, config)
                if isempty(event.Indices) || event.Indices(2) ~= 3
                    return
                end

                row = event.Indices(1);
                param = src.Data.Parameter{row};

                % Handle features selection dialog
                if strcmp(param, 'features') && isequal(config.constructor, @detection_opts)
                    current = src.Data.Value{row};
                    new = featuresDialog(current);
                    if ~isempty(new)
                        try
                            newOpts = updateOption(obj.(config.field), param, new, config.constructor);
                            obj.(config.field) = newOpts; % Direct assignment to object property
                            src.Data.Value{row} = formatValue(param, new, config.constructor);
                            if verbose
                                fprintf('✅ Updated %s.%s = %s\n', config.field, param, mat2str(new));
                            end
                        catch ME
                            uialert(fig, ME.message, 'Validation Error');
                        end
                    end
                end
            end

            function resetAll(~, ~)
                try
                    for ii = 1:length(configs)
                        defaultOpts = configs{ii}.constructor();
                        obj.(configs{ii}.field) = defaultOpts; % Direct assignment to object property

                        % Update table data
                        fields = fieldnames(defaultOpts);
                        newData = tables{ii}.Data;
                        for j = 1:length(fields)
                            newData.Value{j} = formatValue(fields{j}, defaultOpts.(fields{j}), configs{ii}.constructor);
                        end
                        tables{ii}.Data = newData;
                        if verbose
                            fprintf('✅ Reset %s to defaults\n', configs{ii}.field);
                        end
                    end
                    if verbose
                        fprintf('✅ All options reset to defaults - DYNAMO object updated\n');
                    end
                catch ME
                    uialert(fig, ME.message, 'Reset Error');
                end
            end

            function rerunDynamo(~, ~)
                try
                    % Show progress dialog
                    progressDlg = uiprogressdlg(fig, 'Title', 'Running DYNAMO...', ...
                        'Message', 'Processing with updated options...', ...
                        'Indeterminate', 'on');

                    % Rerun DYNAMO with current options
                    obj = obj.run('time_range', obj.time_range, ...
                        'baseline_options', obj.baseline_options, ...
                        'detection_options', obj.detection_options, ...
                        'SOPH_options', obj.SOPH_options, ...
                        'verbose', verbose, ...
                        'plot_on', true, ...
                        'save_output_image', false, ...
                        'fit_SOPH', true);

                    % Close progress dialog
                    if isvalid(progressDlg)
                        close(progressDlg);
                    end

                    if verbose
                        fprintf('✅ DYNAMO rerun completed successfully\n');
                    end

                    % Show success message
                    uialert(fig, 'DYNAMO pipeline completed successfully!', 'Success', 'Icon', 'success');

                catch ME
                    % Close progress dialog if still open
                    if exist('progressDlg', 'var') && isvalid(progressDlg)
                        close(progressDlg);
                    end

                    % Show error message
                    uialert(fig, ['Error during rerun: ' ME.message], 'Rerun Error');

                    if verbose
                        fprintf('❌ DYNAMO rerun failed: %s\n', ME.message);
                    end
                end
            end

            % Helper functions (copy from original app)
            function newOpts = updateOption(opts, param, value, constructor)
                % Parse value
                if ischar(value) || isstring(value)
                    value = parseValue(param, char(value));
                end

                % Update struct
                opts.(param) = value;

                % Validate with constructor
                args = struct2args(opts);

                if strcmp(func2str(constructor), '@(x)param_basis_opts(''power'')')
                    newOpts = param_basis_opts('power', args{:});
                elseif strcmp(func2str(constructor), '@(x)param_basis_opts(''phase'')')
                    newOpts = param_basis_opts('phase', args{:});
                elseif strcmp(func2str(constructor), '@(x)spline_basis_opts(''power'')')
                    newOpts = spline_basis_opts('power', args{:});
                elseif strcmp(func2str(constructor), '@(x)spline_basis_opts(''phase'')')
                    newOpts = spline_basis_opts('phase', args{:});
                else
                    newOpts = constructor(args{:});
                end
            end

            function value = parseValue(param, str)
                str = strtrim(str);
                if isempty(str)
                    value = [];
                elseif strcmp(str, 'all')
                    value = str;
                elseif startsWith(str, '{') && endsWith(str, '}')
                    value = parseCell(str);
                elseif startsWith(str, '[') && endsWith(str, ']')
                    value = eval(str);
                    if strcmp(param, 'baseline_exclude')
                        value = logical(value);
                    end
                else
                    try
                        value = evalin('base', str);
                    catch
                        value = str;
                    end
                end
            end

            function cellArray = parseCell(str)
                content = strtrim(str(2:end-1));
                if isempty(content)
                    cellArray = {};
                else
                    parts = strsplit(content, ',');
                    cellArray = cellfun(@(x) strtrim(strrep(strrep(x, '''', ''), '"', '')), parts, 'UniformOutput', false);
                end
            end

            function args = struct2args(s)
                fields = fieldnames(s);
                args = cell(1, 2*length(fields));
                for ii = 1:length(fields)
                    args{2*ii-1} = fields{ii};
                    args{2*ii} = s.(fields{ii});
                end
            end

            function str = formatValue(param, value, constructor)
                % Handle categorical options (dropdowns)
                if isequal(constructor, @detection_opts) && strcmp(param, 'quality_setting')
                    % Create categorical with proper categories for dropdown
                    str = categorical(string(value), {'default', 'precision', 'stokes_2023'});
                elseif (strcmp(func2str(constructor), '@(x)param_basis_opts(''power'')') || strcmp(func2str(constructor), '@(x)param_basis_opts(''phase'')')) &&  strcmp(param, 'criterion')
                    % Create categorical with proper categories for dropdown
                    str = categorical(string(value), {'minpctr2', 'max', 'mindr2', 'kneedle'});
                elseif strcmp(param, 'features') && isequal(constructor, @detection_opts)
                    if ischar(value) && strcmp(value, 'all')
                        str = 'all';
                    elseif iscell(value)
                        str = ['{' strjoin(cellfun(@(x) ['''' x ''''], value, 'UniformOutput', false), ', ') '}'];
                    else
                        str = char(value);
                    end
                elseif islogical(value) && isscalar(value)
                    str = value;  % Keep as logical for checkbox
                elseif ischar(value) || isstring(value)
                    str = char(value);
                elseif isnumeric(value)
                    if isempty(value)
                        str = '[]';
                    elseif isscalar(value)
                        str = num2str(value);
                    else
                        str = mat2str(value);
                    end
                else
                    str = mat2str(value);
                end

                if ismember(param, {'SOphase_binsizestep', 'SOphase_range', 'LB_default', 'UB_default',  'watershed_params'})
                    str = '[';
                    for ii = 1:length(value)
                        str = [str obj.double2pifracstr(value(ii)) ' '];
                    end
                    str = [str ']'];
                end
            end

            function desc = getDescription(param, constructor)
                descriptions = getDescMap(constructor);
                if isfield(descriptions, param)
                    desc = descriptions.(param);
                else
                    desc = '';
                end
            end

            function map = getDescMap(constructor)
                if isequal(constructor, @detection_opts)
                    map = struct(...
                        'double_watershed', 'Run 2nd pass watershed (logical)', ...
                        'mtm_dsfreqs', 'Frequency bin resolution (Hz)', ...
                        'mtm_freq_range', 'Frequency range [min max] (Hz)', ...
                        'mtm_taper_params', '[time-halfbandwidth, tapers]', ...
                        'mtm_window_length_1', '1st pass window size (s)', ...
                        'mtm_window_length_2', '2nd pass window size (s)', ...
                        'mtm_window_stepsize', 'Window step size (s)', ...
                        'downsample_spect', '[time, freq] downsample steps', ...
                        'seg_time', 'Segment length (s)', ...
                        'merge_thresh', 'Merge threshold', ...
                        'quality_setting', 'Parameter preset (dropdown)', ...
                        'max_merges', 'Max merges per segment', ...
                        'trim_vol', 'Volume trim fraction', ...
                        'dur_max', 'Max duration (s)', ...
                        'bw_max', 'Max bandwidth (Hz)', ...
                        'refinement', 'Refine peak frequency (logical)', ...
                        'features', 'Features to compute (click to select)', ...
                        'debug_mode', 'Debug mode (logical)');
                elseif isequal(constructor, @baseline_opts)
                    map = struct(...
                        'baseline_stages', 'Sleep stages for baseline (vector)', ...
                        'baseline_exclude', 'Exclude time points (logical array)', ...
                        'baseline_ptile', 'Percentile for baseline', ...
                        'baseline_trim', 'Trim times (min)');
                elseif isequal(constructor, @SOpowerphasehist_opts)
                    map = struct(...
                        'freq_range', 'Frequency range (Hz)', ...
                        'freq_binsizestep', '[bin size, step] (Hz)', ...
                        'compute_rate', 'Compute event rate (logical)', ...
                        'SOPH_stages', 'Sleep stages (vector)', ...
                        'SO_freqrange', 'SO frequency range (Hz)', ...
                        'SOpower_tapers', '[time-halfbandwidth, tapers]', ...
                        'SOpower_window_params', '[window length, step] (s)', ...
                        'SOpower_outlier_threshold', 'Outlier threshold', ...
                        'SOpower_norm_method', 'Normalization method', ...
                        'SOpower_retain_Fs', 'Retain sampling freq (logical)', ...
                        'SOpower_min_time_in_bin', 'Min time in bin (s) required to display', ...
                        'SOpower_range', 'Power range (auto if empty)', ...
                        'SOpower_binsizestep', 'Power bin size/step', ...
                        'SOphase_filter', 'Phase filter settings', ...
                        'SOphase_norm_dim', 'Phase norm dimension', ...
                        'SOphase_range', 'Phase range (radians)', ...
                        'SOphase_binsizestep', 'Phase bin size/step',...
                        'SOphase_min_peaks_in_bin', 'Min number of peaks required to display');
                elseif strcmp(func2str(constructor), '@(x)param_basis_opts(''power'')')
                    map = struct(...
                        'ylimits', 'Frequency limits for watershed and parameterization (Hz)', ...
                        'watershed_params', '[merge_thresh, dur_min, bw_min, height_min, trim_vol]', ...
                        'wshed_exp', 'Watershed expansion flag (logical)', ...
                        'max_peaks', 'Maximum number of peaks to fit (-1 for unlimited)', ...
                        'prefix_modes', 'Prefix modes fitting parameters [amp0, fmean0, fstd0, pmean0, pstd0, theta0]', ...
                        'prefix_modes_order', 'Prefix modes order (-1: after, 0: only, 1: before watershed)', ...
                        'max_overlap', 'Maximum allowed mode overlap', ...
                        'min_amp', 'Minimum amplitude for a peak', ...
                        'min_freq_diff', 'Minimum allowed frequency difference (Hz)', ...
                        'criterion', 'Model selection criterion (max, mindr2, minpctr2, kneedle)', ...
                        'min_dr2', 'Minimum acceptable change in R-squared', ...
                        'min_pctr2', 'Minimum percentage change in R-squared', ...
                        'kneedle_tol', 'Kneedle algorithm iteration tolerance', ...
                        'UB_default', 'Upper bounds [amp0, fmean0, fstd0, pmean0, pstd0, theta0]', ...
                        'LB_default', 'Lower bounds [amp0, fmean0, fstd0, pmean0, pstd0, theta0]', ...
                        'plot_on', 'Plot flag (0: none, 1: final, 2: iterations, 3: both)', ...
                        'SOPH_clim_prctiles', 'Heatmap color scaling percentiles [low, high]', ...
                        'verbose', 'Display detailed output (logical)');
                elseif strcmp(func2str(constructor), '@(x)param_basis_opts(''phase'')')
                    map = struct(...
                        'ylimits', 'Frequency limits for watershed and parameterization (Hz)', ...
                        'watershed_params', '[merge_thresh, dur_min, bw_min, height_min, trim_vol]', ...
                        'gauss_filt_std', 'Gaussian filter std dev [row, col] for spectrogram smoothing', ...
                        'wshed_exp', 'Watershed expansion flag (logical)', ...
                        'max_peaks', 'Maximum number of peaks to fit (-1 for unlimited)', ...
                        'prefix_modes', 'Prefix modes fitting parameters [amp0, fmean0, fstd0, pmean0, pstd0, theta0]', ...
                        'prefix_modes_order', 'Prefix modes order (-1: after, 0: only, 1: before watershed)', ...
                        'max_overlap', 'Maximum allowed mode overlap', ...
                        'min_amp', 'Minimum amplitude for a peak', ...
                        'criterion', 'Model selection criterion (max, mindr2, minpctr2, kneedle)', ...
                        'min_dr2', 'Minimum acceptable change in R-squared', ...
                        'min_pctr2', 'Minimum percentage change in R-squared', ...
                        'kneedle_tol', 'Kneedle algorithm iteration tolerance', ...
                        'UB_default', 'Upper bounds [amp0, fmean0, fstd0, pmean0, pstd0, theta0]', ...
                        'LB_default', 'Lower bounds [amp0, fmean0, fstd0, pmean0, pstd0, theta0]', ...
                        'plot_on', 'Plot flag (0: none, 1: final, 2: iterations, 3: both)', ...
                        'SOPH_clim_prctiles', 'Heatmap color scaling percentiles [low, high]', ...
                        'verbose', 'Display detailed output (logical)');
                elseif strcmp(func2str(constructor), '@(x)spline_basis_opts(''power'')') || strcmp(func2str(constructor), '@(x)spline_basis_opts(''phase'')')
                    map = struct(...
                        'ylimits', 'Frequency limits for splines (Hz)', ...
                        'num_knots_x', 'Number of spline knots in the x dimension', ...
                        'num_knots_y', 'Number of spline knots in the y dimension', ...
                        'plot_on', 'Plot flag ', ...
                        'SOPH_clim_prctiles', 'Heatmap color scaling percentiles [low, high]');
                else
                    map = struct();
                end
            end

            function result = featuresDialog(current)
                features = {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', ...
                    'Height', 'HeightData', 'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume', 'PeakStage'};

                % Parse current selection
                if ischar(current) && strcmp(current, 'all')
                    selected = features;
                elseif iscell(current)
                    selected = current;
                else
                    selected = {};
                end

                % Simple dialog
                dlg = uifigure('Name', 'Select Features', 'Position', [300 300 300 400], 'WindowStyle', 'modal');

                listbox = uilistbox(dlg, 'Items', features, 'Value', selected, 'Multiselect', 'on', ...
                    'Position', [20 80 260 280]);

                result = [];
                uibutton(dlg, 'Text', 'OK', 'Position', [150 20 50 30], ...
                    'ButtonPushedFcn', @(~,~) setResult());
                uibutton(dlg, 'Text', 'Cancel', 'Position', [210 20 60 30], ...
                    'ButtonPushedFcn', @(~,~) delete(dlg));

                uiwait(dlg);

                function setResult()
                    if isvalid(dlg)
                        vals = listbox.Value;
                        if length(vals) == length(features)
                            result = 'all';
                        else
                            result = vals;
                        end
                        delete(dlg);
                    end
                end
            end

        end

        function tf = isInitialized(obj)
            %ISINITIALIZED  Check if required fields are present
            %
            %   tf = obj.isInitialized()
            %   Ensures DYNAMO object contains valid data and configuration.

            tf = ~isempty(obj.data) && ~isempty(obj.Fs) && ...
                ~isempty(obj.stage_times) && ~isempty(obj.stage_vals);
        end
    end

    methods (Static, Access = private)
        function [SOPH_paramfit] = createSOPHparamfitStruct(params, fitobj, gof, model_SOPH, wshed_img, fh)
            %CREATESOPHPARAMFITSTRUCT  Build struct for SOPH parametric fit results
            %
            %   Internal helper function. Stores params, fit object, goodness-of-fit, etc.

            SOPH_paramfit = struct;
            SOPH_paramfit.params = params;
            SOPH_paramfit.fitobj = fitobj;
            SOPH_paramfit.gof = gof;
            SOPH_paramfit.model_SOPH = model_SOPH;
            SOPH_paramfit.wshed_img = wshed_img;
            SOPH_paramfit.fh = fh;
        end

        function [SOPH_splinefit] = createSOPHsplinefitStruct(splinefit, coefs, spline_obj, knots_x, knots_y, fh)
            %CREATESOPHSPLINEFITSTRUCT  Build struct for SOPH spline fit results
            %
            %   Internal helper. Stores spline, coefficients, knots, and figure handle.

            SOPH_splinefit = struct;
            SOPH_splinefit.splinefit = splinefit;
            SOPH_splinefit.coefs = coefs;
            SOPH_splinefit.spline_obj = spline_obj;
            SOPH_splinefit.knots_x = knots_x;
            SOPH_splinefit.knots_y = knots_y;
            SOPH_splinefit.fh = fh;
        end

        function pi_str = double2pifracstr(val, tol)
            if nargin < 2
                tol = 1e-10;
            end

            [n,d] = rat(val/pi,tol);

            if n<100 && d<100 && n~=0 && d~=0

                if n == -1
                    pi_str = '-pi';
                elseif n == 1
                    pi_str = 'pi';
                else
                    pi_str = [num2str(n) '*pi'];
                end

                if d>1
                    pi_str = [pi_str '/' num2str(d)];
                end
            else
                pi_str = num2str(val);
            end
        end

        function plot_SOPH_splinefits( ...
                SOpower_mat, SOpower_bins, fit_pow, coefs_pow, knots_x_pow, knots_y_pow, opts_pow, ...
                SOphase_mat, SOphase_bins, fit_phase, coefs_phase, knots_x_phase, knots_y_phase, opts_phase, ...
                freq_bins)
            %PLOT_SOPH_SPLINEFITS  Plot SOPH histograms and spline reconstructions in one figure.
            %
            %   Plots SO-Power (top row) and SO-Phase (bottom row) histograms,
            %   their spline reconstructions, and spline coefficients in a 2x3 layout.
            %
            %   See also: SPLINE_BASIS

            f = figure;
            ax = figdesign(f, 2, 3, ...
                'type', 'usletter', ...
                'orient', 'landscape', ...
                'margins', [0.05 0.05 0.08 0.1 0.1 0.1], ...
                'position',[0.0404 0.1764 0.4840 0.6576]);

            % Helper: plot one set into 3 adjacent axes
            function plot_splinefit(ax_handles, hist_mat, x_bins, fit_mat, coefs, knots_x, knots_y, opts, freq_bins, cmap_hist, cmap_fit, labels)
                % Histogram
                axes(ax_handles(1))
                imagesc(x_bins, freq_bins, hist_mat');
                axis xy
                ylabel('Frequency (Hz)')
                colormap(gca, cmap_hist)
                xlabel(labels.x)
                title(sprintf('%s Histogram: %d Parameters', labels.name, numel(hist_mat)))
                colorbar_noresize;

                % Spline reconstruction
                axes(ax_handles(2))
                imagesc(knots_x, knots_y, fit_mat');
                axis xy
                ylabel('Frequency (Hz)')
                c = colorbar_noresize;
                c.Label.String = labels.fitLabel;
                c.Label.Rotation = -90;
                c.Label.VerticalAlignment = "bottom";
                colormap(gca, cmap_fit)
                xlabel(labels.x)
                title(sprintf('Spline Reconstruction: %d Parameters', numel(coefs)))

                % Coefficients
                axes(ax_handles(3))
                imagesc(1:size(coefs,2), 1:size(coefs,1), coefs);
                axis xy;
                clim(max(coefs,[],'all')*[-1 1]);
                c = colorbar_noresize;
                c.Label.String = {'Coefficient'};
                c.Label.Rotation = -90;
                c.Label.VerticalAlignment = "bottom";
                colormap(gca, flipud(redblue_equalized));
                xlabel('x coeff knots')
                ylabel('y coeff knots')
                title('Spline Coefficients')

                % Equalize & limits
                equalize_axes(ax_handles(1:2),'dimension','xyc');
                axes(ax_handles(1))
                axis tight
                ylim(opts.ylimits)
                c_ptiles = prctile(hist_mat(hist_mat(:)~=0), opts.SOPH_clim_prctiles);
                clim(ax_handles(1), [c_ptiles(1) c_ptiles(2)]);
            end

            % Top row: SO-Power
            plot_splinefit(ax(1:3), SOpower_mat, SOpower_bins, fit_pow, coefs_pow, knots_x_pow, knots_y_pow, ...
                opts_pow, freq_bins, gouldian, gouldian, ...
                struct('x','SO-Power (dB)', 'name','SO-Power', 'fitLabel',{{'Density','(peaks/min in bin)'}}));

            % Bottom row: SO-Phase
            plot_splinefit(ax(4:6), SOphase_mat, SOphase_bins, fit_phase, coefs_phase, knots_x_phase, knots_y_phase, ...
                opts_phase, freq_bins, magma, magma, ...
                struct('x','SO-Phase (rad)', 'name','SO-Phase', 'fitLabel',{{'Proportion'}}));

            set(ax,'fontsize',10);
        end




        function plot_param_basis_good( ...
                power_bins, freq_bins, power_wshed_img, SOPH_pow, model_SOPH_pow, params_pow, SOPH_clim_prctiles_pow, ylimits_pow, ...
                phase_bins, phase_wshed_img, SOPhH_phase, model_SOPhH_phase, params_phase, SOPH_clim_prctiles_phase, ylimits_phase, power_fitobj, phase_fitobj)

            % Hover distance threshold (fraction of axis diagonal). Tweak this value as desired.
            hover_dist_threshold = 0.05;  % 0.05 = 5% of axis diagonal

            f = figure;
            ax = figdesign(f, 2, 3, ...
                'type', 'usletter', ...
                'orient', 'landscape', ...
                'margins', [0.05 0.05 0.08 0.1 0.1 0.1], ...
                'position',[0.0404 0.1764 0.4840 0.6576]);

            % Store all necessary data in the figure's application data
            setappdata(f, 'power_fitobj', power_fitobj);
            setappdata(f, 'phase_fitobj', phase_fitobj);
            setappdata(f, 'power_bins', power_bins);
            setappdata(f, 'phase_bins', phase_bins);
            setappdata(f, 'freq_bins', freq_bins);
            setappdata(f, 'power_ax', ax(3));
            setappdata(f, 'phase_ax', ax(6));

            % Helper function for one row
            function plot_paramfit(ax_handles, x_bins, freq_bins, wshed_img, hist_mat, model_mat, params, cmap, type_str, xlabel_str, fitLabel, clim_prctiles, ylimits, plot_type)
                % --- Watershed segmentation
                axes(ax_handles(1))
                hImg1 = imagesc(x_bins, freq_bins, wshed_img);
                set(hImg1, 'HitTest', 'off', 'PickableParts', 'none'); % images shouldn't capture datatips
                axis xy
                ylabel('Frequency (Hz)');
                title('Watershed Segmentation')

                % --- Original histogram
                axes(ax_handles(2))
                hImg2 = imagesc(x_bins, freq_bins, hist_mat');
                set(hImg2, 'HitTest', 'off', 'PickableParts', 'none');
                axis xy
                colorbar_noresize;
                colormap(gca, cmap);
                xlabel(xlabel_str);
                title(['Original ' type_str ' Histogram'])

                % --- Fitted modes
                axes(ax_handles(3))
                hImg3 = imagesc(x_bins, freq_bins, model_mat);
                set(hImg3, 'HitTest', 'off', 'PickableParts', 'none'); % disable datatips for image
                axis xy
                hold on

                % --- Plot the mode points (single line object with multiple markers)
                hPts = plot(params(:, 4), params(:, 2), 'o', ...
                    'markersize', 8, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'r', 'LineStyle', 'none');

                % Clear default data tip rows - most compatible method (old-style approach)
                try
                    hPts.DataTipTemplate.DataTipRows = dataTipTextRow.empty();
                catch
                    try
                        delete(hPts.DataTipTemplate.DataTipRows);
                    catch
                        % fallback - overwrite later
                    end
                end

                % Choose parameter names depending on type (using the latex-like names you provided)
                if strcmpi(type_str,'Power')
                    colNames = {'amp','freq_{mean}','freq_{std}','power_{mean}','power_{std}','\theta'};
                else
                    colNames = {'amp','freq_{mean}','freq_{std}','phase_{mean}','phase_{std}','\theta'};
                end

                % Add custom data tip rows for each parameter (vector values per marker)
                try
                    for k = 1:length(colNames)
                        hPts.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow(colNames{k}, params(:,k), '%.3f');
                    end
                catch
                    % ignore if DataTipTemplate not supported exactly
                end

                % Make the marker object pickable (so datatips work) but do not let images steal hits
                set(hPts, 'HitTest', 'on', 'PickableParts', 'all');

                % Store mode data and point handle in axes appdata
                setappdata(ax_handles(3), [plot_type '_mode_pts'], hPts);
                setappdata(ax_handles(3), [plot_type '_params'], params);
                setappdata(ax_handles(3), [plot_type '_x_bins'], x_bins);
                setappdata(ax_handles(3), [plot_type '_mode_x'], params(:, 4));
                setappdata(ax_handles(3), [plot_type '_mode_y'], params(:, 2));

                % --- Plot contours for each mode (initially invisible)
                fitobj = getappdata(f, [plot_type '_fitobj']);
                x_fine = linspace(x_bins(1), x_bins(end), 200);
                freq_fine = linspace(freq_bins(1), freq_bins(end), 100);
                contours = gobjects(size(params,1),1);
                for k = 1:size(params,1)
                    try
                        cdata = select_modes(fitobj, k, x_fine, freq_fine);
                    catch
                        cdata = nan(length(freq_fine), length(x_fine));
                    end
                    try
                        % Capture the graphics object handle returned by contour
                        [~, contours(k)] = contour(ax_handles(3), x_fine, freq_fine, cdata, 'w-', 'LineWidth', 2);
                        if isgraphics(contours(k))
                            % make contours non-pickable so they don't steal picks from markers
                            set(contours(k), 'Visible','off', 'Tag','mode_contour', 'HitTest','off', 'PickableParts','none');
                        end
                    catch
                        contours(k) = gobjects(1);
                    end
                end
                setappdata(ax_handles(3), [plot_type '_contours'], contours);

                % Now ensure points are visually on top of contours
                try
                    uistack(hPts, 'top');
                catch
                    % ignore if uistack unavailable
                end

                % Colorbar, colormap and titles
                c = colorbar_noresize;
                c.Label.String = fitLabel;
                c.Label.Rotation = -90;
                c.Label.VerticalAlignment = "bottom";
                colormap(gca, cmap);
                title(['Model ' type_str ' Histogram and Modes'])

                % Additional layout / scaling adjustments
                linkcaxes(ax_handles(2:3));
                axes(ax_handles(2))
                if any(hist_mat(:) ~= 0)
                    c_ptiles = prctile(hist_mat(hist_mat(:)~=0), clim_prctiles);
                else
                    c_ptiles = prctile(hist_mat(:), clim_prctiles);
                end
                clim([c_ptiles(1) c_ptiles(2)]);
                linkaxes(ax_handles)
                axis tight
                ylim(ylimits)
                set(ax_handles, 'fontsize', 10)
            end

            % --- SO-Power row ---
            plot_paramfit(ax(1:3), power_bins, freq_bins, power_wshed_img, SOPH_pow, model_SOPH_pow, params_pow, ...
                gouldian, 'Power', 'SO-Power (dB)', {'Density','(peaks/min in bin)'}, SOPH_clim_prctiles_pow, ylimits_pow, 'power');

            % --- SO-Phase row ---
            plot_paramfit(ax(4:6), phase_bins, freq_bins, phase_wshed_img(:,length(phase_bins)+1:end-length(phase_bins),:), SOPhH_phase, model_SOPhH_phase, params_phase, ...
                magma, 'Phase', 'SO-Phase (rad)', {'Proportion'}, SOPH_clim_prctiles_phase, ylimits_phase, 'phase');

            % --- Enable datacursor mode (so clicking markers produces the enhanced datatip) ---
            dcm = datacursormode(f);
            set(dcm, 'Enable','on');

            % --- Hover function to toggle contours (with axis-aware threshold) ---
            set(f, 'WindowButtonMotionFcn', @(src,evt) hoverModeContour(src));

            function hoverModeContour(fig_handle)
                % Only act if there's a current axes under the pointer
                curr_ax = get(fig_handle, 'CurrentAxes');
                if isempty(curr_ax) || ~isgraphics(curr_ax)
                    return
                end

                % For each plot type (power/phase) check if this axes contains its data
                for plot_type = {'power','phase'}
                    plot_type_str = plot_type{1};
                    if ~isappdata(curr_ax, [plot_type_str '_mode_pts'])
                        continue
                    end

                    hPts = getappdata(curr_ax, [plot_type_str '_mode_pts']);
                    if isempty(hPts) || ~isvalid(hPts)
                        continue
                    end

                    % If cursor is over any mode point, do not update contours (let datatips work)
                    curr_obj = hittest(fig_handle);
                    if ~isempty(curr_obj) && any(curr_obj == hPts)
                        return
                    end

                    % Mouse in axis coordinates
                    pt = get(curr_ax,'CurrentPoint');
                    x_mouse = pt(1,1);
                    y_mouse = pt(1,2);

                    % Mode points and contours
                    mode_x = getappdata(curr_ax, [plot_type_str '_mode_x']);
                    mode_y = getappdata(curr_ax, [plot_type_str '_mode_y']);
                    contours = getappdata(curr_ax, [plot_type_str '_contours']);
                    if isempty(contours), continue; end

                    % Compute normalized distances so threshold is axis-aware:
                    xlim_curr = get(curr_ax, 'XLim');
                    ylim_curr = get(curr_ax, 'YLim');
                    xrange = diff(xlim_curr);
                    yrange = diff(ylim_curr);
                    if xrange == 0, xrange = eps; end
                    if yrange == 0, yrange = eps; end

                    norm_dx = (mode_x - x_mouse) ./ xrange;
                    norm_dy = (mode_y - y_mouse) ./ yrange;
                    norm_dist = sqrt(norm_dx.^2 + norm_dy.^2);  % axis-normalized Euclidean distance

                    % Find closest mode
                    [min_dist, idx] = min(norm_dist);

                    % If not within threshold, hide all contours
                    if min_dist > hover_dist_threshold
                        for k = 1:length(contours)
                            try
                                if isgraphics(contours(k))
                                    set(contours(k),'Visible','off');
                                end
                            catch
                                % ignore individual errors
                            end
                        end
                        return
                    end

                    % Otherwise show only the selected contour
                    for k = 1:length(contours)
                        try
                            if isgraphics(contours(k))
                                if k == idx
                                    set(contours(k),'Visible','on');
                                else
                                    set(contours(k),'Visible','off');
                                end
                            end
                        catch
                            % ignore individual errors
                        end
                    end
                end
            end

            % Clean up on figure close
            set(f, 'DeleteFcn', @(src,evt) delete(findobj(f, 'Tag', 'mode_contour')));
        end

    end
end