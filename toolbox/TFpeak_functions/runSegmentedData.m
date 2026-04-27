function [stats_table, regions, borders, labels_img] = runSegmentedData(spect, stimes, sfreqs, varargin)
%RUNSEGMENTEDDATA  Segment, extract, and compile time-frequency peaks from a spectrogram
%
%   Usage:
%       [stats_table, regions, borders] = runSegmentedData(spect, stimes, sfreqs, baseline, seg_time, downsample_spect, features, ...
%           dur_min, bw_min, merge_thresh, max_merges, trim_vol, f_verb, show_pbar, debug_mode, ...
%           'backend', 'rust' | 'matlab')
%       [stats_table, regions, borders, labels_img] = runSegmentedData(...)   % 4th output only populated by Rust backend
%
%   Required Inputs:
%       spect: 2D double array - Spectrogram data [freqs x time]
%       stimes: vector - Time stamps for each column of spect (seconds)
%       sfreqs: vector - Frequencies for each row of spect (Hz)
%
%   Optional Inputs (positional, in order):
%       baseline: vector - 1D baseline spectrum for normalization (default: [])
%       seg_time: scalar - Segment length in seconds (default: 30)
%       downsample_spect: [2x1] - [time_bins, freq_bins] pre-watershed decimation (default: [])
%       features: cell/char - Features to extract (default: 'all')
%       dur_min: scalar - Minimum peak duration allowed (default: 0)
%       bw_min: scalar - Minimum peak bandwidth allowed (default: 0)
%       merge_thresh: scalar - Merge threshold (default: 8)
%       max_merges: scalar - Maximum number of merges (default: inf)
%       trim_vol: scalar - Fraction of max volume to keep during trimming (default: 0.8)
%       f_verb: scalar - Verbosity 0..5 (default: 1)
%       show_pbar: logical - Controls the Rust-backend MEX inline
%                  progress ticks (default: true). IGNORED on the MATLAB
%                  backend path — that path never shows a waitbar (to
%                  dodge MATLAB R2025b's CEF fontations SIGSEGV on
%                  macOS 26+) and always prints 10% console ticks
%                  regardless of this setting.
%       debug_mode: logical - Serial for-loop instead of parfor (default: false)
%
%   Optional Inputs (name-value):
%       backend: 'rust' (default) or 'matlab'. 'rust' delegates the full
%                segment/watershed/merge/trim/regionprops pipeline to the
%                extract_tfpeaks_mex MEX (dynamo_rs); internally parallelised
%                via rayon, no MATLAB parpool used. 'matlab' runs the parfor
%                + extractTFPeaks path below.
%
%   Outputs:
%       stats_table: table - Peak statistics for all segments, sorted by peak time
%       regions: cell array - Linear indices of TFpeak regions (MATLAB path only)
%       borders: cell array - Linear indices of TFpeak borders (MATLAB path only)
%       labels_img: [F x T] int64 label image — only populated by the Rust
%                   backend (regions/borders return empty in that case).
%                   Used by the pass-2 mask step in computeTFPeaks.
%
%   Example:
%       stats = runSegmentedData(spect, stimes, sfreqs);                     % default (Rust)
%       stats = runSegmentedData(..., 'backend', 'matlab');                  % force MATLAB
%
%   Notes:
%       All POSITIONAL optional inputs must be passed in order. `backend`
%       is a name-value pair and can appear anywhere in varargin.
%
%   See Also: extractTFPeaks, segmentData, computeTFPeaks
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
addOptional(p, 'show_pbar', true, @islogical);
addOptional(p, 'debug_mode', false, @islogical);
% Pipeline backend: 'rust' routes to extract_tfpeaks_mex (dynamo_rs),
% 'matlab' routes to the parfor + extractTFPeaks path below.
addOptional(p, 'backend', 'rust', @(x) any(validatestring(lower(char(x)), {'matlab','rust'})));

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
show_pbar        = S.show_pbar;
debug_mode       = S.debug_mode;
backend          = lower(char(S.backend));

if debug_mode
    verb_pref = 'DEBUG: ';
else
    verb_pref = '';
