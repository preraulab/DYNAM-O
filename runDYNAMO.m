%RUNDYNAMO  Compute time-frequency peaks and SO-power/phase histograms
%
%   This is a pipeline for identifying transient oscillatory events and their
%   relationship to slow oscillations in sleep EEG using the computeTFPeaks()
%   and SOpowerphaseHistogram() functions. It returns TF-peak features,
%   associated histograms, and time-frequency representations. Optional
%   parametric and spline fits are also computed.
%
%   Usage:
%       [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals, ...)
%
%   Required Inputs:
%       data:               [N x 1] double - time-domain EEG signal
%       Fs:                 double - sampling frequency (Hz)
%       stage_times:        [1 x S] double - sleep stage time markers (s)
%       stage_vals:         [1 x S] double - sleep stage labels (1-5)
%
%   Optional Inputs (Name-Value Pairs):
%       time_range:                   [1 x 2] double - start and end time in seconds (default: entire scored range)
%       baseline_options:             struct - parameters for baseline estimation (default: baseline_opts())
%       detection_options:            struct - parameters for TF-peak detection (default: detection_opts())
%       SOPH_options:                 struct - parameters for SO-power/phase histograms (default: SOpowerphasehist_opts())
%       param_basis_power_options:    struct - parameters for parametric fitting of SO-power histograms (default: param_basis_opts('power'))
%       param_basis_phase_options:    struct - parameters for parametric fitting of SO-phase histograms (default: param_basis_opts('phase'))
%       spline_basis_power_options:   struct - parameters for spline fitting of SO-power histograms (default: spline_basis_opts('power'))
%       spline_basis_phase_options:   struct - parameters for spline fitting of SO-phase histograms (default: spline_basis_opts('phase'))
%       stats_table:                  table/double - precomputed TF-peak table to bypass detection (default: [])
%       verbose:                      logical - print progress info (default: true)
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
%
%   Notes:
%       - If no inputs are provided, the function runs an internal example using bundled data.
%       - A single input of 'segment' or 'night' toggles the example data time range (default: 'segment')
%       - The SOPHs output includes histogram matrices, bin edges, time-in-bin info, and optionally
%         parametric and spline fit results for both SO-power and SO-phase histograms.
%
%   Example:
%       load('example_data/example_data.mat');  % should include data, Fs, stage_times, stage_vals
%       [stats_table, spect, stimes, sfreqs, artifacts, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals);
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
% Add necessary functions to path (only if not already on path)
if isempty(which('computeTFPeaks'))
    repo_root = fileparts(which('runDYNAMO'));
    addpath(genpath(fullfile(repo_root, 'toolbox')))
    % MEX accelerator lives outside toolbox/ under optimization/mex/.
    % On the path so trimWshedRegions can find and auto-compile
    % trim_region_mex when running in a ProcessPool.
    mex_dir = fullfile(repo_root, 'optimization', 'mex');
    if exist(mex_dir, 'dir'), addpath(mex_dir); end
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
    [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, SOPHs] = runExampleData(data_range, default_verbose, run_app, varargin{2:end});
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

%Set up parallel pool (auto-detects Threads vs Processes based on OS)
t_stage = tic;
setup_parallel_pool(detection_options.parallel_mode);
timings.pool_setup = toc(t_stage);

%Pre-build trim MEX on the client, ONCE, before any parfor. This avoids
%every worker racing to compile the same file simultaneously (N workers
%= N concurrent build_all_mex calls writing to the same output).
t_stage = tic;
mex_name_ = ['trim_region_mex.' mexext];
is_apple_silicon_ = ismac && strcmp(computer('arch'), 'maca64');
if ~is_apple_silicon_ && exist(mex_name_, 'file') ~= 3 && exist('build_all_mex', 'file') == 2
    try
        fprintf('  Compiling trim_region_mex for this platform (first-time only)...\n');
        build_all_mex();
        mex_dir_ = fileparts(which('build_all_mex'));
        if ~isempty(mex_dir_) && exist(fullfile(mex_dir_, mex_name_), 'file') == 3
            addpath(mex_dir_);
        end
        fprintf('  MEX compilation complete.\n');
    catch
        fprintf('  MEX compilation failed; using stock MATLAB path.\n');
    end
end
clear mex_name_ is_apple_silicon_ mex_dir_
timings.mex_build = toc(t_stage);

%Report configuration
if verbose
    pool = gcp('nocreate');
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
    mex_avail = exist(['trim_region_mex.' mexext], 'file') == 3;
    mex_usable = mex_avail && (isempty(pool) || ~isa(pool, 'parallel.ThreadPool'));
    if mex_usable
        fprintf('  Trim MEX:      enabled (trim_region_mex)\n');
    elseif mex_avail
        fprintf('  Trim MEX:      disabled (ThreadPool cannot run MEX)\n');
    elseif ~isempty(pool) && isa(pool, 'parallel.ThreadPool')
        fprintf('  Trim MEX:      n/a (ThreadPool cannot run MEX)\n');
    else
        fprintf('  Trim MEX:      not built (will auto-compile on first run)\n');
    end
end

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

