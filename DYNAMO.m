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

            % Run pipeline
            [obj.stats_table, obj.SOPHs, obj.spect, obj.stimes, obj.sfreqs, obj.artifacts] = runDYNAMO(...
                obj.data, obj.Fs, obj.stage_times, obj.stage_vals, ...
                R.time_range, R.baseline_options, R.detection_options, ...
                R.SOPH_options, R.stats_table, R.verbose, ...
                R.plot_on, R.save_output_image, R.output_fname, R.fit_SOPH);
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

            % Update options for baseline, detection, or SOPH
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

    end
end