end

%% === Rust MEX fast path ================================================
%   When backend='rust', delegate the entire
%   segment/watershed/merge/trim/regionprops pipeline to dynamo_rs via
%   extract_tfpeaks_mex. The Rust kernel parallelises internally (rayon),
%   so no MATLAB parpool is used in this path.
%
%   Peak count parity vs MATLAB on night: ~-0.8% (34514 vs 34788). Source
%   of the remaining gap is a label-assignment-order subtlety in Rust
%   merge — border-handling / paint / watershed / trim / stats all pass
%   bisection equivalence tests.
if strcmp(backend, 'rust') && nargout <= 4 && exist('extract_tfpeaks_mex', 'file') == 3 %#ok<STCI>
    % Resolve defaults
    seg_time_x         = seg_time;         if isempty(seg_time_x),         seg_time_x = 30; end
    downsample_spect_x = downsample_spect; if isempty(downsample_spect_x), downsample_spect_x = [1, 1]; end
    baseline_arg       = baseline;         if isempty(baseline_arg),       baseline_arg = zeros(size(spect, 1), 0); end

    % Global min across baseline-divided spectrogram — matches the MATLAB
    % path's `trim_shift = min(spect,[],'all')` (line below). Passed to
    % Rust so both backends apply the same uniform shift per segment.
    % Helper `compute_global_trim_shift` is a local fn at the bottom of
    % this file; it safely masks non-positive / non-finite baseline rows.
    trim_shift = compute_global_trim_shift(spect, baseline);

    mex_params = struct( ...
        'seg_time',     double(seg_time_x), ...
        'downsample_f', uint32(downsample_spect_x(2)), ... % MATLAB [t_stride, f_stride] (extractTFPeaks:207)
        'downsample_t', uint32(downsample_spect_x(1)), ...
        'merge_thresh', double(merge_thresh), ...
        'trim_vol',     double(trim_vol), ...
        'trim_shift',   double(trim_shift), ...   % MATCHES MATLAB global min
        'dur_min',      double(dur_min), ...
        'dur_max',      inf, ...            % outer filterStatsTable will cap
        'bw_min',       double(bw_min), ...
        'bw_max',       inf, ...            % outer filterStatsTable will cap
        'freq_min',     -inf, ...
        'freq_max',      inf, ...
        'ht_db_min',    -inf, ...            % outer filterStatsTable will cap
        'show_pbar',    logical(show_pbar)); % MEX runs extract on a background
    % pthread; main MATLAB thread polls
    % atomic counters and prints "10%
    % 20%..." ticks safely. See
    % extract_tfpeaks_mex.c for details.

    if f_verb > 0 && ~show_pbar
        fprintf('%s  Extracting TF peaks (Rust MEX, rayon-parallel)...\n', verb_pref);
    end
    tmex = tic;
    if nargout >= 2
        [mex_out, labels_img] = extract_tfpeaks_mex( ...
            double(spect), double(stimes(:)'), double(sfreqs(:)), ...
            double(baseline_arg(:)), mex_params);
    else
        mex_out = extract_tfpeaks_mex( ...
            double(spect), double(stimes(:)'), double(sfreqs(:)), ...
            double(baseline_arg(:)), mex_params);
        labels_img = [];
    end

    % Build a MATLAB table with the columns extractTFPeaks would produce,
    % filtered to the `features` requested.
    n = numel(mex_out.PeakTime);
    all_cols = struct( ...
        'PeakTime',      mex_out.PeakTime, ...
        'PeakFrequency', mex_out.PeakFrequency, ...
        'Duration',      mex_out.Duration, ...
        'Bandwidth',     mex_out.Bandwidth, ...
        'Height',        mex_out.Height, ...
        'Volume',        mex_out.Volume, ...
        'SegmentNum',    mex_out.SegmentNum, ...
        'BoundingBox',   mex_out.BoundingBox, ...
        'Area',          mex_out.Area, ...
        'Peakiness',     mex_out.Peakiness);
    % Cell-typed columns assigned post-construction so MATLAB's struct()
    % constructor doesn't unwrap them into a struct array.
    all_cols.Boundaries = mex_out.Boundaries;
    all_cols.HeightData = mex_out.HeightData;
    % features is a cell or 'all'; select subset
    if ischar(features) && strcmpi(features, 'all')
        keep_names = fieldnames(all_cols);
    else
        keep_names = intersect(fieldnames(all_cols), features, 'stable');
    end
    if n == 0
        stats_table = table();
    else
        cell_data = cellfun(@(nm) all_cols.(nm), keep_names, 'UniformOutput', false);
        stats_table = table(cell_data{:}, 'VariableNames', keep_names);
        % Match MATLAB path: sort by PeakTime so downstream consumers
        % (refinePeakFrequency -> hann_event_spectra) get monotonic times.
        if any(strcmp(keep_names, 'PeakTime'))
            stats_table = sortrows(stats_table, 'PeakTime', 'ascend');
        end
    end
    if f_verb > 0
        fprintf('%s  MEX extract took %.3f s, %d peaks\n', verb_pref, toc(tmex), n);
    end

    % MEX callers use the 4th output (`labels_img`, F x T int64) with
    % mask_spectrogram_mex directly — no regions/borders dance. We keep
    % regions/borders outputs for back-compat with MATLAB callers but
    % leave them empty; any caller requesting nargout >= 2 with MEX
    % should also accept the labels_img output and use mask_spectrogram_mex.
    regions = cell(0, 1);
    borders = cell(0, 1);
    % labels_img is already set from extract_tfpeaks_mex above (or [] if
    % only 1 output was requested from MEX).
    if nargout < 4
        labels_img = [];
    end
    return;
end
%% ======================================================================

%******************
% Remove baseline *
%******************
if ~isempty(baseline)
    spect = removeBaseline(spect, baseline, [], [], f_verb);
end

%Variables that should not change unless enabling new functionality
conn_wshed = 8;
conn_trim = 8;
merge_rule = 'absolute';
bl_threshold = '';
trim_shift = min(spect,[],'all'); % approximates a dynamic local baseline correction for each segment

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

% Progress reporting for the MATLAB path:
%   (1) waitbar is DISABLED here regardless of show_pbar. MATLAB R2025b's
%       Chromium Embedded Framework has a recurrent font-rendering SIGSEGV
%       on macOS 26+ (QT GuiThread -> fontations_ffi -> OnTimerTimeout).
%       The waitbar widget is one of the triggers and the extract's long
%       parfor runtime makes the CEF timer tick thousands of times — so
%       skipping the waitbar noticeably reduces crash rate even if it
%       doesn't eliminate it. See benchmarks/README.md for the headless
%       -batch workaround when you need 100% reliability.
%   (2) 10% console ticks ARE printed regardless of show_pbar, via a
%       parallel.pool.DataQueue whose afterEach callback runs on the
%       main MATLAB thread — so fprintf is safe there (unlike in parfor
%       worker bodies where stdout is not coherent).
v = ver;
haspar = any(strcmp({v.Name}, 'Parallel Computing Toolbox'));
pbar_state.done = 0;
pbar_state.total = n_segs;
pbar_state.last_tick = 0;   % last printed 10% bucket (0, 10, 20, ..., 100)
if haspar
    D = parallel.pool.DataQueue;
    afterEach(D, @nPrintConsoleTick);
else
    D = [];
end

% Print the progress-line label
if f_verb > -1
    fprintf('%s  Extracting TF peaks:', verb_pref);
end

%Need to save the nargout outside the parfor.
%extractTFPeaks returns at most 3 outputs (stats, regions, borders). The
%4th optional output of runSegmentedData (labels_img) is only produced by
%the MEX fast path above; for the MATLAB path it is left as [] below.
num_out = min(nargout, 3);

poolobj = gcp("nocreate");
% Defensive: gcp("nocreate") returns [] when no pool exists, and on newer
% MATLAB versions may return a bare parallel.Pool (no NumWorkers). Thread
% pools expose NumThreads instead. Treat all of these gracefully.
if isempty(poolobj)
    num_workers = 0;
elseif isprop(poolobj, 'NumWorkers')
    num_workers = poolobj.NumWorkers;
elseif isprop(poolobj, 'NumThreads')
    num_workers = poolobj.NumThreads;
else
    num_workers = 1;
end

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
            stats_tables{ii} = extractTFPeaks(data_segs{ii},x_segs{ii},sfreqs,features,ii,conn_wshed,merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,bl_threshold,merge_rule,f_verb-1,['  ' verb_pref],[]);
        elseif num_out == 2
            [stats_tables{ii}, regions{ii}] = extractTFPeaks(data_segs{ii},x_segs{ii},sfreqs,features,ii,conn_wshed,merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,bl_threshold,merge_rule,f_verb-1,['  ' verb_pref],[]);
            regions{ii} = cellfun(@(x)x+pixel_shift(ii),regions{ii},'UniformOutput',false);
        elseif num_out == 3
            [stats_tables{ii}, regions{ii}, borders{ii}] = extractTFPeaks(data_segs{ii},x_segs{ii},sfreqs,features,ii,conn_wshed,merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,bl_threshold,merge_rule,f_verb-1,['  ' verb_pref],[]);
            regions{ii} = cellfun(@(x)x+pixel_shift(ii),regions{ii},'UniformOutput',false);
            borders{ii} = cellfun(@(x)x+pixel_shift(ii),borders{ii},'UniformOutput',false);
        end

        % Signal completion to main-thread afterEach listener so it can
        % print a 10% console tick if this segment crossed a bucket.
        if haspar
            send(D, ii);
        end
    end
else
    for ii = 1:n_segs
        % Check for valid segments
        if all(data_segs{ii}(:) == 0) || all(isnan(data_segs{ii}(:))) || length(x_segs{ii}) <= 1
            stats_tables{ii} = table;
            continue
        end

        %Compute the stats table with optional regions and borders
        [stats_tables{ii}, reg, bord] = extractTFPeaks(data_segs{ii},x_segs{ii},sfreqs,features,ii,conn_wshed,merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,bl_threshold,merge_rule,f_verb-1,['  ' verb_pref],[]);

        if num_out>1
            regions{ii} = cellfun(@(x)x+pixel_shift(ii),reg,'UniformOutput',false);
        end

        if num_out>2
            borders{ii} = cellfun(@(x)x+pixel_shift(ii),bord,'UniformOutput',false);
        end

        % Inline 10%-tick printing (serial / debug path).
        if f_verb > -1
            nPrintConsoleTick(ii);
        end
    end
end

% Close the line the console-tick listener/inline-printer was building
% up across the parfor / serial loop.
if f_verb > -1
    fprintf('\n');
end

% Console-tick listener: runs on the main MATLAB thread (afterEach
% marshals from parfor workers) so fprintf is safe here. Accepts the
% segment index from `send(D, ii)` but ignores it — we count
% completions internally and print a bucket only when crossed.
    function nPrintConsoleTick(~)
        pbar_state.done = pbar_state.done + 1;
        pct = floor(100 * pbar_state.done / pbar_state.total);
        bucket = floor(pct / 10) * 10;
        while pbar_state.last_tick < bucket && pbar_state.last_tick < 100
            pbar_state.last_tick = pbar_state.last_tick + 10;
            fprintf(' %d%%', pbar_state.last_tick);
        end
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

% MATLAB path cannot produce labels_img (MEX-only); return empty.
if nargout > 3
    labels_img = [];
end

end


function shift = compute_global_trim_shift(spect, baseline)
% Replicate MATLAB's `trim_shift = min(spect, [], 'all')` on the
% baseline-DIVIDED spectrogram, so the MEX fast path and the MATLAB
% path see the same shift value applied uniformly to every segment.
if ~isempty(baseline)
    bv = double(baseline(:));
    good = bv > 0 & isfinite(bv);
    if any(good)
        s_div = double(spect(good, :)) ./ bv(good);
        shift = min(s_div, [], 'all');
    else
        shift = min(double(spect), [], 'all');
    end
else
    shift = min(double(spect), [], 'all');
end
end
