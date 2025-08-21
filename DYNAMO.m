classdef DYNAMO < handle
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
    %   Input:
    %       data: [N x 1] vector - EEG time series data -- required
    %       Fs: double - sampling frequency in Hz -- required
    %       stage_times: [1 x T] vector - time markers for sleep staging (s) -- required
    %       stage_vals:  [1 x T] vector - corresponding sleep stage values (1-5) -- required
    %
    %   Optional Name-Value Inputs:
    %       time_range: [1 x 2] double - start and end analysis time in seconds (default: [])
    %       baseline_options: struct - baseline preprocessing options (default: baseline_opts())
    %       detection_options: struct - TF-peak detection options (default: detection_opts())
    %       SOPH_options: struct - SO-power/phase histogram options (default: SOpowerphasehist_opts())
    %       param_basis_power_options: struct - parametric power model opts (default: param_basis_opts('power'))
    %       param_basis_phase_options: struct - parametric phase model opts (default: param_basis_opts('phase'))
    %       spline_basis_power_options: struct - spline power model opts (default: spline_basis_opts('power'))
    %       spline_basis_phase_options: struct - spline phase model opts (default: spline_basis_opts('phase'))
    %       stats_table: table - precomputed TF peak table to bypass detection (default: [])
    %       verbose: logical - print progress (default: true)
    %       plot_on: logical - show summary figure (default: true)
    %       save_output_image: logical - save summary image (default: false)
    %       output_fname: char - filename for saved figure (default: 'DYNAM-O_output')
    %       fit_SOPH: logical - compute SOPH model fits (default: true)
    %
    %   Public Properties:
    %       stats_table, SOPHs, spect, stimes, sfreqs, artifacts
    %       data, Fs, stage_times, stage_vals, time_range
    %       baseline_options, detection_options, SOPH_options
    %       param_basis_power_options, param_basis_phase_options
    %       spline_basis_power_options, spline_basis_phase_options
    %
    %   Methods:
    %       computeTFPeaks()       - run pipeline and compute TF peaks + SOPHs
    %       updateOptions(...)     - update baseline/detection/SOPH/model options
    %       displaySummaryPlot()   - plot SOPH and TF peak summary figure
    %       displayTFPeaks()       - plot raw spectrogram with peak overlays
    %       fitParamBasis()        - fit parametric models to SOPHs
    %       fitSplineBasis()       - fit spline models to SOPHs
    %       plot()                 - shortcut to displaySummaryPlot()
    %
    %   Examples:
    %       % Run analysis with defaults
    %       d = DYNAMO(data, Fs, stage_times, stage_vals);
    %       d.computeTFPeaks();
    %
    %       % Re-run with a different time window
    %       d.time_range = [0 3600];
    %       d.computeTFPeaks();
    %
    %       % Update detection parameters and reprocess
    %       opts = detection_opts(); opts.peak_power_thresh = 3;
    %       d.updateOptions('detection_options', opts);
    %       d.computeTFPeaks();
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
        % --- Input & staging data
        data                        % [N x 1] EEG time series
        Fs                          % Sampling frequency (Hz)
        stage_times                 % [1 x T] Sleep stage timestamps (s)
        stage_vals                  % [1 x T] Sleep stage values (1-5)

        % --- Outputs of pipeline
        stats_table                 % Table of detected time-frequency peaks
        SOPHs                       % Struct of SO-power/phase histograms and related fields
        spect                       % Spectrogram matrix (F x T)
        stimes                      % Spectrogram time vector (1 x T)
        sfreqs                      % Spectrogram frequency vector (1 x F)
        artifacts                   % Artifact mask or indicators

        % --- Option structures
        baseline_options            % Options for baseline correction
        detection_options           % Options for peak detection
        SOPH_options                % Options for SOPH computation
        param_basis_power_options   % Options for parametric fits (power)
        param_basis_phase_options   % Options for parametric fits (phase)
        spline_basis_power_options  % Options for spline fits (power)
        spline_basis_phase_options  % Options for spline fits (phase)

        % --- Analysis range
        time_range                  % [t0 t1] analysis time (s)
    end

    methods
        function obj = DYNAMO(varargin)
            %DYNAMO  Construct a DYNAMO object and parse inputs
            %
            %   Usage:
            %       obj = DYNAMO(data, Fs, stage_times, stage_vals, ...)
            %
            %   Input:
            %       See class header for required and optional inputs.
            %
            %   Output:
            %       obj: DYNAMO object
            %
            %   Example:
            %       d = DYNAMO(data, Fs, stage_times, stage_vals, 'plot_on', true);
            %
            %   Notes:
            %       Uses an inputParser to enforce types and to allow optional
            %       name-value pairs for all option structures and flags.

            default_verbose = true;

            % --- Set up parser
            p = inputParser;
            p.KeepUnmatched = true;

            % --- Required inputs with validation
            addRequired(p, 'data', @(x) validateattributes(x, {'numeric'}, {'real','vector'}));
            addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','scalar'}));
            addRequired(p, 'stage_times', @(x) validateattributes(x, {'numeric'}, {'real','finite','nondecreasing','vector'}));
            addRequired(p, 'stage_vals', @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector'}));

            % --- Optional inputs (scalar or structs)
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

            % --- Parse inputs
            parse(p, varargin{:});
            R = p.Results;

            % --- Assign to object (ensure shapes/types)
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

            % Note: Pipeline execution is not run in constructor. Call computeTFPeaks().
        end

        function obj = computeTFPeaks(obj)
            %COMPUTETFPEAKS  Run the DYNAM-O pipeline (TF peaks + SOPHs)
            %
            %   Usage:
            %       obj = obj.computeTFPeaks()
            %
            %   Description:
            %       Re-executes the DYNAM-O pipeline using the current object
            %       configuration and option structs. Results populate:
            %           - obj.stats_table (TF peaks)
            %           - obj.SOPHs (SOPH structures)
            %           - obj.spect, obj.stimes, obj.sfreqs (spectrogram)
            %           - obj.artifacts (artifact indicators)
            %
            %   Output:
            %       obj: DYNAMO object (updated fields)
            %
            %   Example:
            %       d.time_range = [0 3600];
            %       d = d.computeTFPeaks();

            % Ensure object has required inputs before running
            assert(obj.isInitialized(), 'DYNAMO object is not fully initialized.');

            % Rerun the full DYNAMO pipeline
            [obj.stats_table, obj.SOPHs, obj.spect, obj.stimes, obj.sfreqs, obj.artifacts] = runDYNAMO(...
                obj.data, obj.Fs, obj.stage_times, obj.stage_vals, obj.time_range, obj.baseline_options, obj.detection_options, obj.SOPH_options, 'fit_param_basis', false,'fit_spline_basis', false);
        end

        function obj = updateOptions(obj, varargin)
            %UPDATEOPTIONS  Update internal processing options (programmatic or GUI)
            %
            %   Usage:
            %       obj = obj.updateOptions('detection_options', new_opts, ...)
            %       obj = obj.updateOptions()
            %
            %   Input:
            %       name-value pairs for any of:
            %           'baseline_options' : struct
            %           'detection_options': struct
            %           'SOPH_options'     : struct
            %
            %       If called with no inputs, a GUI is launched to edit options.
            %
            %   Output:
            %       obj: DYNAMO object (options updated)
            %
            %   Examples:
            %       % Programmatic update
            %       opts = detection_opts(); opts.peak_power_thresh = 3;
            %       d.updateOptions('detection_options', opts);
            %
            %       % GUI-based update
            %       d.updateOptions();  % launches the options editor GUI

            % If no inputs provided, launch GUI
            if nargin == 1
                obj = obj.DYNAMOOptionsApp(false); % Launch GUI with verbose=false
                return;
            end

            % Programmatic update parsing
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
            %DISPLAYSUMMARYPLOT  Display the summary SOPH/TF-peak figure
            %
            %   Usage:
            %       fh = obj.displaySummaryPlot()
            %
            %   Description:
            %       Plots SOPH histogram surfaces (power and phase), detected peaks,
            %       and slow oscillation metrics. Requires computeTFPeaks() to have
            %       been run successfully.
            %
            %   Output:
            %       fh: figure handle for the summary plot
            %
            %   Example:
            %       fh = d.displaySummaryPlot();

            assert(obj.isInitialized(), 'Object not initialized properly.');
            assert(~isempty(obj.stats_table) && ~isempty(obj.SOPHs), 'Run computeTFPeaks() first.');

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
            %DISPLAYTFPEAKS  Plot spectrogram with detected TF peaks overlaid
            %
            %   Usage:
            %       fh = obj.displayTFPeaks()
            %
            %   Description:
            %       Useful for validating peak detection and visualizing peak
            %       localization on the underlying spectrogram.
            %
            %   Output:
            %       fh: figure handle for the TF peaks plot
            %
            %   Example:
            %       fh = d.displayTFPeaks();

            % --- Required input checks
            assert(obj.isInitialized(), 'DYNAMO object is not fully initialized.');
            assert(~isempty(obj.stats_table), 'stats_table is empty.');
            assert(~isempty(obj.spect), 'spect is empty.');
            assert(~isempty(obj.stimes), 'stimes is empty.');
            assert(~isempty(obj.sfreqs), 'sfreqs is empty.');

            % --- Compute optional inputs: choose full data or subrange for plotting
            if isempty(obj.time_range)
                % Use full data
                data_time_range = obj.data;
                t_time_range = (0:length(obj.data)-1) / obj.Fs;
            else
                % Use time_range subset (guard against bounds)
                sample_inds = round(obj.time_range(1) * obj.Fs) + 1 : round(obj.time_range(2) * obj.Fs);
                sample_inds = sample_inds(sample_inds >= 1 & sample_inds <= length(obj.data));
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
            %   Usage:
            %       obj = obj.fitParamBasis()
            %       obj = obj.fitParamBasis(plot_on)
            %
            %   Input:
            %       plot_on: logical - show fit visualization (default: true)
            %
            %   Output:
            %       obj: DYNAMO object (SOPHs updated with parametric fit fields)
            %
            %   Example:
            %       d.computeTFPeaks();
            %       d.fitParamBasis();   % stores results in d.SOPHs.SOpower_paramfit / SOphase_paramfit

            if nargin < 2, plot_on = true; end
            assert(obj.isInitialized(), 'Object not initialized properly.');
            assert(~isempty(obj.SOPHs), 'SOPHs not computed.');

            % Copy options, ensure plot flags are off for merged plot below
            opts_pow = obj.param_basis_power_options;
            opts_pow.plot_on = false;

            opts_phase = obj.param_basis_phase_options;
            opts_phase.plot_on = false;

            % --- Power histogram parametric fit
            [params_pow, fitobj_pow, gof_pow, model_SOPH_pow, power_wshed_img] = ...
                param_basis_power(obj.SOPHs.SOpower_mat, obj.SOPHs.SOpower_bins, obj.SOPHs.freq_bins, ...
                'verbose', false, 'plot_on', false);
            obj.SOPHs.SOpower_paramfit = obj.createSOPHparamfitStruct(params_pow, fitobj_pow, gof_pow, model_SOPH_pow, power_wshed_img);

            % --- Phase histogram parametric fit
            [params_phase, fitobj_phase, gof_phase, model_SOPhH_phase, phase_wshed_img] = ...
                param_basis_phase(obj.SOPHs.SOphase_mat, obj.SOPHs.SOphase_bins, obj.SOPHs.freq_bins, ...
                'verbose', false, 'plot_on', false);
            obj.SOPHs.SOphase_paramfit = obj.createSOPHparamfitStruct(params_phase, fitobj_phase, gof_phase, model_SOPhH_phase, phase_wshed_img);

            % --- Optional visualization (combined)
            if plot_on
                plot_SOPH_paramfits( ...
                    obj.SOPHs.SOpower_bins, obj.SOPHs.freq_bins, power_wshed_img, obj.SOPHs.SOpower_mat, model_SOPH_pow, params_pow, opts_pow.SOPH_clim_prctiles, opts_pow.ylimits, ...
                    obj.SOPHs.SOphase_bins, phase_wshed_img, obj.SOPHs.SOphase_mat, model_SOPhH_phase, params_phase, opts_phase.SOPH_clim_prctiles, opts_phase.ylimits, ...
                    obj.SOPHs.SOpower_paramfit.fitobj, obj.SOPHs.SOphase_paramfit.fitobj);
            end
        end

        function obj = fitSplineBasis(obj, plot_on)
            %FITSPLINEBASIS  Fit spline surfaces to SOPH histograms
            %
            %   Usage:
            %       obj = obj.fitSplineBasis()
            %       obj = obj.fitSplineBasis(plot_on)
            %
            %   Input:
            %       plot_on: logical - show fit visualization (default: true)
            %
            %   Output:
            %       obj: DYNAMO object (SOPHs updated with spline fit fields)
            %
            %   Example:
            %       d.computeTFPeaks();
            %       d.fitSplineBasis();  % stores results in d.SOPHs.SOpower_splinefit / SOphase_splinefit

            % Guard requirements
            assert(obj.isInitialized(), 'Object not initialized properly.');
            assert(~isempty(obj.SOPHs), 'SOPHs not computed.');

            if nargin<2
                plot_on = true;
            end

            % Copy options and disable internal plotting for merged view
            opts_pow = obj.spline_basis_power_options;
            opts_pow.plot_on = false;

            opts_phase = obj.spline_basis_phase_options;
            opts_phase.plot_on = false;

            % --- Power spline fit
            [fit_pow, coefs_pow, s_pow, knots_x_pow, knots_y_pow] = ...
                spline_basis('power', obj.SOPHs.SOpower_mat, obj.SOPHs.SOpower_bins, obj.SOPHs.freq_bins, opts_pow);
            obj.SOPHs.SOpower_splinefit = obj.createSOPHsplinefitStruct(fit_pow, coefs_pow, s_pow, knots_x_pow, knots_y_pow);

            % --- Phase spline fit
            [fit_phase, coefs_phase, s_phase, knots_x_phase, knots_y_phase] = ...
                spline_basis('phase', obj.SOPHs.SOphase_mat, obj.SOPHs.SOphase_bins, obj.SOPHs.freq_bins, opts_phase);
            obj.SOPHs.SOphase_splinefit = obj.createSOPHsplinefitStruct(fit_phase, coefs_phase, s_phase, knots_x_phase, knots_y_phase);

            % --- Optional visualization (combined)
            if plot_on
                plot_SOPH_splinefits( ...
                    obj.SOPHs.SOpower_mat, obj.SOPHs.SOpower_bins, fit_pow, coefs_pow, knots_x_pow, knots_y_pow, opts_pow, ...
                    obj.SOPHs.SOphase_mat, obj.SOPHs.SOphase_bins, fit_phase, coefs_phase, knots_x_phase, knots_y_phase, opts_phase, ...
                    obj.SOPHs.freq_bins);
            end
        end

        function fh = plot(obj)
            %PLOT  Shortcut for displaying the summary SOPH/TF-peak plot
            %
            %   Usage:
            %       fh = plot(obj)
            %
            %   Output:
            %       fh: figure handle (from displaySummaryPlot)
            %
            %   Example:
            %       fh = plot(d);

            fh = obj.displaySummaryPlot();
        end
    end

    methods (Access = private)
        methods (Access = private)
            function obj = DYNAMOOptionsApp(obj, verbose)
                %DYNAMOOPTIONSAPP  Interactive UI for editing pipeline options
                %
                %   obj = obj.DYNAMOOptionsApp(verbose)
                %
                %   Input:
                %       verbose: logical (default = false)
                %           If true, prints console output during option editing
                %
                %   This method opens an interactive app (using uifigure/uitable) that
                %   allows the user to view and edit DYNAM-O pipeline options.
                %   The app provides a tabbed interface for each configurable family:
                %       - Baseline
                %       - Detection
                %       - SOPH (SO-power/phase histogram)
                %       - Parametric fits (power, phase)
                %       - Spline fits (power, phase)
                %
                %   Each tab shows the fields of the corresponding options struct
                %   in a table format. Users can edit values, reset to defaults,
                %   or re-run the pipeline with updated parameters.
                %
                %   Example:
                %       d = DYNAMO(data, Fs, stage_times, stage_vals);
                %       d.DYNAMOOptionsApp(true); % launch interactive editor
                %
                %   Note:
                %       Changes made in the app are stored back into the object's
                %       corresponding options property (e.g. detection_options).
                %

                if nargin < 2
                    verbose = false;
                end

                % --- Table of configurable option families ------------------------
                % Each entry defines:
                %   - Display name for tab
                %   - Property name in the DYNAMO object
                %   - Constructor for defaults
                configs = {
                    struct('name','Detection','field','detection_options','constructor',@detection_opts)
                    struct('name','Baseline','field','baseline_options','constructor',@baseline_opts)
                    struct('name','SOPHs','field','SOPH_options','constructor',@SOpowerphasehist_opts)
                    struct('name','Param Power','field','param_basis_power_options','constructor',@(varargin) param_basis_opts('power'))
                    struct('name','Param Phase','field','param_basis_phase_options','constructor',@(varargin) param_basis_opts('phase'))
                    struct('name','Spline Power','field','spline_basis_power_options','constructor',@(varargin) spline_basis_opts('power'))
                    struct('name','Spline Phase','field','spline_basis_phase_options','constructor',@(varargin) spline_basis_opts('phase'))
                    };

                % --- Build UI container -------------------------------------------
                fig = uifigure('Name','DYNAMO Options','Position',[100 100 900 650]);
                tabGroup = uitabgroup(fig,'Position',[10 60 880 580]);

                % --- Create tabs for each option family ---------------------------
                tables = cell(size(configs));
                for ii = 1:numel(configs)
                    % Create tab for this options family
                    tab = uitab(tabGroup,'Title',configs{ii}.name);

                    % Extract current options struct from object
                    opt_struct = obj.(configs{ii}.field);

                    % Convert struct fields into table format
                    names = fieldnames(opt_struct);
                    vals = struct2cell(opt_struct);
                    t = table(names, vals, 'VariableNames',{'Field','Value'});

                    % Create editable uitable in tab
                    tables{ii} = uitable(tab, 'Data', t, ...
                        'ColumnEditable',[false true], ...
                        'Position',[10 10 850 500]);
                end

                % --- Control buttons ----------------------------------------------
                uibutton(fig,'Text','Apply','Position',[10 10 100 30], ...
                    'ButtonPushedFcn', @(btn,event) applyChanges());
                uibutton(fig,'Text','Reset Defaults','Position',[120 10 120 30], ...
                    'ButtonPushedFcn', @(btn,event) resetDefaults());
                uibutton(fig,'Text','Rerun Pipeline','Position',[250 10 120 30], ...
                    'ButtonPushedFcn', @(btn,event) rerunPipeline());

                % --- Nested callback functions ------------------------------------
                function applyChanges()
                    % Read table edits back into object options
                    for jj = 1:numel(configs)
                        tbl = tables{jj}.Data;
                        new_opts = struct();
                        for kk = 1:height(tbl)
                            fname = tbl.Field{kk};
                            fval  = tbl.Value{kk};
                            new_opts.(fname) = fval;
                        end
                        obj.(configs{jj}.field) = new_opts;
                    end
                    if verbose, disp('Options updated.'); end
                end

                function resetDefaults()
                    % Reset each options family to its default constructor
                    for jj = 1:numel(configs)
                        obj.(configs{jj}.field) = configs{jj}.constructor();
                        if verbose
                            fprintf('Reset %s to defaults.\n', configs{jj}.name);
                        end
                    end
                end

                function rerunPipeline()
                    % Apply changes and re-run detection pipeline
                    applyChanges();
                    obj.computeTFPeaks();
                    if verbose, disp('Pipeline re-run with updated options.'); end
                end
            end
        end

        %DYNAMOOPTIONSAPP  UI for editing DYNAM-O pipeline options
        %
        %   Usage:
        %       obj = obj.DYNAMOOptionsApp(verbose)
        %
        %   Input:
        %       verbose: logical - print updates to console (default: false)
        %
        %   Output:
        %       obj: DYNAMO object (options updated via GUI)
        %
        %   Description:
        %       Launches a uifigure-based GUI with tabs for Detection, Baseline,
        %       SOPHs, and model options. Edits are validated and applied to the
        %       object. Includes Reset All, Rerun, and Close controls.

        if nargin == 1
            verbose = false;
        end

        % --- Main UI container
        fig = uifigure('Name', 'DYNAMO Options', 'Position', [100 100 900 650]);
        tabGroup = uitabgroup(fig, 'Position', [10 60 880 580]);

        % --- Tab configuration list
        configs = {
            struct('name', 'Detection', 'field', 'detection_options', 'constructor', @detection_opts)
            struct('name', 'Baseline', 'field', 'baseline_options', 'constructor', @baseline_opts)
            struct('name', 'SOPHs', 'field', 'SOPH_options', 'constructor', @SOpowerphasehist_opts)
            struct('name', 'Param Power', 'field', 'param_basis_power_options', 'constructor', @(x)param_basis_opts('power'))
            struct('name', 'Param Phase', 'field', 'param_basis_phase_options', 'constructor', @(x)param_basis_opts('phase'))
            struct('name', 'Spline Power', 'field', 'spline_basis_power_options', 'constructor', @(x)spline_basis_opts('power'))
            struct('name', 'Spline Phase', 'field', 'spline_basis_phase_options', 'constructor', @(x)spline_basis_opts('phase'))
            };

        % --- Create tables per tab
        tables = cell(size(configs));
        for jj = 1:length(configs)
            tab = uitab(tabGroup, 'Title', [configs{jj}.name ' Options']);
            tables{jj} = createTable(tab, obj.(configs{jj}.field), configs{jj});
        end

        % --- Footer buttons
        uibutton(fig, 'Text', 'Reset All', 'Position', [250 10 130 40], 'ButtonPushedFcn', @resetAll);
        uibutton(fig, 'Text', 'Rerun', 'Position', [390 10 100 40], 'ButtonPushedFcn', @rerunDynamo);
        uibutton(fig, 'Text', 'Close', 'Position', [500 10 100 40], 'ButtonPushedFcn', @(~,~) delete(fig));

        uiwait(fig);

        %----------------- Nested UI helper functions -----------------%
        function tbl = createTable(parent, opts, config)
            % Create a 3-column table: Parameter | Description | Value

            % Build table data
            fields = fieldnames(opts);
            numFields = length(fields);

            paramNames = cell(numFields, 1);
            descriptions = cell(numFields, 1);
            values = cell(numFields, 1);

            for j = 1:numFields
                paramNames{j} = fields{j};
                descriptions{j} = getDescription(paramNames{j}, config.constructor);
                values{j} = formatValue(fields{j}, opts.(fields{j}), config.constructor);
            end

            tableData = table(paramNames, descriptions, values, ...
                'VariableNames', {'Parameter', 'Description', 'Value'});

            % Create table UI
            tbl = uitable(parent, 'Data', tableData, ...
                'ColumnName', {'Parameter', 'Description', 'Value'}, ...
                'ColumnWidth', {180, 500, 'auto'}, ...
                'ColumnEditable', [false false true], ...
                'Position', [10 10 860 540], ...
                'CellEditCallback', @(src,ev) editCell(src, ev, config), ...
                'CellSelectionCallback', @(src,ev) selectCell(src, ev, config));
        end

        function editCell(src, event, config)
            % Apply edits only on Value column
            if event.Indices(2) ~= 3
                return
            end

            row = event.Indices(1);
            param = src.Data.Parameter{row};
            value = event.NewData;

            % Normalize categorical edits
            if iscategorical(value)
                value = char(value);
            end

            % Update DYNAMO object option
            try
                newOpts = updateOption(obj.(config.field), param, value, config.constructor);
                obj.(config.field) = newOpts; % Direct assignment to object property
                if verbose
                    fprintf('✅ Updated %s.%s = %s\n', config.field, param, mat2str(value));
                end
            catch ME
                uialert(fig, ME.message, 'Validation Error');
                src.Data.Value{row} = event.PreviousData; % Revert if invalid
            end
        end

        function selectCell(src, event, config)
            % Special UI for selecting detection "features"
            if isempty(event.Indices) || event.Indices(2) ~= 3
                return
            end

            row = event.Indices(1);
            param = src.Data.Parameter{row};

            if strcmp(param, 'features') && isequal(config.constructor, @detection_opts)
                current = src.Data.Value{row};
                new = featuresDialog(current);
                if ~isempty(new)
                    try
                        newOpts = updateOption(obj.(config.field), param, new, config.constructor);
                        obj.(config.field) = newOpts;
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
            % Reset each tab to constructor defaults and reflect in UI
            try
                for ii = 1:length(configs)
                    defaultOpts = configs{ii}.constructor();
                    obj.(configs{ii}.field) = defaultOpts;

                    % Update table cells with formatted defaults
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
            % Rerun the pipeline using current options (with progress dialog)
            try
                progressDlg = uiprogressdlg(fig, 'Title', 'Running DYNAMO...', ...
                    'Message', 'Processing with updated options...', ...
                    'Indeterminate', 'on');

                obj.computeTFPeaks();

                if isvalid(progressDlg)
                    close(progressDlg);
                end

                if verbose
                    fprintf('✅ DYNAMO rerun completed successfully\n');
                end

                uialert(fig, 'DYNAMO pipeline completed successfully!', 'Success', 'Icon', 'success');

            catch ME
                if exist('progressDlg', 'var') && isvalid(progressDlg)
                    close(progressDlg);
                end

                uialert(fig, ['Error during rerun: ' ME.message], 'Rerun Error');

                if verbose
                    fprintf('❌ DYNAMO rerun failed: %s\n', ME.message);
                end
            end
        end

        %----------------- Validation/formatting helpers -----------------%
        function newOpts = updateOption(opts, param, value, constructor)
            % Parse text into MATLAB values where needed, update and validate
            if ischar(value) || isstring(value)
                value = parseValue(param, char(value));
            end
            opts.(param) = value;

            % Reconstruct via constructor for validation
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
            % Interpret user text into MATLAB variable/array/cell/etc.
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
            % Parse a brace-enclosed comma-separated cell array of strings
            content = strtrim(str(2:end-1));
            if isempty(content)
                cellArray = {};
            else
                parts = strsplit(content, ',');
                cellArray = cellfun(@(x) strtrim(strrep(strrep(x, '''', ''), '"', '')), parts, 'UniformOutput', false);
            end
        end

        function args = struct2args(s)
            % Convert struct fields to name-value cell array for constructor
            fields = fieldnames(s);
            args = cell(1, 2*length(fields));
            for ii = 1:length(fields)
                args{2*ii-1} = fields{ii};
                args{2*ii} = s.(fields{ii});
            end
        end

        function str = formatValue(param, value, constructor)
            % Format a value for display/editing in the UI table

            % Dropdown (categorical) handling
            if isequal(constructor, @detection_opts) && strcmp(param, 'quality_setting')
                str = categorical(string(value), {'default', 'precision', 'stokes_2023'});
            elseif (strcmp(func2str(constructor), '@(x)param_basis_opts(''power'')') || strcmp(func2str(constructor), '@(x)param_basis_opts(''phase'')')) &&  strcmp(param, 'criterion')
                str = categorical(string(value), {'minpctr2', 'max', 'mindr2', 'kneedle'});

                % Feature list handling
            elseif strcmp(param, 'features') && isequal(constructor, @detection_opts)
                if ischar(value) && strcmp(value, 'all')
                    str = 'all';
                elseif iscell(value)
                    str = ['{' strjoin(cellfun(@(x) ['''' x ''''], value, 'UniformOutput', false), ', ') '}'];
                else
                    str = char(value);
                end

                % Simple scalar/logical/string/array formatting
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

            % Display special parameters as multiples of pi where appropriate
            if ismember(param, {'SOphase_binsizestep', 'SOphase_range', 'LB_default', 'UB_default',  'watershed_params'})
                str = '[';
                for ii = 1:length(value)
                    str = [str obj.double2pifracstr(value(ii)) ' ']; %#ok<AGROW>
                end
                str = [str ']'];
            end
        end

        function desc = getDescription(param, constructor)
            % Map a parameter name to a human-readable description string
            descriptions = getDescMap(constructor);
            if isfield(descriptions, param)
                desc = descriptions.(param);
            else
                desc = '';
            end
        end

        function map = getDescMap(constructor)
            % Provide description maps per constructor/option family
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
                    'plot_on', 'Plot flag', ...
                    'SOPH_clim_prctiles', 'Heatmap color scaling percentiles [low, high]');
            else
                map = struct();
            end
        end

        function result = featuresDialog(current)
            % Simple modal listbox for toggling detection features
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

            % Dialog UI
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
        %ISINITIALIZED  Verify that required fields are present
        %
        %   Usage:
        %       tf = obj.isInitialized()
        %
        %   Output:
        %       tf: logical - true if data, Fs, stage_times, stage_vals are set

        tf = ~isempty(obj.data) && ~isempty(obj.Fs) && ...
            ~isempty(obj.stage_times) && ~isempty(obj.stage_vals);
    end
end

methods (Static, Access = private)

    function [SOPHs] = createSOPHsStruct(SOpower_mat, SOphase_mat, SOpower_bins, SOpower_norm, SOpower_times, SOphase_bins, freq_bins, num_peaks_at_freq, SOpower_TIB, SOphase_TIB)
        %CREATESOPHSSTRUCT  Package SOPH arrays into a single struct
        %
        %   Usage:
        %       S = DYNAMO.createSOPHsStruct(...)
        %
        %   Output:
        %       SOPHs: struct with fields for power/phase matrices, binning,
        %              normalization, timing, and per-frequency peak counts.

        SOPHs = struct;
        SOPHs.SOpower_mat = SOpower_mat;
        SOPHs.SOphase_mat = SOphase_mat;
        SOPHs.SOpower_bins = SOpower_bins;
        SOPHs.SOphase_bins = SOphase_bins;
        SOPHs.freq_bins = freq_bins;
        SOPHs.num_peaks_at_freq = num_peaks_at_freq;
        SOPHs.SOpower_TIB = SOpower_TIB;
        SOPHs.SOphase_TIB = SOphase_TIB;
        SOPHs.SOpower_norm = SOpower_norm;
        SOPHs.SOpower_times = SOpower_times;
    end


    function [SOPH_paramfit] = createSOPHparamfitStruct(params, fitobj, gof, model_SOPH, wshed_img)
        %CREATESOPHPARAMFITSTRUCT  Bundle parametric fit outputs into struct
        %
        %   Usage:
        %       S = DYNAMO.createSOPHparamfitStruct(params, fitobj, gof, model_SOPH, wshed_img)

        SOPH_paramfit = struct;
        SOPH_paramfit.params = params;
        SOPH_paramfit.fitobj = fitobj;
        SOPH_paramfit.gof = gof;
        SOPH_paramfit.model_SOPH = model_SOPH;
        SOPH_paramfit.wshed_img = wshed_img;
    end


    function [SOPH_splinefit] = createSOPHsplinefitStruct(splinefit, coefs, spline_obj, knots_x, knots_y)
        %CREATESOPHSPLINEFITSTRUCT  Bundle spline fit outputs into struct
        %
        %   Usage:
        %       S = DYNAMO.createSOPHsplinefitStruct(fit, coefs, s, kx, ky)

        SOPH_splinefit = struct;
        SOPH_splinefit.splinefit = splinefit;
        SOPH_splinefit.coefs = coefs;
        SOPH_splinefit.spline_obj = spline_obj;
        SOPH_splinefit.knots_x = knots_x;
        SOPH_splinefit.knots_y = knots_y;
    end


    function pi_str = double2pifracstr(val, tol)
        %DOUBLE2PIFRACSTR  Format a number as a rational multiple of pi when simple
        %
        %   Usage:
        %       s = DYNAMO.double2pifracstr(value)
        %       s = DYNAMO.double2pifracstr(value, tol)
        %
        %   Input:
        %       val: double - numeric value to format
        %       tol: double - tolerance for rat() (default: 1e-10)
        %
        %   Output:
        %       pi_str: char - string representation (e.g., 'pi/2', '3*pi/4', or numeric)

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

end
end
