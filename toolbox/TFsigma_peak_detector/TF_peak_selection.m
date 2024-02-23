function [ TFpeak_times, noise_peak_times, clustering_idx, clustering_prom_order, lowbw_TFpeaks, clustering_centroids]...
    = TF_peak_selection(candidate_signals, candidate_times, varargin) 
%
% ** DETERMINING TF PEAK TIMES FROM CANDIDATE PEAKS**
%&#x1F536;
%
% function used to calculate which prominence curve peaks are TF peaks. 
% This function uses kmeans to create two separate clusters and then
% extracts TF peak times from one of the clusters that is labelled to be
% TF peaks based on higher peak prominence (in time) values. An optional
% rectification is provided by running a second round of kmeans that tries
% to significantly reduce false positive rates, with the cost of
% sacrificing some "true" TF peaks. 
%
% Usage: [ spindle_times ] = TF_peak_selection(candidate_signals, candidate_times, '<flag#1>',<arg#1>...'<flag#n>',<arg#n>);
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% ##### Declared Inputs: [[[NEEDS UPDATES!!!]]]
%           The following variables can be acquired from the function
%           find_prominence_peaks.m:
%
%           - can_signals:      This is the input signal(s) of candidate
%                               spindle peaks from which spindles are
%                               detected. It can either be a vector of peak
%                               prominence values with the same length as
%                               number of candidate spindles, or a matrix
%                               with dimensions [#row = number of candidate
%                               spindles] and [#column = different features
%                               about each candidate spindle]. 
%
%           - can_times:        A matrix with two columns, specifying the
%                               start and end times of candidate spindle
%                               times. Output detected spindle times are
%                               subsets from this input can_times, so it 
%                               should have the same length as the number
%                               of candidate spindles. 
%
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% ##### Optional Inputs:
%
%           - 'detection_method':   Method used to detect sleep spindles,
%                                   can be either 'kmeans' or 'threshold'. 
%                                   default: 'kmeans'
%
%           - 'prominence_column':  A column number specifying which column
%                                   of can_signals is prominence value.
%                                   This is used to disambiguate which
%                                   group clustered by kmeans is spindles.
%                                   This column should normally be in
%                                   logarithmic scale already. If not, log
%                                   it before constructing can_signals.
%                                   default: 1
%
%           - 'bandwidth_column':   A column number for the bandwidth. Will
%                                   perform an arbitrary cutoff below half
%                                   of specified spectral resolution to be
%                                   non-spindles.
%                                   default: []
%
%           - 'spectral_resol':     A value specifying spectral resolution,
%                                   will be used to mark non-spindles if
%                                   bandwidth_column is non-empty.
%                                   Everything with bandwidth below half of
%                                   this value will be non-spindles.
%                                   default: 4
%
%           - 'kmeans_column':      A parameter specifying the columns of
%                                   can_signals to use in the kmeans
%                                   algorithm. If this value is Inf and
%                                   method is 'kmeans', then all columns
%                                   are used. 
%                                   default: Inf
%
%           - 'kmeans_class':       A parameter specifying the number of
%                                   classes to detect in the kmeans
%                                   algorithm.
%                                   default: 2
%
%           - 'threshold_percentile':  A parameter specifying percentile
%                                   threshold used for cut-off detection of
%                                   spindles from candidate spindles (range
%                                   0-1). 
%                                   default: 0.75
%
%           - 'verbose':            Whether to print some verbose messages.
%                                   default: true
%
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% ##### Outputs:
%
%           - spindle_times:        A two column vector containing
%                                   [spindle_start, spindle_end] times in
%                                   seconds.
%
%           - non_spindle_times:    A two column vector containing
%                                   [nonspindle_start, nonspindle_end]
%                                   times in seconds.
%
%           - spindle_index:        A logical index that is the same length
%                                   as the number of candidate spindles
%                                   (i.e., length of can_signals and
%                                   can_times). 1 for detected spindles, 0
%                                   for detected non-spindles. 
%
%           - group_idx:            A double array specifying the group
%                                   assignment of all candidate spindles by
%                                   kmeans, will be redundant with
%                                   spindle_index if 'threshold' is the
%                                   method. 
%
%           - spindle_group:        An integer specifying which integer in
%                                   the group_idx array is spindle. Will be
%                                   1 if 'threshold' is the method.
%
%           - group_order:          An array encoding the group order from
%                                   higher peak prominence values to lower.
%           
%           - clustering_centroids: KxN matrix where N is number of dims and K is 
%                                   number of clusters.
%
%   TODO: Implement flag to use only particular stages in clustering and
%   apply those clusters to TFpeaks from all stages detected. Must include staging as input 
%                               
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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

