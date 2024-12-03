function [stats_table, regions, borders] = runSegmentedData(spect, stimes, sfreqs, baseline, seg_time, downsample_spect, features, ...
    dur_min, bw_min, merge_thresh, max_merges, trim_vol, f_verb, verb_pref, f_disp)
%RUNSEGMENTEDDATA: wrapper that runs:
%                      1) Baseline subtraction,
%                      2) Spectrogram segmentation,
%                      3) TFpeak extraction (watershed, merging, trimming, stats),
%                      4) TFpeak statistics packaging and saving
%
%   Usage:
%       [stats_table] = runSegmentedData(spect, stimes, sfreqs, baseline, seg_time, downsample_spect, features, ...
%       dur_min, bw_min, merge_thresh, max_merges, trim_vol, f_verb, verb_pref, f_disp)
%
%   Inputs:
%       spect            -- 2D image data used to extract TFpeaks [freq, time] -- required
%       stimes           -- 1D timestamps corresponding to the 2nd dim of spect (seconds) -- required
%       sfreqs           -- 1D frequencies corresponding to the 1st dim of spect (Hertz) -- required
%       baseline         -- 1D baseline spectrum used to normalize the spectrogram. default []
%       seg_time         -- length of each segment of spectrogram to process
%                           at a time (in seconds). Default = 30. Note that a 60s segment time is
%                           used in the paper accompanying this code, but using 30s offers large
%                           speedup and should not greatly affect results
%       downsample_spect -- 2x1 double indicating number of rows and columns to downsize spect to.
%       features         -- cell array of features to include, can be any subset of
%                           {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height', 'HeightData',
%                            'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume'} or 'all'. default 'all'
%       dur_min          -- minimum duration allowed. default 0.
%       bw_min           -- minimum bandwidth allowed. default 0.
%       merge_thresh     -- threshold weight value for when to stop merge rule. default 8.
%       max_merges       -- maximum number of merges to perform. default inf.
%       trim_vol         -- fraction of maximum in trimmed volume (from 0 to 1),
%                           i.e. 1 means no trim. default 0.8.
%       f_verb           -- number indicating depth of output text statements of progress.
%                           0 - no output.
%                           1 - output current function level.
%                           2 - output at wrapper level. indicates chunk progress.
%                           3 - output at sequence level within each chunk.
%                           4 - output within sequence functions.
%                           5 - output internal progress of merge and trim functions.
%                           defaults to 0. >2 is not recommended unless data is single chunk.
%       verb_pref        -- prefix string for verbose output. defaults to ''.
%       f_disp           -- flag indicator of whether to plot.
%                           defaults to false, unless using default data.
%
%   Outputs:
%       stats_table      -- table of peak statistics
%       regions          -- A cell array of linear indices of peak regions in the entire spect.
%       borders          -- A cell array of linear indices of peak borders in the entire spect.
%
% COPYRIGHT 2024 Prerau Lab - http://www.sleepEEG.org
% This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
% (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
% Please provide the following citation for all use:
%   Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%   Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification,
%   Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
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

if nargin < 10 || isempty(merge_thresh)
    merge_thresh = 8;
end

if nargin < 11 || isempty(max_merges)
    max_merges = inf;
end

if nargin < 12 || isempty(trim_vol)
    trim_vol = 0.8;
end

if nargin < 13 || isempty(f_verb)
    f_verb = 1;
end

if nargin < 14 || isempty(verb_pref)
    verb_pref = '';
end

if nargin < 15 || isempty(f_disp)
    f_disp = 0;
end

%******************
% Remove baseline *
%******************
if ~isempty(baseline)
    % Remove baseline. Subtraction in dB equivalent to division in non-dB.
    spect = spect./repmat(baseline,1,size(spect,2));
end

%Variables that should not change unless enabling new functionality
conn_wshed = 8;
conn_trim = 8;
merge_rule = 'absolute';
bl_threshold = '';
trim_shift = min(spect,[],'all');

%% Segment spectrogram data
[data_segs, x_segs, x_inds] = segmentData(spect, stimes, sfreqs, seg_time, f_verb, verb_pref);
%Compute the linear index pixel shift for each segment
pixel_shift = cellfun(@(x)x(1)-1, x_inds) * size(spect,1);

%% Extract TFpeaks from spectrogram segments
% Initialize storage for parallel processing of image segs
n_segs = length(data_segs);
stats_tables = cell(n_segs,1);
regions = cell(n_segs,1);
borders = cell(n_segs,1);

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

%Need to save the nargout outside the parfor
num_out = nargout;

%MAIN LOOP ACROSS SEGMENTS
parfor ii = 1:n_segs
    % Check for valid segments
    if all(data_segs{ii}(:) == 0) || all(isnan(data_segs{ii}(:))) || length(x_segs{ii}) <= 1
        stats_tables{ii} = table;
        continue
    end

    %Compute the stats table with optional regions and borders
    if num_out == 1
        stats_tables{ii} = extractTFPeaks(data_segs{ii},x_segs{ii},sfreqs,features,ii,conn_wshed,merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,bl_threshold,merge_rule,f_verb-1,['  ' verb_pref],f_disp);
    elseif num_out == 2
        [stats_tables{ii}, regions{ii}] = extractTFPeaks(data_segs{ii},x_segs{ii},sfreqs,features,ii,conn_wshed,merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,bl_threshold,merge_rule,f_verb-1,['  ' verb_pref],f_disp);
        regions{ii} = cellfun(@(x)x+pixel_shift(ii),regions{ii},'UniformOutput',false);
    elseif num_out == 3
        [stats_tables{ii}, regions{ii}, borders{ii}] = extractTFPeaks(data_segs{ii},x_segs{ii},sfreqs,features,ii,conn_wshed,merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,bl_threshold,merge_rule,f_verb-1,['  ' verb_pref],f_disp);
        regions{ii} = cellfun(@(x)x+pixel_shift(ii),regions{ii},'UniformOutput',false);
        borders{ii} = cellfun(@(x)x+pixel_shift(ii),borders{ii},'UniformOutput',false);
    end

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

%% Assemble peaks stats for all segs into single table and sorts by peak time
stats_table = cat(1,stats_tables{:});
peaktimes_ind = find(strcmpi(stats_table.Properties.VariableNames, 'PeakTime'));
[stats_table, sort_inds] = sortrows(stats_table, peaktimes_ind, 'ascend');

if nargout>1
    regions = cat(2, regions{:});  % linear indices here have been shifted to the entire spect
    regions = regions(sort_inds);
end

if nargout>2
    borders = cat(2, borders{:});  % linear indices here have been shifted to the entire spect
    borders = borders(sort_inds);
end

end
