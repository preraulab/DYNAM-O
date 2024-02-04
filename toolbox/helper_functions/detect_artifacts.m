function [ artifacts ] = detect_artifacts(data, Fs, varargin)
%DETECT_ARTIFACTS  Detect artifacts in the time domain by iteratively removing data above a given z-score criterion
%
%   Usage:
%   Direct input:
%   artifacts = detect_artifacts(data, Fs, crit_units, hf_crit, hf_pass, bb_crit, bb_pass, smooth_duration, ...
%                                            verbose, histogram_plot, return_filts_only, hpFilt_high, hpFilt_broad, detrend_duration)
%
%   Input:
%   data: 1 x <number of samples> vector - time series data-- required
%   Fs: double - sampling frequency in Hz  -- required
%   isexcluded: logical array - boolean for time points to be excluded when updating thresholds (default: all false)
%   crit_units: string 'std' to use iterative crit_units (default) or a strict threshold on 'MAD',defined as K*MEDIAN(ABS(A-MEDIAN(A)))
%   hf_crit: double - high frequency criterion - number of stds/MAD above the mean to remove (default: 3.5)
%   hf_pass: double - high frequency pass band - frequency for high pass filter in Hz (default: 35 Hz)
%   bb_crit: double - broadband criterion - number of stds/MAD above the mean to remove (default: 3.5)
%   bb_pass: double - broadband pass band - frequency for high pass filter in Hz (default: .1 Hz)
%   smooth_duration: double - time (in seconds) to smooth the time series (default: 2 seconds)
%   detrend_duration: double - time (in seconds) to use for detrending (default: 300 seconds)
%   buffer_duration: double - time (in seconds) to mask on both sides of detected artifacts (default: 0 second)
%   verbose: logical - verbose output (default: false)
%   histogram_plot: logical - plot histograms for debugging (default: false)
%   return_filts_only: logical - return 3 digitalFilter objects and nothing else [1x3] (order is hpFilt_high, hpFilt_broad, detrend_filt)
%                                for use in this function (default: false)
%   hpFilt_high: digitalFilter - Includes parameters to use for the high frequency high pass filte
%   hpFilt_broad: digitalFilter - Includes parameters to use for the broadband high pass filter
%
%   Output:
%   artifacts: 1xT logical of times flagged as artifacts (logical OR of hf and bb artifacts)
%
%   Copyright 2024 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%% ********************************************************************

%% Input parsing
%Force column vector for uniformity
if ~iscolumn(data)
    data=data(:);
end

%Force to double
if ~isa(data, 'double')
    data = double(data);
end

p = inputParser;

addOptional(p, 'isexcluded', [], @(x) validateattributes(x, {'logical', 'vector'},{}));
addOptional(p, 'crit_units', 'std', @(x) validateattributes(x, {'char'},{}));
addOptional(p, 'hf_crit', 4.5, @(x) validateattributes(x,{'numeric'},{'real', 'finite', 'nonnan'}));
addOptional(p, 'hf_pass', 35, @(x) validateattributes(x,{'numeric'},{'real', 'finite', 'nonnan'}));
addOptional(p, 'bb_crit', 4.5, @(x) validateattributes(x,{'numeric'},{'real', 'finite', 'nonnan'}));
addOptional(p, 'bb_pass', .1, @(x) validateattributes(x,{'numeric'},{'real', 'finite', 'nonnan'}));

addOptional(p, 'smooth_duration', 2, @(x) validateattributes(x,{'numeric'},{'real', 'finite', 'nonnan'}));
addOptional(p, 'detrend_duration', 5*60, @(x) validateattributes(x,{'numeric'},{'real', 'finite', 'nonnan'}));
addOptional(p, 'buffer_duration', 0, @(x) validateattributes(x,{'numeric'},{'real', 'finite', 'nonnan'}));

