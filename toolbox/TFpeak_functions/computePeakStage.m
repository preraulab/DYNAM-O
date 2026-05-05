function [ stats_table ] = computePeakStage(varargin)
%COMPUTEPEAKSTAGE  Compute the sleep stage for each TF peak in stats_table
%
%   Usage:
%       stats_table = computePeakStage(stats_table, stage_times, stage_vals, t_artifacts, artifacts)
%
%   Required Inputs:
%       stats_table: table - TFpeak stats table from computeTFPeaks(); must contain PeakTime -- required
%       stage_times: [1xS] double or single - timestamps of stage_vals -- required
%       stage_vals:  [1xS] double or single - sleep stage values at each time in stage_times.
%                    Staging convention: 0=unidentified, 1=N3, 2=N2, 3=N1, 4=REM, 5=WAKE -- required
%
%   Optional Inputs:
%       t_artifacts: [1xT] double - time vector for EEG data used to compute input stats_table.
%                    If time_range was used in computeTFPeaks(), pass in t_time_range. (default: [])
%       artifacts:   [1xT] logical - boolean vector marking artifact time points; used to assign
%                    artifact stage (6=ARTIFACT) to TF peaks. (default: [])
%
%   Outputs:
%       stats_table: table - input table with PeakStage column added.
%                    PeakStage encoding:
%                        0 = Unknown / unscored
%                        1 = N3
%                        2 = N2
%                        3 = N1
%                        4 = REM
%                        5 = Wake
%                        6 = Artifact (only when artifacts vector is provided)
%
%   Notes:
%       - Stage assignment uses interp1(..., 'previous'): each peak is labelled with the
%         stage in effect from the most recent stage transition at or before its PeakTime.
%         Peaks occurring before the first scored stage are assigned 0 (Unknown).
%       - Artifact stage (6) is only populated when both t_artifacts and artifacts are provided;
%         otherwise peaks overlapping artifact windows retain their scored sleep stage.
%
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
    % Peaks whose PeakTime falls outside [t_artifacts(1), t_artifacts(end)]
    % return NaN from interp1, and logical(NaN) errors in modern MATLAB.
    % Default out-of-range peaks to "not an artifact".
    artifact_hits = interp1(t_artifacts, single(artifacts), stats_table.PeakTime, 'nearest', 0);
    stats_table.PeakStage(logical(artifact_hits)) = 6;
end

% update table column header
if ~isempty(artifacts) && ~isempty(t_artifacts)
    stats_table.Properties.VariableDescriptions{'PeakStage'} = 'Stage: 6 = Artifact, 5 = W, 4 = R, 3 = N1, 2 = N2, 1 = N3, 0 = Unknown';
else
    stats_table.Properties.VariableDescriptions{'PeakStage'} = 'Stage: 5 = W, 4 = R, 3 = N1, 2 = N2, 1 = N3, 0 = Unknown';
end
stats_table.Properties.VariableUnits{'PeakStage'} = 'Stage #';

end
