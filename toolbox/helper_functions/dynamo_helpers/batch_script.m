function batch_script(varargin)
%BATCH_SCRIPT  Run the DYNAM-O pipeline on a batch of EDF and staging file pairs
%
%   Usage:
%       batch_script(edf_fpaths, scoring_fpaths, output_fpath, stage_col, time_col, channels, ...)
%
%   Required Inputs:
%       edf_fpaths:      char or cell - path(s) to EDF file(s) -- required
%       scoring_fpaths:  char or cell - path(s) to scoring file(s), one per EDF -- required
%       output_fpath:    char or cell - output directory path -- required
%       stage_col:       double - column number for sleep stage data (1-based) -- required
%       time_col:        double - column number for time data (1-based) -- required
%       channels:        char or cell - EEG channel label(s) to process -- required
%
%   Optional Inputs:
%       stage_vals_in:               cell - custom 1x7 stage label mappings (default: [])
%       header_lines:                double - number of header lines in scoring file (default: 0)
%       start_time:                  char/string - recording start time (default: NaN)
%       epoch_dur:                   double - epoch duration in seconds (default: 30)
%       plot_on_staging:             logical - plot hypnogram during staging (default: false)
%       resample_freq:               double - target resampling frequency in Hz (default: [])
%       time_range:                  [1x2] double - analysis time range in seconds (default: [])
%       baseline_options:            struct - baseline estimation options (default: baseline_opts())
%       detection_options:           struct - TF-peak detection options (default: detection_opts())
%       SOPH_options:                struct - SOPH options (default: SOpowerphasehist_opts())
%       param_basis_power_options:   struct - parametric basis options for power (default: param_basis_opts('power'))
%       param_basis_phase_options:   struct - parametric basis options for phase (default: param_basis_opts('phase'))
%       spline_basis_power_options:  struct - spline basis options for power (default: spline_basis_opts('power'))
%       spline_basis_phase_options:  struct - spline basis options for phase (default: spline_basis_opts('phase'))
%       verbose:                     logical - print progress info (default: true)
%       save_output_image:           logical - save output images to disk (default: true)
%       output_fname:                char - output filename base (default: 'DYNAM-O_output')
%       fit_param_basis:             logical - run parametric fitting (default: true)
%       fit_spline_basis:            logical - run spline fitting (default: true)
%       SaveAppTree:                 logical - write the canonical per-channel output tree
%                                    (<out>/<chan>/{TFpeaks,SOPHs,auxiliary_data,param_basis,
%                                    spline_basis,figures/summary}) with provenance stamps,
%                                    the layout shared with dynamo-cli and the desktop app
%                                    (default: true)
%       SaveLegacyMat:               logical - keep the flat unstamped .mat outputs and the
%                                    legacy summary-figure name in <out>/ (default: true)
%
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
%   GITHUB     https://github.com
%
%   ATTRIBUTION
%   If you use this toolbox, please cite:
%
%   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
p = inputParser;
% Required inputs
addRequired(p, 'edf_fpaths', @(x) validateattributes(x, {'char','cell'},{}));
addRequired(p, 'scoring_fpaths', @(x) validateattributes(x, {'char','cell'},{}));
addRequired(p, 'output_fpath', @(x) validateattributes(x, {'char','cell'},{}));
addRequired(p, 'stage_col', @(x) validateattributes(x,{'double'},{'real','positive'}));
addRequired(p, 'time_col', @(x) validateattributes(x,{'double'},{'real','positive'}));
addRequired(p, 'channels',@(x)validateattributes(x,{'char','cell'},{}));
% Optional inputs for reading stages
addOptional(p, 'stage_vals_in', [], @(x) isempty(x) || (iscell(x) && numel(x)==7));
addOptional(p, 'header_lines', 0, @(x) isnumeric(x) && isscalar(x) && x>=0);
addOptional(p, 'start_time', NaN, @(x) ischar(x) || isstring(x) || isnan(x));
addOptional(p, 'epoch_dur', 30, @(x) isnumeric(x) && isscalar(x) && x>0);
addOptional(p, 'plot_on_staging', false, @(x) islogical(x) && isscalar(x));
% Optional inputs for the batch function
addOptional(p, 'resample_freq', [], @(x) validateattributes(x,{'double'},{'real','positive'}));
% DYNAM-O Inputs
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
addOptional(p, 'verbose', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'scalar'}));
addOptional(p, 'save_output_image', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'output_fname', 'DYNAM-O_output', @(x) validateattributes(x, {'char','string'}, {'nonempty','scalartext'}));
addOptional(p, 'fit_param_basis', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'fit_spline_basis', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
% Output-tree selection. Post-compute serialization only: neither flag
% changes what runDYNAMO computes or returns.
addOptional(p, 'SaveAppTree', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'scalar', 'binary'}));
addOptional(p, 'SaveLegacyMat', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'scalar', 'binary'}));

