function combined_mask = savePeakStats(peaks_matr, matr_names, matr_fields, PixelIdxList, f_save, ofile_pref, ...
                                       verb_pref, f_verb)
% Saves peak stats to file(s)
%
% INPUTS:
%       peaks_matr: feature data for each peak found
%       matr_names: cell array of features in peaks_matr
%       matr_fields: cell array indicating number of cells taken up by each
%                    feature listed in matr_names
%       PixelIDxList: cell array of pixel indices for each peak found
%       f_save: -- integer indicator of whether to save output files and how much
%                   information to save. [0 = no saving, 1 = save fewer peak stats,
%                   2 = save all peak stats]. Default 0.
%       ofile_pref: string of path and data name for outputs. default 'tmp'.
%       verb_pref: prefix string for verbose output. defaults to ''.
%       f_verb: number indicating depth of output text statements of progress.
%                   0 - no output.
%                   1 - output current function level.
%
%   OUTPUTS:
%       combined_mask: logical indicating which peaks are valid after peak rejection
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
%**********************************************************************

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
            save([ofile_pref 'meta.mat'],'-v7.3','matr_names','matr_fields');

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
else
    combined_mask = filterpeaks_watershed(peaks_matr, matr_fields, matr_names, PixelIdxList, [0.5,5], [2,15], [0,40]);
end


end

