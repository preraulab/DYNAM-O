function [ fpeak_proms, tpeak_proms, tpeak_times, tpeak_durations, tpeak_center_times, tpeak_central_frequencies, tpeak_bandwidths, tpeak_bandwidth_bounds,...
    tpeak_sd_central_frequencies, tpeak_sd_bandwidths, tpeak_interpeak_intervals ]...
    = find_time_peaks(fpeak_proms, fpeak_freqs, fpeak_bandwidths, fpeak_bandwidth_bounds, stimes, varargin)
%
% **PEAK PROMINENCE CALCULATION OF PROMINENCE CURVE IN THE TIME DOMAIN**
%&#x1F536;
%
% function used to calculate the peak prominence of the extracted
% prominence curve in the time domain. The prominence curve time series,
% ffreq, and fwidth can be calculated using the find_frequency_peaks.m
% function that uses findpeaks in the frequency domain.
%
% Usage: [ tpeak_proms, tpeak_times, tpeak_widths, fwidth_at_tpeak, sd_ffreq, sd_fwidth, tpeak_intervals ] = ...
%           find_time_peaks(prominence_curve, ffreq, fwidth, stimes, stages, stage_times, '<flag#1>',<arg#1>...'<flag#n>',<arg#n>);
%
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% ##### Declared Inputs: [[[NEEDS UPDATES!!!]]]
%
%           The following variables are derived from
%           find_frequency_peaks.m
%
%           - prominence_curve: This is the prominence of the peaks
%                               detected on the normalized spectrum at
%                               each time slice.
%
%           - ffreq:            The frequency of the peaks detected on the
%                               normalized spectrum at each time slice.
%
%           - fwidth:           The width of the peaks detected on the
%                               normalized spectrum at each time slice.
%
%           The following variable can be generated from the multitaper
%           spectrogram function:
%
%           - stimes:           The time axis vector as used in multitaper
%                               spectrogram estimation. This vector has the
%                               same length as prominence_curve, ffreq, and
%                               fwidth. Each sample is the time in seconds
%                               for the center of the window used to
%                               compute one time slice of the spectrogram.
%                               This vector should be in seconds.
%
%           Other Parameters:
%
%           - stages:           Scored sleep stages as a vector. All motion
%                               artifacts should already be marked as
%                               periods of wake prior to calling this
%                               function. This is important for detecting
%                               spindles during only NREM segments.
%
%           - stage_times:      The is the vector of times at which every
%                               new stage starts. This should be in
%                               seconds.
%
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% ##### Optional Inputs:
%
%           - 'smooth_sec':         The number of seconds to smooth the
%                                   prominence curve by. This is
%                                   implemented with movmean.m
%                                   default: [0.3]
%
%           - 'only_NREM':          A boolean specifying whether only to
%                                   detect peaks in prominence curve during
%                                   NREM sleep stages. If false, peaks are
%                                   also detected during REM sleep.
%                                   default: True
%
%           - 'min_peak_width_sec':   The minimum peak width required for a
%                                   peak to be detected by findpeaks. It
%                                   is specified in seconds. Can be
%                                   adjusted to prevent detecting tiny
%                                   noisy peaks. A default value of 0.3 is
%                                   chosen considering smoothing and the
%                                   literature assumption of sleep spindles
%                                   having durations in the range 0.3-3s. 
%                                   default: [0.3]
%
%           - 'min_peak_distance_sec':The minimum distance between detected
%                                   peaks in findpeaks. It is specified in
%                                   seconds. Peak distance is measured from
%                                   peak to peak. This corresponds to prior
%                                   assumption about silence period between
%                                   peaks. This parameter should match
%                                   the step size and time window
%                                   parameters in multitaper spectrogram.
%                                   If a multitaper spectrogram is
%                                   estimated with window lenth of 1s, then
%                                   it is difficult to interpret two peaks
%                                   that are less than 0.5s apart. However,
%                                   default is set to be 0s here because
%                                   usually this parameter doesn't change
%                                   results by much.
%                                   default: [0]
%
%           - 'report_width_scale': This parameter determines the
%                                   conversion from half height width of
%                                   detected peaks on the prominence curve
%                                   to start and end times of possible
%                                   spindle candidates. The spindle start
%                                   and end times are derived as
%
%                                   tpeak_time - (report_width_scale*half_height_width)
%                                                       ~
%                                   tpeak_time + (report_width_scale*half_height_width)
%
%                                   thus, if report_width_scale is set to
%                                   be 0.5, the width of detected peak will
%                                   have the same width as the half height
%                                   width.
%                                   default = [0.5];
%
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% ##### Outputs:
%
%           - tpeak_proms:      The prominence values of peaks detected
%                               in the input prominence curve.
%
%           - tpeak_times:      The time points of detected peaks.
%                               This will be the a 2 column vector in the
%                               format: [start_times, end_times]. The times
%                               are calculated based on the
%                               report_width_scale.
%
%           - tpeak_widths:     The width of peaks detected in
%                               the input prominence curve. These values
%                               are reported in seconds.
%
%           - fwidth_at_tpeak:  The width of maximal spectral peak at the
%                               time slice of a peak detected in the
%                               prominence curve.
%
%           - sd_ffreq:         The standard deviation of the frequencies
%                               of spectral peaks in the time slices where
%                               a peak is detected in the prominence value.
%                               These values are computed using ffreqs
%                               from find_spectrogram_peaks.m
%
%           - sd_fwidth:        The standard deviation of the width of
%                               spectral peaks in the time slices where a
%                               peak is detected in the prominence value.
%                               These values are computed using fwidth
%                               from find_spectrogram_peaks.m
%
%           - ffreq_at_tpeak:   The frequency of maximal spectral peak at
%                               the time slice of a peak detected in the
%                               prominence curve.
%
%           - tpeak_intervals:  Intervals between tpeaks, calculated as end
%                               time of previous peak to start time of next
%                               peak. This is the upper bound for
%                               peakdistance, which is calculated from peak
%                               to peak. 
%
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

%%
% Parse inputs and preparation
[ fpeak_proms, min_peak_width_sec, min_peak_distance_sec ] = tpeak_inputparse(fpeak_proms, stimes, varargin{:});

% Find peaks in the peak prominence curve time series
[~,locs,w,proms,x_w] = findpeaks_extents(fpeak_proms, stimes, 'minPeakWidth',min_peak_width_sec, 'MinPeakDistance',min_peak_distance_sec);
assert(all(ismember(locs, stimes)), 'Some detected peaks do not occur at a known time slice. Please check why.')

% Compute output variables 
% whether to compute standard deviation and interval results 
if nargout > 8
    needmoreout = true;
else
    needmoreout = false;
end
[ tpeak_proms, tpeak_times, tpeak_durations, tpeak_center_times, tpeak_bandwidths, tpeak_bandwidth_bounds,...
    tpeak_central_frequencies, tpeak_sd_central_frequencies, tpeak_sd_bandwidths, tpeak_interpeak_intervals ]...
    = tpeak_compute_output(locs, w, proms, x_w, stimes, fpeak_freqs, fpeak_bandwidths, fpeak_bandwidth_bounds, needmoreout);

end

function [ fpeak_proms, min_peak_width_sec, min_peak_distance_sec ] = tpeak_inputparse(fpeak_proms, stimes, varargin)
%% Configure optional input arguments:
optionalInputs = {'valid_time_inds', 'smooth_sec', 'min_peak_width_sec', 'min_peak_distance_sec'}; % optional
optionalDefaults = {true(1, length(stimes)), 0.3, 0.3, 0};

% sanity check on varargin
assert(~mod(length(varargin),2), 'varargin is not of even length. Please check!')
valid_varargin = contains(varargin(1:2:end), optionalInputs);
assert(all(valid_varargin), 'some varargin cannot be recognized. Did you make a typo?')

% Update optionalDefaults values according to varargin
for ii = 1:length(optionalInputs)
    FlagIndex = find(strcmpi(optionalInputs{ii}, varargin)==1);
    assert(length(FlagIndex) <= 1,'Only one %s value can be entered as an input.', optionalInputs{ii})
    if ~isempty(FlagIndex)
        optionalDefaults{ii} = varargin{FlagIndex+1};
    end
end

% Instantiate these optional input variables
valid_time_inds = optionalDefaults{1};
smooth_sec = optionalDefaults{2};
min_peak_width_sec = optionalDefaults{3};
min_peak_distance_sec = optionalDefaults{4};

%% Preprocessing
assert(length(valid_time_inds) == length(stimes), 'Length of time selection vector is different from that of stimes.')

% smooth before findpeaks
if smooth_sec > 0
    % calculate smooth_samples from smooth_sec, round up
    smooth_samples = ceil(smooth_sec / (stimes(2)-stimes(1)));
    % by setting 'includenan', if there is a nan value within the smoothing
    % window, it will become nan as well. This effectively makes a
    % conservative bleeding of removal of prominence curve values around
    % artifacts or wake periods.
    fpeak_proms = movmean(fpeak_proms, smooth_samples, 'includenan'); % to be conservative about NaN values
end

% Mask out non-valid time points
fpeak_proms(~valid_time_inds) = nan;

end

function [ tpeak_proms, tpeak_times, tpeak_durations, tpeak_center_times, tpeak_bandwidths, tpeak_bandwidth_bounds,...
    tpeak_central_frequencies, tpeak_sd_central_frequencies, tpeak_sd_bandwidths, tpeak_interpeak_intervals ]...
    = tpeak_compute_output(locs, w, proms, x_w, stimes, fpeak_freqs, fpeak_bandwidths, fpeak_bandwidth_bounds, needmoreout)
%% Configure outputs
tpeak_proms = proms;
if size(x_w,1)<size(x_w,2)
    x_w = x_w';
end
tpeak_times = x_w;
tpeak_durations = w(:); % transpose to be a column vector
tpeak_center_times = locs;
if size(tpeak_center_times,1)<size(tpeak_center_times,2)
    tpeak_center_times = tpeak_center_times';
end

% Compute frequency related output variables
[~, tinds] = ismember(locs, stimes);
tpeak_bandwidths = fpeak_bandwidths(tinds);
tpeak_bandwidth_bounds =  fpeak_bandwidth_bounds(tinds,:);
tpeak_central_frequencies = fpeak_freqs(tinds);

if needmoreout
    %Compute the standard deviations over the course of the peaks as a metric
    %of variability
    tpeak_sd_central_frequencies = zeros(length(locs),1);
    tpeak_sd_bandwidths = zeros(length(locs),1);
    for ii = 1:length(locs)
        % this step is slow since x_w don't fall on stimes samples
        curr_tinds = stimes>=x_w(ii,1) & stimes<=x_w(ii,2);
        tpeak_sd_central_frequencies(ii) = nanstd(fpeak_freqs(curr_tinds));
        tpeak_sd_bandwidths(ii) = nanstd(fpeak_bandwidths(curr_tinds));
    end
    % calculate the intervals between detected peaks from end-time to start-time
    tpeak_interpeak_intervals = tpeak_times(2:end,1)-tpeak_times(1:end-1,2);
else
    tpeak_sd_central_frequencies = [];
    tpeak_sd_bandwidths = [];
    tpeak_interpeak_intervals = [];
end

end