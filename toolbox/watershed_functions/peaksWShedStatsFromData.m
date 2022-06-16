function  [matr_names, matr_fields, peaks_matr,PixelIdxList,PixelList,PixelValues, ...
    rgn,bndry,chunks_minmax, chunks_xyminmax, chunks_time, bad_chunks,chunk_error] = extract_TFpeaks(data,Fs,window_params,taper_params,freq_range,min_NFFT,f_detrend,f_plotspgm,bl_prc,bl_sm_win,max_area,conn_wshed,merge_thresh,max_merges,trim_vol,trim_shift,conn_trim,conn_stats,bl_thresh,f_verb,verb_pref,f_disp,f_save,ofile_pref)
% peaksWShedStatsFromData computes the time-frequency peaks and their
% features from a time-series signal. It uses multitaper_spectrogram to
% compute the spectrogram and peaksWShedStatsWrapper to find the peaks and
% determine their features. A baseline can be removed prior to peak
% identification. The matrix and cell arrays of peak features can be saved
% to output files.
%
% INPUTS:
%   data          -- time-domain signal data.
%   Fs            -- sampling frequency of data.
%   window_params -- window parameters of spectrogram.
%   taper_params  -- taper parameters of spectrogram.
%   freq_range    -- min and max frequency to retain.
%   min_NFFT      -- minimum NFFT to increase the number of frequency bins.
%   f_detrend     -- logical flag indicating whether to detrend the
%                    spectrogram. default 0.
%   f_plotspgm    -- logical flad indication whether to display the
%                    spectrogram. default 0.
%   bl_prc       -- percentile to be used for baseline. default 2.
%   bl_sm_win    -- width of window for smoothing the baseline. default 5.
%   max_area     -- maximum square-pixel size of image chunks to use. default 487900.
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
%                   information to save. [0 = no saving, 1 = save less peak stats, 
%                   2 = save all peak stats]. Default 0.
%   ofile_pref   -- string of path and data name for outputs. default 'tmp'.
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
%   Authors: Patrick Stokes
%
% Created on: 20190228
% Modified: 4/21/2021 - Tom P - fixed multitaper arguments to be compatable with new multitaper function
%

%*************************
% Handle variable inputs *
%*************************
if nargin < 1
    data = [];
end
if nargin < 2
    Fs = [];
end
if nargin < 3
    window_params = [];
end
if nargin < 4
    taper_params = [];
end
if nargin < 5
    freq_range = [];
end
if nargin < 6
    min_NFFT = [];
end
if nargin < 7
    f_detrend = [];
end
if nargin < 8
    f_plotspgm = [];
end
if nargin < 9
    bl_prc = [];
end
if nargin < 10
    bl_sm_win = [];
end
if nargin < 11
    max_area = [];
end
if nargin < 12
    conn_wshed = [];
end
if nargin < 13
    merge_thresh = [];
end
if nargin < 14
    max_merges = [];
end
if nargin < 15
    trim_vol = [];
end
if nargin < 16
    trim_shift = [];
end
if nargin < 17
    conn_trim = [];
end
if nargin < 18
    conn_stats = [];
end
if nargin < 19
    bl_thresh = [];
end
if nargin < 20
    f_verb = [];
end
if nargin < 21
    verb_pref = [];
end
if nargin < 22
    f_disp = [];
end
if nargin < 23
    f_save = [];
end
if nargin < 24
    ofile_pref = [];
end

if isempty(data)
    disp('Warning: data not provided. Aborting.');
elseif isempty(Fs)
    disp('Warning: Fs not provided. Aborting.');
