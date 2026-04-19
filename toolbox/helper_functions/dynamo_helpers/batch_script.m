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

% Loop through each pair
for ii = 1:length(scoring_fpaths)

    % File naming logistics
    curr_scoring_fpath = scoring_fpaths{ii};
    curr_edf_fpath = edf_fpaths{ii};
    [~,input_fbase] = fileparts(curr_edf_fpath);
    output_fig_name = strcat(output_fpath,'/',input_fbase,'_summary_fig.png');
    output_stats_name = strcat(output_fpath,'/',input_fbase,'_stats_table.mat');
    output_SOPH_name = strcat(output_fpath,'/',input_fbase,'_SOPHs.mat');
 
    % Load Data
    [data, Fs, stage_times, stage_vals] = load_data(curr_edf_fpath,curr_scoring_fpath,stage_col,time_col,channels,stage_vals_in,header_lines,start_time,epoch_dur,plot_on_staging,resample_freq);

    % Run DYNAM-O
    [stats_table, ~, ~, ~, ~, ~, ~, SOPHs] = runDYNAMO(data,Fs,stage_times,stage_vals,'save_output_image',save_output_image,'output_fname',output_fig_name);

    % (Several figures are generated during DYNAM-O, they are saved
    % separately)
    close all;

    % Saving
    save(output_stats_name,'stats_table');
    save(output_SOPH_name,'SOPHs');

end

end

