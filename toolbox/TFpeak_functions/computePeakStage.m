function [ stats_table ] = computePeakStage(stats_table, stage_times, stage_vals, t, artifacts)
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
%   t            --  time for each EEG data sample used to compute the
%                    input stats_table. If `time_range` is used during
%                    computeTFPeaks(), then must provide the t_time_range.
%   artifacts    --  boolean vector indicating whether EEG data at each
%                    time point is an artifact, used to interpolate
%                    artifact stages (6=ARTIFACT) for TFpeaks.
%
% OUTPUTS:
%   stats_table: a table of TFpeaks with the PeakStage column added
%
%   Copyright 2024 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

assert(length(t) == length(artifacts), 'Artifacts and timestamp t must have the same length.')
assert(ismember('PeakTime', stats_table.Properties.VariableNames), 'PeakTime must be available in the stats_table to compute PeakStage.')

%% Add PeakStage to stats_table
stats_table.PeakStage = interp1(stage_times, stage_vals, stats_table.PeakTime, 'previous');
stats_table.PeakStage(isnan(stats_table.PeakStage)) = 0; % a conservative choice to mark peaks outside scored stages as unknown
stats_table.PeakStage(logical(interp1(t, single(artifacts), stats_table.PeakTime, 'nearest'))) = 6;

% update table column header
stats_table.Properties.VariableDescriptions{'PeakStage'} = 'Stage: 6 = Artifact, 5 = W, 4 = R, 3 = N1, 2 = N2, 1 = N3, 0 = Unknown';
stats_table.Properties.VariableUnits{'PeakStage'} = 'Stage #';

end
