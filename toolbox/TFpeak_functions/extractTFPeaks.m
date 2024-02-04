function stats_table = extractTFPeaks(img,x,y,features,num_segment,conn_wshed,...
    merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,...
    bl_thresh,merge_rule,f_verb,verb_pref,f_disp)
% EXTRACTTFPEAKS Determines the peak regions within a spectral topography and extracts a set of features for each
%
%   Usage:
%       stats_table = extractTFPeaks(img,x,y,num_segment,conn_wshed,...
%       merge_thresh,max_merges,downsample_spect,dur_min,bw_min,trim_vol,trim_shift,conn_trim,conn_stats,...
%       bl_thresh,merge_rule,f_verb,verb_pref,f_disp)
%
% INPUTS:
%   img          -- 2D matrix of image data. defaults to peaks(100).
%   x            -- x axis of image data. default 1:size(data,2).
%   y            -- y axis of image data. default 1:size(data,1).
%   features     -- cell array of features to include, can be any subset of
%                   {'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height', 'HeightData', 
%                    'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume'} or 'all'. default 'all'
%   num_segment  -- segment number if data comes from larger image. default 1.
%   conn_wshed   -- pixel connection to be used by peaksWShed. default 8.
%   merge_thresh -- threshold weight value for when to stop merge rule. default 8.
%   max_merges   -- maximum number of merges to perform. default inf.
%   downsample_spect   --  2x1 double indicating number of rows and columns to downsize spect to. Default = []
%   dur_min      -- minimum duration allowed
%   bw_min       -- minimum bandwidth allowed
%   trim_vol     -- fraction maximum trimmed volume (from 0 to 1),
%                   i.e. 1 means no trim. default 0.8.
%   trim_shift   -- value to be subtracted from image prior to evaulation of trim volume.
%                   default min(min(img_data)).
%   conn_trim    -- pixel connection to be used by trimRegionsWShed. default 8.
%   bl_thresh    -- power threshold used to cut off low power data to speed
%                   up computation. Default = [];
%   merge_rule   --
%   f_verb       -- number indicating depth of output text statements of progress.
%                   0 - no output.
%                   1 - output current function level.
%                   2 - output within sequence functions.
%                   3 - output internal progress of merge and trim.
%                   defaults to 0, unless using default data.
%   verb_pref    -- prefix string for verbose output. defaults to ''.
%   f_disp       -- flag indicator of whether to plot.
%                   defaults to 0, unless using default data.
% OUTPUTS:
%   stats_table   -- Table of peak statistics. Each row is a peak.
%
%   Copyright 2024 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%      
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach, 
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis 
%       for Electroencephalographic Phenotyping and Biomarker Identification, 
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%
%**********************************************************************

%*************************
% Handle variable inputs *
%*************************
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
    %Min TF-peak duration
    dur_min = 0;
end

if nargin < 11 || isempty(bw_min)
    %Min TF-peak bandwidth
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
if nargin < 29
    f_disp = [];
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
    img_LR = img(1:downsample_spect(2):end, 1:downsample_spect(1):end);
else
    img_LR = img;
end

%************************************
%   Run watershed and create graph  *
%************************************
t_start = tic;
if f_verb > 0
    disp([verb_pref 'Computing watershed and building graph...']);
    ttic = tic;
end
%Run the watershed
Ldata = runWatershed(img_LR,conn_wshed,bl_thresh,f_verb-1,['    ' verb_pref],f_disp);

%Convert labeled region to graph
[regions, rgn_lbls, Lborders, adj_list] = Ldata2graph(Ldata,[],f_disp);

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

[regions, bndry] = mergeWshedSegment(img_LR,regions,rgn_lbls,Lborders,adj_list,merge_thresh,max_merges,merge_rule,f_verb-1,['     ' verb_pref],f_disp);

if f_verb > 0
    disp([verb_pref '    merge took: ' num2str(toc(ttic)) ' seconds.']);
end

%Return if empty stats table
if isempty(regions)
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
    rgn_HR = cell(1,num_regions);
    for ii = 1:num_regions
        rgn_HR{ii} = find(LdataHR == ii);
    end

    regions = rgn_HR;
end

%%
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
stats_table = computePeakStatsTable(regions, bndry, img, x, y, num_segment, features);

seq_time = toc(t_start);
if f_verb > 0
    disp([verb_pref '    stats took: ' num2str(toc(ttic)) ' seconds.']);
    disp([verb_pref 'Sequence took ' num2str(seq_time/60) ' minutes.']);
end

end
