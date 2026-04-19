function [stats_table, regions, borders] = extractTFPeaks(img,x,y,features,num_segment,conn_wshed,...
    merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,...
    bl_thresh,merge_rule,f_verb,verb_pref,f_disp,use_trim_mex)
%EXTRACTTFPEAKS  Determine peak regions within a spectrogram and extract features for each
%
%   Usage:
%       [stats_table, regions, borders] = extractTFPeaks(img, x, y, features, num_segment, conn_wshed, ...
%           merge_thresh, max_merges, downsample_spect, dur_min, bw_min, trim_vol, trim_shift, conn_trim, ...
%           bl_thresh, merge_rule, f_verb, verb_pref, f_disp, use_trim_mex)
%
%   Required Inputs:
%       img:          [M x N] double - 2D image data
%
%   Optional Inputs (positional):
%       x:                [1 x N] double - x axis of image data (default: 1:size(img,2))
%       y:                [1 x M] double - y axis of image data (default: 1:size(img,1))
%       features:         cell or char - any subset of {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox',
%                         'Duration', 'Height', 'HeightData', 'PeakFrequency', 'PeakTime', 'SegmentNum',
%                         'Volume'} or 'all' (default: 'all')
%       num_segment:      integer - segment index if img is a sub-segment of a larger image (default: 1)
%       conn_wshed:       integer - pixel connectivity used in watershed labeling (default: 8)
%       merge_thresh:     double - threshold weight at which merging stops (default: 8)
%       max_merges:       integer - maximum number of merges to perform (default: inf)
%       downsample_spect: [1 x 2] double - [cols, rows] decimation factors for low-res pass (default: [])
%       dur_min:          double - minimum peak duration allowed (default: 0)
%       bw_min:           double - minimum peak bandwidth allowed (default: 0)
%       trim_vol:         double - fraction of max volume to retain after trim, in (0, 1] (default: 0.8)
%       trim_shift:       double - floor value subtracted from img before trim (default: min(img(:)))
%       conn_trim:        integer - pixel connectivity used during trim (default: 8)
%       bl_thresh:        double - optional power cutoff to accelerate computation (default: [])
%       merge_rule:       char - reserved (default: 'default')
%       f_verb:           integer - verbosity depth: 0 silent, up to 3 for full internal progress (default: 0)
%       verb_pref:        char - prefix string for verbose output (default: '')
%       f_disp:           logical/integer - plot progress if nonzero (default: 0)
%       use_trim_mex:     logical - allow trim_region_mex on ProcessPool / serial calls;
%                         false forces the MATLAB trim path (default: true)
%
%   Outputs:
%       stats_table: table - peak statistics, one row per peak
%       regions:     [1 x K] cell - linear indices of peak regions (full image coords)
%       borders:     [1 x K] cell - linear indices of peak borders (full image coords)
%
%   See Also: runWatershed, Ldata2graph, mergeWshedSegment, trimWshedRegions, computePeakStatsTable
%
%
%*************************
% Handle variable inputs *
%*************************
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
if nargin < 1
    img = [];
end
if nargin < 2
    x = [];
end
if nargin < 3
    y = [];
end
if nargin < 4 || isempty(features)
    features = 'all';
end
if nargin < 5
    num_segment = [];
end
if nargin < 6
    conn_wshed = [];
end
if nargin < 7
    merge_thresh = [];
end
if nargin < 8
    max_merges = [];
end
if nargin < 9
    downsample_spect = [];
end
if nargin < 10 || isempty(dur_min)
    %Min TF peak duration
    dur_min = 0;
end
if nargin < 11 || isempty(bw_min)
    %Min TF peak bandwidth
    bw_min = 0;
end
if nargin < 12
    trim_vol = [];
end
if nargin < 13
    trim_shift = [];
end
if nargin < 14
    conn_trim = [];
end
if nargin < 15
    bl_thresh = [];
end
if nargin < 16
    merge_rule = [];
