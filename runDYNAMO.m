%RUNDYNAMO  Compute time-frequency peaks and SO-power/phase histograms
%
%   This is a pipeline for identifying transient oscillatory events and their
%   relationship to slow oscillations in sleep EEG using the computeTFPeaks()
%   and SOpowerphaseHistogram() functions. It returns TF-peak features,
%   associated histograms, and time-frequency representations. Optional
%   parametric and spline fits are also computed.
%
%   Usage:
%       [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, SOPHs, timings] = runDYNAMO(data, Fs, stage_times, stage_vals, ...)
%
%   The 9th output `timings` is optional; 7- and 8-output callers work
%   unchanged.
%
%   Required Inputs:
%       data:               [N x 1] double - time-domain EEG signal
%       Fs:                 double - sampling frequency (Hz)
%       stage_times:        [1 x S] double - sleep stage time markers (s)
%       stage_vals:         [1 x S] double - sleep stage labels (1-5)
%
%   Optional Inputs (Name-Value Pairs):
%       backend:                      char - pipeline backend: 'rust' (default, MEX wrappers
%                                     around dynamo_rs; ~4x faster, -0.8% peak count vs MATLAB)
%                                     or 'matlab' (pure MATLAB reference path).
%       time_range:                   [1 x 2] double - start and end time in seconds (default: entire scored range)
%       baseline_options:             struct - parameters for baseline estimation (default: baseline_opts())
%       detection_options:            struct - parameters for TF-peak detection (default: detection_opts())
%       SOPH_options:                 struct - parameters for SO-power/phase histograms (default: SOpowerphasehist_opts())
%       param_basis_power_options:    struct - parameters for parametric fitting of SO-power histograms (default: param_basis_opts('power'))
%       param_basis_phase_options:    struct - parameters for parametric fitting of SO-phase histograms (default: param_basis_opts('phase'))
%       spline_basis_power_options:   struct - parameters for spline fitting of SO-power histograms (default: spline_basis_opts('power'))
%       spline_basis_phase_options:   struct - parameters for spline fitting of SO-phase histograms (default: spline_basis_opts('phase'))
%       stats_table:                  table/double - precomputed TF-peak table to bypass detection (default: [])
%       verbose:                      logical - print progress info + timing summary table (default: true)
%       plot_on:                      logical - generate summary figure (default: true)
%       save_output_image:            logical - save summary figure to disk (default: false)
%       output_fname:                 string/char - output filename for image (default: 'DYNAM-O_output')
%       fit_param_basis:              logical - run parametric fitting of histograms (default: true)
%       fit_spline_basis:             logical - run spline fitting of histograms (default: true)
%
%   Outputs:
%       stats_table:        table - features of detected time-frequency peaks
%       spect:              [F x N] double - time-frequency spectrogram
%       stimes:             [1 x N] double - spectrogram time centers (s)
%       sfreqs:             [1 x F] double - frequency bins (Hz)
%       data_time_range:    [1 x T] double - data within time range and are analyzed
%       t_time_range:       [1 x T] double - time axis vector for data within time range
%       artifacts:          [1 x T] logical - artifact mask for data within time range
%       SOPHs:              struct - SO-power and SO-phase histograms (and fits if fit_param_basis or fit_spline_basis is true)
%       timings:            struct (optional) - per-stage wallclock seconds
%                           Fields: pool_setup, spect_pass1, artifact,
%                                   baseline_pass1, extract_pass1,
%                                   spect_pass2, baseline_pass2, extract_pass2,
%                                   refine, peak_stage, peak_sopower,
%                                   peak_sophase, soph_sopower_compute,
%                                   soph_sophase_compute, soph_sopower_hist,
%                                   soph_sophase_hist, plot_summary,
%                                   fit_param_basis, fit_spline_basis, total.
%                           Stages that didn't run are absent or zero.
%                           (backend='rust' skips pool_setup entirely.)
%                           A sorted summary table with these timings also
%                           prints at the end of verbose runs.
%
%   Notes:
%       - If no inputs are provided, the function runs an internal example using bundled data.
%       - A single input of 'segment' or 'night' toggles the example data time range (default: 'segment')
%       - The SOPHs output includes histogram matrices, bin edges, time-in-bin info, and optionally
%         parametric and spline fit results for both SO-power and SO-phase histograms.
%       - Two pipeline backends via the 'backend' option:
%           * 'rust' (default) — dynamo_rs MEX wrappers. ~3.7x faster on night.
%             Requires pre-built MEX files (see rust_bridge/README.md).
%             Rayon parallelises internally; MATLAB parpool is not started.
%           * 'matlab' — pure MATLAB reference path. Uses parpool over
%             segments; pool type is controlled by detection_options.parallel_mode
%             ('Processes' (default) / 'Threads' / '').
%
%   Example:
%       load('example_data/example_data.mat');  % should include data, Fs, stage_times, stage_vals
%       [stats_table, spect, stimes, sfreqs, ~, ~, artifacts, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals);
%
%       % With per-stage timing capture:
%       [~, ~, ~, ~, ~, ~, ~, SOPHs, timings] = runDYNAMO(data, Fs, stage_times, stage_vals);
%       disp(timings)
%
%       % Fast iteration with precomputed stats_table (skips TF-peak extraction):
%       [~, ~, ~, ~, ~, ~, ~, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals, 'stats_table', stats_table);
%
%   See Also: DYNAMO, runSegmentedData, computeTFPeaks, SOpowerphaseHistogram, computePeakStage,
%             fitParamBasis, fitSplineBasis, printTimingSummary
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
%    "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%    in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%    Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%    Manoach, D. S., Stickgold, R., Prerau, M. J.
%    "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
%    Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================