addOptional(p, 'verbose', false, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
addOptional(p, 'histogram_plot', false, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
addOptional(p, 'return_filts_only', false, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));

addOptional(p, 'hpFilt_high', []);
addOptional(p, 'hpFilt_broad', []);

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

% Verify that the isexcluded boolean is valid
if isempty(isexcluded)
    isexcluded = false(size(data));
else
    if ~iscolumn(isexcluded)
        isexcluded=isexcluded(:);
    end
    assert(length(isexcluded) == length(data),'isexcluded must be the same length as data');
end

% Create filters if none are provided
if isempty(hpFilt_high) %#ok<*NODEF>
    hpFilt_high = designfilt('highpassiir','FilterOrder',4, ...
        'PassbandFrequency',hf_pass,'PassbandRipple',0.2, ...
        'SampleRate',Fs);
end

if isempty(hpFilt_broad)
    hpFilt_broad = designfilt('highpassiir','FilterOrder',4, ...
        'PassbandFrequency',bb_pass,'PassbandRipple',0.2, ...
        'SampleRate',Fs);
end

% If desired, return filter parameters only
if return_filts_only
    artifacts = [hpFilt_high, hpFilt_broad];
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
[~, ~, ~, is_flat] = get_chunks(data,100);
bad_inds = isnan(data) | isinf(data) | is_flat;
bad_inds = find_outlier_noise(data, bad_inds);

%Interpolate big gaps in data
t = 1:length(data);
data_fixed = interp1([0, t(~bad_inds), length(data)+1], [0; data(~bad_inds); 0], t)';

%% Get high frequency artifacts
hf_artifacts = compute_artifacts(hpFilt_high, detrend_duration, hf_crit, data_fixed, smooth_duration, Fs, bad_inds, verbose,...
    'high frequency', histogram_plot, crit_units, isexcluded);

%% Get broad band frequency artifacts
bb_artifacts = compute_artifacts(hpFilt_broad, detrend_duration, bb_crit, data_fixed, smooth_duration, Fs, bad_inds, verbose,...
    'broadband frequency', histogram_plot, crit_units, isexcluded);

%% Join artifacts from different frequency bands
artifacts = hf_artifacts | bb_artifacts;

%% Add buffer on both sides of detected artifacts 
if buffer_duration > 0
    [cons, inds] = consecutive_runs(artifacts);
    for ii = 1:length(cons)
        buffer_start_idx = ceil(max(1, inds{ii}(1)-buffer_duration*Fs));
        buffer_end_idx = ceil(min(length(artifacts), inds{ii}(end)+buffer_duration*Fs));
        artifacts(buffer_start_idx:buffer_end_idx) = true;
    end
end

%% Sanity check before outputting
assert(length(artifacts) == length(data), 'Data vector length is inconsistent. Please check.')

%Find all time points that have outlier high or low noise
function bad_inds = find_outlier_noise(data, bad_inds)
data_mean = mean(data(~bad_inds));
data_std = std(data(~bad_inds));

outlier_scalar = 10;
low_thresh = data_mean - outlier_scalar * data_std;
high_thresh = data_mean + outlier_scalar * data_std;

inds = data <= low_thresh | data >= high_thresh;
bad_inds(inds) = true;


function [ detected_artifacts, y_detrend ] = compute_artifacts(filter_coeff, detrend_duration, crit, data_fixed, smooth_duration, Fs, bad_inds, verbose, verbosestring, histogram_plot, crit_units, isexcluded)
%% Get artifacts for a particular frequency band

%Perform a high pass filter
filt_data = filter(filter_coeff, data_fixed);

%Look at the data envelope
y_hilbert = abs(hilbert(filt_data));

%Smooth data
y_smooth = movmean(y_hilbert, smooth_duration*Fs);

% We should smooth then take log
y_log = log(y_smooth);

% Detrend data
y_detrend = y_log - movmedian(y_log, Fs*detrend_duration);
% y_detrend = spline_detrend(y_log, Fs, [], 60);
% y_detrend = filter(detrend_filt, y_log);
y_signal = y_detrend;

% create an indexing array marking bad timepoints before z-scoring
detected_artifacts = bad_inds;

%Take z-score
ysig = y_signal(~detected_artifacts & ~isexcluded);
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
        over_crit = abs(y_signal)>crit & ~detected_artifacts;
        
        %Loop until nothing over criterion
        count = 1;
        while any(over_crit)
            
            %Update the detected artifact time points
            detected_artifacts(over_crit) = true;
            
            %Compute modified z-score
            ysig = y_signal(~detected_artifacts & ~isexcluded);
            ymid = mean(ysig);
            ystd = std(ysig);
            
            y_signal = (y_signal - ymid)/ystd;
            
            %Find new criterion
            over_crit = abs(y_signal)>crit & ~detected_artifacts;
            
            if histogram_plot
                axes(ah); %#ok<*LAXES>
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
        valid_idx = find(~detected_artifacts & ~isexcluded);
        [outlier_idx, L, U] = isoutlier(y_signal(valid_idx),'thresholdfactor',crit);
        outlier_idx = valid_idx(outlier_idx);
        y_signal(outlier_idx) = nan;
        y_signal(y_signal<=L | y_signal>=U) = nan;
        detected_artifacts = isnan(y_signal) | detected_artifacts;
        
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
