function varargout = runExampleData(data_range, verbose, run_app)
if ~exist('verbose', 'var')
    verbose = false;
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
data_fname = 'example_data/example_data.mat';

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
    h = msgbox('Example data loaded. Launching app...');
    pause(1);
    if ishandle(h)
        close(h);
    end
    d = DYNAMO(data, Fs, stage_times, stage_vals, time_range, baseline_options, detection_options, SOPH_options, 'app', true);
    varargout = {d};
else
    %Call main function runDYNAMO()
    [stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, SOPHs] = runDYNAMO(data, Fs, stage_times, stage_vals, time_range, baseline_options, detection_options, SOPH_options);
    varargout = {stats_table, spect, stimes, sfreqs, data_time_range, t_time_range, artifacts, SOPHs};
end

end
