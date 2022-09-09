function [matr_names, matr_fields, peaks_matr,PixelIdxList,PixelList,PixelValues, ...
    rgn,bndry,chunks_minmax, chunks_xyminmax, chunks_time, bad_chunks,chunk_error] = extract_TFpeaks(spect, stimes, sfreqs, baseline,...
    chunk_time, downsample_spect, conn_wshed, merge_thresh, max_merges, trim_vol, trim_shift, conn_trim, conn_stats, bl_thresh, CI_upper_bl, merge_rule,...
    f_verb, verb_pref, f_disp, f_save, ofile_pref, SD)
% extract_TFpeaks computes the time-frequency peaks and their
% features from a time-series signal. It uses peaksWShedStatsWrapper to find the peaks and
% determine their features. A baseline can be removed prior to peak
% identification. The matrix and cell arrays of peak features can be saved
% to output files.
%
% INPUTS:
%   spect        --  2D image data used to extract TFpeaks [freq, time] --required
%   stimes       --  1D timestamps corresponding to the 2nd dim of spect (seconds) --required
%   sfreqs       --  1D frequencies corresponding to the 1st dim of spect (Hertz) --required
%   baseline     --  1D baseline spectrum used to normalize the spectrogram. default []
%   chunk_time   --  length of each segment/chunk of spectrogram to process
%                    at a time (in seconds). Default = 30. Note that a 60s chunk time is
%                    used in the paper accompanying this code, but using 30s offers large
%                    speedup and should not greatly affect results
%   downsample_spect   --  2x1 double indicating number of rows and columns to downsize spect to. 
%                    Default = []
%   conn_wshed   -- pixel connection to be used by peaksWShed. default 8.
%   merge_thresh -- threshold weight value for when to stop merge rule. default 8.
%   max_merges   -- maximum number of merges to perform. default inf.
%   trim_vol     -- fraction maximum trimmed volume (from 0 to 1),
%                   i.e. 1 means no trim. default 0.8.
%   trim_shift   -- value to be subtracted from image prior to evaulation of trim volume.
%                   default min(min(img_data)).
%   conn_trim    -- pixel connection to be used by trimRegionsWShed. default 8.
%   conn_stats   -- pixel connection to be used by peaksWShedStats_LData. default 8.
%   bl_thresh    -- flag indicating use of baseline thresholding to reduce volume of data
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
%   f_save       -- integer indicator of whether to save output files and how much
%                   information to save. [0 = no saving, 1 = save fewer peak stats,
%                   2 = save all peak stats]. Default 0.
%   ofile_pref   -- string of path and data name for outputs. default 'tmp'.
%   SD           -- standard deviation of spect to be divided in z-score computation. Default = 1
%
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
%   f_success       --
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Authors: Patrick Stokes, Thomas Possidente, Michael Prerau
%
% Created on: 20190228
% Modified: 4/21/2021 - Tom P - fixed multitaper arguments to be compatable with new multitaper function
% Modified: 11/24/2021 - Tom P - multitaper spectrogram and baseline now are inputs (not internally
%           computed) and function name changed to extract_TFpeaks
%

%*************************
% Handle variable inputs *
%*************************
assert(nargin >= 3 || isempty(spect), '3 input required: spect, stimes, sfreqs');

if nargin < 4 || isempty(baseline)
    baseline = [];
end

if nargin < 5 || isempty(chunk_time)
    % chunk size should be number of pixels in 1 min of data
    %     dt = stimes(2) - stimes(1);
    %     desired_chunk_time = 15; % seconds
    %     num_stimes = desired_chunk_time/dt;
    %     max_area = num_stimes*length(sfreqs); %487900
    chunk_time = 30; % seconds
end

if nargin < 6 || isempty(downsample_spect)
    downsample_spect = [];
end

if nargin < 7 || isempty(conn_wshed)
    conn_wshed = 8;
end

if nargin < 8 || isempty(merge_thresh)
    merge_thresh = 8;
end

if nargin < 9 || isempty(max_merges)
    max_merges = inf;
end

if nargin < 10 || isempty(trim_vol)
    trim_vol = 0.8;
end

if nargin < 11 || isempty(trim_shift)
    trim_shift = [];
end

if nargin < 12 || isempty(conn_trim)
    conn_trim = 8;
end

if nargin < 13 || isempty(conn_stats)
    conn_stats = 8;
end

if nargin < 14 || isempty(bl_thresh)
    bl_thresh = false;
end

if nargin < 15 || isempty(CI_upper_bl)
    CI_upper_bl = [];
end

if nargin < 16 || isempty(merge_rule)
    merge_rule = 'default';
end

if nargin < 17 || isempty(f_verb)
    f_verb = 2;
end

if nargin < 18 || isempty(verb_pref)
    verb_pref = '';