parse(p,varargin{:});
input_arguments = struct2cell(p.Results); %#ok<NASGU>
input_flags = fieldnames(p.Results);
eval(['[', sprintf('%s ', input_flags{:}), '] = deal(input_arguments{:});']);

%%

% Check to confirm scoring and edf paths are the same lenght (each EDF
% should have a scoring file)
if size(scoring_fpaths)~=size(edf_fpaths) %#ok<USENS>
    error('Different number of scoring files to edf files')
end

% Provenance stamp for the canonical tree, resolved once per batch. The
% kernel identity follows the backend that will compute the peaks: the
% pure-MATLAB path records the literal 'matlab-native'; the default rust
% backend records the loaded dynamo_rs build (or 'unknown').
if SaveAppTree %#ok<NODEF>
    batch_backend = 'rust';
    if isstruct(detection_options) && isfield(detection_options, 'backend') ...
            && ~isempty(detection_options.backend) %#ok<NODEF>
        batch_backend = lower(char(detection_options.backend));
    end
    if strcmp(batch_backend, 'matlab')
        tree_stamp = dynamo_stamp('matlab-native');
    else
        tree_stamp = dynamo_stamp();
    end
end

% Loop through each pair
for ii = 1:length(scoring_fpaths)

    % File naming logistics. The subject ID is the EDF basename; the
    % channel folder uses the label load_data actually emitted (falling
    % back to the first requested channel spec).
    curr_scoring_fpath = scoring_fpaths{ii};
    curr_edf_fpath = edf_fpaths{ii};
    [~,input_fbase] = fileparts(curr_edf_fpath);
    legacy_fig_name = strcat(output_fpath,'/',input_fbase,'_summary_fig.png');
    output_stats_name = strcat(output_fpath,'/',input_fbase,'_stats_table.mat');
    output_SOPH_name = strcat(output_fpath,'/',input_fbase,'_SOPHs.mat');

    % Load Data
    [data, Fs, stage_times, stage_vals, signal_labels] = load_data(curr_edf_fpath,curr_scoring_fpath,stage_col,time_col,channels,stage_vals_in,header_lines,start_time,epoch_dur,plot_on_staging,resample_freq);

    if exist('signal_labels', 'var') && iscell(signal_labels) && ~isempty(signal_labels)
        chan = char(signal_labels{1});
    elseif iscell(channels) %#ok<NODEF>
        chan = char(channels{1});
    else
        chan = char(channels);
    end

    % Summary figure destination: the canonical figures/summary slot when
    % the app tree is on, else the legacy flat name.
    if SaveAppTree
        fig_dir = fullfile(char(output_fpath), chan, 'figures', 'summary');
        if ~isfolder(fig_dir), mkdir(fig_dir); end
        output_fig_name = fullfile(fig_dir, sprintf('%s_summary_figure_%s.png', input_fbase, chan));
    else
        output_fig_name = legacy_fig_name;
    end

    % Run DYNAM-O. artifacts/t_time_range are captured for the auxiliary
    % file; the compute call itself is unchanged.
    [stats_table, ~, ~, ~, ~, t_time_range, artifacts, SOPHs] = runDYNAMO(data,Fs,stage_times,stage_vals,'save_output_image',save_output_image,'output_fname',output_fig_name);

    % (Several figures are generated during DYNAM-O, they are saved
    % separately)
    close all;

    % Legacy flat saves — .mat is HDF5 internally (-v7.3) so h5py /
    % h5dump can read these files directly without a MATLAB round-trip.
    % Unstamped, byte-compatible with what earlier releases wrote.
    if SaveLegacyMat %#ok<NODEF>
        save(output_stats_name,'stats_table','-v7.3');
        save(output_SOPH_name,'SOPHs','-v7.3');
        if SaveAppTree && save_output_image && isfile(output_fig_name)
            copyfile(output_fig_name, legacy_fig_name, 'f');
        end
    end

    % Canonical per-channel tree (post-compute serialization of the
    % returned results; per-artifact failures warn and move on so one
    % bad write cannot lose the rest of the batch).
    if SaveAppTree
        write_app_tree_(char(output_fpath), chan, input_fbase, tree_stamp, ...
            stats_table, SOPHs, SOPH_options, Fs, stage_times, stage_vals, ...
            artifacts, t_time_range);
    end

