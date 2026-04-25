function [stats_table] = refinePeakFrequency(varargin)
%REFINEPEAKFREQUENCY  Compute a Hann spectrogram with 1Hz spectral resolution to refine the event frequencies
%
%   Usage:
%       [stats_table] = refinePeakFrequency(data, Fs, stats_table, freq_range, t, baseline_opt, refine_method, remove_edge_peaks)
%
%   Required Inputs:
%       data: <number of samples> x 1 vector - time series data
%       Fs: double - sampling frequency in Hz
%       stats_table: table - list of events, including the peak times, peak frequencies,
%                    and the bounding box
%
%   Optional Inputs:
%       freq_range: 1x2 vector - frequency range to compute spectrogram over (Hz). Default = [0, 30]
%       t: <number of samples> x 1 vector - timestamps for data. Default = (0:length(data)-1)/Fs
%       baseline_opt: logical - true to include baseline removal, false to exclude. Default = false
%       refine_method: char - method to assign max frequency value using interpolation;
%                      {'spline_interp', 'spline_opt', 'spect_max'}. Default = 'spline_interp'
%       remove_edge_peaks: logical - true to remove peaks at edge of event bounding box. Default = true
%
%   Output:
%       stats_table: input stats table with the Peak Frequency column updated following the 1Hz refinement
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
addRequired(p, 'data', @(x) validateattributes(x, {'numeric'}, {'real','vector'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','scalar'}));
addRequired(p, 'stats_table', @(x) validateattributes(x, {'table'}, {'real','nonempty','2d'}));

detection_options = detection_opts(); % get the default parameters
addOptional(p, 'freq_range', detection_options.mtm_freq_range, @(x) validateattributes(x,{'numeric'},{'real','finite','vector','numel',2}));
addOptional(p, 't', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addOptional(p, 'baseline_opt', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'refine_method', 'spline_interp', @(x) any(validatestring(x, {'spline_interp', 'spline_opt', 'spect_max'})));
addOptional(p, 'remove_edge_peaks', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));

parse(p,varargin{:});

% Manually assign variables because eval doesn't work with parpool
data = p.Results.data;
Fs = p.Results.Fs;
stats_table = p.Results.stats_table;
freq_range = p.Results.freq_range;
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
nfft = 2^(nextpow2(Fs/dsfreqs)); % zero pad data to this minimum value for fft
window_size = 4;
step_size = 0.05;
detrend_opt = 'constant'; % do not detrend
ploton = false; % do not plot out
mts_verbose = false; % suppress verbose messages

%% Extract necessary stats from the stats_table
event_times = stats_table.PeakTime;
% Exclude event times that fall within half the window size distance from
% the start/end of the data collected
event_times_inc = event_times >= (t(1)+(0.5*window_size)) & event_times <= (t(end)-(0.5*window_size));

bounding_box_lower = stats_table.BoundingBox(event_times_inc,2); % Element 2 of the bounding box corresponds to the lower bound frequency of the detected event
bounding_box_height = stats_table.BoundingBox(event_times_inc,4); % Element 4 of the bounding box gives the height of the bounding box

%% SPECTROGRAM

% Compute Hann spectrogram at the center of each event time. Rather than
% computing the entire spectrogram, this approach takes a fixed window
% around each event center to use for the frequency refinement
[spect, ~, sfreqs] = hann_event_spectra(data, Fs, event_times(event_times_inc),'t',t, ...
    'frequency_range',freq_range,'data_window_params',[window_size,step_size],'NFFT',nfft,'detrend_opt',detrend_opt, 'plot_on',ploton,'verbose',mts_verbose);

%% RECOMPUTE BASELINE

% If baseline removal is on
if baseline_opt
    spect = removeBaseline(spect); % recompute spect with baseline removed
end

%% REFINE STATS_TABLE
N_events = height(stats_table(event_times_inc,:));
% Pre-allocate space to store updated spindle values
peak_freqs = NaN(height(stats_table(event_times_inc,:)),1);

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
            %not corrupt the peaks. This method is far more computationally
            %efficient than the spline optimization.

            freq_interp = linspace(start_freq, end_freq, 1000);
            spline_interp = interp1(sfreqs, curr, freq_interp, 'spline');
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

% Update the stats_table with the refined frequency array
stats_table.PeakFrequency(event_times_inc) = peak_freqs;

end


%% Define a helper function to enforce constraints
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
