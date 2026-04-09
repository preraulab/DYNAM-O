function [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, SOPHs] = runExampleData(data_range, default_verbose, run_app, varargin)
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
%% PARSE INPUTS
p = inputParser;

addOptional(p, 'skip_SOPH', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'plot_on', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'verbose', default_verbose, @(x) validateattributes(x, {'logical', 'numeric'}, {'scalar'}));
addOptional(p, 'speed_test', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

if speed_test
    skip_SOPH = true;
    plot_on = false;
end

if verbose
    disp('Running Example Data...');
end

%Load default options
baseline_options = baseline_opts();
detection_options = detection_opts();
SOPH_options = SOpowerphasehist_opts();

%% DATA SETTINGS
%Location of example data
data_fname = fullfile(fileparts(which('runDYNAMO')), 'example_data', 'example_data.mat');

if nargin == 0
    data_range = 'segment';
end

%% LOAD DATA
%Load example EEG data
load(data_fname, 'data', 'stage_times', 'stage_vals', 'Fs');

switch data_range
    case 'segment'
        % Choose an example segment from the data
        time_range = [8420 13446];

        %Set the minimum time in SO-power bin and minimum peak in SO-phase frequency to include in the SOPHs
        SOPH_options.SOpower_min_time_in_bin = 5;
        SOPH_options.SOphase_min_peak_at_freq = 10;

        if verbose
            disp(['  Loading example segment...', newline])
        end
    case 'night'
        % Use the full night from the example data
        wake_buffer = 5*60; % 5 minute buffer before/after first/last wake
        start_time = stage_times(find(stage_vals < 5 & stage_vals > 0, 1, 'first')) - wake_buffer;
        end_time = stage_times(find(stage_vals < 5 & stage_vals > 0, 1, 'last')) + wake_buffer;
        time_range = [start_time end_time];

        if verbose
            disp(['  Loading full night...', newline])
        end
end

if run_app
    %Open up app with DYNAMO class
    % h = msgbox('Example data loaded. Launching app...');
    % pause(1);
    % if ishandle(h)
    %     close(h);
    % end
    d = DYNAMO(data, Fs, stage_times, stage_vals, time_range, baseline_options, detection_options, SOPH_options, 'app', true);
    stats_table = d;  % abuse the stats_table variable to return the DYNAMO object
    [spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, SOPHs] = deal([]);
else
    %Call main function runDYNAMO()
    if speed_test
        detection_options.show_pbar = false;
    end

    if skip_SOPH
        [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts] = runDYNAMO(data, Fs, stage_times, stage_vals, time_range, baseline_options, detection_options, SOPH_options,...
            'verbose', verbose, 'plot_on', plot_on);
        SOPHs = [];
    else
        [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals, time_range, baseline_options, detection_options, SOPH_options,...
            'verbose', verbose, 'plot_on', plot_on);
    end
end

end