function [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, SOPHs, timings] = runDYNAMO(varargin)
%%%% Example script showing how to compute time-frequency peaks and SO-power/phase histograms
%
% Users are encouraged to edit this script and the data loading boilerplate in runExampleData()
% for their specific analysis. This script is provided only as a template for illustrative
% purposes on how to use various functions in DYNAM-O in tandem.

%% SYSTEM SETTINGS
% Add necessary functions to path (only if not already on path).
if isempty(which('computeTFPeaks'))
    repo_root = fileparts(which('runDYNAMO'));
    addpath(genpath(fullfile(repo_root, 'toolbox')))
end

% ---- Required MATLAB toolboxes ----
% DYNAM-O uses watershed(), regionprops(), imresize(), label2rgb(),
% bwconncomp(), imreconstruct() from the Image Processing Toolbox in BOTH
% backends — the rust backend replaces the compute-heavy watershed/merge/
% trim calls with MEX, but display helpers (runWatershed plot path,
% label2rgb in extract diagnostics, imresize for pass-1/pass-2 alignment
% in the pure-MATLAB path) still touch IPT. Fail fast with a clear message
% so users don't hit cryptic "Undefined function 'watershed'" errors deep
% in the pipeline.
if ~license('test', 'Image_Toolbox') || exist('watershed', 'file') == 0
    error('runDYNAMO:missingToolbox', [ ...
        'DYNAM-O requires the MATLAB Image Processing Toolbox, which ' ...
        'is not available on this machine.\n\n' ...
        'To install:  Home tab > Add-Ons > Get Add-Ons > search ' ...
        '"Image Processing Toolbox" > Install.\n' ...
        'Or via license portal: https://www.mathworks.com/products/image.html']);
end

% default verbose setting for all processing steps
default_verbose = true;

%% RUN EXAMPLE DATA IF CALLED WITHOUT DATA INPUTS
run_app = false;
if nargin == 0 || ~isnumeric(varargin{1})
    if nargin == 0
        data_range = 'segment';
    elseif any(strcmpi(varargin{1}, {'app', 'demo'}))
        data_range = 'night';
        run_app = true;
    else
        data_range = varargin{1};
        assert(ismember(lower(data_range), {'segment','night'}), 'Select ''segment'' or ''night'' as input for example data.');
    end
    addpath(fullfile(fileparts(which('runDYNAMO')), 'example_data'))
    [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, SOPHs, timings] = runExampleData(data_range, default_verbose, run_app, varargin{2:end});
    return;
end

%% PARSE INPUTS
p = inputParser;

