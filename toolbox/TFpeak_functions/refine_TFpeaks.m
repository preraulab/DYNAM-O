function [spindle_table] = refine_TFpeaks(data,Fs,spindle_table,baseline_opt,method, remove_edge_peaks)
%REFINE_TFPEAKS  Compute a high res hanning spectrogram to refine the event table after performing the double watershed
%
%   Usage:
%       [spindle_table] = refine_TFpeaks(data, Fs, spindle_table, baseline_opt, method)
%
%   Input:
%       data: <number of samples> x 1  vector - time series data -- required
%       Fs: double - sampling frequency in Hz  -- required
%       spindle_table: table - list of events, including the peak times, peak frequencies,
%                      and the bounding box -- required
%       baseline_opt: logical - true to include baseline removal, false to exclude (default: false)
%       method: char - method for refining peak frequencies ('spline_opt', 'spline_grid', 'spect_max') (default: 'spline_opt')
%
%   Output:
%       spindle_table: input spindle table with the Peak Frequency column updated following the 1Hz refinement
%
%    Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%
%% ********************************************************************
if nargin<5
    method = 'spline_opt';
end

if nargin<6
    remove_edge_peaks = true;
end

%% SPECTROGRAM PARAMS

dsfreqs = 0.05; % With Fs = 200, this should make the nfft = 2^12

window_size = 4;
step_size = 0.05;
freq_range = [0,30]; % frequency range to compute spectrum over (Hz)
nfft = 2^(nextpow2(Fs/dsfreqs)); % zero pad data to this minimum value for fft
detrend = 'constant'; % do not detrend
ploton = false; % do not plot out
mts_verbose = true; % suppress verbose messages

%% Extract necessary stats from the spindle table

% Calculate total recording time
data_len = length(data)/Fs;

event_times = spindle_table.PeakTime;
% Exclude event times that fall within half the window size distance from
% the start/end of the data collected
event_times_inc = event_times>=(0.5*window_size) & event_times<=data_len-(0.5*window_size);

bounding_box_lower = spindle_table.BoundingBox(event_times_inc,2); % Element 2 of the bounding box corresponds to the lower bound frequency of the detected event
bounding_box_height = spindle_table.BoundingBox(event_times_inc,4); % Element 4 of the bounding box gives the height of the bounding box
% Pre-allocate space to store updated spindle values
peak_freqs = NaN(height(spindle_table(event_times_inc,:)),1);

%% SPECTROGRAM

% Compute Optimized Hanning Spectrogram
[spect, ~, sfreqs] = hanning_spectrogram_optimized(data, Fs, event_times(event_times_inc), freq_range, [window_size,step_size], nfft, detrend, ploton, mts_verbose);

%% RECOMPUTE BASELINE

% If baseline removal is on
if baseline_opt
    spect_bl = spect;
    spect_bl(spect_bl==0) = NaN; % Turn 0s to NaNs for percentile computation

    baseline_ptile = 2; % using 2nd percentile of spectrogram as baseline
    baseline = prctile(spect_bl, baseline_ptile, 2); % get baseline

    clear spect_bl % for cleanup

    [spect, ~] = removeBaseline(spect, baseline); % recompute spect with baseline removed
end

%% REFINE SPINDLE TABLE
N_events = height(spindle_table(event_times_inc,:));
peak_freqs = zeros(1,N_events);

% Loop through each event
parfor ii = 1:N_events

    % Get the bounding box frequencies detected from the original double watershed 231->232 spectrogram
    start_freq = bounding_box_lower(ii);
    end_freq = bounding_box_lower(ii) + bounding_box_height(ii);

    % Take the spectrogram slice at that single timepoint
    curr = spect(:,ii);

    switch method
        case 'spline_opt'
            %Find the maximum with a search on the spline
            idxs = sfreqs<=end_freq-1 & sfreqs>=start_freq;
            spline_fit = csapi(sfreqs, curr);

            [~,idx] = max(curr(idxs)); % Find the index of the max within those bounds
            idx = idx + find(idxs,1,"first")-1; % Perform a find for the max index within bounds indices
            freq_guess = sfreqs(idx); % Get final frequency location

            %Do a search for the min starting at the max value as a guess
            objectiveFunction = @(x) -fnval(spline_fit, x);
            options = optimset('Display', 'off');
            peak_freqs(ii) = fminsearch(@(x) constrainedObjective(x, objectiveFunction, start_freq, end_freq), freq_guess, options);

        case 'spline_grid'
            % Use spline fit on a grid to have less descretized frequency result
            idxs = sfreqs<=end_freq-1 & sfreqs>=start_freq;
            spline_fit = csapi(sfreqs(idxs), curr(idxs));

            freq_interp = linspace(start_freq, end_freq, 1000);
            [~,idx] = max(fnval(spline_fit, freq_interp));
            peak_freqs(ii) = freq_interp(idx);
        case 'spect_max'
            % Calculate the location (frequency) of the max value within the slice and bounding box freqs
            idxs = sfreqs<=end_freq & sfreqs>=start_freq; % Find the indices of frequencies within the bounding box
            [~,idx] = max(curr(idxs)); % Find the index of the max within those bounds
            idx = idx + find(idxs,1,"first")-1; % Perform a find for the max index within bounds indices
            peak_freqs(ii) = sfreqs(idx); % Get final frequency location
    end

    % Update peak frequencies array with the final refined frequency
    % remove if at a boundary
    if remove_edge_peaks && min(abs(peak_freqs(ii)-[start_freq end_freq]))<1e-3
         peak_freqs(ii) = nan;
    end 

end

% Update the spindle table with the refined frequency array
spindle_table.PeakFrequency(event_times>=(0.5*window_size) & event_times<=data_len-(0.5*window_size)) = peak_freqs;

end

% Define a function to enforce constraints
function constrainedValue = constrainedObjective(x, objective_fcn, LB, UB)
    % Penalize values outside the bounds
    penalty = 1e6;
    if x < LB || x > UB
        constrainedValue = penalty;
    else
        % Evaluate the original objective function
        constrainedValue = objective_fcn(x);
    end
end



