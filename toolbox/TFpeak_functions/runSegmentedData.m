function stats_table = ...
    runSegmentedData(spect, stimes, sfreqs, baseline, seg_time, downsample_spect, features, ...
    dur_min, bw_min, conn_wshed, merge_thresh, max_merges, trim_vol, trim_shift, conn_trim, ...
    bl_thresh_flag, CI_upper_bl, merge_rule, f_verb, verb_pref, f_disp)
%RUNSEGMENTEDDATA wrapper that runs 1) baseline subtraction, 2) spectrogram
%segmentation, 3) TFpeak extraction (watershed, merging, trimming, stats), 4)TFpeak statistics packaging and saving
%
%   Usage:
%       [matr_names, matr_fields, peaks_matr, PixelIdxList, PixelList, PixelValues, rgn, bndry, valid_peak_mask] = ...
%       runSegmentedData(spect, stimes, sfreqs, baseline, seg_time, downsample_spect, ...
%       dur_min, bw_min, conn_wshed, merge_thresh, max_merges, trim_vol, trim_shift, conn_trim, ...
%       conn_stats, bl_thresh_flag, CI_upper_bl, merge_rule, f_verb, verb_pref, f_disp)
%
% INPUTS:
%   spect        --  2D image data used to extract TFpeaks [freq, time] --required
%   stimes       --  1D timestamps corresponding to the 2nd dim of spect (seconds) --required
%   sfreqs       --  1D frequencies corresponding to the 1st dim of spect (Hertz) --required
%   baseline     --  1D baseline spectrum used to normalize the spectrogram. default []
%   seg_time     --  length of each segment of spectrogram to process
%                    at a time (in seconds). Default = 30. Note that a 60s segment time is
%                    used in the paper accompanying this code, but using 30s offers large
%                    speedup and should not greatly affect results
%   downsample_spect   --  2x1 double indicating number of rows and columns to downsize spect to.
%   features     -- cell array of features to include, can be any subset of
%                   {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height', 'HeightData', 
%                    'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume'} or 'all'. default 'all'
%   dur_min      -- minimum duration allowed
%   bw_min       -- minimum bandwidth allowed
%   conn_wshed   -- pixel connection to be used by peaksWShed. default 8.
%   merge_thresh -- threshold weight value for when to stop merge rule. default 8.
%   max_merges   -- maximum number of merges to perform. default inf.
%   trim_vol     -- fraction maximum trimmed volume (from 0 to 1),
%                   i.e. 1 means no trim. default 0.8.
%   trim_shift   -- value to be subtracted from image prior to evaulation of trim volume.
%                   default min(min(img_data)).
%   conn_trim    -- pixel connection to be used by trimRegionsWShed. default 8.
%   bl_thresh_flag  -- flag indicating use of baseline thresholding to reduce volume of data
%                   being run through watershed and merging. Default = []
%   CI_upper_bl  -- upper confidence interval of the baseline, used to
%                   compute the threshold used in bl_thresh. Default = []
%   merge_rule   -- rule used to merge segments into complete TFpeaks. Default = 'absolute'
%   f_verb       -- number indicating depth of output text statements of progress.
%                   0 - no output.
%                   1 - output current function level.
%                   2 - output at wrapper level. indicates chunk progress.
%                   3 - output at sequence level within each chunk.
%                   4 - output within sequence functions.
%                   5 - output internal progress of merge and trim functions.
%                   defaults to 0. >2 is not recommended unless data is single chunk.
%   verb_pref    -- prefix string for verbose output. defaults to ''.
%   f_disp       -- flag indicator of whether to plot.
%                   defaults to false, unless using default data.
%
% OUTPUTS:
%   stats_table     -- table of peak statistics
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

%*************************
% Handle variable inputs *
%*************************
assert(nargin >= 3 || isempty(spect), '3 input required: spect, stimes, sfreqs');

if nargin < 4 || isempty(baseline)
    baseline = [];
end

if nargin < 5 || isempty(seg_time)
    seg_time = 30; % seconds
end

if nargin < 6 || isempty(downsample_spect)
    downsample_spect = [];
