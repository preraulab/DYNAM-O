function stats_table = extractTFPeaks(img,x,y,num_segment,merge_thresh,max_merges,downsample_spect,...
                                      dur_min,bw_min,trim_vol,trim_shift,bl_thresh,f_verb,verb_pref,f_disp)
% EXTRACTTFPEAKS Determines the peak regions within a spectral topography and extracts a set of features for each
%
%   Usage:
%       stats_table = extractTFPeaks(img,x,y,num_segment, merge_thresh,max_merges,downsample_spect,
%                                    dur_min,bw_min,trim_vol,trim_shift, bl_thresh,f_verb,verb_pref,f_disp)
%
% INPUTS:
%   img         -- 2D matrix of image data. defaults to peaks(100).
%   x            -- x axis of image data. default 1:size(data,2).
%   y            -- y axis of image data. default 1:size(data,1).
%   num_segment  -- segment number if data comes from larger image. default 1.
%   merge_thresh -- threshold weight value for when to stop merge rule. default 8.
%   max_merges   -- maximum number of merges to perform. default inf.
%   downsample_spect   --  2x1 double indicating number of rows and columns to downsize spect to. Default = []
%   dur_min      -- minimum duration allowed
%   bw_min       -- minimum bandwidth allowed
%   trim_vol     -- fraction maximum trimmed volume (from 0 to 1),
%                   i.e. 1 means no trim. default 0.8.
%   trim_shift   -- value to be subtracted from image prior to evaulation of trim volume.
%                   default min(min(img_data)).
%   bl_thresh    -- power threshold used to cut off low power data to speed
%                   up computation. Default = [];
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
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
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
if nargin < 1 || isempty(img)
    error('Must have non-empty image')
end

if nargin < 2 || isempty(x)
    x = 1:size(img,2);
end

if nargin < 3 || isempty(y)
    y = 1:size(img,1);
end

if nargin < 4 || isempty(num_segment)
    num_segment = 1;
end

if nargin < 5 || isempty(merge_thresh)
    merge_thresh = 8;
end

if nargin < 6 || isempty(max_merges)
    max_merges = inf;
end

if nargin < 7
    downsample_spect = [];
end

if nargin < 8 || isempty(dur_min)
    %Min TF-peak duration
    dur_min = 0;
end

if nargin < 9 || isempty(bw_min)
    %Min TF-peak bandwidth
    bw_min = 0;
end

if nargin < 10 || isempty(trim_vol)
    trim_vol = 0.8;
end

if nargin < 11 || isempty(trim_shift)
    trim_shift = min(img,[],'all');
end

if nargin < 12 || isempty(bl_thresh)
    bl_thresh = [];
end

if nargin < 13 || isempty(f_verb)
    f_verb = 0;
end

if nargin < 14 || isempty(verb_pref)
    verb_pref = '';
end

if nargin < 15 || isempty(f_disp)
    f_disp = 0;
end

%Return empty stats table if all zeros or nans/infs
if ~any(img,'all') || ~any(isfinite(img),'all')
    stats_table = {};
    return;
end

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
t_start = now;
if f_verb > 0
    disp([verb_pref 'Computing watershed and building graph...']);
    ttic = tic;
end

%Run the watershed
Ldata = runWatershed(img_LR, bl_thresh, f_verb-1, ['    ' verb_pref], f_disp);

%Convert labeled region to graph
[regions, region_lbls, Lborders, adj_list] = Ldata2graph(Ldata, [], f_disp);

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

[regions, bndry] = mergeWshedSegment(img_LR, regions, region_lbls, Lborders, adj_list, merge_thresh, max_merges,f_verb-1,['     ' verb_pref],f_disp);

if f_verb > 0
    disp([verb_pref '    merge took: ' num2str(toc(ttic)) ' seconds.']);
end

%Return empty stats table empty regions
if isempty(regions)
    stats_table = {};
    return;
end

%**********************************************
% Interpolate peak regions to high-resolution *
%**********************************************
if ~isempty(downsample_spect)
    %UPSCALE THE LABELED IMAGE
    Ldata = zeros(size(img_LR),"uint16");
    
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
    region_HR = cell(1,num_regions);
    for ii = 1:num_regions
        region_HR{ii} = find(LdataHR == ii);
    end

    regions = region_HR;
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

%Return empty stats table if all zeros or nans/infs
if isempty(regions)
    stats_table = {};
    return;
end

%%
%***********************************************************
% Trim merged regions if trim_vol parameter is less than 1 *
%***********************************************************
if trim_vol < 1 && trim_vol > 0 
    if f_verb > 0
        disp([verb_pref '  Starting trim to ' num2str(100*trim_vol) ' percent volume...']);
        ttic = tic;
    end
    [trim_rgn, trim_bndry] = trimWshedRegions(img,regions,trim_vol,trim_shift,f_verb-1,['    ' verb_pref],f_disp);
    if f_verb > 0
        disp([verb_pref '    trim took: ' num2str(toc(ttic)) ' seconds.']);
    end

    regions = trim_rgn;
    bndry = trim_bndry;
end

%Check for empty regions
if isempty(regions)
    stats_table = {};
    return;
end

%***********************************
% Computing stats for peak regions *
%***********************************
if f_verb > 0
    disp([verb_pref '  Starting stats...']);
    ttic = tic;
end

%Create the peak stats table
stats_table = computePeakStatsTable(regions,bndry,img,x,y,num_segment);

seq_time = (now-t_start)/datenum([0 0 0 0 0 1]);
if f_verb > 0
    disp([verb_pref '    stats took: ' num2str(toc(ttic)) ' seconds.']);
    disp([verb_pref 'Sequence took ' num2str(seq_time/60) ' minutes.']);
end

end
