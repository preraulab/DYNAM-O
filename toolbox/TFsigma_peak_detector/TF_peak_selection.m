function [ TFpeak_times, noise_peak_times, clustering_idx, clustering_prom_order, lowbw_TFpeaks, clustering_centroids]...
    = TF_peak_selection(candidate_signals, candidate_times, varargin) 
%TF_PEAK_SELECTION  Classify candidate TF peaks as true peaks or noise using clustering or thresholding
%
%   Usage:
%       [TFpeak_times, noise_peak_times, clustering_idx, clustering_prom_order,
%        lowbw_TFpeaks, clustering_centroids] = ...
%           TF_peak_selection(candidate_signals, candidate_times, ...)
%
%   Required Inputs:
%       candidate_signals: [PxN] double - matrix of candidate peak feature values,
%                          one row per candidate peak; N features per peak -- required
%       candidate_times:   [Px2] double - [start_time, end_time] in seconds for each
%                          candidate peak -- required
%
%   Optional Inputs:
%       'detection_method':     char - classification method: 'kmeans' or 'threshold'
%                               (default: 'kmeans')
%       'prominence_column':    double - column index of prominence values in candidate_signals,
%                               used to label kmeans clusters (default: 1)
%       'bandwidth_column':     double - column index of bandwidth values; used to reject
%                               low-bandwidth candidates (default: [])
%       'spectral_resol':       double - spectral resolution (Hz); candidates with bandwidth
%                               below half this value are rejected (default: 4)
%       'kmeans_column':        double or Inf - columns of candidate_signals to use in kmeans;
%                               Inf uses all columns (default: Inf)
%       'kmeans_class':         double - number of kmeans clusters (default: 2)
%       'threshold_percentile': double - percentile cutoff (0-1) for threshold detection
%                               (default: 0.75)
%       'verbose':              logical - print progress messages (default: true)
%
%   Outputs:
%       TFpeak_times:           [Kx2] double - [start, end] times (seconds) of detected TF peaks
%       noise_peak_times:       [Jx2] double - [start, end] times (seconds) of noise peaks
%       clustering_idx:         [Px1] double - cluster assignment for each candidate peak
%       clustering_prom_order:  [1xK] double - cluster indices ordered from high to low prominence
%       lowbw_TFpeaks:          [Px1] logical - true for candidates rejected due to low bandwidth
%       clustering_centroids:   [KxN] double - centroid of each cluster (K clusters, N features)
%
%   Notes:
%       TODO: Implement flag to use only particular stages in clustering and apply
%       those clusters to TF peaks from all stages detected.
%
%   Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%% ********************************************************************
warn_state = warning; 

%%
% Parse inputs and preparation
[ candidate_signals, candidate_times, detection_method, num_clusters, prominence_column, threshold_percentile, lowbw_TFpeaks, verbose ]...
    = TF_peak_cluster_inputparse(candidate_signals, candidate_times, varargin{:});

%% Spindle detection processing
switch detection_method
    case 'kmeans'
        [idx, clustering_centroids] = kmeans(candidate_signals, num_clusters);
        
        % Label the class that has the highest mean prominence as TF peaks
        mean_proms = zeros(1, num_clusters);
        for ii = 1:num_clusters
            mean_proms(ii) = mean(candidate_signals(idx==ii, prominence_column));
        end
        clustering_idx = idx;
        [~, clustering_prom_order] = maxk(mean_proms, num_clusters); % assume TF peaks have the highest prominence values
        
        candidate_spindle_index = idx == clustering_prom_order(1);
        TFpeak_times = candidate_times(candidate_spindle_index,:);
        noise_peak_times = candidate_times(~candidate_spindle_index,:);
        
    case 'threshold'
        threshold = prctile(candidate_signals, threshold_percentile);
        candidate_spindle_index = candidate_signals >= threshold;
        clustering_idx = candidate_spindle_index;
        clustering_prom_order = [1, 0];
        TFpeak_times = candidate_times(candidate_spindle_index,:);
        noise_peak_times = candidate_times(~candidate_spindle_index,:);
        clustering_centroids = [];
end

% sanity check to wrap up
assert(length(TFpeak_times) + length(noise_peak_times) == size(candidate_signals,1), 'Missed labeling of some candidates. Please check.')

% report number of TF peaks and noise peaks
if verbose 
    disp(['Number of noise peaks detected = ', num2str(sum(~candidate_spindle_index))])
    disp(['Number of TF peaks detected = ', num2str(sum(candidate_spindle_index))])
end

% turn warning back to original state
if any(isnan(candidate_signals(:,1)))
    for jj = 1:size(warn_state,1)
        warning(warn_state(jj).state, warn_state(jj).identifier)
    end
end

end

function [ candidate_signals, candidate_times, detection_method, num_clusters, prominence_column, threshold_percentile, lowbw_TFpeaks, verbose ]...
    = TF_peak_cluster_inputparse(candidate_signals, candidate_times, varargin)
%% Configure optional input arguments:
optionalInputs = {'detection_method',...
    'bandwidth_data', 'num_clusters', 'prominence_column', 'spectral_resol',...
     'threshold_percentile', 'verbose'}; % optional
% default values
optionalDefaults = {'kmeans', [], 2, 1, 4, 75, true};

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
detection_method = optionalDefaults{1};
bandwidth_data = optionalDefaults{2};
num_clusters = optionalDefaults{3};
prominence_column = optionalDefaults{4};
spectral_resol = optionalDefaults{5};
threshold_percentile = optionalDefaults{6};
verbose = optionalDefaults{7};

%% Input processing and sanity checks
% make sure can_signals and can_times have the same length
assert(length(candidate_signals) == length(candidate_times), 'Numbers of candidate TF peaks do not match between inputs. Please check.')
% there should be more TF peak candidates than classification variables
if size(candidate_signals,1) < size(candidate_signals,2)
    candidate_signals = candidate_signals';
end
% flip TF peak times if the input is a matrix with two rows
if size(candidate_times,1) < size(candidate_times,2)
    candidate_times = candidate_times';
end

% make sure the specified prominence column exists
assert(prominence_column <= size(candidate_signals,2), 'Prominence column number exceeds the dimension of the signals matrix.')

% if 'threshold' is used, then there must be a sensible threshold_percent
if strcmp(detection_method, 'threshold')
    assert(size(candidate_signals,2)==1, 'threshold method is used, but multiple columns are provided in candidate_signals. Please input only a single vector to perform the percentile thresholding on.')
    assert(threshold_percentile>=0 && threshold_percentile<=100, 'threshold method is used but percentile number provided is invalid. It should be between 0 and 100.')
end

% exclude rows with infinity values
[rows, ~] = find(isinf(candidate_signals));
candidate_signals(rows,:) = nan;
if verbose && ~isempty(rows)
    disp(['Number of noise peaks due to infinity values: ', num2str(length(rows))])
end

% exclude candidates with bandwidth below half of spectral resolution
if ~isempty(bandwidth_data)
    assert(length(bandwidth_data) == length(candidate_signals),'bandwidth data must be the same length as the candidate signals data. Please check inputs');
    bwcut = bandwidth_data < spectral_resol/2;
    lowbw_TFpeaks = candidate_times(bwcut,:);
    candidate_signals(bwcut, :) = nan;
    if verbose; disp(['Number of noise peaks due to bandwidth < 1/2 spectral resolution: ', num2str(sum(bwcut))]); end
else
    lowbw_TFpeaks = nan;
end

% disable missing value warning if anything is nan
if any(isnan(candidate_signals(:,1)))
    warning('off', 'stats:kmeans:MissingDataRemoved')
end

end