else
    %***************
    % Set defaults *
    %***************
    % Multitaper spectrogram parameters
    if isempty(window_params)
        window_params = [1, .05];
    end
    if isempty(taper_params)
        taper_params = [2, 3];
    end
    if isempty(freq_range)
        freq_max = 40;
        freq_range = [0 min([Fs/2, freq_max])];
    end
    if isempty(min_NFFT)
        min_NFFT = 2^10;
    end
    if isempty(f_detrend)
        f_detrend = 'off';
    end
    if isempty(f_plotspgm)
        f_plotspgm = false;
    end
    % Baseline subtraction parameters
    if isempty(bl_prc)
        bl_prc = 2;
    end
    if isempty(bl_sm_win)
        bl_sm_win = 5;
    end
    % chunk and watershed parameters
    if isempty(max_area)
        max_area = 487900; % 400000; % 
    end
    if isempty(conn_wshed)
        conn_wshed = 8;
    end
    % merge parameters
    if isempty(merge_thresh)
        merge_thresh = 8;
    end
    if isempty(max_merges)
        max_merges = inf;
    end
    % trim and stats parameters (trim_shift set after baseline removal)
    if isempty(trim_vol)
        trim_vol = 0.8;
    end
    if isempty(conn_trim)
        conn_trim = 8;
    end
    if isempty(conn_stats)
        conn_stats = 8;
    end
    if isempty(bl_thresh)
        bl_thresh = false;
    end
    % output parameters
    if isempty(f_verb)
        f_verb = 2;
    end
    if isempty(verb_pref)
        verb_pref = '';
    end
    if isempty(f_disp)
        f_disp = 0;
    end
    if isempty(f_save)
        f_save = 0;
    end
    if isempty(ofile_pref)
        ofile_pref = 'tmp/';
    end
    
    %*********************************
    % Compute multitaper spectrogram *
    %*********************************
    if f_verb > 0
        disp([verb_pref 'Computing spectrogram...']);
    end
    [sspect, sstimes, ssfreqs] = multitaper_spectrogram_mex(data,Fs,freq_range,taper_params,window_params,min_NFFT,f_detrend,[],f_plotspgm,true,true);
    
    sspect = sspect';
    
    %******************
    % Remove baseline *
    %******************
    if bl_prc > 0
        % Compute baseline based on percentile across time
        
        if f_verb > 0
            disp([verb_pref 'Computing baseline...']);
        end
        sspect(sspect==0) = NaN;
        bl = prctile(sspect,bl_prc,2);
        
        if bl_thresh == true
            % Bootstrap baseline ptile
            iterations = 500;
            bootstat = bootstrp(iterations, @(x)prctile(x,bl_prc), sspect(:,1:20:size(sspect,2))');

            %Set alpha level
            alpha = 0.05;

            %Compute CIs on percentile
            CI_upper_bl = prctile(bootstat,100*(1-(alpha/2)));
            %CI_lower_bl = prctile(bootstat,100*(alpha/2));
        else
            CI_upper_bl = zeros(size(sspect,2),1);
        end
        
        % turn nans back into 0s
        sspect(isnan(sspect)) = 0;
        
        % Smooth baseline using a windowed average
        if(bl_sm_win > 1)
            if f_verb > 0
                disp([verb_pref 'Smoothing baseline...']);
            end
            bl_old = bl;
            CI_upper_old = CI_upper_bl;
            sm_hwin = floor(bl_sm_win/2);
            for ii = 1:length(bl)
                if (ii-sm_hwin) < 1
                    CI_upper_bl(ii) = sum(CI_upper_old(1:(ii+sm_hwin)))/(ii+sm_hwin);
                    bl(ii) = sum(bl_old(1:(ii+sm_hwin)))/(ii+sm_hwin);
                elseif (ii+sm_hwin) > length(bl)
                    bl(ii) = sum(bl_old((ii-sm_hwin):end))/(length(bl)-(ii-sm_hwin));
                    CI_upper_bl(ii) = sum(CI_upper_old((ii-sm_hwin):end))/(length(bl)-(ii-sm_hwin));
                else
                    bl(ii) = sum(bl_old((ii-sm_hwin):(ii+sm_hwin)))/bl_sm_win;
                    CI_upper_bl(ii) = sum(CI_upper_old((ii-sm_hwin):(ii+sm_hwin)))/bl_sm_win;
                end
            end
        end
        
        % Remove baseline. Subptraction in dB equivalent to subtraction in non-dB.
        if f_verb > 0
            disp([verb_pref 'Removing baseline...']);
        end
        sspect = sspect./repmat(bl,1,length(sstimes));
        
        % Get threshold used to remove low pow data
        if bl_thresh == true
            wshed_threshold = CI_upper_bl./bl';
            
%             if f_disp == true
%                 %Plot 
%                 figure;
%                 h1 = plot(ssfreqs, sspect); 
%                 hold on;
%                 h2 = plot(ssfreqs, wshed_threshold, 'color', 'r', 'linewidth', 3);
%                 title(['Spectrum data and Watershed Threshold - ptile=', num2str(bl_prc)]);
%                 legend([h1(1), h2], 'Spectrum', 'Threshold');
%             end
            
        else
            wshed_threshold = [];
        end
        
    end
    % Set default trim_shift
    if isempty(trim_shift)
        trim_shift = min(sspect,[],'all');
    end
    
    %*********************
    % Compute peak stats *
    %*********************
    if f_verb > 0
        disp([verb_pref 'Computing peak stats...']);
        computetime = tic;
    end
    [matr_names, matr_fields, peaks_matr,PixelIdxList,PixelList,PixelValues, ...
        rgn,bndry,chunks_minmax, chunks_xyminmax, chunks_time, bad_chunks,chunk_error] = peaksWShedStatsWrapper(sspect,sstimes,ssfreqs,max_area,conn_wshed,...
                                                                                                                merge_thresh,max_merges,trim_vol,trim_shift,conn_trim,...
                                                                                                                conn_stats,wshed_threshold,f_verb-1,['  ' verb_pref],...
                                                                                                                f_disp);
    if f_verb > 0
        disp([verb_pref '  Computing took ' num2str(toc(computetime)/60) ' minutes.']);
    end
    
    %******************
    % Save peak stats *
    %******************
    
    if f_verb > 0
        disp([verb_pref 'Saving peak stats...']);
        savetime_bytestream = tic;
    end
    
    switch f_save
        case 2
        
            if ~strcmp(ofile_pref(end),'/')
                ofile_pref = [ofile_pref '_'];
            end

            % Save meta information
            save([ofile_pref 'meta.mat'],'-v7.3','matr_names','matr_fields','chunks_minmax','chunks_xyminmax', ...
                'chunks_time','bad_chunks','chunk_error','freq_range','taper_params','window_params','min_NFFT');

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
            save([ofile_pref 'meta.mat'],'-v7.3', 'chunks_time','bad_chunks','chunk_error','freq_range','taper_params','window_params','min_NFFT');
            
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
            
            [~, ~, ~, combined_mask] = filterpeaks_watershed(peaks_matr, matr_fields, matr_names, [0.5,5], [2,15], [0,40]);
            
            saveout_table(~combined_mask,:) = [];
           
            % save stats
            save([ofile_pref, 'peakstats_tbl.mat'], 'saveout_table');
            timetaken = toc;
            if f_verb > 0
                disp([verb_pref '  Saving took ' num2str(timetaken/60) ' minutes.']);
            end
    end
    
    %******
    % End *
    %******
    if f_verb > 0
        disp([verb_pref 'Done with peak stats.']);
    end
end