%% COMPUTE ADDITIONAL PEAK FEATURES
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
[stats_table, SOphase, SOphase_times] = computePeakSOphase(stats_table, data_time_range, Fs, 'EEG_times', t_time_range, 'isexcluded', artifacts, SOPH_options);
timings.peak_sophase = toc(t_stage);

%% COMPUTE SO-POWER/PHASE HISTOGRAMS
% See SOpowerphaseHistogram() for a full list of optional arguments for
% finer control of histogram generation

if nargout > 7
    t_stage = tic;
    [SOpower_mat, SOphase_mat, SOpower_bins, SOphase_bins, freq_bins, num_peaks_at_freq,...
        SOpower_TIB, SOphase_TIB, ~, ~, hist_peakidx] = SOpowerphaseHistogram(data_time_range, Fs, stats_table.PeakFrequency, stats_table.PeakTime,...
        'stage_times', stage_times, 'stage_vals', stage_vals, 'verbose', verbose, SOPH_options,...
        'SOpower', SOpower_norm, 'SOpower_times', SOpower_times, 'SOphase', SOphase, 'SOphase_times', SOphase_times);
    timings.soph_histograms = toc(t_stage);

    %Create a SOPHs structure for output
    SOPHs = createSOPHsStruct(SOpower_mat, SOphase_mat, SOpower_bins, SOpower_norm, SOpower_times, SOphase_bins, freq_bins, num_peaks_at_freq, SOpower_TIB, SOphase_TIB);

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