end
if nargin < 17
    f_verb = [];
end
if nargin < 18
    verb_pref = [];
end
if nargin < 19
    f_disp = [];
end
if nargin < 20 || isempty(use_trim_mex)
    use_trim_mex = true;
end

%************************
% Set default arguments *
%************************
% The 2d matrix to be analyzed
if isempty(img) || ~any(img(:)) || ~any(isfinite(img(:)))
    error('Image must not be empty')
end
% x-axis
if isempty(x)
    x = 1:size(img,2);
end
% y-axis
if isempty(y)
    y = 1:size(img,1);
end
% segment number of image data in larger image
if isempty(num_segment)
    num_segment = 1;
end
% connection parameter in labeling watershed boundaries
if isempty(conn_wshed)
    conn_wshed = 8;
end
% threshold parameter for stopping merge
if isempty(merge_thresh)
    merge_thresh = 8;
end
% maximum number of merges
if isempty(max_merges)
    max_merges = inf;
end
% volume to which regions are trimmed
if isempty(trim_vol)
    trim_vol = 0.8;
end
% floor level from which trim volume is evaluated
if isempty(trim_shift)
    trim_shift = min(img(:));
end
% connection parameter used in trimming regions
if isempty(conn_trim)
    conn_trim = 8;
end
% for use if there is a baseline threshold
if isempty(bl_thresh)
    bl_thresh = [];
end
%NOT USED
if isempty(merge_rule)
    merge_rule = 'default';
end
% indicator for level of output verbosity
if isempty(f_verb)
    f_verb = 0;
end
% prefix string for verbose outputs
if isempty(verb_pref)
    verb_pref = '';
end
% flag for displaying outputs
if isempty(f_disp)
    f_disp = 0;
end

assert(trim_vol>0 && trim_vol<=1,'Trim volume must be (0, 1]');

%*******************************
% Get low-res version of image *
%*******************************
if ~isempty(downsample_spect)
    % Using decimation instead of downsampling with anti-aliasing filter to
    % preserve the watershed region properties (borders, integer region labels)
    img_LR = img(1:downsample_spect(2):end, 1:downsample_spect(1):end);
else
    img_LR = img;
end

%**********************************
% Run watershed and create graph  *
%**********************************
t_start = tic;
if f_verb > 0
    disp([verb_pref 'Computing watershed and building graph...']);
    ttic = tic;
end
%Run the watershed
Ldata = runWatershed(img_LR,conn_wshed,bl_thresh,f_verb-1,['    ' verb_pref],f_disp);

%Convert labeled region to graph
[regions, region_lbls, borders, adj_list] = Ldata2graph(Ldata,[],f_disp);

if f_verb > 0
    disp([verb_pref '    watershed took: ' num2str(toc(ttic)) ' seconds.']);
end

%**************************************************
% Merge watershed regions according to merge rule *
%**************************************************
if ~isempty(adj_list)

    if f_verb > 0
        disp([verb_pref '  Starting merge...']);
        ttic = tic;
    end

    [regions, borders] = mergeWshedSegment(img_LR,regions,region_lbls,borders,adj_list,merge_thresh,max_merges,merge_rule,f_verb-1,['     ' verb_pref],f_disp);

    if f_verb > 0
        disp([verb_pref '    merge took: ' num2str(toc(ttic)) ' seconds.']);
    end

else

    if f_verb > 0
        disp('Nothing found to merge.');
    end

end

%Return if empty stats table
if isempty(regions) || isempty(borders)
    stats_table = table;
    return;
end

%**********************************************
% Interpolate peak regions to high-resolution *
%**********************************************
if ~isempty(downsample_spect)
    %UPSCALE THE LABELED IMAGE
    Ldata = zeros(size(img_LR));

    %Create the labeled image and skip empty regions
    num_regions = length(regions);
    for ii = 1:num_regions
        ii_pixels = regions{ii};
        if ~isempty(ii_pixels)
            Ldata(ii_pixels)=ii;
        end
    end

    %Resize image
    LdataHR = imresize(Ldata,size(img),'nearest');

    %COMPUTE NEW REGIONS
    regions_HR = cell(1,num_regions);
    for ii = 1:num_regions
        regions_HR{ii} = find(LdataHR == ii);
    end

    regions = regions_HR;
