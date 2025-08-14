%RUNDYNAMO  Compute time-frequency peaks and SO-power/phase histograms
%
%   This is a pipeline for identifying transient oscillatory events and their
%   relationship to slow oscillations in sleep EEG using the computeTFPeaks()
%   and SOpowerphaseHistogram() functions. It returns TF-peak features,
%   associated histograms, and time-frequency representations. Optional
%   parametric and spline fits are also computed.
%
%   Usage:
%       [stats_table, SOPHs, spect, stimes, sfreqs, artifacts] = runDYNAMO(data, Fs, stage_times, stage_vals, ...)
%
%   Required Inputs:
%       data:               [N x 1] double - time-domain EEG signal
%       Fs:                 double - sampling frequency (Hz)
%       stage_times:        [1 x S] double - sleep stage time markers (s)
%       stage_vals:         [1 x S] double - sleep stage labels (1-5)
%
%   Optional Inputs (Name-Value Pairs):
%       time_range:         [1 x 2] double - start and end time in seconds (default: entire scored range)
%       baseline_options:   struct - parameters for baseline estimation (default: baseline_opts())
%       detection_options:  struct - parameters for TF-peak detection (default: detection_opts())
%       SOPH_options:       struct - parameters for SO-power/phase histograms (default: SOpowerphasehist_opts())
%       stats_table:        table - precomputed TF-peak table to bypass detection (default: [])
%       verbose:            logical - print progress info (default: true)
%       plot_on:            logical - generate summary figure (default: true)
%       save_output_image:  logical - save summary figure to disk (default: false)
%       output_fname:       string/char - output filename for image (default: 'DYNAM-O_output')
%       fit_SOPH:           logical - run parametric and spline fitting (default: true)
%
%   Outputs:
%       stats_table:        table - features of detected time-frequency peaks
%       SOPHs:              struct - SO-power and SO-phase histograms and fits
%       spect:              [F x T] double - time-frequency spectrogram
%       stimes:             [1 x T] double - spectrogram time centers (s)
%       sfreqs:             [1 x F] double - frequency bins (Hz)
%       artifacts:          [1 x T] logical - artifact mask for data
%
%   Notes:
%       - If no inputs are provided, the function runs an internal example using bundled data.
%       - The SOPHs output includes histogram matrices, bin edges, time-in-bin info, and optionally
%         parametric and spline fit results for both SO-power and SO-phase histograms.
%
%   Example:
%       load('my_sleep_data.mat');  % should include data, Fs, stage_times, stage_vals
%       [stats_table, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals);
%
%   Citation:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification", *Sleep*, 2022; zsac223.
%       https://doi.org/10.1093/sleep/zsac223
%
%**********************************************************************

function [stats_table, SOPHs, spect, stimes, sfreqs, artifacts] = runDYNAMO(varargin)
%%%% Example script showing how to compute time-frequency peaks and SO-power/phase histograms
%
% Users are encouraged to edit this script and the data loading boilerplate
% in runExampleData() for their specific analysis. This script is provided
% only as a template for illustrative purposes on how to use various
% functions in DYNAM-O in tandem.

%% SYSTEM SETTINGS
% Add necessary functions to path
addpath(genpath('./toolbox'))

%Check for parallel toolbox
v = ver;
if any(strcmp({v.Name}, 'Parallel Computing Toolbox'))
    gcp;
end

% default verbose setting for all processing steps
default_verbose = true;

%% RUN EXAMPLE DATA IF CALLED WITHOUT INPUT
if nargin == 0
    [stats_table, SOPHs, fh] = runExampleData(default_verbose);
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

%Force data to be a column vector
if isrow(data)
    data = data(:);
end

%Check sleep stages
valid_stages = stage_vals>0 & stage_vals<6;
assert(~isempty(valid_stages),'No valid stages found');

%Set to range of valid scored data by default
if isempty(time_range) %#ok<*NODEF>
    valid_stage_inds = find(valid_stages);
    time_range = stage_times(valid_stage_inds([1, end]));
end

%Cast stage_vals to single for interpolations
stage_vals = single(stage_vals);

%Start a timer
ttotal = datetime('now');

%% COMPUTE TIME-FREQUENCY PEAKS
% See computeTFPeaks() for a full list of optional arguments for finer
% control of watershed extraction of Time-Frequency Peaks

