function  [matr_names, matr_fields, peaks_matr,PixelIdxList,PixelList,PixelValues,...
         rgn,bndry,chunks_minmax, chunks_xyminmax, chunks_time, bad_chunks,chunk_error] = peaksWShedStatsWrapper(data,x,y,chunk_time,conn_wshed,merge_thresh,max_merges,trim_vol,trim_shift,conn_trim,conn_stats,bl_thresh,merge_rule,f_verb,verb_pref,f_disp)
%peaksWShedStatsWrapper determines the peak regions of a 2D image and 
% extracts a set of features for each. It initially divides the data into 
% chunks to allow parallel computation of peaks and processing of larger images.
% It applies peaksWShedStatsSequence to each chunk.
%
% INPUTS:
%   data         -- 2D matrix of image data. defaults to peaks(100).
%   x            -- x axis of image data. default 1:size(data,2).
%   y            -- y axis of image data. default 1:size(data,1).
%   chunk_time     -- seconds per chunk to use (default = 30).
%   conn_wshed   -- pixel connection to be used by peaksWShed. default 8. 
%   merge_thresh -- threshold weight value for when to stop merge rule. default 8. 
%   max_merges   -- maximum number of merges to perform. default inf. 
%   trim_vol     -- fraction maximum trimmed volume (from 0 to 1), 
%                   i.e. 1 means no trim. default 0.8. 
%   trim_shift   -- value to be subtracted from image prior to evaulation of trim volume. 
%                   default min(min(img_data)).
%   conn_trim    -- pixel connection to be used by trimRegionsWShed. default 8. 
%   conn_stats   -- pixel connection to be used by peaksWShedStats_LData. default 8.
%   bl_thresh    -- power threshold used to cut off low power data to speed
%                   up computation. Default = [];
%   merge_rule   --
%   f_verb       -- number indicating depth of output text statements of progress.
%                   0 - no output. 
%                   1 - output current function level. indicates chunk progress. 
%                   2 - output at sequence level within each chunk.
%                   3 - output within sequence functions. 
%                   4 - output internal progress of merge and trim functions. 
%                   defaults to 0, unless using default data. 
%                   >1 is not recommended unless data is single chunk. 
%   verb_pref    -- prefix string for verbose output. defaults to ''.
%   f_disp       -- flag indicator of whether to plot. 
%                   defaults to false, unless using default data.
% OUTPUTS:
%   peaks_matr      -- matrix of peak features. each row is a peak.
%   matr_names      -- 1D cell array of names for each feature.
%   matr_fields     -- vector indicating number of matrix columns occupied by each feature. 
%   PixelIdxList    -- 1D cell array of vector lists of linear idx of all pixels for each region.
%   PixelList       -- 1D cell array of vector lists of row-col idx of all pixels for each region.
%   PixelValues     -- 1D cell array of vector lists of all pixel values for each region.
%   rgn             -- same as PixelIdxList.
%   bndry           -- 1D cell array of vector lists of linear idx of border pixels for each region. 
%   chunks_minmax   -- num_chunks x 4 matrix, each row with [minx miny maxx maxy] indices of a chunk. 
%   chunks_xyminmax -- num_chunks x 4 matrix, each row with [minx miny maxx maxy] values of a chunk. 
%   bad_chunks      --
%   chunk_error     --
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%      
%   Authors: Patrick Stokes
%
% Created on: 20171015 -- forked from version in wshed1
% Modified: 20190410 -- commented and cleaned up for toolbox.
%           20190214 -- spectrogram moved up to peaksWShedFromData, and 
%                       other functions moved into peaksWShedStatsSequence.
%
%*******************************************

%*************************
% Handle variable inputs *
%*************************
if nargin < 1
    data = [];
end
if nargin < 2
    x = [];
end
if nargin < 3
    y = [];
end
if nargin < 4
    chunk_time = [];
end
if nargin < 5
    conn_wshed = [];
end
if nargin < 6
    merge_thresh = [];
end
if nargin < 7
    max_merges = [];
end
if nargin < 8
    trim_vol = [];
end
if nargin < 9
    trim_shift = [];
end
if nargin < 10 
    conn_trim = [];
end
if nargin < 11
    conn_stats = [];
end
if nargin <12
    bl_thresh = [];
end
if nargin < 13
    merge_rule = [];
end
if nargin < 14
    f_verb = [];
end
if nargin < 15
    verb_pref = [];
end
if nargin < 16
    f_disp = [];
end

%************************
% Set default arguments *
%************************
% The 2d matrix to be analyzed
if isempty(data)
    data = abs(peaks(100))+randn(100)*.5;
    % data = [data data];
    f_verb = 4;
    f_disp = 1;
    merge_thresh = 2;
end
% x-axis
if isempty(x)
    x = 1:size(data,2);
end
% y-axis
if isempty(y)
    y = 1:size(data,1);
end
% maximum number of pixels per chunk 
if isempty(chunk_time)
    chunk_time = 15; %487900 % 975800; % 400000;
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
    trim_shift = min(min(data));
end
% connection parameter used in trimming regions
if isempty(conn_trim)
    conn_trim = 8;
end
% connection parameter used in peak stats evaluation
if isempty(conn_stats)
    conn_stats = 8;
end
if isempty(bl_thresh)
    bl_thresh = [];
end
if isempty(merge_rule)
    merge_rule = 'absolute';
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

%************************
% Determine data chunks *
%************************
% This chunking prevents having a small chunk at the end.
len_y = length(y);
len_x = length(x);
dt = x(2) - x(1);
max_area = floor((chunk_time/dt) * len_y);
max_dx = floor(max_area/len_y);
n_chunks = ceil(len_x/max_dx);
new_dx = ceil(len_x/n_chunks);
data_chunks = cell(n_chunks,1); 
x_chunks = cell(n_chunks,1); 

