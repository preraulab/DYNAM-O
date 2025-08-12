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
    %       rerun(...)             - rerun pipeline with optional overrides
    %       updateOptions(...)     - update baseline/detection/SOPH options
    %       displaySummaryPlot()   - plot SOPH and TF peak summary figure
    %       displayTFPeaks()       - plot raw spectrogram and overlaid peaks
    %       fitParamBasis()        - fit parametric models to SOPHs
    %       fitSplineBasis()       - fit spline models to SOPHs
    %
    %   Examples:
    %       % Run analysis with defaults
    %       d = DYNAMO(data, Fs, stage_times, stage_vals);
    %
    %       % Re-run with a different time window
    %       d.rerun('time_range', [0 3600]);
    %
    %       % Update detection parameters and reprocess
    %       opts = detection_opts(); opts.peak_power_thresh = 3;
    %       d.updateOptions('detection_options', opts);
    %       d.rerun();
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
        data               % EEG time series
        Fs                 % Sampling frequency
        stage_times        % Sleep stage timestamps
        stage_vals         % Sleep stage values
        stats_table        % Time-frequency peaks table
        SOPHs              % SO-power/phase histograms structure
        baseline_options   % Options for baseline correction
        detection_options  % Options for peak detection
        SOPH_options       % Options for SOPH computation
        time_range         % Time range for data
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
            obj.SOPH_options = R.SOPH_options;
            obj.time_range = R.time_range;
            %
            % % Run pipeline
            % [obj.stats_table, obj.SOPHs, obj.spect, obj.stimes, obj.sfreqs, obj.artifacts] = runDYNAMO(...
            %     obj.data, obj.Fs, obj.stage_times, obj.stage_vals, ...
            %     R.time_range, R.baseline_options, R.detection_options, ...
            %     R.SOPH_options, R.stats_table, R.verbose, ...
            %     R.plot_on, R.save_output_image, R.output_fname, R.fit_SOPH);
        end

        function obj = rerun(obj, varargin)
            %RERUN  Re-execute the DYNAM-O pipeline
            %
            %   obj = obj.rerun(...)
            %   Reruns the analysis with updated parameters such as time range, verbosity,
            %   plotting, or whether to save output.

            % Rerun the full DYNAMO pipeline
            assert(obj.isInitialized(), 'DYNAMO object is not fully initialized.');



            [obj.stats_table, obj.SOPHs, obj.spect, obj.stimes, obj.sfreqs, obj.artifacts] = runDYNAMO(...
                obj.data, obj.Fs, obj.stage_times, obj.stage_vals, ...
                varargin{:});
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

            [params, fitobj, gof, model, wshed, f] = param_basis_power(...
                obj.SOPHs.SOpower_mat, obj.SOPHs.SOpower_bins, obj.SOPHs.freq_bins, ...
                'verbose', false, 'plot_on', plot_on);
            obj.SOPHs.SOpower_paramfit = obj.createSOPHparamfitStruct(params, fitobj, gof, model, wshed, f);

            [params, fitobj, gof, model, wshed, f] = param_basis_phase(...
                obj.SOPHs.SOphase_mat, obj.SOPHs.SOphase_bins, obj.SOPHs.freq_bins, ...
                'verbose', false, 'plot_on', plot_on);
            obj.SOPHs.SOphase_paramfit = obj.createSOPHparamfitStruct(params, fitobj, gof, model, wshed, f);
        end

        function obj = fitSplineBasis(obj, plot_on)
            %FITSPLINEBASIS  Fit spline surfaces to SOPH histograms
            %
            %   obj = obj.fitSplineBasis()
            %   Computes flexible B-spline surfaces to characterize SOPH structure.

            % Fit SOPH with spline models and store the result
            if nargin < 2, plot_on = true; end
            assert(obj.isInitialized(), 'Object not initialized properly.');
            assert(~isempty(obj.SOPHs), 'SOPHs not computed.');

            [fit, coefs, s, kx, ky, f] = SOPH2spline('power', obj.SOPHs.SOpower_mat, obj.SOPHs.SOpower_bins, obj.SOPHs.freq_bins, 'plot_on', plot_on);
            obj.SOPHs.SOpower_splinefit = obj.createSOPHsplinefitStruct(fit, coefs, s, kx, ky, f);

            [fit, coefs, s, kx, ky, f] = SOPH2spline('phase', obj.SOPHs.SOphase_mat, obj.SOPHs.SOphase_bins, obj.SOPHs.freq_bins, 'plot_on', plot_on);
            obj.SOPHs.SOphase_splinefit = obj.createSOPHsplinefitStruct(fit, coefs, s, kx, ky, f);
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
                struct('name', 'SOPowerPhaseHist', 'field', 'SOPH_options', 'constructor', @SOpowerphasehist_opts)
                };

            % Create tabs and tables
            tables = cell(size(configs));
            for ii = 1:length(configs)
                tab = uitab(tabGroup, 'Title', [configs{ii}.name ' Options']);
                tables{ii} = createTable(tab, obj.(configs{ii}.field), configs{ii});
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
                    descriptions{j} = getDescription(fields{j}, config.constructor);

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
                    obj = obj.rerun('time_range', obj.time_range, ...
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
                newOpts = constructor(args{:});
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

                if isequal(constructor, @SOpowerphasehist_opts) && ((strcmp(param, 'SOphase_binsizestep') || strcmp(param, 'SOphase_range')))
                    str = ['[', obj.double2pifracstr(value(1)), ', ', obj.double2pifracstr(value(2)), ']'];
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

            if n<100 && d<100

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
                pi_str = [];
            end
        end
    end
end