function [stats_table, label_img] = extracthistpeaks(img, x, y, merge_thresh, dur_min, bw_min, height_min, trim_vol, f_disp, f_verb)
%EXTRACTHISTPEAKS  Determine peak regions within a spectral topography and extract features using watershed
%
%   Usage:
%       [stats_table, label_img] = extracthistpeaks(img, x, y, merge_thresh, dur_min, bw_min, height_min, trim_vol, f_disp, f_verb)
%
%   This function determines the peak regions within a spectral topography and extracts a set of features for each peak.
%
%   Input:
%       img: 2D matrix of image data. Defaults to peaks(100).
%       x: x-axis of image data. Default is 1:size(data, 2).
%       y: y-axis of image data. Default is 1:size(data, 1).
%       merge_thresh: Threshold weight value for stopping the merge. Default is 8.
%       dur_min: Minimum duration allowed for peaks. Default is 5.
%       bw_min: Minimum bandwidth allowed for peaks. Default is 2.
%       height_min: Minimum height allowed for peaks. Default is 2.
%       trim_vol: Fraction of the maximum trimmed volume (from 0 to 1). Default is 0.8.
%       f_disp: Flag to indicate whether to plot. Default is 0 unless using default data.
%       f_verb: Flag to indicate whether to be verbose. Default is false.
%
%   Output:
%       stats_table: Table of peak statistics, where each row represents a peak.
%       label_img: RGB image with labeled peak regions.
%
%   The function performs peak extraction, merging of watershed regions, trimming, and computes statistics for peak regions.
%   It returns the peak statistics as a table and, optionally, a labeled RGB image.
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
%   TUTORIALS  https://harvard.edu
%   GITHUB     https://github.com
%
%   CITATION
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

if nargin < 4
    merge_thresh = [];
end

if nargin < 5 || isempty(dur_min)
    %Min TF-peak duration
    dur_min = 5;
end

if nargin < 6 || isempty(bw_min)
    %Min TF-peak bandwidth
    bw_min = 2;
end

if nargin < 7 || isempty(height_min)
    %Min TF-peak height
    height_min = 2;
end

if nargin < 8
    trim_vol = .8;
end

if nargin < 9
    f_disp = 0;
end

if nargin < 10
    f_verb = false;
end

num_segment = 1;
conn_wshed = [];
max_merges = [];
trim_shift = [];
conn_trim = [];
bl_thresh = [];
merge_rule = [];
verb_pref = [];
label_img = [];

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
    merge_thresh = .1;
end
% maximum number of merges
if isempty(max_merges)
    max_merges = inf;
end
% volume to which regions are trimmed
if isempty(trim_vol)
    trim_vol = 0.95;
end
% floor level from which trim volume is evaluated
if isempty(trim_shift)
    trim_shift = min(img(:));
end
% connection parameter used in trimming regions
if isempty(conn_trim)
    conn_trim = 8;
end
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

if f_verb
    disp(['Merge threshold:' num2str(merge_thresh)])
    disp(['Duration min:' num2str(dur_min)])
    disp(['Bandwidth min:' num2str(bw_min)])
    disp(['Height min:' num2str(height_min)])
    disp(['Trim volume:' num2str(trim_vol)])
end

%************************************
%   Run watershed and create graph  *
%************************************
t_start = datetime("now");
if f_verb > 0
    disp([verb_pref 'Computing watershed and building graph...']);
    ttic = tic;
end
%Run the watershed
Ldata = runWatershed(img,conn_wshed,bl_thresh,f_verb-1,['    ' verb_pref],0);

%Convert labeled region to graph
[regions, rgn_lbls, Lborders, adj_list] = Ldata2graph(Ldata,[],0);

if f_verb > 0
    disp([verb_pref '    watershed took: ' num2str(toc(ttic)) ' seconds.']);
end

%**************************************************
% Merge watershed regions according to merge rule *
%**************************************************
if f_verb > 0
    disp([verb_pref '  Starting merge...']);
    ttic = tic;
end

[regions, bndry] = mergeWshedSegment(img,regions,rgn_lbls,Lborders,adj_list,merge_thresh,max_merges,merge_rule,f_verb-1,['     ' verb_pref],f_disp);

if f_verb > 0
    disp([verb_pref '    merge took: ' num2str(toc(ttic)) ' seconds.']);
end

%**********************************************************
% Do not trim regions already below the removal criteria  *
%**********************************************************
if dur_min>0 || bw_min>0
    df = y(2)-y(1);
    dt = x(2)-x(1);

    [f_inds,t_inds]=cellfun(@(x)ind2sub(size(img),x),regions,'UniformOutput',false);
    good_inds = cellfun(@(x)(max(x)-min(x))*dt>dur_min,t_inds) & cellfun(@(x)(max(x)-min(x))*df>bw_min,f_inds);
    regions = regions(good_inds);
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
if trim_vol < 1
    if f_verb > 0
        disp([verb_pref '  Starting trim to ' num2str(100*trim_vol) ' percent volume...']);
        ttic = tic;
    end
    [trim_rgn, trim_bndry] = trimWshedRegions(img,regions,trim_vol,trim_shift,conn_trim,f_verb-1,['    ' verb_pref],f_disp);
    if f_verb > 0
        disp([verb_pref '    trim took: ' num2str(toc(ttic)) ' seconds.']);
    end

    %Return if empty stats table
    if isempty(trim_rgn)
        stats_table = table;
        return;
    end

    regions = trim_rgn;
    bndry = trim_bndry;
end

%***********************************
% Computing stats for peak regions *
%***********************************
if f_verb > 0
    disp([verb_pref '  Starting stats...']);
    ttic = tic;
end

%Create the peak stats table
stats_table = computePeakStatsTable(regions, bndry, img, x, y, num_segment);

%Remove those small peaks
filter_idx = filterStatsTable(stats_table, [dur_min, inf], [bw_min, inf], [-inf inf], pow2db(height_min), f_verb-1>0);
stats_table = stats_table(filter_idx, :);
regions = regions(filter_idx);

if nargout>1
    Ldata = zeros(size(img));
    for ii = 1:height(stats_table)
        ii_pixels = regions{ii};
        Ldata(ii_pixels)=ii;
    end

    RGB2 = label2rgb(Ldata, 'jet', 'k', 'shuffle');
    R = squeeze(RGB2(:,:,1));
    G = squeeze(RGB2(:,:,2));
    B = squeeze(RGB2(:,:,3));
    R(~Ldata) = 100;
    G(~Ldata) = 100;
    B(~Ldata) = 100;
    label_img = cat(3,R,G,B);
end

seq_time = seconds(datetime("now")-t_start);
if f_verb > 0
    disp([verb_pref '    stats took: ' num2str(toc(ttic)) ' seconds.']);
    disp([verb_pref 'Sequence took ' num2str(seq_time/60) ' minutes.']);
end

stats_table.SOFeature = stats_table.PeakTime;
stats_table.PeakTime = [];
end