end

if nargin < 7 || isempty(features)
    features = 'all';
end

if nargin < 8 || isempty(dur_min)
    dur_min = 0;
end

if nargin < 9 || isempty(bw_min)
    bw_min = 0;
end

if nargin < 10 || isempty(conn_wshed)
    conn_wshed = 8;
end

if nargin < 11 || isempty(merge_thresh)
    merge_thresh = 8;
end

if nargin < 12 || isempty(max_merges)
    max_merges = inf;
end

if nargin < 13 || isempty(trim_vol)
    trim_vol = 0.8;
end

if nargin < 14 || isempty(trim_shift)
    trim_shift = [];
end

if nargin < 15 || isempty(conn_trim)
    conn_trim = 8;
end

if nargin < 16 || isempty(bl_thresh_flag)
    bl_thresh_flag = false;
end

if nargin < 17 || isempty(CI_upper_bl)
    CI_upper_bl = [];
end

if nargin < 18 || isempty(merge_rule)
    merge_rule = 'default';
end

if nargin < 19 || isempty(f_verb)
    f_verb = 1;
end

if nargin < 20 || isempty(verb_pref)
    verb_pref = '';
end

if nargin < 21 || isempty(f_disp)
    f_disp = 0;
end

%******************
% Remove baseline *
%******************
if ~isempty(baseline)
    [spect, bl_threshold] = removeBaseline(spect, baseline, bl_thresh_flag, CI_upper_bl, f_verb);
else
    bl_threshold = [];
end

% Set default trim_shift
if isempty(trim_shift)
    trim_shift = min(spect(:));
end

%% Segment spectrogram data
[data_segs, x_segs] = segmentData(spect, stimes, sfreqs, seg_time, f_verb, verb_pref);

%% Extract TFpeaks from spectrogram segments
% Initialize storage for parallel processing of image segs
n_segs = length(data_segs);
stats_tables = cell(n_segs,1);

% In parallel, find TFpeaks for each seg
computetime = tic;

% Check for parallel processing toolbox and set up loading bar
v = ver;
haspar = any(strcmp({v.Name}, 'Parallel Computing Toolbox'));
if haspar
    D = parallel.pool.DataQueue;
    h = waitbar(0, 'Processing Segments...');
    afterEach(D, @nUpdateWaitbar);
else
    h = waitbar(0, 'Processing Segments...');
end
segments_processed = 1;

if f_verb > 0
    disp([verb_pref 'Processing segments...']);
end

%MAIN LOOP ACROSS SEGMENTS
parfor ii = 1:n_segs
    % Check for valid segments
    if all(~data_segs{ii}(:)) || all(isnan(data_segs{ii}(:))) || length(x_segs{ii}) <= 1
        stats_tables{ii} = table;
        continue
    end
    
    stats_tables{ii} = extractTFPeaks(data_segs{ii},x_segs{ii},sfreqs,features,ii,conn_wshed,merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,bl_threshold,merge_rule,f_verb-1,['  ' verb_pref],f_disp);
    
    % Update loading bar
    if haspar
        send(D, ii);
    else
        h = waitbar(ii/n_segs, [num2str(ii) ' out of ' num2str(n_segs) ' (' num2str((ii/n_segs*100),'%.2f') '%) segments processed...']);
    end
end
delete(h); % delete loading bar

%Add a parallel friendly waitbar
    function nUpdateWaitbar(~)
        waitbar(segments_processed/n_segs, h, [num2str(segments_processed) ' out of ' num2str(n_segs) ' (' num2str((segments_processed/n_segs*100),'%.2f') '%) segments processed...']);
        segments_processed = segments_processed + 1;
    end

if f_verb > 1
    disp([verb_pref '  Computing took ' num2str(toc(computetime)/60) ' minutes.']);
end

%% Assembles peaks stats for all segs into single table and sorts by peak time
stats_table = cat(1,stats_tables{:});
peaktimes_ind = find(strcmpi(stats_table.Properties.VariableNames, 'PeakTime'));
stats_table = sortrows(stats_table, peaktimes_ind,'ascend');
 
end