if f_verb > 0
    disp([verb_pref num2str(n_chunks) ' total chunks.']);
    disp([verb_pref 'Chunking data...']);
end    
chunks_xyminmax = zeros(n_chunks,4);
chunks_minmax = zeros(n_chunks,4);
for ii = 1:n_chunks
    idx1 = (ii-1)*new_dx+1;
    idx2 = min([ii*new_dx,len_x]);
    
    % disp(['Chunk ' num2str(ii) ' of ' num2str(n_chunks) ': ' num2str(diff(x([idx1 idx2]))/60) ' minutes']);
    
    % l_chunks(ii) = length(idx1:idx2);
    data_chunks{ii} = data(:,idx1:idx2); % data_chunks(:,1:l_chunks(ii),ii) = data(:,idx1:idx2);
    x_chunks{ii} = x(idx1:idx2); % x_chunks(ii,1:l_chunks(ii)) = x(idx1:idx2);
    chunks_xyminmax(ii,:) = [min(x_chunks{ii}) min(y) max(x_chunks{ii}) max(y)];
    chunks_minmax(ii,:) = [idx1 1 idx2 length(y)];
    
end
   
%*************************************************************
% Initialize storage for parallel processing of image chunks *
%*************************************************************
chunks_matr_names = cell(n_chunks,1);
chunks_matr_fields = cell(n_chunks,1);
chunks_peaks_matr = cell(n_chunks,1); 
chunks_PixelIdxList = cell(n_chunks,1);
chunks_PixelList = cell(n_chunks,1);
chunks_PixelValues = cell(n_chunks,1);
chunks_rgn = cell(n_chunks,1); 
chunks_bndry = cell(n_chunks,1);
bad_chunks = false(n_chunks,1);
chunk_error = cell(n_chunks,1);
chunks_time = zeros(n_chunks,1);

%**********************************************
% In parallel, find peak stats for each chunk *
%**********************************************
if n_chunks > 1
    parfor ii = 1:n_chunks 
        if f_verb > 0
            disp([verb_pref 'Starting Chunk ' num2str(ii) '...']);
        end
        [chunks_peaks_matr{ii}, chunks_matr_names{ii}, chunks_matr_fields{ii}, ...
            chunks_PixelIdxList{ii},chunks_PixelList{ii},chunks_PixelValues{ii}, ...
            chunks_rgn{ii},chunks_bndry{ii},chunks_time(ii)] = peaksWShedStatsSequence(data_chunks{ii},x_chunks{ii},y,ii,conn_wshed,merge_thresh,max_merges,trim_vol,trim_shift,conn_trim,conn_stats,bl_thresh,merge_rule,f_verb-1,['  ' verb_pref],f_disp);
        if f_verb > 0
            disp([verb_pref '  Chunk ' num2str(ii) ' took ' num2str(chunks_time(ii)) ' seconds.']);
        end
    end
else
    for ii = 1:n_chunks
        if f_verb > 0
            disp([verb_pref 'Starting Chunk ' num2str(ii) '...']);
        end
        [chunks_peaks_matr{ii}, chunks_matr_names{ii}, chunks_matr_fields{ii}, ...
            chunks_PixelIdxList{ii},chunks_PixelList{ii},chunks_PixelValues{ii}, ...
            chunks_rgn{ii},chunks_bndry{ii},chunks_time(ii)] = peaksWShedStatsSequence(data_chunks{ii},x_chunks{ii},y,ii,conn_wshed,merge_thresh,max_merges,trim_vol,trim_shift,conn_trim,conn_stats,bl_thresh,merge_rule,f_verb-1,['  ' verb_pref],f_disp);
        if f_verb > 0
            disp([verb_pref '  Chunk ' num2str(ii) ' took ' num2str(chunks_time(ii)) ' seconds.']);
        end
    end    
end

%**************************************************************************
% Assembles peaks stats for all chunks into single matrix and cell arrays *
%**************************************************************************
if f_verb > 0 
    disp([verb_pref 'Assembling stats from chunks...']);
end
% Determine number of non-empty peaks
num_peaks = 0;
first_nonempty = 0;
for ii = 1:n_chunks
    num_peaks = num_peaks + length(chunks_rgn{ii});
    if first_nonempty==0 && ~isempty(chunks_rgn{ii})
        first_nonempty = ii;
    end
end
% Allocate storage
matr_names = chunks_matr_names{first_nonempty};
matr_fields = chunks_matr_fields{first_nonempty};
peaks_matr = zeros(num_peaks,size(chunks_peaks_matr{first_nonempty},2));
PixelIdxList = cell(num_peaks,1);
PixelList = cell(num_peaks,1);
PixelValues = cell(num_peaks,1);
rgn = cell(num_peaks,1);
bndry = cell(num_peaks,1);
% Extract from cell arrays
cnt_peaks = 0;
for ii = 1:n_chunks
    num_add = length(chunks_rgn{ii});
    peaks_matr((cnt_peaks+1):(cnt_peaks+num_add),:) = chunks_peaks_matr{ii};
    PixelIdxList((cnt_peaks+1):(cnt_peaks+num_add)) = chunks_PixelIdxList{ii};
    PixelList((cnt_peaks+1):(cnt_peaks+num_add)) = chunks_PixelList{ii};
    PixelValues((cnt_peaks+1):(cnt_peaks+num_add)) = chunks_PixelValues{ii};
    rgn((cnt_peaks+1):(cnt_peaks+num_add)) = chunks_rgn{ii};
    bndry((cnt_peaks+1):(cnt_peaks+num_add)) = chunks_bndry{ii};
    
    cnt_peaks = cnt_peaks + num_add;
end



end