if isempty(stats_table)
    % If no stats table provided
    [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts]= computeTFPeaks(data, Fs, stage_times, stage_vals,...
        'time_range', time_range, 'verbose', verbose, detection_options, baseline_options); %#ok<*ASGLU>
else
    % If stats table provided, check to be sure SOPH is requested by output
    assert(nargout>1, 'Nothing to compute. Must request SOPH output if stats table is inputted.');
    if verbose
        disp('TF peaks stats table provided. Computing SOPH only.');
    end

    data_time_range = data;
    t_time_range = (0:length(data)-1)/Fs;
    artifacts = detect_artifacts(data, Fs);
end

%% COMPUTE ADDITIONAL PEAK FEATURES
% Additional useful features that describe each detected TF peak in the
% stats_table are computed here. Customized functions can be added in this
% section to populate the table with other feature columns.

% Compute sleep stage at each TF peak
stats_table = computePeakStage(stats_table, stage_times, stage_vals, t_time_range, artifacts);
% Compute slow oscillation power (SO-Power) at each TF peak
[stats_table, SOpower_norm, SOpower_times] = computePeakSOpower(stats_table, data_time_range, Fs, 'EEG_times', t_time_range, 'isexcluded', artifacts, SOPH_options);
% Compute slow oscillation phase (SO-Phase) at each TF peak
[stats_table, SOphase, SOphase_times] = computePeakSOphase(stats_table, data_time_range, Fs, 'EEG_times', t_time_range, 'isexcluded', artifacts, SOPH_options);

%% COMPUTE SO-POWER/PHASE HISTOGRAMS
% See SOpowerphaseHistogram() for a full list of optional arguments for
% finer control of histogram generation

if nargout > 1
    [SOpower_mat, SOphase_mat, SOpower_bins, SOphase_bins, freq_bins,...
        SOpower_TIB, SOphase_TIB, ~, ~, hist_peakidx] = SOpowerphaseHistogram(data_time_range, Fs, stats_table.PeakFrequency, stats_table.PeakTime,...
        'stage_times', stage_times, 'stage_vals', stage_vals, 'verbose', verbose, SOPH_options,...
        'SOpower', SOpower_norm, 'SOpower_times', SOpower_times, 'SOphase', SOphase, 'SOphase_times', SOphase_times);

    %Create a SOPHs structure for output
    SOPHs = createSOPHsStruct(SOpower_mat, SOphase_mat, SOpower_bins, SOpower_norm, SOpower_times, SOphase_bins, freq_bins, SOpower_TIB, SOphase_TIB);

    %Check for valid histogramas
    valid_powerhist = ~all(isnan(SOPHs.SOpower_mat),'all');
    valid_phasehist = ~all(isnan(SOPHs.SOphase_mat),'all');

    if ~valid_powerhist
        warning('Power histogram is empty. Consider changing time range or minimum time in bin.');
    end

    if ~valid_phasehist
        warning('Phase histogram is empty. Consider changing time range or minimum time in bin.');
    end
else
    if verbose
        disp('Computing TF peaks only. No SOPH output requested.');
    end
end

%% PLOT OUTPUT SUMMARY FIGURE
if plot_on
    if nargout > 1
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
else
    fh = [];
end

