function [spindle_table] = refine_TFpeaks(varargin)
%REFINE_TFPEAKS  Compute a Hann spectrogram with 1Hz spectral resolution to refine the event frequencies
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
%
%   Output:
%       spindle_table: input spindle table with the Peak Frequency column updated following the 1Hz refinement
%
%    Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%
%% ********************************************************************
p = inputParser;
addRequired(p, 'data', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p,'spindle_table',@(x) validateattributes(x, {'table'}, {'real'}));
addOptional(p, 't',[], @(x) validateattributes(x, {'numeric', 'vector'}, {'real'}));
addOptional(p,'baseline_opt',false,@(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
addOptional(p, 'refine_method', 'spline_interp', @(x) ismember(x,{'spline_interp','spline_opt','spect_max'}));
addOptional(p,'remove_edge_peaks',true,@(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));

parse(p,varargin{:});
% Manually assign variables because eval doesn't work with parpool
data = p.Results.data;
Fs = p.Results.Fs;
spindle_table = p.Results.spindle_table;
t = p.Results.t;
baseline_opt = p.Results.baseline_opt;
refine_method = p.Results.refine_method;
remove_edge_peaks = p.Results.remove_edge_peaks;

if isempty(t)
    t = (0:length(data)-1)/Fs;
end

%Force spline interp if spline fitting is unavailable
if strcmpi(refine_method,'spline_opt') && ~license('test', 'Curve_Fitting_Toolbox')
    warning('Curve fitting toolbox not available. Unable to use optimization approach');
    refine_method = 'spline_interp';
end


%% SPECTROGRAM PARAMS
dsfreqs = 0.05; % For example, with Fs = 200, this should make the nfft = 2^12

window_size = 4;
step_size = 0.05;
freq_range = [0,30]; % frequency range to compute spectrum over (Hz)
nfft = 2^(nextpow2(Fs/dsfreqs)); % zero pad data to this minimum value for fft
detrend = 'constant'; % do not detrend
ploton = false; % do not plot out
mts_verbose = false; % suppress verbose messages

%% Extract necessary stats from the spindle table

% Calculate total recording time
data_len = length(data)/Fs;

event_times = spindle_table.PeakTime-t(1);
% Exclude event times that fall within half the window size distance from
% the start/end of the data collected
event_times_inc = event_times>=(0.5*window_size) & event_times<=data_len-(0.5*window_size);

% POTENTIAL FIX:
%event_times_inc(floor((event_times-(window_size/2))*Fs)==0) = 0;

bounding_box_lower = spindle_table.BoundingBox(event_times_inc,2); % Element 2 of the bounding box corresponds to the lower bound frequency of the detected event
bounding_box_height = spindle_table.BoundingBox(event_times_inc,4); % Element 4 of the bounding box gives the height of the bounding box

%% SPECTROGRAM

% Compute Hann spectrogram at the center of each event time. Rather than
% computing the entire spectrogram, this approach takes a fixed window
% around each event center to use for the frequency refinement
[spect, ~, sfreqs] = hanning_spectrogram_optimized(data, Fs, event_times(event_times_inc),'t',t, ...
    'frequency_range', freq_range,'data_window_params',[window_size,step_size],'NFFT',nfft,'detrend_opt',detrend, 'plot_on',ploton,'verbose',mts_verbose);

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
% Pre-allocate space to store updated spindle values
peak_freqs = NaN(height(spindle_table(event_times_inc,:)),1);

% Loop through each event
parfor ii = 1:N_events

    % Get the bounding box frequencies detected from the original double watershed 231->232 spectrogram
    start_freq = bounding_box_lower(ii);
    end_freq = bounding_box_lower(ii) + bounding_box_height(ii);
    range_inds = sfreqs<=end_freq & sfreqs>=start_freq;

    % Take the spectrogram slice at that single timepoint
    curr = spect(:,ii);

    % Calculate the location (frequency) of the max value within the slice and bounding box freqs
    max_val = max(curr(range_inds)); % Find the index of the max within those bounds
    max_freq = sfreqs(range_inds & (curr' == max_val)); % Get final frequency location

    switch refine_method
        case 'spline_interp' %Spline interpolation over a grid

            %NOTE: This method uses spline interpolation over a fixed grid.
            %While introducing theoretical discretization, this is
            %performed at a fine level. Moreover, as the grids are
            %non-uniform between peaks (1k points between start and end
            %freqs) this should not produce fix discretization and thus
            %not corrupt the peaks. This method far more computationally
            %efficient than the spline optimization.

            freq_interp = linspace(start_freq, end_freq, 1000);
            spline_interp = interp1(sfreqs, curr,freq_interp,'spline');
            [~, max_interp_ind] = max(spline_interp);
            peak_freqs(ii) = freq_interp(max_interp_ind);

        case 'spline_opt' %Fit a parametric spline model and estimate analytic max via optimization

            %NOTE: This method theoretically avoids discretization but is
            %computationally expensive due to the parametric fit and
            %optimization via fminsearch

            %Find the maximum with a search on the spline
            spline_fit = csapi(sfreqs, curr);

            %Do a search for the min starting at the max value as a guess
            objectiveFunction = @(x) -fnval(spline_fit, x);
            options = optimset('Display', 'off');
            peak_freqs(ii) = fminsearch(@(x) constrainedObjective(x, objectiveFunction, start_freq, end_freq), max_freq, options);

        case 'spect_max' %Find the max of the Hann FFT
            
            %NOTE: This simple approach adds descritization at the level of the FFT
            %frequency bins to the PeakFrequency estimates, resulting in false
            %peaks in the SOPH. This is due to interference between two levels of
            %discretization (i.e. doing a histogram on discretized values).
            %Should be avoided if possible.

            peak_freqs(ii) = max_freq;
    end

    % Update peak frequencies array with the final refined frequency
    % remove if at a boundary
    if remove_edge_peaks && (min(abs(peak_freqs(ii)-[start_freq end_freq]))<1e-3 || peak_freqs(ii)>end_freq || end_freq<start_freq)
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