end

if nargin < 19 || isempty(f_disp)
    f_disp = 0;
end

if nargin < 20 || isempty(f_save)
    f_save = 0;
end

if nargin < 21 || isempty(ofile_pref)
    ofile_pref = 'tmp/';
end


if nargin < 22 || isempty(SD)
    SD = 1;
end

%******************
% Remove baseline *
%******************
if ~isempty(baseline)

    if f_verb > 0
        disp([verb_pref 'Removing baseline...']);
    end

    % Remove baseline. Subtraction in dB equivalent to subtraction in non-dB.
    spect = spect./repmat(baseline,1,size(spect,2));

    if bl_thresh == true  % Get threshold used to remove low pow data
        if isempty(CI_upper_bl)
            error('If bl_thresh is true, input CI_upper_bl must be provided')
        else
            wshed_threshold = CI_upper_bl./baseline';
        end
    else
        wshed_threshold = [];
    end

end
% Set default trim_shift
if isempty(trim_shift)
    trim_shift = min(spect,[],'all');
end

%*********
% Z-Score *
%*********

spect = (spect) ./ SD;


%*********************
% Compute peak stats *
%*********************
if f_verb > 0
    disp([verb_pref 'Computing peak stats...']);
    computetime = tic;
end
[matr_names, matr_fields, peaks_matr,PixelIdxList,PixelList,PixelValues, ...
    rgn,bndry,chunks_minmax, chunks_xyminmax, chunks_time, bad_chunks,chunk_error] = peaksWShedStatsWrapper(spect,stimes,sfreqs,chunk_time,conn_wshed,...
    merge_thresh,max_merges,downsample_spect,trim_vol,trim_shift,conn_trim,...
    conn_stats,wshed_threshold,merge_rule,f_verb-1,['  ' verb_pref],...
    f_disp);
if f_verb > 0
    disp([verb_pref '  Computing took ' num2str(toc(computetime)/60) ' minutes.']);
end

%******************
% Save peak stats *
%******************

if f_verb > 0 && f_save > 0
    disp([verb_pref 'Saving peak stats...']);
    savetime_bytestream = tic;
end

if f_save > 0
    switch f_save
        case 2

            if ~strcmp(ofile_pref(end),'/')
                ofile_pref = [ofile_pref '_'];
            end

            % Save meta information
            save([ofile_pref 'meta.mat'],'-v7.3','matr_names','matr_fields','chunks_minmax','chunks_xyminmax', ...
                'chunks_time','bad_chunks','chunk_error');

            % Save stats to separate bytestream files
            var_list = {'peaks_matr','PixelIdxList','PixelValues','bndry'};
            for kk = 1:length(var_list)
                eval([var_list{kk} '_bs = getByteStreamFromArray(' var_list{kk} ');']);
                save([ofile_pref var_list{kk} '.mat'],'-v7.3',[var_list{kk} '_bs']);
            end

            if f_verb > 0
                disp([verb_pref '  Saving took ' num2str(toc(savetime_bytestream)/60) ' minutes.']);
            end

        case 1
            tic;
            if ~strcmp(ofile_pref(end),'/')
                ofile_pref = [ofile_pref '_'];
            end

            % save meta information
            save([ofile_pref 'meta.mat'],'-v7.3', 'chunks_time','bad_chunks','chunk_error');

            % Cut down peaks matrix to only necessary features
            keep_fields = {'Perimeter', 'loc', 'height', 'xy_area', 'dx', 'dy', 'xy_bndbox', 'xy_wcentrd',  'n_children', 'chunk_num'};
            keep_fields_inds = find(ismember(matr_names, keep_fields));
            fields_cumsum = cumsum(matr_fields);

            peaks_table = table();

            for kf = 1:length(keep_fields)
                keep_ind = keep_fields_inds(kf);
                field_inds = (fields_cumsum(keep_ind) - matr_fields(keep_ind))+1:fields_cumsum(keep_ind);
                peaks_table.(keep_fields{kf}) = peaks_matr(:,field_inds);
            end

            saveout_table = table(PixelIdxList, PixelValues, bndry);
            saveout_table = [saveout_table, peaks_table];

            [~, ~, ~, combined_mask] = filterpeaks_watershed(peaks_matr, matr_fields, matr_names, PixelIdxList, [0.5,5], [2,15], [0,40]);

            saveout_table(~combined_mask,:) = [];

            % save stats
            save([ofile_pref, 'peakstats_tbl.mat'], 'saveout_table');
            timetaken = toc;
            if f_verb > 0
                disp([verb_pref '  Saving took ' num2str(timetaken/60) ' minutes.']);
            end
    end
end

%******
% End *
%******
if f_verb > 0
    disp([verb_pref 'Done with peak stats.']);
end


end