% ------------------------------------------------------------------------
% printTimingSummary
%   Pretty-prints the timings struct as a right-aligned, dot-leadered table
%   with per-stage percentages of total wallclock. Any fields missing from
%   the struct (stage didn't run — e.g., plot_on=false) are simply skipped.
% ------------------------------------------------------------------------
function printTimingSummary(timings)
% Display: pipeline stages sorted by time (largest first) with
% millisecond precision so small stages don't show as 0.0 s. Any
% fields missing from the struct (stage didn't run — e.g.,
% plot_on=false, single-watershed) are silently omitted.
order = { ...
    'pool_setup',      'Parallel pool setup'; ...
    'mex_build',       'MEX build / check'; ...
    'spect_pass1',     'Spectrogram (pass 1)'; ...
    'artifact',        'Artifact rejection'; ...
    'baseline_pass1',  'Baseline (pass 1)'; ...
    'extract_pass1',   'TF peak extraction (pass 1)'; ...
    'spect_pass2',     'Spectrogram (pass 2)'; ...
    'baseline_pass2',  'Baseline + mask (pass 2)'; ...
    'extract_pass2',   'TF peak extraction (pass 2)'; ...
    'refine',          'Peak refinement'; ...
    'peak_stage',      'Peak stage assignment'; ...
    'peak_sopower',    'Peak SO-power compute'; ...
    'peak_sophase',    'Peak SO-phase compute'; ...
    'soph_histograms', 'SO-power/phase histograms'; ...
    'plot_summary',    'Summary plot'; ...
    'fit_param_basis', 'Parametric basis fit'; ...
    'fit_spline_basis','Spline basis fit'};

total = timings.total;
if total <= 0, total = eps; end  % avoid /0 on degenerate runs

% Collect present stages, sort descending by time
keys   = order(:, 1);
labels = order(:, 2);
pres   = cellfun(@(k) isfield(timings, k), keys);
labels = labels(pres);
times  = cellfun(@(k) timings.(k), keys(pres));
[times_sorted, si] = sort(times, 'descend');
labels_sorted = labels(si);

width   = 70;
bar_top = repmat(char(9552), 1, width);   % ═
bar_sep = repmat(char(9472), 1, width);   % ─
fprintf('\n%s\n', bar_top);
fprintf(' %-*s\n', width-1, 'TIMING SUMMARY  (stages sorted by time, ms precision)');
fprintf('%s\n', bar_top);

sum_reported = 0;
for k = 1:numel(labels_sorted)
    t = times_sorted(k);
    sum_reported = sum_reported + t;
    pct = 100 * t / total;
    left = sprintf(' %s ', labels_sorted{k});
    right = sprintf(' %8.3f s   (%5.1f%%)', t, pct);
    fill_len = width - numel(left) - numel(right);
    if fill_len < 1, fill_len = 1; end
    fprintf('%s%s%s\n', left, repmat('.', 1, fill_len), right);
end

% "Other" catches any time between stages (tic/toc boundaries, arg
% parsing, unmeasured helpers). Printed only when it's non-trivial
% (>100 ms) so clean runs stay clean.
other = total - sum_reported;
if other > 0.1
    left = ' Other / overhead ';
    right = sprintf(' %8.3f s   (%5.1f%%)', other, 100 * other / total);
    fill_len = width - numel(left) - numel(right);
    if fill_len < 1, fill_len = 1; end
    fprintf('%s%s%s\n', left, repmat('.', 1, fill_len), right);
end

fprintf('%s\n', bar_sep);
left = ' Total ';
right = sprintf(' %8.3f s   (100.0%%)', total);
fill_len = width - numel(left) - numel(right);
if fill_len < 1, fill_len = 1; end
fprintf('%s%s%s\n', left, repmat('.', 1, fill_len), right);
fprintf('%s\n\n', bar_top);
end


%% Helper functions
function [SOPHs] = createSOPHsStruct(SOpower_mat, SOphase_mat, SOpower_bins, SOpower_norm, SOpower_times, SOphase_bins, freq_bins, num_peaks_at_freq, SOpower_TIB, SOphase_TIB)
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
SOPH_paramfit = struct;
SOPH_paramfit.params = params; % Columns are: [amp0, fmean0, fstd0, pmean0, pstd0, theta0]
SOPH_paramfit.fitobj = fitobj;
SOPH_paramfit.gof = gof;
SOPH_paramfit.model_SOPH = model_SOPH;
SOPH_paramfit.wshed_img = wshed_img;
end


function [SOPH_splinefit] = createSOPHsplinefitStruct(splinefit, coefs, spline_obj, knots_x, knots_y)
SOPH_splinefit = struct;
SOPH_splinefit.splinefit = splinefit;
SOPH_splinefit.coefs = coefs;
SOPH_splinefit.spline_obj = spline_obj;
SOPH_splinefit.knots_x = knots_x;
SOPH_splinefit.knots_y = knots_y;
end


function [SOPHs] = fitParamBasis(SOPHs, power_opts, phase_opts, valid_powerhist, valid_phasehist, verbose, plot_each, plot_both)
if verbose && (valid_powerhist || valid_phasehist)
    disp('  Fitting parametric basis...');
end

% Parametric fit of SO-Power Histogram
if valid_powerhist
    power_opts.plot_on = plot_each;
    power_opts.verbose = verbose-1;
    [params_power, fitobj_power, gof_power, model_SOPH_power, wshed_img_power] = param_basis_power(SOPHs.SOpower_mat, SOPHs.SOpower_bins, SOPHs.freq_bins, power_opts);
    SOPHs.SOpower_paramfit = createSOPHparamfitStruct(params_power, fitobj_power, gof_power, model_SOPH_power, wshed_img_power);
end

% Parametric fit of SO-Phase Histogram
if valid_phasehist
    phase_opts.plot_on = plot_each;
    phase_opts.verbose = verbose-1;
    [params_phase, fitobj_phase, gof_phase, model_SOPH_phase, wshed_img_phase] = param_basis_phase(SOPHs.SOphase_mat, SOPHs.SOphase_bins, SOPHs.freq_bins, phase_opts);
    SOPHs.SOphase_paramfit = createSOPHparamfitStruct(params_phase, fitobj_phase, gof_phase, model_SOPH_phase, wshed_img_phase);
end

if plot_both
    plot_SOPH_paramfits( ...
        SOPHs.SOpower_bins, SOPHs.SOpower_paramfit.wshed_img, SOPHs.SOpower_mat, model_SOPH_power, params_power, power_opts.SOPH_clim_prctiles, power_opts.power_limits, power_opts.freq_limits, ...
        SOPHs.SOphase_bins, SOPHs.SOphase_paramfit.wshed_img, SOPHs.SOphase_mat, model_SOPH_phase, params_phase, phase_opts.SOPH_clim_prctiles, phase_opts.phase_limits, phase_opts.freq_limits, ...
        SOPHs.freq_bins, SOPHs.SOpower_paramfit.fitobj, SOPHs.SOphase_paramfit.fitobj);
end
end


function [SOPHs] = fitSplineBasis(SOPHs, power_opts, phase_opts, valid_powerhist, valid_phasehist, verbose, plot_each, plot_both)
if verbose && (valid_powerhist || valid_phasehist)
    disp('  Fitting spline basis...');
end

% Spline fit of SO-Power Histogram
if valid_powerhist
    power_opts.plot_on = plot_each;
    [splinefit_power, coefs_power, spline_obj_power, knots_x_power, knots_y_power] = spline_basis('power', SOPHs.SOpower_mat, SOPHs.SOpower_bins, SOPHs.freq_bins, power_opts);
    SOPHs.SOpower_splinefit = createSOPHsplinefitStruct(splinefit_power, coefs_power, spline_obj_power, knots_x_power, knots_y_power);
end

% Spline fit of SO-Phase Histogram
if valid_phasehist
    phase_opts.plot_on = plot_each;
    [splinefit_phase, coefs_phase, spline_obj_phase, knots_x_phase, knots_y_phase] = spline_basis('phase', SOPHs.SOphase_mat, SOPHs.SOphase_bins, SOPHs.freq_bins, phase_opts);
    SOPHs.SOphase_splinefit = createSOPHsplinefitStruct(splinefit_phase, coefs_phase, spline_obj_phase, knots_x_phase, knots_y_phase);
end

if plot_both
    plot_SOPH_splinefits( ...
        SOPHs.SOpower_mat, SOPHs.SOpower_bins, splinefit_power, coefs_power, knots_x_power, knots_y_power, power_opts, ...
        SOPHs.SOphase_mat, SOPHs.SOphase_bins, splinefit_phase, coefs_phase, knots_x_phase, knots_y_phase, phase_opts, ...
        SOPHs.freq_bins);
end
end