addRequired(p, 'data', @(x) validateattributes(x, {'numeric'}, {'real','vector'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','scalar'}));
addRequired(p, 'stage_times', @(x) validateattributes(x, {'numeric'}, {'real','finite','nondecreasing','vector'}));
addRequired(p, 'stage_vals', @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector'}));
% section of EEG to use in analysis (seconds)
addOptional(p, 'time_range', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
% parameters managed using struct outputs from opts functions
addOptional(p, 'baseline_options', baseline_opts(), @(x) validateattributes(x, {'struct'}, {'nonempty'}));
addOptional(p, 'detection_options', detection_opts(), @(x) validateattributes(x, {'struct'}, {'nonempty'}));
addOptional(p, 'SOPH_options', SOpowerphasehist_opts(), @(x) validateattributes(x, {'struct'}, {'nonempty'}));
addOptional(p, 'param_basis_power_options', param_basis_opts('power'), @(x) isstruct(x));
addOptional(p, 'param_basis_phase_options', param_basis_opts('phase'), @(x) isstruct(x));
addOptional(p, 'spline_basis_power_options', spline_basis_opts('power'), @(x) isstruct(x));
addOptional(p, 'spline_basis_phase_options', spline_basis_opts('phase'), @(x) isstruct(x));
% additional inputs to control the outputs from runDYNAMO()
addOptional(p, 'stats_table', [], @(x) validateattributes(x, {'double','table'}, {'real','2d'}));
addOptional(p, 'verbose', default_verbose, @(x) validateattributes(x, {'logical', 'numeric'}, {'scalar'}));
addOptional(p, 'plot_on', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'save_output_image', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'output_fname', 'DYNAM-O_output', @(x) validateattributes(x, {'char','string'}, {'nonempty','scalartext'}));
addOptional(p, 'fit_param_basis', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'fit_spline_basis', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
% Pipeline backend override. Empty (default) means "inherit from
% detection_options.backend" (which defaults to 'rust'); pass 'rust' or
% 'matlab' here to override what the GUI/detection_opts set. 'rust' uses
% compiled MEX wrappers around dynamo_rs (~3.7x faster on night, peaks
% within ~0.8% of MATLAB); 'matlab' is the pure-MATLAB reference path.
addOptional(p, 'backend', '', @(x) isempty(x) || any(validatestring(lower(char(x)), {'matlab','rust'})));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

% Per-stage timing accumulator. Fields populated by each stage below;
% merged with computeTFPeaks' tfp_timings struct after the big call.
% Returned as 9th output for programmatic callers (bench loops, CI) and
% printed as a formatted summary at the end of the function when verbose.
timings = struct();

% Start the master wallclock timer here so pool_setup / mex_build are
% included in timings.total — gives coherent 100% bookkeeping in the
% summary table.
ttotal = datetime('now');

% Harden against partial option structs: a user may pass an
% old/incomplete struct from a prior session (e.g., before a new field
% like reuse_baseline or seg_time was added). Without backfilling we'd
% crash deep in the pipeline with "Unrecognized field name". Merge any
% missing fields from the canonical defaults so partial inputs are
% always well-formed.
detection_options = mergeOptsDefaults(detection_options, detection_opts());
baseline_options  = mergeOptsDefaults(baseline_options,  baseline_opts());

%Force data to be a column vector
if isrow(data) %#ok<*NODEF>
    data = data(:);
end

%Check sleep stages
valid_stages = stage_vals > 0 & stage_vals < 6;
assert(~isempty(valid_stages),'No valid stages found');

%Set to range of valid scored data by default
if isempty(time_range)
    valid_stage_inds = find(valid_stages);
    time_range = stage_times(valid_stage_inds([1, end]));
end

%Cast stage_vals to single for interpolations
stage_vals = single(stage_vals);

%% SETUP BACKEND
% Resolve backend: explicit top-level override wins; otherwise inherit
% from detection_options.backend (the GUI/options-struct source of truth).
if isempty(backend)
    if isfield(detection_options, 'backend') && ~isempty(detection_options.backend)
        backend = detection_options.backend;
    else
        backend = 'rust';
    end
end
backend = lower(char(backend));
% Sync the resolved value back into the struct so downstream struct-expand
% callers see a single, consistent backend (prevents inputParser's
% "Cannot include struct and duplicate parameters" error when the struct
% is passed alongside an explicit 'backend' name/value pair).
detection_options.backend = backend;

if strcmp(backend, 'rust')
    % Rust MEX backend: add rust_bridge/ to path, assert the four MEX
    % wrappers exist, and skip parpool setup entirely (Rust internally
    % parallelises via rayon).
    repo_root_ = fileparts(which('runDYNAMO'));
    rb_dir_ = fullfile(repo_root_, 'rust_bridge');
    if isfolder(rb_dir_)
        addpath(rb_dir_);
    end
    clear repo_root_ rb_dir_

    needed = {'extract_tfpeaks_mex', 'mask_spectrogram_mex', ...
        'refine_peaks_mex', 'tfpeak_histogram_mex'};
    missing = needed(cellfun(@(n) exist(n, 'file') ~= 3, needed));
    if ~isempty(missing)
        error('runDYNAMO:missingMEX', ['backend=''rust'' requires compiled MEX files ' ...
            '(missing: %s).\n\nBuild them with:\n  cd <DYNAM-O_rs>/rust && cargo build --release\n' ...
            '  cd <DYNAM-O_dev>/rust_bridge && build_rust_mex\n\n' ...
            'Or call runDYNAMO(..., ''backend'', ''matlab'') to use the pure MATLAB path.'], ...
            strjoin(missing, ', '));
    end
    timings.pool_setup = 0;
    timings.mex_build = 0;

    if verbose
        fprintf('  Backend:       rust (MEX)\n');
        fprintf('  Parallel mode: rayon (in-MEX, no MATLAB parpool)\n');
        fprintf('  Segment size:  %g s\n', detection_options.seg_time);
    end
else
    % MATLAB backend: parpool benefits segment parfor in runSegmentedData.
    t_stage = tic;
    setup_parallel_pool(detection_options.parallel_mode);
    timings.pool_setup = toc(t_stage);
    timings.mex_build = 0;

    if verbose
        pool = gcp('nocreate');
        fprintf('  Backend:       matlab\n');
        if isempty(pool)
            fprintf('  Parallel mode: serial (no pool)\n');
        else
            if isprop(pool, 'NumWorkers')
                nw = pool.NumWorkers;
            elseif isprop(pool, 'NumThreads')
                nw = pool.NumThreads;
            else
                nw = feature('numcores');
            end
            if isa(pool, 'parallel.ThreadPool')
                fprintf('  Parallel mode: ThreadPool (%d threads)\n', nw);
            else
                fprintf('  Parallel mode: ProcessPool (%d workers)\n', nw);
            end
        end
        fprintf('  Segment size:  %g s\n', detection_options.seg_time);
    end
end

%% COMPUTE TIME-FREQUENCY PEAKS
% See computeTFPeaks() for a full list of optional arguments for finer
% control of watershed extraction of Time-Frequency Peaks

if isempty(stats_table)
    % If no stats table provided
    [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, tfp_timings] = computeTFPeaks(data, Fs, stage_times, stage_vals,...
        'time_range', time_range, 'verbose', verbose, detection_options, baseline_options);
    % Fold computeTFPeaks' per-stage timings into our master struct
    % (spect_pass1, artifact, baseline_pass1, extract_pass1, spect_pass2,
    % baseline_pass2, extract_pass2, refine).
    fns = fieldnames(tfp_timings);
    for kk = 1:numel(fns), timings.(fns{kk}) = tfp_timings.(fns{kk}); end
    clear tfp_timings fns
else
    % If stats table provided, check to be sure SOPH is requested by output
    assert(nargout > 7, 'Nothing to compute. Must request SOPH output if stats table is inputted.');

    if verbose
        disp('TF peaks stats table provided. Computing SOPH only.');
    end

    % Truncate to time_range — same as computeTFPeaks does when building
    % fresh. Without this, SOpower_times would span the full recording
    % and interp1(stage_times, stage_vals, SOpower_times, 'previous')
    % would return NaN stages for samples before the first / after the
    % last scored stage, which the histogram validator rejects.
    t_full = (0:length(data)-1)/Fs;
    time_range_inds = t_full >= time_range(1) & t_full <= time_range(2);
    data_time_range = data(time_range_inds);
    t_time_range = t_full(time_range_inds);
    [spect, stimes, sfreqs] = deal([]);
    t_stage = tic;
    artifacts = detect_artifacts(data_time_range, Fs);
    timings.artifact = toc(t_stage);
end

%% COMPUTE ADDITIONAL PEAK FEATURE PROPERTIES
% Additional useful features that describe each detected TF peak in the
% stats_table are computed here. Customized functions can be added in this
% section to populate the table with other feature columns.

% Compute sleep stage at each TF peak
t_stage = tic;
stats_table = computePeakStage(stats_table, stage_times, stage_vals, t_time_range, artifacts);
timings.peak_stage = toc(t_stage);
% Compute slow oscillation power (SO-Power) at each TF peak
t_stage = tic;
[stats_table, SOpower_norm, SOpower_times] = computePeakSOpower(stats_table, data_time_range, Fs, 'EEG_times', t_time_range, 'isexcluded', artifacts, SOPH_options);
timings.peak_sopower = toc(t_stage);
% Compute slow oscillation phase (SO-Phase) at each TF peak
t_stage = tic;
[stats_table, SOphase, SOphase_times, SOfiltered] = computePeakSOphase(stats_table, data_time_range, Fs, 'EEG_times', t_time_range, 'isexcluded', artifacts, SOPH_options);
timings.peak_sophase = toc(t_stage);

%% COMPUTE SO-POWER/PHASE HISTOGRAMS
% See SOpowerphaseHistogram() for a full list of optional arguments for
% finer control of histogram generation

if nargout > 7
    t_stage = tic;
    [SOpower_mat, SOphase_mat, SOpower_bins, SOphase_bins, freq_bins, num_peaks_at_freq,...
        SOpower_TIB, SOphase_TIB, ~, ~, hist_peakidx, ~, ~, ~, ~, ~, soph_timings] = SOpowerphaseHistogram(data_time_range, Fs, stats_table.PeakFrequency, stats_table.PeakTime,...
        'stage_times', stage_times, 'stage_vals', stage_vals, 'verbose', verbose, SOPH_options,...
        'SOpower', SOpower_norm, 'SOpower_times', SOpower_times, 'SOphase', SOphase, 'SOphase_times', SOphase_times,...
        'backend', backend);
    timings.soph_histograms = toc(t_stage);
    % Merge the sub-breakdown (sopower_compute, sophase_compute,
    % sopower_hist, sophase_hist) into the master struct. The outer
    % timings.soph_histograms total ≈ sum of these four + tiny sync/masking
    % overhead, so we keep both: the coarse total AND the individual parts.
    fns = fieldnames(soph_timings);
    for kk = 1:numel(fns), timings.(['soph_' fns{kk}]) = soph_timings.(fns{kk}); end
    clear soph_timings fns

    %Create a SOPHs structure for output
    SOPHs = createSOPHsStruct(SOpower_mat, SOphase_mat, SOpower_bins, SOpower_norm, SOpower_times, SOphase_bins, SOphase, SOphase_times, SOfiltered, freq_bins, num_peaks_at_freq, SOpower_TIB, SOphase_TIB);

    %Check for valid histogramas
    valid_powerhist = any(isfinite(SOPHs.SOpower_mat), 'all');
    valid_phasehist = any(isfinite(SOPHs.SOphase_mat), 'all');

    if ~valid_powerhist
        warning('Power histogram is empty. Consider changing time range or minimum time in bin.');
    end

    if ~valid_phasehist
        warning('Phase histogram is empty. Consider changing time range or minimum peak at frequency.');
    end
else
    if verbose
        disp('Computing TF peaks only. No SOPH output requested.');
    end
end

%% PLOT OUTPUT SUMMARY FIGURE
if plot_on
    t_stage = tic;
    if nargout > 7
        fh = displaySummaryPlot('stage_times',stage_times, 'stage_vals',stage_vals, 'artifacts',artifacts, 't_time_range',t_time_range,...
            'data',data, 'Fs',Fs, 'time_range',time_range,...
            'SOpower_norm',SOpower_norm, 'SOpower_times',SOpower_times, 'SOpower_norm_method',SOPH_options.SOpower_norm_method,...
            'stats_table',stats_table, 'hist_peakidx',hist_peakidx,...
            'freq_bins',freq_bins, 'SOpower_mat',SOpower_mat, 'SOpower_bins',SOpower_bins,...
            'SOphase_mat',SOphase_mat, 'SOphase_bins',SOphase_bins);
    else
        fh = displaySummaryPlot('stage_times',stage_times, 'stage_vals',stage_vals, 'artifacts',artifacts, 't_time_range',t_time_range,...
            'data',data, 'Fs',Fs, 'time_range',time_range,...
            'stats_table',stats_table);
    end

    % Save output summary figure
    if save_output_image
        print(fh,'-dpng','-r200',output_fname);
    end
    timings.plot_summary = toc(t_stage);
end

%% DIMENSIONALITY REDUCTION OF SO-POWER/PHASE HISTOGRAMS
if nargout > 7 && (fit_param_basis || fit_spline_basis)
    if verbose && (valid_powerhist || valid_phasehist)
        disp('Fitting SOPHs...');
    end

    plot_both = plot_on && valid_powerhist && valid_phasehist;
    plot_each = plot_on && ~plot_both;

    if fit_param_basis
        t_stage = tic;
        SOPHs = fitParamBasis(SOPHs, param_basis_power_options, param_basis_phase_options, valid_powerhist, valid_phasehist, verbose, plot_each, plot_both);
        timings.fit_param_basis = toc(t_stage);
    end

    if fit_spline_basis
        t_stage = tic;
        SOPHs = fitSplineBasis(SOPHs, spline_basis_power_options, spline_basis_phase_options, valid_powerhist, valid_phasehist, verbose, plot_each, plot_both);
        timings.fit_spline_basis = toc(t_stage);
    end

    if plot_on
        figure(fh); % bring the summary figure to front
    end
end

%% Print a formatted per-stage timing summary
timings.total = seconds(datetime('now') - ttotal);

if verbose
    printTimingSummary(timings);
end

end
