function [ fpeak_proms, tpeak_proms, tpeak_times, tpeak_durations, tpeak_center_times, tpeak_central_frequencies, tpeak_bandwidths, tpeak_bandwidth_bounds,...
    tpeak_sd_central_frequencies, tpeak_sd_bandwidths, tpeak_interpeak_intervals ]...
    = find_time_peaks(fpeak_proms, fpeak_freqs, fpeak_bandwidths, fpeak_bandwidth_bounds, stimes, varargin)
%FIND_TIME_PEAKS  Detect peaks in the frequency-domain prominence curve in the time domain
%
%   Usage:
%       [fpeak_proms, tpeak_proms, tpeak_times, tpeak_durations, tpeak_center_times,
%        tpeak_central_frequencies, tpeak_bandwidths, tpeak_bandwidth_bounds,
%        tpeak_sd_central_frequencies, tpeak_sd_bandwidths, tpeak_interpeak_intervals] = ...
%           find_time_peaks(fpeak_proms, fpeak_freqs, fpeak_bandwidths, fpeak_bandwidth_bounds, stimes, ...)
%
%   Required Inputs:
%       fpeak_proms:            [Tx1] double - frequency-domain peak prominence at each time point
%                               (output of find_frequency_peaks) -- required
%       fpeak_freqs:            [Tx1] double - frequency of the spectral peak at each time point (Hz)
%                               -- required
%       fpeak_bandwidths:       [Tx1] double - bandwidth of the spectral peak at each time point (Hz)
%                               -- required
%       fpeak_bandwidth_bounds: [Tx2] double - lower/upper frequency bounds of spectral peak -- required
%       stimes:                 [1xT] double - time axis vector in seconds -- required
%
%   Optional Inputs:
%       'smooth_sec':              double - seconds to smooth the prominence curve with movmean
%                                  (default: 0.3)
%       'only_NREM':               logical - detect peaks only during NREM sleep stages
%                                  (default: true)
%       'min_peak_width_sec':      double - minimum peak width (seconds) for findpeaks
%                                  (default: 0.3)
%       'min_peak_distance_sec':   double - minimum peak-to-peak distance (seconds) for findpeaks
%                                  (default: 0)
%       'report_width_scale':      double - scale factor converting half-height width to
%                                  reported start/end times (default: 0.5)
%
%   Outputs:
%       fpeak_proms:                    [Tx1] double - (smoothed) frequency prominence curve
%       tpeak_proms:                    [Px1] double - prominence of each detected time peak
%       tpeak_times:                    [Px2] double - [start, end] times (seconds) of each peak
%       tpeak_durations:                [Px1] double - duration (seconds) of each peak
%       tpeak_center_times:             [Px1] double - center time (seconds) of each peak
%       tpeak_central_frequencies:      [Px1] double - mean spectral peak frequency (Hz) within each peak
%       tpeak_bandwidths:               [Px1] double - mean spectral bandwidth (Hz) within each peak
%       tpeak_bandwidth_bounds:         [Px2] double - mean lower/upper frequency bounds within each peak
%       tpeak_sd_central_frequencies:   [Px1] double - std of spectral peak frequency within each peak
%       tpeak_sd_bandwidths:            [Px1] double - std of spectral bandwidth within each peak
%       tpeak_interpeak_intervals:      [Px1] double - interval (seconds) from end of previous peak
%                                       to start of next peak
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
%   He, M., Prerau, M. J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%    in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%    for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
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