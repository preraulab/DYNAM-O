function [stats_table, SOphase, SOphase_times, SOdata] = computePeakSOphase(varargin)
%COMPUTEPEAKSOPHASE  Compute the slow oscillation phase for each TF peak in stats_table
%
%   Usage:
%       [stats_table, SOphase, SOphase_times, SOdata] = computePeakSOphase(stats_table, data, Fs, <options>)
%
%   Inputs:
%    REQUIRED:
%       stats_table: table - TF peak stats_table output from computeTFPeaks --required
%       data: Nx1 double - timeseries EEG data --required
%       Fs: numerical - sampling frequency of data (Hz) --required
%
%    OPTIONAL:
%       EEG_times: 1xN double - times for each EEG data sample. Default = (0:length(data)-1)/Fs
%       isexcluded: 1xN logical - marks each time point of data to be excluded or not, e.g., due to artifacts. Default = all false.
%
%       SO-PHASE HISTOGRAM STRUCTURE PARAMETERS - see SOpowerphasehist_opts()
%       SO_freqrange: 1x2 double - min and max frequencies (Hz) considered to be "slow oscillation".
%                     Default = [0.3, 1.5]
%       SOphase_filter: 1xF double - custom filter that will be used to estimate SOphase
%
%   Outputs:
%       stats_table: a table of TFpeaks with the SOphase column added
%       SOphase: 1xN double - SO phase timeseries data
%       SOphase_times: 1xN double - SO phase timeseries times
%       SOdata: 1xN double - SO filtered timeseries data
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
addOptional(p, 'isexcluded', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));

%SOphase computation params
SOphase_options = SOpowerphasehist_opts(); % get the default parameters
addOptional(p, 'SO_freqrange', SOphase_options.SO_freqrange, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector','numel',2}));
addOptional(p, 'SOphase_filter', SOphase_options.SOphase_filter);

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

assert(ismember('PeakTime', stats_table.Properties.VariableNames), 'PeakTime must be available in the stats_table to compute SOphase at each TF peak.') %#ok<NODEF>

%% Compute SO-phase
[SOphase, SOphase_times, ~, SOdata] = computeSOphase(data, Fs,...
    'EEG_times', EEG_times, 'isexcluded', isexcluded, 'SO_freqrange', SO_freqrange, 'SOphase_filter', SOphase_filter);

%% Compute SO-phase at TF peak times
% Get SOphase_times step size
SOphase_times_step = SOphase_times(2) - SOphase_times(1);

% Interpolate SOphase to peak time points
peak_SOphase = interp1([SOphase_times(1)-SOphase_times_step, SOphase_times, SOphase_times(end)+SOphase_times_step],...
    [SOphase(1), SOphase, SOphase(end)], stats_table.PeakTime); % peaks at isexcluded time points have NaN values here

% Re-wrap phases to be between -pi and pi
peak_SOphase = wrapToPi(peak_SOphase);
SOphase = wrapToPi(SOphase);

%% Add SOphase to stats_table
stats_table.SOphase = peak_SOphase;

% update table column header
stats_table.Properties.VariableDescriptions{'SOphase'} = 'Slow-oscillation phase at peak time';
stats_table.Properties.VariableUnits{'SOphase'} = 'rad';

end