end

end


function write_app_tree_(out_root, chan, subj, stamp, stats_table, SOPHs, ...
    SOPH_options, Fs, stage_times, stage_vals, artifacts, t_time_range)
%WRITE_APP_TREE_  Serialize one (subject, channel) result set to the canonical tree
%
%   Inputs:
%       out_root     : char - results root directory -- required
%       chan         : char - output channel label (folder name) -- required
%       subj         : char - subject ID (file-name prefix) -- required
%       stamp        : struct - provenance stamp from dynamo_stamp -- required
%       stats_table  : table - per-peak features from runDYNAMO -- required
%       SOPHs        : struct - histograms + fits from runDYNAMO -- required
%       SOPH_options : struct - SOpowerphasehist_opts used for the run -- required
%       Fs           : double - sample rate(s) from load_data -- required
%       stage_times  : vector - stage onset times (s) -- required
%       stage_vals   : vector - stage codes -- required
%       artifacts    : logical vector - artifact mask over the analyzed range -- required
%       t_time_range : vector - time axis of the analyzed range (s) -- required
%
%   Outputs:
%       none (side effects only)
chan_dir = fullfile(out_root, chan);

% TFpeaks stats CSV (format 3)
try
    writeStatsTableCsv(fullfile(chan_dir, 'TFpeaks', ...
        sprintf('%s_stats_table_%s.csv', subj, chan)), ...
        stats_table, stamp, 'subjectID', subj);
catch ME
    warning('batch_script:writeFailed', 'stats CSV write failed for %s: %s', subj, ME.message);
end

% SOPH TIFFs (format 2)
try
    writeSOPHsTiff(fullfile(chan_dir, 'SOPHs', ...
        sprintf('%s_SOPHs_power_%s.tiff', subj, chan)), ...
        SOPHs.SOpower_mat, SOPHs.SOpower_bins, SOPHs.freq_bins, ...
        'sopower', stamp, 'subjectID', subj);
catch ME
    warning('batch_script:writeFailed', 'SOPH power TIFF write failed for %s: %s', subj, ME.message);
end
try
    writeSOPHsTiff(fullfile(chan_dir, 'SOPHs', ...
        sprintf('%s_SOPHs_phase_%s.tiff', subj, chan)), ...
        SOPHs.SOphase_mat, SOPHs.SOphase_bins, SOPHs.freq_bins, ...
        'sophase', stamp, 'subjectID', subj);
catch ME
    warning('batch_script:writeFailed', 'SOPH phase TIFF write failed for %s: %s', subj, ME.message);
end

% Auxiliary data h5 (format 2)
try
    aux = assemble_aux_(subj, Fs, stage_times, stage_vals, SOPHs, ...
        SOPH_options, artifacts, t_time_range);
    aux_dir = fullfile(chan_dir, 'auxiliary_data');
    if ~isfolder(aux_dir), mkdir(aux_dir); end
    aux_path = fullfile(aux_dir, sprintf('%s_auxiliary_data_%s.h5', subj, chan));
    % writeAuxH5 requires a fresh file (h5create cannot overwrite).
    if isfile(aux_path), delete(aux_path); end
    writeAuxH5(aux_path, aux, stamp);
catch ME
    warning('batch_script:writeFailed', 'auxiliary h5 write failed for %s: %s', subj, ME.message);
end

% Parametric-basis CSVs (format 3). Fields are absent or empty when the
% fit was disabled or failed; both are quietly skipped.
if isfield(SOPHs, 'SOpower_paramfit') && ~isempty(SOPHs.SOpower_paramfit)
    try
        writeParamfitCsv(fullfile(chan_dir, 'param_basis', ...
            sprintf('%s_SOpower_paramfit_%s.csv', subj, chan)), ...
            SOPHs.SOpower_paramfit, 'power', SOPHs.SOpower_bins, ...
            SOPHs.freq_bins, stamp, 'subjectID', subj);
    catch ME
        warning('batch_script:writeFailed', 'power paramfit CSV write failed for %s: %s', subj, ME.message);
    end
