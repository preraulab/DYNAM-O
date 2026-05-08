classdef DYNAMO < handle
    % DYNAMO  Class wrapper for running the DYNAM-O pipeline for time-frequency
    % peak and SO-power/phase histogram analysis
    %
    %   Usage:
    %       d = DYNAMO(data, Fs, stage_times, stage_vals, ...)
    %
    %   Input:
    %       data: [N x 1] vector - EEG time series data -- required
    %       Fs: double - sampling frequency in Hz -- required
    %       stage_times: [1 x T] vector - time markers for sleep staging (s) -- required
    %       stage_vals: [1 x T] vector - corresponding sleep stage values (1-5) -- required
    %
    %   Optional Name-Value Inputs:
    %       time_range: [1 x 2] double - start and end analysis time in seconds
    %       baseline_options: struct - baseline preprocessing options
    %       detection_options: struct - TF-peak detection options
    %       SOPH_options: struct - SO-power/phase histogram options
    %       param_basis_power_options: struct - parametric basis options (power)
    %       param_basis_phase_options: struct - parametric basis options (phase)
    %       spline_basis_power_options: struct - spline basis options (power)
    %       spline_basis_phase_options: struct - spline basis options (phase)
    %       stats_table: table - precomputed TF peak table (bypass detection)
    %       app: logical - launch the options GUI from the constructor (default: false)
    %
    %   The OOP runDYNAMO method always runs with plot_on/fit_param_basis/
    %   fit_spline_basis disabled — call displaySummaryPlot, fitParamBasis,
    %   and fitSplineBasis separately on the resulting object.
    %
    %   Public Properties:
    %       stats_table, SOPHs, spect, stimes, sfreqs,
    %       data_time_range, t_time_range, artifacts,
    %       data, Fs, stage_times, stage_vals, time_range,
    %       baseline_options, detection_options, SOPH_options,
    %       param_basis_*_options, spline_basis_*_options
    %
    %   Methods:
    %       runDYNAMO(...)        - run DYNAM-O pipeline. Compute TF-peaks and SOPHs
    %       updateOptions(...)    - update baseline/detection/SOPH options
    %       displaySummaryPlot()  - plot SOPH and TF peak summary figure
    %       displayTFPeaks()      - plot raw spectrogram and overlaid peaks
    %       fitParamBasis()       - fit parametric models to SOPHs
    %       fitSplineBasis()      - fit spline models to SOPHs
    %       plot()                - alias to displaySummaryPlot()
    %
    %   Example:
    %       % Instantiate a DYNAMO object
    %       d = DYNAMO(data, Fs, stage_times, stage_vals);
    %
    %       % Launch a GUI to set parameters and run DYNAMO
    %       d.app % recommended way
    %       open(d) % alternative way
    %
    %       % Instantiate a DYNAMO object and launch GUI directly
    %       d = DYNAMO(data, Fs, stage_times, stage_vals, 'app', true);
    %
    %       % Compute TF peaks
    %       d.runDYNAMO();
    %       d.displaySummaryPlot();
    %       d.displayTFPeaks();
    %
    %       % Re-run analysis with a different time window
    %       d.time_range = [0 3600];
    %       d.runDYNAMO();
    %
    %       % Update detection parameters programmatically, then re-run
    %       opts = detection_opts('quality_setting', 'precision');
    %       d.updateOptions('detection_options', opts);
    %       d.runDYNAMO();
    %
    %       % Force the MATLAB backend with a ThreadPool (useful on 8-core Apple Silicon)
    %       opts = detection_opts('parallel_mode', 'Threads');
    %       d.updateOptions('detection_options', opts);
    %       d.runDYNAMO('backend', 'matlab');
    %
    %   Notes on pool type (backend='matlab' only — backend='rust' uses no parpool):
    %       detection_options.parallel_mode controls the parallel pool:
    %           'Processes'  (default) — ProcessPool; fastest on most hosts.
    %           'Threads'              — ThreadPool; ~8% faster on 8-core M2/M3.
    %           ''                     — same as 'Processes'.
    %       The Rust backend (default) calls dynamo_rs via MEX wrappers that
    %       parallelise internally with rayon; MATLAB parpool is skipped in
    %       that mode. See rust_bridge/README.md for build instructions.
    %
    %       % Visualize and fit SOPH models
    %       fh = d.displaySummaryPlot();
    %       d.fitParamBasis();
    %       d.fitSplineBasis();
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
    %   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
    %   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
    %
    %    Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
    %    Manoach, D. S., Stickgold, R., Prerau, M. J.
    %    "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
    %     for Electroencephalographic Phenotyping and Biomarker Identification"
    %    Sleep, 2022; zsac223. https://doi.org
    %
    % =========================================================================
    properties
        % EEG / staging / outputs
        data                % EEG time series
        Fs                  % Sampling frequency
        stage_times         % Sleep stage timestamps
        stage_vals          % Sleep stage values

        % Analysis outputs
        stats_table         % Time-frequency peaks table
        SOPHs               % SO-power/phase histograms structure
        spect               % Spectrogram matrix
        stimes              % Spectrogram time vector
        sfreqs              % Spectrogram frequency vector
        data_time_range     % Data within time range
        t_time_range        % Time axis for data within time range
        artifacts           % Artifact mask / info

        % Options
        baseline_options
        detection_options
        SOPH_options

        % Basis fitting options
        param_basis_power_options
        param_basis_phase_options
        spline_basis_power_options
        spline_basis_phase_options

        % Misc
        time_range
    end

    properties (Access = private)
        data_validated = false
        staging_validated = false
        options_validated = false
    end

    methods
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Constructor
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function obj = DYNAMO(varargin)
            %DYNAMO Construct a DYNAMO object and parse inputs
            %
            %   Usage:
            %       obj = DYNAMO(data, Fs, stage_times, stage_vals, ...)
            %
            %   Input/Name-Value:
            %       See class header for full list of inputs and defaults.
            %
            %   Output:
            %       obj: DYNAMO object initialized with provided options.
            %
            %   Example:
            %       d = DYNAMO(data, Fs, stage_times, stage_vals);
            %
            if isempty(which('computeTFPeaks'))
                addpath(genpath(fileparts(which('DYNAMO.m'))))
            end

            if isempty(which('runExampleData'))
                addpath(fullfile(fileparts(which('DYNAMO.m')), 'example_data'))
            end

            if nargin <= 1 && strcmp(class(obj),"DYNAMO")
                if nargin == 0
                    data_range = 'segment';
                elseif any(strcmpi(varargin{1}, {'app', 'demo'}))
                    data_range = 'night';
                else
                    data_range = varargin{1};
                    assert(ismember(lower(data_range), {'segment','night'}), 'Select ''segment'' or ''night'' as input for example data.');
                end
                obj = runExampleData(data_range, true, true);
            else
                % Set up parser
                p = inputParser;
                p.KeepUnmatched = true;

                % Removes requirements as a subclass
                if strcmp(class(obj),"DYNAMO")
                    addRequired(p, 'data', @(x) isnumeric(x));
                    addRequired(p, 'Fs', @(x) isnumeric(x) && isscalar(x) && x > 0);
                    addRequired(p, 'stage_times', @(x) isnumeric(x));
                    addRequired(p, 'stage_vals', @(x) isnumeric(x));
                end

                addOptional(p, 'time_range', [], @(x) isempty(x) || (isnumeric(x) && numel(x)==2));
                addOptional(p, 'baseline_options', baseline_opts(), @(x) isstruct(x));
                addOptional(p, 'detection_options', detection_opts(), @(x) isstruct(x));
                addOptional(p, 'SOPH_options', SOpowerphasehist_opts(), @(x) isstruct(x));
                addOptional(p, 'param_basis_power_options', param_basis_opts('power'), @(x) isstruct(x));
                addOptional(p, 'param_basis_phase_options', param_basis_opts('phase'), @(x) isstruct(x));
                addOptional(p, 'spline_basis_power_options', spline_basis_opts('power'), @(x) isstruct(x));
                addOptional(p, 'spline_basis_phase_options', spline_basis_opts('phase'), @(x) isstruct(x));
                addOptional(p, 'stats_table', [], @(x) istable(x) || isempty(x));
                addOptional(p, 'app', false, @(x) islogical(x) || isnumeric(x));

                % Parse inputs
                parse(p, varargin{:});
                R = p.Results;

                % Avoid unnecessary data copying
                if strcmp(class(obj),"DYNAMO")
                    if iscolumn(R.data)
                        obj.data = R.data;  % No copy needed
                    else
                        obj.data = R.data(:);  % Only reshape if necessary
                    end

                    obj.Fs = R.Fs;
                    obj.stage_times = R.stage_times;
                    obj.stage_vals = single(R.stage_vals);
                end

                obj.baseline_options = R.baseline_options;
                obj.detection_options = R.detection_options;
                obj.param_basis_power_options = R.param_basis_power_options;
                obj.param_basis_phase_options = R.param_basis_phase_options;
                obj.spline_basis_power_options = R.spline_basis_power_options;
                obj.spline_basis_phase_options = R.spline_basis_phase_options;
                obj.SOPH_options = R.SOPH_options;
                obj.time_range = R.time_range;

                % Launch GUI from the constructor
                if R.app
                    obj.app();
                end
            end
        end

        % Lazy validation methods
        function validateData(obj)
            %VALIDATEDATA Perform expensive data validation only when needed
            if ~obj.data_validated
                validateattributes(obj.data, {'numeric'}, {'real','vector'});
                obj.data_validated = true;
            end
        end

        function validateStaging(obj)
            %VALIDATESTAGING Validate staging data only when needed
            if ~obj.staging_validated
                validateattributes(obj.stage_times, {'numeric'}, {'real','finite','nondecreasing','vector'});
                validateattributes(obj.stage_vals, {'numeric'}, {'real','finite','nonnegative','vector'});
                obj.staging_validated = true;
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % App GUI
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function app(obj, verbose, fig, tab)
            % APP  Open the DYNAMO options GUI
            if nargin<2
                obj.DYNAMOOptionsApp(false);
            elseif nargin==2
                obj.DYNAMOOptionsApp(verbose);
            elseif nargin==3
                obj.DYNAMOOptionsApp(verbose, fig);
            elseif nargin==4
                obj.DYNAMOOptionsApp(verbose, fig, tab);
            end
        end

        function open(obj)
            % OPEN  Alias to APP so users can call open(d)
            obj.app();
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % run
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function obj = runDYNAMO(obj)
            %run  Re-execute the DYNAM-O pipeline and compute TF
            %peaks and SOPH
            %
            %   Usage:
            %       obj.runDYNAMO()
            %
            %   Description:
            %       Runs the full DYNAM-O pipeline (wrapped runDYNAMO function)
            %       using the current object settings and stores the outputs in
            %       the object's properties: stats_table, SOPHs, spect, stimes,
            %       sfreqs, artifacts.
            %
            %   Inputs:
            %       obj: DYNAMO object (must be initialized)
            %
            %   Outputs:
            %       obj: DYNAMO object with updated analysis outputs
            %
            %   Example:
            %       d.runDYNAMO();
            %

            % Lazy validation - only validate when running
            obj.validateData();
            obj.validateStaging();
            assert(obj.isInitialized(), 'DYNAMO object is not fully initialized.');

            [obj.stats_table, obj.spect, obj.stimes, obj.sfreqs,...
                obj.data_time_range, obj.t_time_range, obj.artifacts, obj.SOPHs] = runDYNAMO(...
                obj.data, obj.Fs, obj.stage_times, obj.stage_vals, obj.time_range, ...
                obj.baseline_options, obj.detection_options, obj.SOPH_options, ...
                'fit_param_basis', false, 'fit_spline_basis', false, 'plot_on', false);
        end

        function obj = updateOptions(obj, varargin)
            %UPDATEOPTIONS  Update internal processing options
            %
            %   Usage:
            %       obj = obj.updateOptions('detection_options', new_opts, ...)
            %       obj = obj.updateOptions() % Launch GUI
            %
            %   Description:
            %       Update one or more option structs: baseline_options,
            %       detection_options, SOPH_options, param_basis_power_options,
            %       param_basis_phase_options, spline_basis_power_options,
            %       spline_basis_phase_options, or launch a GUI when called
            %       without arguments to interactively edit options.
            %
            %   Inputs:
            %       obj: DYNAMO object
            %       Name-Value pairs: Any combination of the following option structs:
            %         'baseline_options'
            %         'detection_options'
            %         'SOPH_options'
            %         'param_basis_power_options'
            %         'param_basis_phase_options'
            %         'spline_basis_power_options'
            %         'spline_basis_phase_options'
            %
            %   Outputs:
            %       obj: DYNAMO object with updated options
            %
            %   Example (programmatic):
            %       obj.updateOptions('detection_options', new_detection_opts, ...
            %                         'baseline_options', new_baseline_opts);
            %
            %   Example (GUI):
            %       obj.updateOptions();
            %

            % Launch GUI if no additional inputs (interactive editing)
            if nargin == 1
                obj.DYNAMOOptionsApp(false);
                return;
            end

            % Set up parser for all option types
            p = inputParser;
            addParameter(p, 'baseline_options', [], @(x) isstruct(x) || isempty(x));
            addParameter(p, 'detection_options', [], @(x) isstruct(x) || isempty(x));
            addParameter(p, 'SOPH_options', [], @(x) isstruct(x) || isempty(x));
            addParameter(p, 'param_basis_power_options', [], @(x) isstruct(x) || isempty(x));
            addParameter(p, 'param_basis_phase_options', [], @(x) isstruct(x) || isempty(x));
            addParameter(p, 'spline_basis_power_options', [], @(x) isstruct(x) || isempty(x));
            addParameter(p, 'spline_basis_phase_options', [], @(x) isstruct(x) || isempty(x));

            parse(p, varargin{:});

            % Update each option struct if provided
            if ~isempty(p.Results.baseline_options)
                obj.baseline_options = p.Results.baseline_options;
            end
            if ~isempty(p.Results.detection_options)
                obj.detection_options = p.Results.detection_options;
            end
            if ~isempty(p.Results.SOPH_options)
                obj.SOPH_options = p.Results.SOPH_options;
            end
            if ~isempty(p.Results.param_basis_power_options)
                obj.param_basis_power_options = p.Results.param_basis_power_options;
            end
            if ~isempty(p.Results.param_basis_phase_options)
                obj.param_basis_phase_options = p.Results.param_basis_phase_options;
            end
            if ~isempty(p.Results.spline_basis_power_options)
                obj.spline_basis_power_options = p.Results.spline_basis_power_options;
            end
            if ~isempty(p.Results.spline_basis_phase_options)
                obj.spline_basis_phase_options = p.Results.spline_basis_phase_options;
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % displaySummaryPlot
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function fh = displaySummaryPlot(obj)
            %DISPLAYSUMMARYPLOT  Display the summary figure of SOPHs and peaks
            %
            %   Usage:
            %       fh = obj.displaySummaryPlot()
            %
            %   Description:
            %       Displays histogram surfaces, detected peaks, and slow oscillation
            %       metrics using the stored SOPHs and stats_table. Requires the
            %       pipeline to have been run (runDYNAMO).
            %
            %   Inputs:
            %       obj: DYNAMO object with populated stats_table and SOPHs
            %
            %   Outputs:
            %       fh: figure handle of the generated summary plot
            %
            %   Example:
            %       fh = obj.displaySummaryPlot();
            %

            assert(obj.isInitialized(), 'Object not initialized properly.');
            assert(~isempty(obj.stats_table) && ~isempty(obj.SOPHs), 'Run the pipeline first.');

            fh = displaySummaryPlot('stage_times', obj.stage_times, ...
                'stage_vals', obj.stage_vals, ...
                'artifacts', obj.artifacts, ...
                't_time_range', obj.t_time_range, ...
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

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % displayTFPeaks
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function fh = displayTFPeaks(obj)
            %DISPLAYTFPEAKS  Plot raw spectrogram and overlay TF peaks
            %
            %   Usage:
            %       fh = obj.displayTFPeaks()
            %
            %   Description:
            %       Produces a figure of the raw spectrogram with detected TF peaks
            %       overlaid for validation and visualization of peak localization.
            %       Uses stored outputs from runDYNAMO.
            %
            %   Inputs:
            %       obj: DYNAMO object (must have spect, stimes, sfreqs, stats_table)
            %
            %   Outputs:
            %       fh: figure handle for the TF peaks plot
            %
            %   Example:
            %       fh = obj.displayTFPeaks();
            %

            % Required input checks
            assert(obj.isInitialized(), 'DYNAMO object is not fully initialized.');
            assert(~isempty(obj.stats_table), 'stats_table is empty.');
            assert(~isempty(obj.spect), 'spect is empty.');
            assert(~isempty(obj.stimes), 'stimes is empty.');
            assert(~isempty(obj.sfreqs), 'sfreqs is empty.');

            % Call the plotting function (keeps original signature)
            fh = displayTFPeaks(obj.stats_table, obj.spect, obj.stimes, obj.sfreqs, ...
                'data_time_range', obj.data_time_range, ...
                't_time_range', obj.t_time_range, ...
                'stage_times', obj.stage_times, ...
                'stage_vals', obj.stage_vals, ...
                'artifacts', obj.artifacts);
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % fitParamBasis
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function obj = fitParamBasis(obj, plot_on)
            %FITPARAMBASIS  Fit parametric models to SOPH histograms
            %
            %   Usage:
            %       obj = obj.fitParamBasis()
            %       obj = obj.fitParamBasis(plot_on)
            %
            %   Description:
            %       Fits Gaussian-like parametric mode models to SOPH power and phase
            %       histograms using the configured parametric options. Stores fit
            %       results in obj.SOPHs.*_paramfit fields.
            %
            %   Inputs:
            %       obj: DYNAMO object with SOPHs computed
            %       plot_on: logical (optional, default true) - whether to show fit plots
            %
            %   Outputs:
            %       obj: DYNAMO object with updated SOPH parametric fits
            %
            %   Example:
            %       obj.fitParamBasis(true);
            %

            if nargin < 2, plot_on = true; end
            assert(obj.isInitialized(), 'Object not initialized properly.');
            assert(~isempty(obj.SOPHs), 'SOPHs not computed.');

            opts_pow = obj.param_basis_power_options;
            opts_pow.plot_on = false;

            opts_phase = obj.param_basis_phase_options;
            opts_phase.plot_on = false;

            % Power and phase fits are isolated: a failure in one is logged
            % but does not block the other or anything downstream. Empty
            % *_paramfit signals "fit failed" to the rest of the pipeline.
            % Side variables are pre-set to [] so the plot call below can
            % run when only one of the two fits succeeded.
            pow_ok = false; phase_ok = false;
            params_pow = []; model_SOPH_pow = []; power_wshed_img = [];
            params_phase = []; model_SOPhH_phase = []; phase_wshed_img = [];
            % Phase fit runs first so its model surface
            % (model_SOPhH_phase) is available when the power table is
            % annotated with model-based preferred-phase columns.
            try
                [params_phase, fitobj_phase, gof_phase, model_SOPhH_phase, phase_wshed_img] = ...
                    param_basis_phase(obj.SOPHs.SOphase_mat, obj.SOPHs.SOphase_bins, obj.SOPHs.freq_bins, ...
                    opts_phase);
                if isempty(fitobj_phase)
                    obj.SOPHs.SOphase_paramfit = [];
                    fprintf(2, '   [WARN] param_basis_phase returned no fit (see warning above).\n');
                else
                    obj.SOPHs.SOphase_paramfit = obj.createSOPHparamfitStruct('phase', params_phase, fitobj_phase, gof_phase, model_SOPhH_phase, phase_wshed_img);
                    phase_ok = true;
                end
            catch ME_phase
                obj.SOPHs.SOphase_paramfit = [];
                fprintf(2, '   [ERROR] param_basis_phase failed: %s\n', ME_phase.message);
                warning('DYNAMO:fitParamBasis:phase', 'param_basis_phase failed: %s', ME_phase.message);
            end

            try
                [params_pow, fitobj_pow, gof_pow, model_SOPH_pow, power_wshed_img] = ...
                    param_basis_power(obj.SOPHs.SOpower_mat, obj.SOPHs.SOpower_bins, obj.SOPHs.freq_bins, ...
                    opts_pow);
                if isempty(fitobj_pow)
                    % Soft-fail: no fit object at all. param_basis_power
                    % normally produces at least a background-only fit
                    % (params=[], fitobj=plane); reaching here means
                    % something else went wrong upstream.
                    obj.SOPHs.SOpower_paramfit = [];
                    fprintf(2, '   [WARN] param_basis_power returned no fit (see warning above).\n');
                else
                    obj.SOPHs.SOpower_paramfit = obj.createSOPHparamfitStruct('power', params_pow, fitobj_pow, gof_pow, model_SOPH_pow, power_wshed_img);
                    pow_ok = true;

                    if ~isempty(obj.SOPHs.SOpower_paramfit.params)
                        obj.SOPHs.SOpower_paramfit.params = annotatePowerWithPreferredPhase( ...
                            obj.SOPHs.SOpower_paramfit.params, obj.SOPHs.SOphase_mat, ...
                            obj.SOPHs.freq_bins, obj.SOPHs.SOphase_bins, model_SOPhH_phase);
                    end
                end
            catch ME_pow
                obj.SOPHs.SOpower_paramfit = [];
                fprintf(2, '   [ERROR] param_basis_power failed: %s\n', ME_pow.message);
                warning('DYNAMO:fitParamBasis:power', 'param_basis_power failed: %s', ME_pow.message);
            end

            if plot_on && (pow_ok || phase_ok)
                if pow_ok,   pow_fitobj   = obj.SOPHs.SOpower_paramfit.fitobj; else, pow_fitobj   = []; end
                if phase_ok, phase_fitobj = obj.SOPHs.SOphase_paramfit.fitobj; else, phase_fitobj = []; end
                plot_SOPH_paramfits( ...
                    obj.SOPHs.SOpower_bins, power_wshed_img, obj.SOPHs.SOpower_mat, model_SOPH_pow, params_pow, opts_pow.SOPH_clim_prctiles, opts_pow.power_limits, opts_pow.freq_limits, ...
                    obj.SOPHs.SOphase_bins, phase_wshed_img, obj.SOPHs.SOphase_mat, model_SOPhH_phase, params_phase, opts_phase.SOPH_clim_prctiles, opts_phase.phase_limits, opts_phase.freq_limits, ...
                    obj.SOPHs.freq_bins, pow_fitobj, phase_fitobj);
            elseif plot_on
                figure;  % both fits failed — empty figure so gcf-grabbers don't die
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % fitSplineBasis
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function obj = fitSplineBasis(obj, plot_on)
            %FITSPLINEBASIS  Fit spline surfaces to SOPH histograms
            %
            %   Usage:
            %       obj = obj.fitSplineBasis()
            %       obj = obj.fitSplineBasis(plot_on)
            %
            %   Description:
            %       Fits flexible B-spline surfaces to power and phase SOPHs and
            %       stores spline fit objects and coefficients in the SOPHs struct.
            %
            %   Inputs:
            %       obj: DYNAMO object with SOPHs computed
            %       plot_on: logical (optional, default true) - display plots
            %
            %   Outputs:
            %       obj: DYNAMO object updated with spline fit fields
            %
            %   Example:
            %       obj.fitSplineBasis();
            %

            assert(obj.isInitialized(), 'Object not initialized properly.');
            assert(~isempty(obj.SOPHs), 'SOPHs not computed.');
            if nargin < 2, plot_on = true; end

            opts_pow = obj.spline_basis_power_options;
            opts_pow.plot_on = false;
            opts_phase = obj.spline_basis_phase_options;
            opts_phase.plot_on = false;

            % Same isolation pattern as fitParamBasis: each fit can fail
            % independently and the survivor (if any) still gets saved.
            pow_ok = false; phase_ok = false;
            fit_pow = []; coefs_pow = []; knots_x_pow = []; knots_y_pow = [];
            fit_phase = []; coefs_phase = []; knots_x_phase = []; knots_y_phase = [];
            try
                [fit_pow, coefs_pow, s_pow, knots_x_pow, knots_y_pow, fit_so_pow, fit_freq_pow] = ...
                    spline_basis('power', obj.SOPHs.SOpower_mat, obj.SOPHs.SOpower_bins, obj.SOPHs.freq_bins, opts_pow);
                obj.SOPHs.SOpower_splinefit = obj.createSOPHsplinefitStruct(fit_pow, coefs_pow, s_pow, knots_x_pow, knots_y_pow, fit_so_pow, fit_freq_pow);
                pow_ok = true;
            catch ME_pow
                obj.SOPHs.SOpower_splinefit = [];
                fprintf(2, '   [ERROR] spline_basis (power) failed: %s\n', ME_pow.message);
                warning('DYNAMO:fitSplineBasis:power', 'spline_basis (power) failed: %s', ME_pow.message);
            end

            try
                [fit_phase, coefs_phase, s_phase, knots_x_phase, knots_y_phase, fit_so_phase, fit_freq_phase] = ...
                    spline_basis('phase', obj.SOPHs.SOphase_mat, obj.SOPHs.SOphase_bins, obj.SOPHs.freq_bins, opts_phase);
                obj.SOPHs.SOphase_splinefit = obj.createSOPHsplinefitStruct(fit_phase, coefs_phase, s_phase, knots_x_phase, knots_y_phase, fit_so_phase, fit_freq_phase);
                phase_ok = true;
            catch ME_phase
                obj.SOPHs.SOphase_splinefit = [];
                fprintf(2, '   [ERROR] spline_basis (phase) failed: %s\n', ME_phase.message);
                warning('DYNAMO:fitSplineBasis:phase', 'spline_basis (phase) failed: %s', ME_phase.message);
            end

            if plot_on && (pow_ok || phase_ok)
                plot_SOPH_splinefits( ...
                    obj.SOPHs.SOpower_mat, obj.SOPHs.SOpower_bins, fit_pow, coefs_pow, knots_x_pow, knots_y_pow, opts_pow, ...
                    obj.SOPHs.SOphase_mat, obj.SOPHs.SOphase_bins, fit_phase, coefs_phase, knots_x_phase, knots_y_phase, opts_phase, ...
                    obj.SOPHs.freq_bins);
            elseif plot_on
                figure;
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % plot (alias)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function fh = plot(obj)
            %PLOT  Shortcut for displaying the summary SOPH/TF peak plot
            %
            %   Usage:
            %       fh = plot(obj)
            %
            %   This overrides the built-in plot() to call displaySummaryPlot().
            %
            %   Example:
            %       fh = obj.plot();
            %

            fh = obj.displaySummaryPlot();
        end
    end

    methods (Access = protected)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % DYNAMOOptionsApp
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function obj = DYNAMOOptionsApp(obj, verbose, fig, tab, showButtons)
            %DYNAMOOPTIONSAPP  Simplified GUI for editing DYNAMO pipeline options
            %
            %   Usage:
            %       obj = obj.DYNAMOOptionsApp(verbose)
            %
            %   Description:
            %       Launches a uifigure-based GUI allowing interactive editing of
            %       various option structs used by the DYNAMO pipeline. Changes are
            %       written directly back into the DYNAMO object properties.
            %
            %   Inputs:
            %       obj: DYNAMO object
            %       verbose: logical - display console messages (default: false)
            %       fig: figure handle - parent figure
            %       tab: tab handle - parent tab
            %       showButtons: logical - display buttons to run analyses (default: true)
            %
            %   Outputs:
            %       obj: DYNAMO object possibly modified via GUI interaction
            %

            if nargin == 1
                verbose = false;
            end

            % Single shared CSSPreset for every CSSui* widget in this dialog.
            appStyle = dynamoStyle();

            % Create main figure
            if nargin<3 || isempty(fig)
                fig = uifigure('Name', 'DYNAMO Options', 'Position', [100 100 900 650]);
                tabGroup = uitabgroup(fig, 'Position', [10 60 880 580]);
                fig.AutoResizeChildren = true;
            else
                tabGroup = uitabgroup(tab);
            end

            if nargin<5
                showButtons = false;
            end

            % Create main menu
            mSettings = uimenu(fig, 'Text', 'DYNAM-O Settings');

            % Create submenu items
            uimenu(mSettings, 'Text', 'Load DYNAM-O Settings...', ...
                'MenuSelectedFcn', @loadSettingsCallback);

            uimenu(mSettings, 'Text', 'Save DYNAM-O Settings...', ...
                'MenuSelectedFcn', @saveSettingsCallback);

            % --- Callback functions ---
            function loadSettingsCallback(~, ~)
                % Load settings from a JSON file written by saveSettingsCallback
                % / the DYNAMOApp run-log. The legacy `.txt` format stored
                % MATLAB code and was loaded via `run()` — a code-injection
                % vector. JSON is inert (jsondecode = data deserialization only).
                [filename, filepath] = uigetfile({'*.json'}, 'Select DYNAM-O settings file (JSON).');
                if isequal(filename, 0); return; end

                try
                    settings = load_run_log(fullfile(filepath, filename));
                catch err
                    uialert(fig, sprintf('Could not parse settings file:\n%s', err.message), ...
                        'Load Settings', 'Icon', 'error');
                    return
                end

                % Update each option struct present in the file. Any
                % unknown keys in settings.options are ignored.
                opt_names = fieldnames(settings.options);
                for k = 1:numel(opt_names)
                    name = opt_names{k};
                    if isprop(obj, name)
                        obj.updateOptions(name, settings.options.(name));
                    end
                end
                updateAll();
            end

            function saveSettingsCallback(~, ~)
                dir_name = uigetdir();

                if dir_name ~= 0
                    options_structs = cell(1, length(all_configs));
                    struct_names = cell(1, length(all_configs));
                    curr_datetime = char(datetime('now','Format','yyMMdd_HHmmSS'));

                    for k = 1:length(all_configs)
                        options_structs{k} = obj.(all_configs{k}.field);
                        struct_names{k} = all_configs{k}.field();
                    end

                    generate_run_log(options_structs, struct_names,'run_start',curr_datetime,'file_path',dir_name);

                    clear dir_name options_structs struct_names curr_datetime
                end
            end

            % Basic option configurations (no changes)
            basic_configs = {
                struct('name', 'Detection', 'field', 'detection_options', 'constructor', @detection_opts)
                struct('name', 'Baseline', 'field', 'baseline_options', 'constructor', @baseline_opts)
                struct('name', 'SOPHs', 'field', 'SOPH_options', 'constructor', @SOpowerphasehist_opts)
                };

            % Create basic tabs and tables
            basic_tables = cell(size(basic_configs));
            for jj = 1:length(basic_configs)
                tab = uitab(tabGroup, 'Title', [basic_configs{jj}.name ' Options']);
                basic_tables{jj} = createTable(tab, obj.(basic_configs{jj}.field), basic_configs{jj});
            end


            % Create Parametric Fit main tab with subtabs
            param_tab  = uitab(tabGroup, 'Title', 'Parametric Fit');
            param_grid = uigridlayout(param_tab, 'RowHeight', {'1x'}, 'ColumnWidth', {'1x'}, 'Padding', [0 0 0 0]);
            param_subtab_group = uitabgroup(param_grid);
            param_subtab_group.Layout.Row    = 1;
            param_subtab_group.Layout.Column = 1;

            % Parametric subtab configurations
            param_configs = {
                struct('name', 'Power Fit', 'field', 'param_basis_power_options', 'constructor', @(x)param_basis_opts('power'))
                struct('name', 'Phase Fit', 'field', 'param_basis_phase_options', 'constructor', @(x)param_basis_opts('phase'))
                };

            param_tables = cell(size(param_configs));
            for jj = 1:length(param_configs)
                subtab = uitab(param_subtab_group, 'Title', param_configs{jj}.name);
                param_tables{jj} = createSubTable(subtab, obj.(param_configs{jj}.field), param_configs{jj});
            end

            % Create Spline Fit main tab with subtabs
            spline_tab  = uitab(tabGroup, 'Title', 'Spline Fit');
            spline_grid = uigridlayout(spline_tab, 'RowHeight', {'1x'}, 'ColumnWidth', {'1x'}, 'Padding', [0 0 0 0]);
            spline_subtab_group = uitabgroup(spline_grid);
            spline_subtab_group.Layout.Row    = 1;
            spline_subtab_group.Layout.Column = 1;

            % Spline subtab configurations
            spline_configs = {
                struct('name', 'Power Fit', 'field', 'spline_basis_power_options', 'constructor', @(x)spline_basis_opts('power'))
                struct('name', 'Phase Fit', 'field', 'spline_basis_phase_options', 'constructor', @(x)spline_basis_opts('phase'))
                };

            spline_tables = cell(size(spline_configs));
            for jj = 1:length(spline_configs)
                subtab = uitab(spline_subtab_group, 'Title', spline_configs{jj}.name);
                spline_tables{jj} = createSubTable(subtab, obj.(spline_configs{jj}.field), spline_configs{jj});
            end

            % Combine all configs and tables for reset functionality
            all_configs = [basic_configs; param_configs; spline_configs];
            all_tables = [basic_tables; param_tables; spline_tables];

            % ---- Buttons ----
            if showButtons
                buttonLabels = {'Reset All','Run DYNAMO','Plot Summary','Param Fit','Spline Fit','Close'};
                buttonCallbacks = {@resetAll, @rerunDynamo, @plotSummary, @runParamFit, @runSplineFit, @(~,~) delete(fig)};

                nButtons = numel(buttonLabels);
                buttonWidth = 120;
                buttonHeight = 40;
                spacing = 20;
                totalWidth = nButtons*buttonWidth + (nButtons-1)*spacing;
                startX = (fig.Position(3) - totalWidth)/2; % center align

                for jj = 1:nButtons
                    xpos = startX + (jj-1)*(buttonWidth+spacing);
                    CSSuiButton(fig, 'Style', appStyle, ...
                        'Text', buttonLabels{jj}, ...
                        'Position', [xpos 10 buttonWidth buttonHeight], ...
                        'ButtonPushedFcn', buttonCallbacks{jj});
                end

                % uiwait(fig); % this wait is not necessary
            end

            % --- Button callbacks ---
            function resetAll(~,~)
                if verbose, disp('Resetting all options...'); end
                for k = 1:length(all_configs)
                    obj.(all_configs{k}.field) = all_configs{k}.constructor();
                    all_tables{k}.Data = tableData2cell(createTableData(obj.(all_configs{k}.field), all_configs{k}));
                end
            end

            function updateAll(~,~)
                if verbose, disp('Updating all options...'); end
                for k = 1:length(all_configs)
                    all_tables{k}.Data = tableData2cell(createTableData(obj.(all_configs{k}.field), all_configs{k}));
                end
            end

            function plotSummary(~,~)
                obj.displaySummaryPlot;
            end

            function runParamFit(~,~)
                if verbose, disp('Running parametric fit...'); end
                obj.fitParamBasis;
            end

            function runSplineFit(~,~)
                if verbose, disp('Running spline fit...'); end
                obj.fitSplineBasis
            end

            %------------------------------------------------------------------
            function tableData = createTableData(opts, config)
                %CREATETABLEDATA  Build the table Data for an options struct
                %
                %   tableData = createTableData(opts, config)
                %
                %   This helper converts an options struct into a 3-column MATLAB
                %   table suitable for use as the 'Data' property of a uitable.
                %   It formats each option value for display (e.g., dropdowns,
                %   logicals, vectors) and pulls human-readable descriptions using
                %   the constructor specified in config.
                %

                fields = fieldnames(opts);
                numFields = length(fields);

                paramNames = cell(numFields, 1);
                descriptions = cell(numFields, 1);
                values = cell(numFields, 1);

                for j = 1:numFields
                    paramNames{j} = fields{j};
                    descriptions{j} = getDescription(paramNames{j}, config.constructor);
                    formattedValue = formatValue(fields{j}, opts.(fields{j}), config.constructor);
                    values{j} = formattedValue;
                end

                tableData = table(paramNames, descriptions, values, ...
                    'VariableNames', {'Parameter', 'Description', 'Value'});
            end

            function tbl = createTable(parent, opts, config)
                %CREATETABLE  CSS-styled options table with inline edit strip.
                %   Builds a CSSuiTable showing Parameter/Description/Value and
                %   an edit strip below. Click a row to load its value into the
                %   edit field, then press Apply (or Select... for the features
                %   special case) to commit the change.

                % Outer grid: table on top, edit strip on bottom
                g = uigridlayout(parent);
                g.RowHeight    = {'1x', 38};
                g.ColumnWidth  = {'1x'};
                g.RowSpacing   = 4;
                g.Padding      = [4 4 4 4];

                tbl = CSSuiTable(g, ...
                    'ColumnName',  {'Parameter', 'Description', 'Value'}, ...
                    'ColumnWidth', [180, 470, 150], ...
                    'Data',        tableData2cell(createTableData(opts, config)), ...
                    'Style', appStyle, ...
                    'SelectionType', 'row');
                tbl.Layout.Row    = 1;
                tbl.Layout.Column = 1;

                % Edit strip — always enabled; Apply guards against empty selection
                editGrid = uigridlayout(g);
                editGrid.ColumnWidth  = {'fit', '1x', 80};
                editGrid.RowHeight    = {'1x'};
                editGrid.Padding      = [0 0 0 0];
                editGrid.ColumnSpacing = 6;
                editGrid.Layout.Row    = 2;
                editGrid.Layout.Column = 1;

                selLabel = CSSuiLabel(editGrid, 'Style', appStyle, ...
                    'Text', 'Select a row to edit', 'HorizontalAlignment', 'left');
                selLabel.Layout.Row = 1; selLabel.Layout.Column = 1;

                valField = CSSuiEditField(editGrid, 'Style', appStyle, ...
                    'Placeholder', 'Select a row above');
                valField.Layout.Row = 1; valField.Layout.Column = 2;

                applyBtn = CSSuiButton(editGrid, 'Style', appStyle, 'Text', 'Apply');
                applyBtn.Layout.Row = 1; applyBtn.Layout.Column = 3;

                curRow   = [];
                curParam = '';

                tbl.SelectionChangedFcn  = @onRowSelected;
                applyBtn.ButtonPushedFcn = @onApply;

                function onRowSelected(~, evt)
                    rows = evt.Selection;
                    if isempty(rows), return; end
                    curRow   = rows(1);
                    curParam = tbl.Data{curRow, 1};
                    selLabel.Text  = curParam;
                    valField.Value = tbl.Data{curRow, 3};
                end

                function onApply(~, ~)
                    if isempty(curRow), return; end
                    % Features param uses the picker dialog instead of the text field
                    if strcmp(curParam,'features') && isequal(config.constructor, @detection_opts)
                        new = featuresDialog(obj.(config.field).features);
                        if isempty(new), return; end
                        newVal = new;
                    else
                        newVal = valField.Value;
                    end
                    try
                        newOpts = updateOption(obj.(config.field), curParam, newVal, config.constructor);
                        obj.(config.field) = newOpts;
                        tbl.Data = tableData2cell(createTableData(obj.(config.field), config));
                        if verbose
                            fprintf('Updated %s.%s\n', config.field, curParam);
                        end
                    catch ME
                        uialert(fig, ME.message, 'Validation Error');
                    end
                end
            end

            %------------------------------------------------------------------
            function tbl = createSubTable(parent, opts, config)
                %CREATESUBTABLE  Delegates to createTable (same layout, subtab context).
                tbl = createTable(parent, opts, config);
            end

            %------------------------------------------------------------------
            function c = tableData2cell(tableData)
                %TABLEDATA2CELL  Convert options MATLAB table to N×3 char cell for CSSuiTable.
                n = height(tableData);
                c = cell(n, 3);
                for ii = 1:n
                    c{ii,1} = tableData.Parameter{ii};
                    c{ii,2} = tableData.Description{ii};
                    v = tableData.Value{ii};
                    if iscategorical(v)
                        c{ii,3} = char(v);
                    elseif ischar(v) || isstring(v)
                        c{ii,3} = char(v);
                    else
                        c{ii,3} = mat2str(v);
                    end
                end
            end

            %------------------------------------------------------------------
            function rerunDynamo(~, ~)
                %RERUNDYNAMO  Rerun DYNAMO pipeline with current GUI options
                try
                    % Show progress dialog
                    progressDlg = uiprogressdlg(fig, 'Title', 'Running DYNAMO...', ...
                        'Message', 'Processing with updated options...', ...
                        'Indeterminate', 'on');

                    % Rerun DYNAMO with current options (uses runDYNAMO wrapper)
                    obj.runDYNAMO();

                    % Close progress dialog if open
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
                    uialert(fig, ['Error during rerun: ' ME.message], 'Rerun Error');
                    if verbose
                        fprintf('❌ DYNAMO rerun failed: %s\n', ME.message);
                    end
                end
            end

            %------------------------------------------------------------------
            function newOpts = updateOption(opts, param, value, constructor)
                %UPDATEOPTION  Update a single option field and revalidate using constructor
                %
                %   newOpts = updateOption(opts, param, value, constructor)
                %
                %   This helper parses edited cell values, updates the struct, and
                %   re-validates by calling the corresponding options constructor.
                %

                % Parse value string form if provided
                if ischar(value) || isstring(value)
                    value = parseValue(param, char(value));
                end

                % Update struct
                opts.(param) = value;

                % Validate with constructor by expanding struct into args
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

            %------------------------------------------------------------------
            function value = parseValue(param, str)
                %PARSEVALUE  Convert a text string to the appropriate MATLAB type
                %
                %   value = parseValue(param, str)
                %
                %   Handles numeric arrays, empty values, cell-like lists and base
                %   workspace variable references when possible. Reserved keywords
                %   such as 'all' are preserved.
                %

                str = strtrim(str);
                if strcmp(param, 'parallel_mode')
                    if isempty(str) || strcmp(str, '(auto)')
                        value = '';
                    else
                        value = str;
                    end
                    return;
                end
                if strcmp(param, 'backend')
                    value = lower(str);
                    return;
                end
                if isempty(str)
                    value = [];
                elseif ismember(str, {'true'})
                    value = true;
                elseif ismember(str, {'false'})
                    value = false;
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

            %------------------------------------------------------------------
            function cellArray = parseCell(str)
                %PARSECELL  Parse a cell-list string like {'a','b'} into a cell array
                content = strtrim(str(2:end-1));
                if isempty(content)
                    cellArray = {};
                else
                    parts = strsplit(content, ',');
                    cellArray = cellfun(@(x) strtrim(strrep(strrep(x, '''', ''), '"', '')), parts, 'UniformOutput', false);
                end
            end

            %------------------------------------------------------------------
            function args = struct2args(s)
                %STRUCT2ARGS  Convert struct to name/value pair cell array
                fields = fieldnames(s);
                args = cell(1, 2*length(fields));
                for ii = 1:length(fields)
                    args{2*ii-1} = fields{ii};
                    args{2*ii} = s.(fields{ii});
                end
            end

            %------------------------------------------------------------------
            function str = formatValue(param, value, constructor)
                %FORMATVALUE  Format an option value for display in the uitable
                %
                %   str = formatValue(param, value, constructor)
                %
                %   This function converts values into human-readable cell entries
                %   for the Value column in the options table. It supports categorical
                %   dropdowns, logicals, numeric arrays, scalars and special formatting
                %   for pi-related values.
                %

                % Known enum options — return plain string (valid values shown in description)
                if isequal(constructor, @detection_opts) && strcmp(param, 'quality_setting')
                    str = char(value);
                    return;
                end

                if isequal(constructor, @detection_opts) && strcmp(param, 'parallel_mode')
                    if isempty(value)
                        str = '(auto)';
                    else
                        str = char(value);
                    end
                    return;
                end

                if isequal(constructor, @detection_opts) && strcmp(param, 'backend')
                    str = lower(char(value));
                    return;
                end

                if (strcmp(func2str(constructor), '@(x)param_basis_opts(''power'')') || strcmp(func2str(constructor), '@(x)param_basis_opts(''phase'')')) && strcmp(param, 'criterion')
                    str = char(value);
                    return;
                end

                if strcmp(param, 'features') && isequal(constructor, @detection_opts)
                    if ischar(value) && strcmp(value, 'all')
                        str = 'all';
                    elseif iscell(value)
                        str = ['{' strjoin(cellfun(@(x) ['''' x ''''], value, 'UniformOutput', false), ', ') '}'];
                    else
                        str = char(value);
                    end
                    return;
                end

                if islogical(value) && isscalar(value)
                    str = char(string(value));   % 'true' or 'false'
                    return;
                end

                % Special handling for numeric verbose parameters in param/spline basis options
                if strcmp(param, 'verbose') && isnumeric(value) && isscalar(value) && ...
                        (strcmp(func2str(constructor), '@(x)param_basis_opts(''power'')') || ...
                        strcmp(func2str(constructor), '@(x)param_basis_opts(''phase'')') || ...
                        strcmp(func2str(constructor), '@(x)spline_basis_opts(''power'')') || ...
                        strcmp(func2str(constructor), '@(x)spline_basis_opts(''phase'')'))
                    str = num2str(value); % Keep as numeric string, not logical
                    return;
                end

                if ischar(value) || isstring(value)
                    str = char(value);
                    return;
                end

                if isnumeric(value)
                    if isempty(value)
                        str = '[]';
                    elseif isscalar(value)
                        str = num2str(value);
                    else
                        str = mat2str(value);
                    end
                    % Efficient string building for pi fractions
                    if ismember(param, {'SOphase_binsizestep', 'SOphase_range', 'LB_default', 'UB_default', 'watershed_params', 'phase_limits'})
                        % Build cell array of strings first, then join
                        pi_strings = cell(1, length(value));
                        for ii = 1:length(value)
                            pi_strings{ii} = obj.double2pifracstr(value(ii));
                        end
                        str = ['[' strjoin(pi_strings, ' ') ']'];
                    end
                    return;
                end

                % Fallback
                str = mat2str(value);
            end

            %------------------------------------------------------------------
            function desc = getDescription(param, constructor)
                %GETDESCRIPTION  Lookup a human-readable description for a parameter
                descriptions = getDescMap(constructor);
                if isfield(descriptions, param)
                    desc = descriptions.(param);
                else
                    desc = '';
                end
            end

            %------------------------------------------------------------------
            function map = getDescMap(constructor)
                %GETDESCMAP  Return a struct mapping params -> short descriptions
                if isequal(constructor, @detection_opts)
                    map = struct(...
                        'double_watershed', 'Run 2nd pass watershed', ...
                        'mtm_dsfreqs', 'Frequency bin resolution (Hz)', ...
                        'mtm_freq_range', 'Frequency range [min max] (Hz)', ...
                        'mtm_taper_params', '[time-halfbandwidth, tapers]', ...
                        'mtm_window_length_1', '1st pass window size (s)', ...
                        'mtm_window_length_2', '2nd pass window size (s)', ...
                        'mtm_window_stepsize', 'Window step size (s)', ...
                        'downsample_spect', '[time, freq] downsample steps', ...
                        'seg_time', 'Segment length (s)', ...
                        'merge_thresh', 'Merge threshold', ...
                        'quality_setting', 'Parameter preset', ...
                        'max_merges', 'Max merges per segment', ...
                        'trim_vol', 'Volume trim fraction', ...
                        'show_pbar','Show the progress bar',...
                        'dur_max', 'Max duration (s)', ...
                        'bw_max', 'Max bandwidth (Hz)', ...
                        'refinement', 'Refine peak frequency', ...
                        'reuse_baseline', 'Reuse pass-1 baseline in pass-2 (~5% faster)', ...
                        'features', 'Features to compute', ...
                        'debug_mode', 'Debug mode', ...
                        'parallel_mode', 'Pool type: Processes, Threads, or auto', ...
                        'backend', 'Pipeline backend: rust (MEX, fast) or matlab (reference)');
                elseif isequal(constructor, @baseline_opts)
                    map = struct(...
                        'baseline_stages', 'Sleep stages for baseline 5=Wake, 4=REM, 3=N1, 2=N2, 1=N1, 0=Unknown, 6=Artifact', ...
                        'baseline_exclude', 'Exclude time points', ...
                        'baseline_ptile', 'Percentile for baseline', ...
                        'baseline_trim', 'Trim times (min)');
                elseif isequal(constructor, @SOpowerphasehist_opts)
                    map = struct(...
                        'freq_range', 'Frequency range (Hz)', ...
                        'freq_binsizestep', '[bin size, step] (Hz)', ...
                        'compute_rate', 'Compute event rate', ...
                        'SOPH_stages', 'Sleep stages 5=Wake, 4=REM, 3=N1, 2=N2, 1=N1, 0=Unknown, 6=Artifact', ...
                        'SO_freqrange', 'SO frequency range (Hz)', ...
                        'SOpower_tapers', '[time-halfbandwidth, tapers]', ...
                        'SOpower_window_params', '[window length, step] (s)', ...
                        'SOpower_outlier_threshold', 'Outlier threshold', ...
                        'SOpower_norm_method', 'Normalization method', ...
                        'SOpower_retain_Fs', 'Retain sampling freq', ...
                        'SOpower_min_time_in_bin', 'Min time in bin (s) required to display', ...
                        'SOpower_range', 'Power range (auto if empty)', ...
                        'SOpower_binsizestep', 'Power bin size/step', ...
                        'SOphase_filter', 'Phase filter settings', ...
                        'SOphase_norm_dim', 'Phase norm dimension', ...
                        'SOphase_range', 'Phase range (radians)', ...
                        'SOphase_binsizestep', 'Phase bin size/step', ...
                        'SOphase_min_peak_at_freq', 'Min number of peaks required to display');
                elseif strcmp(func2str(constructor), '@(x)param_basis_opts(''power'')')
                    map = struct(...
                        'power_limits', 'SO-power limits for watershed and parameterization (dB)', ...
                        'freq_limits', 'Frequency limits for watershed and parameterization (Hz)', ...
                        'watershed_params', '[merge_thresh, dur_min, bw_min, height_min, trim_vol]', ...
                        'wshed_exp', 'Watershed expansion flag', ...
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
                        'verbose', 'Display detailed output');
                elseif strcmp(func2str(constructor), '@(x)param_basis_opts(''phase'')')
                    map = struct(...
                        'phase_limits', 'SO-phase limits for watershed and parameterization (rad)', ...
                        'freq_limits', 'Frequency limits for watershed and parameterization (Hz)', ...
                        'watershed_params', '[merge_thresh, dur_min, bw_min, height_min, trim_vol]', ...
                        'gauss_filt_std', 'Gaussian filter std dev [row, col] for spectrogram smoothing', ...
                        'wshed_exp', 'Watershed expansion flag', ...
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
                        'verbose', 'Display detailed output');
                elseif strcmp(func2str(constructor), '@(x)spline_basis_opts(''power'')')
                    map = struct(...
                        'power_limits', 'SO-power limits for splines (dB)', ...
                        'freq_limits', 'Frequency limits for splines (Hz)', ...
                        'num_knots_x', 'Number of spline knots in the x dimension', ...
                        'num_knots_y', 'Number of spline knots in the y dimension', ...
                        'plot_on', 'Plot flag', ...
                        'SOPH_clim_prctiles', 'Heatmap color scaling percentiles [low, high]');
                elseif strcmp(func2str(constructor), '@(x)spline_basis_opts(''phase'')')
                    map = struct(...
                        'phase_limits', 'SO-phase limits for splines (rad)', ...
                        'freq_limits', 'Frequency limits for splines (Hz)', ...
                        'num_knots_x', 'Number of spline knots in the x dimension', ...
                        'num_knots_y', 'Number of spline knots in the y dimension', ...
                        'plot_on', 'Plot flag', ...
                        'SOPH_clim_prctiles', 'Heatmap color scaling percentiles [low, high]');
                else
                    map = struct();
                end
            end

            %------------------------------------------------------------------
            function result = featuresDialog(current)
                %FEATURESDIALOG  Simple modal dialog to choose detection features
                %
                %   result = featuresDialog(current)
                %
                %   Returns either 'all' or a cell array of selected feature names.
                %

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

                % Build dialog
                dlg = uifigure('Name', 'Select Features', 'Position', [300 300 300 400], 'WindowStyle', 'modal');
                listbox = CSSuiListBox(dlg, 'Items', features, 'Value', selected, 'Multiselect', true, ...
                    'Style', appStyle, ...
                    'Position', [20 80 260 280]);

                result = [];
                CSSuiButton(dlg, 'Style', appStyle, 'Text', 'OK', 'Position', [150 20 50 30], ...
                    'ButtonPushedFcn', @(~,~) setResult());
                CSSuiButton(dlg, 'Style', appStyle, 'Text', 'Cancel', 'Position', [210 20 60 30], ...
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
        end % end DYNAMOOptionsApp

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % isInitialized
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function tf = isInitialized(obj)
            %ISINITIALIZED  Check if required fields are present
            %
            %   tf = obj.isInitialized()
            %
            %   Returns true if the object contains valid data and configuration.
            tf = ~isempty(obj.data) && ~isempty(obj.Fs) && ...
                ~isempty(obj.stage_times) && ~isempty(obj.stage_vals);
        end
    end

    methods (Static)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % createSOPHsStruct
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [SOPHs] = createSOPHsStruct(SOpower_mat, SOphase_mat, SOpower_bins, SOpower_norm, SOpower_times, SOphase_bins, freq_bins, num_peaks_at_freq, SOpower_TIB, SOphase_TIB)
            %CREATESOPHSSTRUCT  Helper to construct a SOPHs struct
            %
            %   SOPHs = createSOPHsStruct(...)
            %
            %   Packs commonly used SOPH outputs into a single struct.
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

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % createSOPHparamfitStruct
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [SOPH_paramfit] = createSOPHparamfitStruct(type, params, fitobj, gof, model_SOPH, wshed_img)
            %CREATESOPHPARAMFITSTRUCT  Pack parametric fit outputs into struct
            %
            %   type: 'power' or 'phase' — selects column names of the
            %         returned params table.
            %   params: N×6 numeric matrix [amp, fmean, fstd, pmean, pstd, theta]
            %
            %   .params is returned as a table.
            %   power: Amplitude (peaks/min/bin), FreqMean (Hz), FreqStd (Hz),
            %          SOpowerMean (dB), SOpowerStd (dB), Theta (rad), plus
            %          (added by fitParamBasis annotation):
            %          PrefPhaseArgmax (rad),  CouplingArgmax (proportion/phase-bin),
            %          PrefPhaseCirc   (rad),  CouplingCirc   ([0,1] MRL),
            %          PrefPhaseModel  (rad),  CouplingModel  (proportion/phase-bin).
            %   phase: Amplitude (proportion/phase-bin), FreqMean (Hz), FreqStd (Hz),
            %          SOphaseMean (rad), SOphaseStd (rad), Theta (rad).
            %
            %   NOTE: power Amplitude is peaks/min/bin; phase Amplitude and the argmax/model coupling columns are proportion/phase-bin (phase histogram is row-normalized upstream); CouplingCirc is dimensionless MRL in [0,1].
            switch lower(type)
                case 'power'
                    vn      = {'Amplitude','FreqMean','FreqStd','SOpowerMean','SOpowerStd','Theta'};
                    vn_full = [vn, {'PrefPhaseArgmax','CouplingArgmax', ...
                                    'PrefPhaseCirc','CouplingCirc', ...
                                    'PrefPhaseModel','CouplingModel'}];
                case 'phase'
                    vn      = {'Amplitude','FreqMean','FreqStd','SOphaseMean','SOphaseStd','Theta'};
                    vn_full = vn;
                otherwise
                    error('createSOPHparamfitStruct:badType','type must be ''power'' or ''phase''.');
            end
            SOPH_paramfit = struct;
            if isempty(params)
                SOPH_paramfit.params = array2table(zeros(0,numel(vn_full)),'VariableNames',vn_full);
            else
                SOPH_paramfit.params = array2table(params,'VariableNames',vn);
            end
            SOPH_paramfit.fitobj = fitobj;
            SOPH_paramfit.gof = gof;
            SOPH_paramfit.model_SOPH = model_SOPH;
            SOPH_paramfit.wshed_img = wshed_img;
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % createSOPHsplinefitStruct
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [SOPH_splinefit] = createSOPHsplinefitStruct(splinefit, coefs, spline_obj, knots_x, knots_y, fit_SOfeature_bins, fit_freq_bins)
            %CREATESOPHSPLINEFITSTRUCT  Pack spline fit outputs into struct.
            %   fit_SOfeature_bins / fit_freq_bins (optional) are the
            %   filtered fit-domain bins from spline_basis — required by
            %   the GUI save path so the spline tiff metadata can carry
            %   the bins page 2 was actually rendered on.
            if nargin < 6, fit_SOfeature_bins = []; end
            if nargin < 7, fit_freq_bins      = []; end
            SOPH_splinefit = struct;
            SOPH_splinefit.splinefit = splinefit;
            SOPH_splinefit.coefs = coefs;
            SOPH_splinefit.spline_obj = spline_obj;
            SOPH_splinefit.knots_x = knots_x;
            SOPH_splinefit.knots_y = knots_y;
            SOPH_splinefit.fit_SOfeature_bins = fit_SOfeature_bins;
            SOPH_splinefit.fit_freq_bins      = fit_freq_bins;
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % double2pifracstr
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function pi_str = double2pifracstr(val, tol)
            %DOUBLE2PIFRACSTR  Convert numeric value to human friendly pi-fraction string
            %
            %   pi_str = double2pifracstr(val)
            %
            %   Attempts to express val as a rational multiple of pi within tolerance.
            if nargin < 2
                tol = 1e-10;
            end
            [n,d] = rat(val/pi,tol);
            if n<100 && d<100 && n~=0 && d~=0
                % Build string efficiently
                if n == -1
                    pi_str = '-pi';
                elseif n == 1
                    pi_str = 'pi';
                else
                    pi_str = [num2str(n) '*pi'];
                end
                if d > 1
                    pi_str = [pi_str '/' num2str(d)];
                end
            else
                pi_str = num2str(val);
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % writeTiff
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function writeTiff(filename,data,description)
            % Optional `description` (char/string/struct) is embedded in
            % the ImageDescription tag of page 1 — used by SOPH writes
            % to carry freq_bins / SO bins so downstream readers can
            % label axes. `data` may be a single 2-D matrix or a cell
            % array of matrices (one per page); pages may differ in
            % size. Used by the spline writer to ship coefs on page 1
            % and the rendered fit on page 2.

            if nargin < 3, description = []; end
            if isstruct(description), description = jsonencode(description); end

            if iscell(data)
                pages = data;
            else
                pages = {data};
            end

            t = Tiff(filename, 'w');
            cleaner = onCleanup(@() close(t)); %#ok<NASGU>

            for kk = 1:numel(pages)
                page = pages{kk};
                tagstruct = struct();
                tagstruct.ImageLength = size(page, 1);
                tagstruct.ImageWidth = size(page, 2);
                tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
                tagstruct.BitsPerSample = 64;              % Use 64 for double precision
                tagstruct.SamplesPerPixel = 1;
                tagstruct.SampleFormat = Tiff.SampleFormat.IEEEFP; % Key for negative/floats
                tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
                if kk == 1 && ~isempty(description)
                    tagstruct.ImageDescription = char(description);
                end

                t.setTag(tagstruct);
                t.write(page);
                if kk < numel(pages)
                    t.writeDirectory();
                end
            end

        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % readTiff
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [tiff_data] = readTiff(filename)

            assert(exist(filename,'file'),'Tiff file %s not found.',filename);
            t = Tiff(filename,'r');
            tiff_data = t.read();
            t.close();

        end

    end
end