%% DIMENSIONALITY REDUCTION OF SO-POWER/PHASE HISTOGRAMS
if nargout > 1
    if verbose
        disp('Fitting SOPHs...');
    end

    if ~valid_powerhist
        warning('Power histogram empty. Skipping parametrization');
    end

    if ~valid_phasehist
        warning('Phase histogram empty. Skipping parametrization');
    end

    if fit_param_basis
        if verbose
            disp('Fitting parametric basis...');
        end
        % Parametric fit of SO-Power Histogram
        if valid_powerhist
            [params, fitobj, gof, model_SOPH, wshed_img] = param_basis_power(SOPHs.SOpower_mat, SOPHs.SOpower_bins, SOPHs.freq_bins, 'verbose', verbose-1, 'plot_on', plot_on);
            SOPHs.SOpower_paramfit = createSOPHparamfitStruct(params, fitobj, gof, model_SOPH, wshed_img);
        end

        % Parametric fit of SO-Phase Histogram
        if valid_phasehist
            [params, fitobj, gof, model_SOPH, wshed_img] = param_basis_phase(SOPHs.SOphase_mat, SOPHs.SOphase_bins, SOPHs.freq_bins, 'verbose', verbose-1, 'plot_on', plot_on);
            SOPHs.SOphase_paramfit = createSOPHparamfitStruct(params, fitobj, gof, model_SOPH, wshed_img);
        end
    end

    if fit_spline_basis
        if verbose
            disp('Fitting spline basis...');
        end
        % Spline fit of SO-Power Histogram
        if valid_powerhist
            [splinefit, coefs, spline_obj, knots_x, knots_y] = spline_basis('power', SOPHs.SOpower_mat, SOPHs.SOpower_bins, SOPHs.freq_bins, 'plot_on', plot_on);
            SOPHs.SOpower_splinefit = createSOPHsplinefitStruct(splinefit, coefs, spline_obj, knots_x, knots_y);
        end

        % Spline fit of SO-Phase Histogram
        if valid_phasehist
            [splinefit, coefs, spline_obj, knots_x, knots_y] = spline_basis('phase', SOPHs.SOphase_mat, SOPHs.SOphase_bins, SOPHs.freq_bins, 'plot_on', plot_on);
            SOPHs.SOphase_splinefit = createSOPHsplinefitStruct(splinefit, coefs, spline_obj, knots_x, knots_y);
        end
    end

    if plot_on
        figure(fh); % bring the summary figure to front
    end
end

%%
if verbose
    disp([newline, 'Total time: ' char(datetime('now')-ttotal)]);
end

end


function [SOPHs] = createSOPHsStruct(SOpower_mat, SOphase_mat, SOpower_bins, SOpower_norm, SOpower_times, SOphase_bins, freq_bins, SOpower_TIB, SOphase_TIB)
SOPHs = struct;
SOPHs.SOpower_mat = SOpower_mat;
SOPHs.SOphase_mat = SOphase_mat;
SOPHs.SOpower_bins = SOpower_bins;
SOPHs.SOphase_bins = SOphase_bins;
SOPHs.freq_bins = freq_bins;
SOPHs.SOpower_TIB = SOpower_TIB;
SOPHs.SOphase_TIB = SOphase_TIB;
SOPHs.SOpower_norm = SOpower_norm;
SOPHs.SOpower_times = SOpower_times;
end


function [SOPH_paramfit] = createSOPHparamfitStruct(params, fitobj, gof, model_SOPH, wshed_img)
SOPH_paramfit = struct;
SOPH_paramfit.params = params;
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


function [stats_table, SOPHs, fh] = runExampleData(verbose)
if verbose
    disp('Running Example Data...');
end

%Load default options
baseline_options = baseline_opts();
detection_options = detection_opts();
SOPH_options = SOpowerphasehist_opts();

%% DATA SETTINGS
%Location of example data
data_fname = 'example_data/example_data.mat';

%Select 'segment' or 'night' for example data range
data_range = 'night'; %Only works for provided example data

%% LOAD DATA
%Load example EEG data
load(data_fname, 'data', 'stage_times', 'stage_vals', 'Fs');

switch data_range
    case 'segment'
        % Choose an example segment from the data
        time_range = [8420 13446];

        %Set the minimum time in SO-power bin to include in the SOPH
        SOPH_options.SOpower_min_time_in_bin = 5;
        if verbose
            disp(['Running example segment', newline])
        end
    case 'night'
        % Choose an example segment from the data
        wake_buffer = 5*60; %5 minute buffer before/after first/last wake
        start_time = stage_times(find(stage_vals < 5 & stage_vals > 0, 1, 'first')) - wake_buffer;
        end_time = stage_times(find(stage_vals < 5 & stage_vals > 0, 1, 'last')) + wake_buffer;

        time_range = [start_time end_time];

        %Set the minimum time in SO-power bin to include in the SOPH
        SOPH_options.SOpower_min_time_in_bin = 10;
        if verbose
            disp(['Running full night', newline])
        end
end

%Call main function
[stats_table, SOPHs, fh] = runDYNAMO(data, Fs, stage_times, stage_vals, time_range, baseline_options, detection_options, SOPH_options);
end