end
if isfield(SOPHs, 'SOphase_paramfit') && ~isempty(SOPHs.SOphase_paramfit)
    try
        writeParamfitCsv(fullfile(chan_dir, 'param_basis', ...
            sprintf('%s_SOphase_paramfit_%s.csv', subj, chan)), ...
            SOPHs.SOphase_paramfit, 'phase', SOPHs.SOphase_bins, ...
            SOPHs.freq_bins, stamp, 'subjectID', subj, ...
            'CrossHist', SOPHs.SOpower_mat, 'CrossBins', SOPHs.SOpower_bins);
    catch ME
        warning('batch_script:writeFailed', 'phase paramfit CSV write failed for %s: %s', subj, ME.message);
    end
end

% Spline-basis TIFFs (format 2)
if isfield(SOPHs, 'SOpower_splinefit') && ~isempty(SOPHs.SOpower_splinefit)
    try
        writeSplinefitTiff(fullfile(chan_dir, 'spline_basis', ...
            sprintf('%s_SOpower_splinefit_%s.tiff', subj, chan)), ...
            SOPHs.SOpower_splinefit, 'power', stamp, 'subjectID', subj);
    catch ME
        warning('batch_script:writeFailed', 'power splinefit TIFF write failed for %s: %s', subj, ME.message);
    end
end
if isfield(SOPHs, 'SOphase_splinefit') && ~isempty(SOPHs.SOphase_splinefit)
    try
        writeSplinefitTiff(fullfile(chan_dir, 'spline_basis', ...
            sprintf('%s_SOphase_splinefit_%s.tiff', subj, chan)), ...
            SOPHs.SOphase_splinefit, 'phase', stamp, 'subjectID', subj);
    catch ME
        warning('batch_script:writeFailed', 'phase splinefit TIFF write failed for %s: %s', subj, ME.message);
    end
end
end


function aux = assemble_aux_(subj, Fs, stage_times, stage_vals, SOPHs, ...
    SOPH_options, artifacts, t_time_range)
%ASSEMBLE_AUX_  Build the compact auxiliary_data struct from run results
%
%   Inputs:
%       subj         : char - subject ID -- required
%       Fs           : double - sample rate(s); the first entry is used -- required
%       stage_times  : vector - stage onset times (s) -- required
%       stage_vals   : vector - stage codes 0-5 -- required
%       SOPHs        : struct - carries SOpower_norm / SOpower_times -- required
%       SOPH_options : struct - SOPH options (freq range, window params,
%                      norm method); missing fields fall back to
%                      SOpowerphasehist_opts defaults -- required
%       artifacts    : logical vector - artifact mask over the analyzed range -- required
%       t_time_range : vector - time axis of the analyzed range (s) -- required
%
%   Outputs:
%       aux : struct - compact aux schema fields for writeAuxH5
opts = mergeOptsDefaults(SOPH_options, SOpowerphasehist_opts());

aux = struct();
aux.Fs = double(Fs(1));
aux.subjectID = subj;
if isfield(SOPHs, 'SOpower_times') && ~isempty(SOPHs.SOpower_times)
    % SOpower_times are the native window-center times; the compact
    % schema stores the first center plus the step (window params).
    aux.SOpower_t_start = double(SOPHs.SOpower_times(1));
end
aux.SOpower_freqrange = double(opts.SO_freqrange(:));
if isfield(SOPHs, 'SOpower_norm') && ~isempty(SOPHs.SOpower_norm)
    aux.SOpower_norm = double(SOPHs.SOpower_norm(:));
end
aux.SOpower_norm_method = char(string(opts.SOpower_norm_method));
aux.SOpower_window_params = double(opts.SOpower_window_params(:));

% Artifact mask indexes data within the analyzed range; shift the spans
% by the range start so they are absolute seconds since recording start.
spans = mask_to_spans(logical(artifacts), double(Fs(1)));
if ~isempty(spans) && ~isempty(t_time_range)
    spans = spans + double(t_time_range(1));
end
aux.artifact_spans = spans;

aux.stage_times = double(stage_times(:)');
aux.stage_vals = uint8(round(double(stage_vals(:)')));
end

