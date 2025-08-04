function [ stats_table ] = computePeakStage(varargin)
% COMPUTEPEAKSTAGE: Compute the sleep stage for each TF peak in stats_table
%
%   Usage:
%       [ stats_table ] = computePeakStage(stats_table, stage_times, stage_vals, t_time_range, artifacts)
%
% INPUTS:
%   stats_table  --  a table of TFpeaks and their features. PeakTime is a
%                    required feature in this table.
%   stage_times  --  double or single - timestamps of stage_vals
%   stage_vals   --  double or single - sleep stage values at eaach time in
%                    stage_times. Note the staging convention:
%                    0=unidentified, 1=N3, 2=N2, 3=N1, 4=REM, 5=WAKE
%   t_artifacts  --  time for each EEG data sample used to compute the
%                    input stats_table and artifacts. If `time_range` is
%                    used during computeTFPeaks(), then must pass in the
%                    t_time_range output from computeTFPeaks().
%   artifacts    --  boolean vector indicating whether EEG data at each
%                    time point is an artifact, used to interpolate
%                    artifact stages (6=ARTIFACT) for TFpeaks.
%
% OUTPUTS:
%   stats_table: a table of TFpeaks with the PeakStage column added
%
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

%% Parse inputs
p = inputParser;

addRequired(p, 'stats_table', @(x) validateattributes(x, {'table'}, {'real','2d'}));
addRequired(p, 'stage_times', @(x) validateattributes(x, {'double','single'}, {'real','finite','nondecreasing','2d'}));
addRequired(p, 'stage_vals', @(x) validateattributes(x, {'double','single'}, {'real','finite','nonnegative','2d'}));

addOptional(p, 't_artifacts', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addOptional(p, 'artifacts', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

assert(length(t_artifacts) == length(artifacts), 'Artifacts and timestamp t must have the same length.')
assert(ismember('PeakTime', stats_table.Properties.VariableNames), 'PeakTime must be available in the stats_table to compute PeakStage.') %#ok<NODEF>
if ~isempty(artifacts)
    assert(~isempty(t_artifacts), 'Must provide t_artifacts along with artifacts to mark TF peaks at an artifact stage.')
end

%% Add PeakStage to stats_table
stats_table.PeakStage = interp1(stage_times, stage_vals, stats_table.PeakTime, 'previous');
stats_table.PeakStage(isnan(stats_table.PeakStage)) = 0; % a conservative choice to mark peaks outside scored stages as unknown

if ~isempty(artifacts) && ~isempty(t_artifacts)
    stats_table.PeakStage(logical(interp1(t_artifacts, single(artifacts), stats_table.PeakTime, 'nearest'))) = 6;
end

% update table column header
if ~isempty(artifacts) && ~isempty(t_artifacts)
    stats_table.Properties.VariableDescriptions{'PeakStage'} = 'Stage: 6 = Artifact, 5 = W, 4 = R, 3 = N1, 2 = N2, 1 = N3, 0 = Unknown';
else
    stats_table.Properties.VariableDescriptions{'PeakStage'} = 'Stage: 5 = W, 4 = R, 3 = N1, 2 = N2, 1 = N3, 0 = Unknown';
end
stats_table.Properties.VariableUnits{'PeakStage'} = 'Stage #';

end
