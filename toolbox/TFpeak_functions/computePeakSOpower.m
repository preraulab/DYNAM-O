function [stats_table, SOpower, SOpower_times, norm_method] = computePeakSOpower(varargin)
%COMPUTEPEAKSOPOWER  Compute the slow oscillation power for each TF peak in stats_table
%
%   Usage:
%       [stats_table, SOpower, SOpower_times, norm_method] = computePeakSOpower(stats_table, data, Fs, <options>)
%
%   Inputs:
%    REQUIRED:
%       stats_table: table - TF peak stats_table output from computeTFPeaks --required
%       data: Nx1 double - timeseries EEG data --required
%       Fs: numerical - sampling frequency of data (Hz) --required
%
%    OPTIONAL:
%       EEG_times: 1xN double - times for each EEG data sample. Default = (0:length(data)-1)/Fs
%       time_range: 1x2 double - min and max times for which to include TFpeaks. Also used to normalize
%                   SOpower. Default = [EEG_times(1), EEG_times(end)]
%       isexcluded: 1xN logical - marks each time point of data to be excluded or not, e.g., due to artifacts. Default = all false.
%
%       SO-POWER HISTOGRAM STRUCTURE PARAMETERS - see SOpowerphasehist_opts()
%       SO_freqrange: 1x2 double - min and max frequencies (Hz) considered to be "slow oscillation".
%                     Default = [0.3, 1.5]
%       SOpower_tapers: 1x2 double - multitaper method parameters. [time half-bandwidth product, number of tapers].
%                       Default = [5, 9]
%       SOpower_window_params: 1x2 double - multitaper method window parameters. [window size, window step size].
%                              Default = [5, .5]
%       SOpower_outlier_threshold: double - cutoff threshold in standard deviation for excluding outlier SOpower values.
%                                  Default = 3.
%       SOpower_norm_method: char - normalization method for SOpower. Options:'pNshiftS', 'percent', 'proportion', 'none'. Default = 'p2shift1234'
%                            For shift, it follows the format pNshiftS where N is the percentile and S is the list of stages (5=W,4=R,3=N1,2=N2,1=N3).
%                            (e.g. p2shift1234 = use the 2nd percentile of stages N3, N2, N1, and REM, p5shift123 = use the 5th percentile of stages
%                            N3, N2 and N1)
%       SOpower_retain_Fs: logical - whether to upsample calculated SOpower to the sampling rate of data. Default = true
%
%   Outputs:
%       stats_table: a table of TFpeaks with the SOpower column added
%       SOpower: 1xM double - SO power timeseries data
%       SOpower_times: 1xM double - SO power timeseries times
%       norm_method: char - normalization method for SOpower
%
%
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://harvard.edu
%   GITHUB     https://github.com
%
%   CITATION
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
%%
% If a struct is input with settings/params, detect and reformat it to work with the input parser below.
struct_ind = cellfun(@isstruct,varargin); % Get index of the struct

if any(struct_ind)
    locs = find(struct_ind==1);
    struct_arguments = cellfun(@(x) struct2cell(x), varargin(locs), 'UniformOutput', false);
    struct_fieldnames = cellfun(@(x) fieldnames(x), varargin(locs), 'UniformOutput', false);
    opt_struct = cell2struct(vertcat(struct_arguments{:}), vertcat(struct_fieldnames{:}));
    varargin = varargin(~struct_ind); % Remove structs from the varargin

    argcell = namedargs2cell(opt_struct); % Convert the struct to cell array
    varargin = cat(2, varargin, argcell); % Add the new cell array with the params to the end of the varargin

    % Test to make sure that none of the additional parameters are already included
    str_cell = cellstr(varargin(cellfun(@(x)(ischar(x)|isstring(x)),varargin)));
    assert(length(str_cell) == length(unique(str_cell)), 'Cannot include struct and duplicate parameters.')
end

%% Parse inputs
p = inputParser;
p.KeepUnmatched = true;

addRequired(p, 'stats_table', @(x) validateattributes(x, {'table'}, {'real','2d'}));
addRequired(p, 'data', @(x) validateattributes(x, {'numeric'}, {'real','vector'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','scalar'}));

%EEG time settings
addOptional(p, 'EEG_times', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addOptional(p, 'time_range', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addOptional(p, 'isexcluded', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));

%SOpower computation params
SOpower_options = SOpowerphasehist_opts(); % get the default parameters
addOptional(p, 'SO_freqrange', SOpower_options.SO_freqrange, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector','numel',2}));
addOptional(p, 'SOpower_tapers', SOpower_options.SOpower_tapers, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'SOpower_window_params', SOpower_options.SOpower_window_params, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'SOpower_outlier_threshold', SOpower_options.SOpower_outlier_threshold, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addOptional(p, 'SOpower_norm_method', SOpower_options.SOpower_norm_method, @(x) validateattributes(x, {'char','string'}, {'nonempty','scalartext'}));
addOptional(p, 'SOpower_retain_Fs', SOpower_options.SOpower_retain_Fs, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

assert(ismember('PeakTime', stats_table.Properties.VariableNames), 'PeakTime must be available in the stats_table to compute SOpower at each TF peak.') %#ok<NODEF>

%% Compute SO-power
[SOpower, SOpower_times, ~, norm_method] = computeSOpower(data, Fs,...
    'EEG_times', EEG_times, 'time_range', time_range, 'isexcluded', isexcluded,...
    'SO_freqrange', SO_freqrange, 'tapers', SOpower_tapers, 'window_params', SOpower_window_params,...
    'SOpower_outlier_threshold', SOpower_outlier_threshold, 'norm_method', SOpower_norm_method, 'retain_Fs', SOpower_retain_Fs);

%% Compute SO-power at TF peak times
% Get SOpower_times step size
SOpower_times_step = SOpower_times(2) - SOpower_times(1);

% Interpolate SOpower to peak time points
peak_SOpower = interp1([SOpower_times(1)-SOpower_times_step, SOpower_times, SOpower_times(end)+SOpower_times_step],...
    [SOpower(1), SOpower, SOpower(end)], stats_table.PeakTime); % peaks at isexcluded time points have NaN values here

%% Add SOpower to stats_table
stats_table.SOpower = peak_SOpower;

% update table column header
switch SOpower_norm_method
    case 'percent'
        pow_units = '%';
    case 'proportion'
        pow_units = 'proportion';
    otherwise
        pow_units = 'dB';
end
stats_table.Properties.VariableDescriptions{'SOpower'} = 'Slow-oscillation power at peak time';
stats_table.Properties.VariableUnits{'SOpower'} = pow_units;

end
