function [artifacts] = detect_artifacts(data, Fs, crit_units, hf_crit, hf_pass, bb_crit, bb_pass, smooth_duration, ...
    verbose, histogram_plot, return_filts_only, hpFilt_high, hpFilt_broad, detrend_filt)
%DETECT_ARTIFACTS  Detect artifacts in the time domain by iteratively removing data above a given z-score criterion
%
%   Usage:
%   Direct input:
%   artifacts = detect_artifacts(data, Fs, crit_units, hf_crit, hf_pass, bb_crit, bb_pass, smooth_duration, ...
%                                            verbose, histogram_plot, return_filts_only, hpFilt_high, hpFilt_broad, detrend_filt)
%
%   Input:
%   data: 1 x <number of samples> vector - time series data-- required
%   Fs: double - sampling frequency in Hz  -- required
%   crit_units: string 'std' to use iterative crit_units (default) or a strict threshold on 'MAD',defined as K*MEDIAN(ABS(A-MEDIAN(A)))
%   hf_crit: double - high frequency criterion - number of stds/MAD above the mean to remove (default: 3.5)
%   hf_pass: double - high frequency pass band - frequency for high pass filter in Hz (default: 25 Hz)
%   bb_crit: double - broadband criterion - number of stds/MAD above the mean to remove (default: 3.5)
%   bb_pass: double - broadband pass band - frequency for high pass filter in Hz (default: .1 Hz)
%   smooth_duration: double - time (in seconds) to smooth the time series (default: 2 seconds)
%   verbose: logical - verbose output (default: false)
%   histogram_plot: logical - plot histograms for debugging (default: false)
%   return_filts_only: logical - return 3 digitalFilter objects and nothing else [1x3] (order is hpFilt_high, hpFilt_broad, detrend_filt)
%                                for use in this function (default: false)
%   hpFilt_high: digitalFilter - Includes parameters to use for the high frequency high pass filter
%   hpFilt_broad: digitalFilter - Includes parameters to use for the broadband high pass filter
%   detrend_filter: digitalFilter - Includes parameters to use for the detrending high pass filter
%
%   Output:
%   artifacts: 1xT logical of times flagged as artifacts (logical OR of hf and bb artifacts)
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Last modified 09/21/2022 by Alex
%% ********************************************************************

%% Input parsing
%Force column vector for uniformity
if ~iscolumn(data)
    data=data(:);
end

%Force to double
if ~isa(data,'double')
    data = double(data);
end

if nargin<2
    error('Data vector and sampling rate required');
end

if nargin < 3 || isempty(crit_units)
    crit_units = 'std';
end

if nargin < 4 || isempty(hf_crit)
    hf_crit = 4.5;
end

if nargin < 5 || isempty(hf_pass)
    hf_pass = 35;
end

if nargin < 6 || isempty(bb_crit)
    bb_crit = 4.5;
end

if nargin < 7 || isempty(bb_pass)
    bb_pass = .1;
end

if nargin < 8 || isempty(smooth_duration)
    smooth_duration = 2;
end

if nargin < 9 || isempty(verbose)
    verbose = false;
end

if nargin < 10 || isempty(histogram_plot)
    histogram_plot = false;
end

if nargin < 11 || isempty(return_filts_only)
    return_filts_only = false;
end

%% Create filters if none are provided
if nargin < 12 || isempty(hpFilt_high)
    hpFilt_high = designfilt('highpassiir','FilterOrder',4, ...
        'PassbandFrequency',hf_pass,'PassbandRipple',0.2, ...
        'SampleRate',Fs);
end

if nargin < 13 || isempty(hpFilt_broad)
    hpFilt_broad = designfilt('highpassiir','FilterOrder',4, ...
        'PassbandFrequency',bb_pass,'PassbandRipple',0.2, ...
        'SampleRate',Fs);
end

if nargin < 14 || isempty(detrend_filt)
    Fstop = 0.001;  % Stopband Frequency
    Fpass = 0.003;  % Passband Frequency
    Astop = 60;     % Stopband Attenuation (dB)
    Apass = 0.2;    % Passband Ripple (dB)

    h = fdesign.highpass('fst,fp,ast,ap', Fstop, Fpass, Astop, Apass, Fs);

    detrend_filt = design(h, 'butter', ...
        'MatchExactly', 'stopband', ...
        'SOSScaleNorm', 'Linf');
end

%% If desired, return filter parameters only
if return_filts_only
    artifacts = [hpFilt_high, hpFilt_broad, detrend_filt];
    return
end

%% Set threshold criterion units
switch lower(crit_units)
    case {'median', 'std'}
        mstring = 'STDs';
    case {'outlier', 'mad'}
        mstring = 'MADs';
    otherwise
        error('Bad crit_units');
end

if verbose
    disp('Performing artifact detection:')
    disp(['     High Frequency Criterion: ' num2str(hf_crit) ' ' mstring ' above the mean']);
    disp(['     High Frequency Passband: ' num2str(hf_pass) ' Hz']);
    disp(['     Broadband Criterion: ' num2str(bb_crit) ' ' mstring ' above the mean']);
    disp(['     Broadband Passband: ' num2str(bb_pass) ' Hz']);
    disp('    ');
