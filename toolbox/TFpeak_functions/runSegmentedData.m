function [stats_table, regions, borders] = runSegmentedData(spect, stimes, sfreqs, varargin)

%RUNSEGMENTEDDATA  Segment, extract, and compile time-frequency peaks from a spectrogram
%
%   Usage:
%       [stats_table, regions, borders] = runSegmentedData(spect, stimes, sfreqs, baseline, seg_time, downsample_spect, features, ...
%           dur_min, bw_min, merge_thresh, max_merges, trim_vol, f_verb, debug_mode)
%
%   Required Inputs:
%       spect: 2D double array - Spectrogram data [freqs x time] -- required
%       stimes: vector - Time stamps for each column of spect (in seconds) -- required
%       sfreqs: vector - Frequencies for each row of spect (in Hz) -- required
%
%   Optional Inputs (in order — must be passed positionally):
%       baseline: vector - 1D baseline spectrum for normalization (default: [])
%       seg_time: scalar - Segment length in seconds (default: 30)
%       downsample_spect: 2x1 vector - [time_bins, freq_bins] to downsample spectrogram (default: [])
%       features: cell array or 'all' - Features to extract (default: 'all')
%       dur_min: scalar - Minimum peak duration allowed (default: 0)
%       bw_min: scalar - Minimum peak bandwidth allowed (default: 0)
%       merge_thresh: scalar - Merge threshold for peak merging (default: 8)
%       max_merges: scalar - Maximum number of merges (default: inf)
%       trim_vol: scalar - Fraction of max volume to keep during trimming (default: 0.8)
%       f_verb: scalar - Verbosity level, from 0 (silent) to 5 (debug) (default: 1)
%       debug_mode: logical - Set to true for single-threaded debug mode (default: false)
%
%   Outputs:
%       stats_table: table - Peak statistics for all segments, sorted by peak time
%       regions: cell array - Linear indices of TFpeak regions across full spectrogram
%       borders: cell array - Linear indices of TFpeak borders across full spectrogram
%
%   Example:
%       stats = runSegmentedData(spect, stimes, sfreqs);
%
%   Notes:
%       All optional inputs must be passed in exact order when using this version with addOptional.
%
%   Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Please cite:
%       Stokes et al., Sleep, 2022, zsac223. https://doi.org/10.1093/sleep/zsac223
% **********************************************************************

% --------------------
% Input validation
% --------------------
p = inputParser;
p.FunctionName = 'runSegmentedData';

% Required
validateSpect = @(x) isnumeric(x) && ismatrix(x);
validateVec = @(x) isnumeric(x) && isvector(x);

addRequired(p, 'spect', validateSpect);
addRequired(p, 'stimes', validateVec);
addRequired(p, 'sfreqs', validateVec);

% Optional positional arguments
addOptional(p, 'baseline', [], validateVec);
addOptional(p, 'seg_time', 30, @(x) isnumeric(x) && isscalar(x));
addOptional(p, 'downsample_spect', [], @(x) isempty(x) || (isnumeric(x) && numel(x)==2));
addOptional(p, 'features', 'all', @(x) iscell(x) || ischar(x));
addOptional(p, 'dur_min', 0, @(x) isnumeric(x) && isscalar(x));
addOptional(p, 'bw_min', 0, @(x) isnumeric(x) && isscalar(x));
addOptional(p, 'merge_thresh', 8, @(x) isnumeric(x) && isscalar(x));
addOptional(p, 'max_merges', inf, @(x) isnumeric(x) && isscalar(x));
addOptional(p, 'trim_vol', 0.8, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1);
addOptional(p, 'f_verb', 1, @(x) isnumeric(x) && isscalar(x));
addOptional(p, 'debug_mode', false, @islogical);

parse(p, spect, stimes, sfreqs, varargin{:});
S = p.Results;

% Assign parser results to local variables for clarity
baseline         = S.baseline;
seg_time         = S.seg_time;
downsample_spect = S.downsample_spect;
features         = S.features;
dur_min          = S.dur_min;
bw_min           = S.bw_min;
merge_thresh     = S.merge_thresh;
max_merges       = S.max_merges;
trim_vol         = S.trim_vol;
f_verb           = S.f_verb;
debug_mode       = S.debug_mode;

if debug_mode
    verb_pref = 'DEBUG: ';
else
    verb_pref = '';
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

%Need to save the nargout outside the parfor
num_out = nargout;

poolobj = gcp("nocreate");
num_workers = poolobj.NumWorkers;

if f_verb > 0
    if num_workers>1 && ~debug_mode
        disp([verb_pref 'Processing segments in parallel on ' num2str(num_workers) ' workers...']);
    else
        disp([verb_pref 'Processing segments in series...']);
    end
end

%MAIN LOOP ACROSS SEGMENTS
if ~debug_mode
    parfor ii = 1:n_segs
        % Check for valid segments
        if all(data_segs{ii}(:) == 0) || all(isnan(data_segs{ii}(:))) || length(x_segs{ii}) <= 1
            stats_tables{ii} = table;
            continue
        end

        %Compute the stats table with optional regions and borders.
        %This construction with multiple function calls for num_out is most
        %efficient for parallel processing
        if num_out == 1
            stats_tables{ii} = extractTFPeaks(data_segs{ii},x_segs{ii},sfreqs,features,ii,conn_wshed,merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,bl_threshold,merge_rule,f_verb-1,['  ' verb_pref]);
        elseif num_out == 2
            [stats_tables{ii}, regions{ii}] = extractTFPeaks(data_segs{ii},x_segs{ii},sfreqs,features,ii,conn_wshed,merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,bl_threshold,merge_rule,f_verb-1,['  ' verb_pref]);
            regions{ii} = cellfun(@(x)x+pixel_shift(ii),regions{ii},'UniformOutput',false);
        elseif num_out == 3
            [stats_tables{ii}, regions{ii}, borders{ii}] = extractTFPeaks(data_segs{ii},x_segs{ii},sfreqs,features,ii,conn_wshed,merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,bl_threshold,merge_rule,f_verb-1,['  ' verb_pref]);
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
else
    for ii = 1:n_segs
        % Check for valid segments
        if all(data_segs{ii}(:) == 0) || all(isnan(data_segs{ii}(:))) || length(x_segs{ii}) <= 1
            stats_tables{ii} = table;
            continue
        end

        %Compute the stats table with optional regions and borders
        [stats_tables{ii}, reg, bord] = extractTFPeaks(data_segs{ii},x_segs{ii},sfreqs,features,ii,conn_wshed,merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,bl_threshold,merge_rule,f_verb-1,['  ' verb_pref]);

        if num_out>1
            regions{ii} = cellfun(@(x)x+pixel_shift(ii),reg,'UniformOutput',false);
        end

        if num_out>2
            borders{ii} = cellfun(@(x)x+pixel_shift(ii),bord,'UniformOutput',false);
        end

        h = waitbar(ii/n_segs, [num2str(ii) ' out of ' num2str(n_segs) ' (' num2str((ii/n_segs*100),'%.2f') '%) segments processed...']);
    end
    delete(h); % delete loading bar
end

%Add a parallel friendly waitbar
    function nUpdateWaitbar(~)
        waitbar(segments_processed/n_segs, h, [num2str(segments_processed) ' out of ' num2str(n_segs) ' (' num2str((segments_processed/n_segs*100),'%.2f') '%) segments processed...']);
        segments_processed = segments_processed + 1;
    end

if f_verb > 0
    disp([verb_pref '  Computing took ' num2str(toc(computetime)/60) ' minutes.']);
end

%% Assemble peaks stats for all segs into a single table and sort by peak time
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