end

%%
%**********************************************************
% Do not trim regions already below the removal criteria  *
%**********************************************************
% NOTE: a nested fastind2sub helper lived here previously, on the theory
% that hand-rolled arithmetic would beat ind2sub's call overhead. Profiling
% in R2025b shows the opposite: nested-function dispatch (closure capture
% for access to this function's workspace) costs ~24 µs/call vs ind2sub's
% ~13 µs/call. Removed 2026-04-16 — worth ~20 s of serial time across the
% three call sites below. If you revive something like it, measure on the
% target MATLAB version first.

if dur_min>0 || bw_min>0
    df = y(2)-y(1);
    dt = x(2)-x(1);
    [f_inds,t_inds] = cellfun(@(x)ind2sub(size(img),x),regions,'UniformOutput',false);
    good_inds = cellfun(@(x)(max(x)-min(x))*dt>dur_min,t_inds) & cellfun(@(x)(max(x)-min(x))*df>bw_min,f_inds);
    regions = regions(good_inds);
    borders = borders(good_inds);
end

%Return if empty stats table
if isempty(regions)
    stats_table = table;
    return;
end

%%
%***********************************************************
% Trim merged regions if trim_vol parameter is less than 1 *
%***********************************************************
if trim_vol >= 1
    trim_vol = 0.99; % force some trimming to clean up salt and pepper artifacts inside regions
end

if trim_vol < 1
    if f_verb > 0
        disp([verb_pref '  Starting trim to ' num2str(100*trim_vol) ' percent volume...']);
        ttic = tic;
    end
    [trim_regions, trim_borders] = trimWshedRegions(img,regions,trim_vol,trim_shift,conn_trim,f_verb-1,['    ' verb_pref],f_disp,use_trim_mex);
    if f_verb > 0
        disp([verb_pref '    trim took: ' num2str(toc(ttic)) ' seconds.']);
    end

    %Remove regions that now fall below the removal criteria after trimming
    if dur_min>0 || bw_min>0
        [f_inds, t_inds] = cellfun(@(x)ind2sub(size(img),x),trim_regions,'UniformOutput',false);
        good_inds = cellfun(@(x)~isempty(max(x))&&((max(x)-min(x))*dt>dur_min),t_inds) & cellfun(@(x)~isempty(max(x))&&((max(x)-min(x))*df>bw_min),f_inds);
        trim_regions = trim_regions(good_inds);
        trim_borders = trim_borders(good_inds);
    end

    %Return if empty stats table
    if isempty(trim_regions)
        stats_table = table;
        return;
    end

    regions = trim_regions;
    borders = trim_borders;

    if dur_min>0 || bw_min>0
        df = y(2)-y(1);
        dt = x(2)-x(1);

        [f_inds, t_inds] = cellfun(@(x)ind2sub(size(img),x),regions,'UniformOutput',false);
        good_inds = cellfun(@(x)(max(x)-min(x))*dt>dur_min,t_inds) & cellfun(@(x)(max(x)-min(x))*df>bw_min,f_inds);
        regions = regions(good_inds);
    end

end

%***********************************
% Computing stats for peak regions *
%***********************************
if f_verb > 0
    disp([verb_pref '  Starting stats...']);
    ttic = tic;
end

%Create the peak stats table
stats_table = computePeakStatsTable(regions, borders, img, x, y, num_segment, features);

seq_time = toc(t_start);
if f_verb > 0
    disp([verb_pref '    stats took: ' num2str(toc(ttic)) ' seconds.']);
    disp([verb_pref 'Sequence took ' num2str(seq_time/60) ' minutes.']);
end

end