end


%% Get bad indicies
%Get bad indices
bad_inds = (isnan(data) | isinf(data) | find_flat(data))';
bad_inds = find_outlier_noise(data, bad_inds);
%bad_inds = bad_inds | data' > 225;

%Interpolate big gaps in data
t = 1:length(data);
data_fixed = interp1([0, t(~bad_inds), length(data)+1], [0; data(~bad_inds); 0], t)';

%% Get high frequency artifacts
[ hf_artifacts, high_detrend ] = compute_artifacts(hpFilt_high, detrend_filt, hf_crit, data_fixed, smooth_duration, Fs, bad_inds, verbose,...
    'high frequency', histogram_plot, crit_units);

%% Get broad band frequency artifacts
[ bb_artifacts, broad_detrend ] = compute_artifacts(hpFilt_broad, detrend_filt, bb_crit, data_fixed, smooth_duration, Fs, bad_inds, verbose,...
    'broadband frequency', histogram_plot, crit_units);

%% Join artifacts from different frequency bands
artifacts = hf_artifacts | bb_artifacts;
% sanity check before outputting
assert(length(artifacts) == length(data), 'Data vector length is inconsistent. Please check.')

%Find all the flat areas in the data
function binds = find_flat(data, min_size)
if nargin<2
    min_size = 100;
end

%Get consecutive values equal values
[clen, cind] = getchunks(data);

%Return indices
if isempty(clen)
    inds = [];
else
    size_inds = clen>=min_size;
    clen = clen(size_inds);
    cind = cind(size_inds);

    flat_inds = cell(1,length(clen));

    for ii = 1:length(clen)
        flat_inds{ii} = cind(ii):(cind(ii)+(clen(ii)-1));
    end

    inds = cat(2,flat_inds{:});
end

binds = false(size(data));
binds(inds) = true;


%Find all time points that have outlier high or low noise
function bad_inds = find_outlier_noise(data, bad_inds)
data_mean = mean(data(~bad_inds));
data_std = std(data(~bad_inds));

outlier_scalar = 10;
low_thresh = data_mean - outlier_scalar * data_std;
high_thresh = data_mean + outlier_scalar * data_std;

inds = data <= low_thresh | data >= high_thresh;
bad_inds(inds) = true;



function [ detected_artifacts, y_detrend ] = compute_artifacts(filter_coeff, detrend_filt, crit, data_fixed, smooth_duration, Fs, bad_inds, verbose, verbosestring, histogram_plot, crit_units)
%% Get artifacts for a particular frequency band

%Perform a high pass filter
filt_data = filter(filter_coeff, data_fixed);

%Look at the data envelope
y_hilbert = abs(hilbert(filt_data));

%Smooth data
y_smooth = movmean(y_hilbert, smooth_duration*Fs);

% We should smooth then take log
y_log = log(y_smooth);

% Detrend data via filter
y_detrend = y_log -movmedian(y_log,Fs*60*5);% spline_detrend(y_log,Fs,[],60);
% y_detrend = filter(detrend_filt, y_log);
y_signal = y_detrend;

% create an indexing array marking bad timepoints before z-scoring
detected_artifacts = bad_inds;

%Take z-score
ysig = y_signal(~detected_artifacts);
ymid = mean(ysig);
ystd = std(ysig);

y_signal = (y_signal - ymid)/ystd;

if verbose
    num_iters = 1;
    disp(['Running ', verbosestring, ' detection...']);
end

if histogram_plot
    fh = figure;
    set(gca,'nextplot','replacechildren');
    histogram(y_signal,100);
    title(['Iteration: ' num2str(num_iters)]);
    drawnow;
    ah = gca;
end

switch lower(crit_units)
    case {'median', 'std'}
        %Keep removing until all values under criterion
        over_crit = abs(y_signal)>crit & ~detected_artifacts';

        %Loop until nothing over criterion
        count = 1;
        while any(over_crit)

            %Update the detected artifact time points
            detected_artifacts(over_crit) = true;

            %Compute modified z-score
            ysig = y_signal(~detected_artifacts);
            ymid = mean(ysig);
            ystd = std(ysig);

            y_signal = (y_signal - ymid)/ystd;

            %Find new criterion
            over_crit = abs(y_signal)>crit & ~detected_artifacts';

            if histogram_plot
                axes(ah);
                histogram(y_signal(~detected_artifacts), 100);
                title(['Outliers Removed: iteration ', num2str(count)]);
                drawnow;
                pause(0.1);
            end
            count = count + 1;
        end

        if verbose
            disp(['     Ran ' num2str(num_iters) ' iterations']);
        end
    case {'outlier', 'mad'}
        y_signal(isoutlier(y_signal,'thresholdfactor',crit)) = nan;
        detected_artifacts = isnan(y_signal);

        if histogram_plot
            axes(ah);
            histogram(y_signal(~detected_artifacts),100);
            title('Outliers Removed');
            drawnow;
            pause(0.1);
        end

    otherwise
        error('Invalid crit_units');
end

if histogram_plot
    close(fh);
end


