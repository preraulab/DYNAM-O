function [matr_names, matr_fields, peaks_matr, PixelIdxList ,PixelList, PixelValues, rgn, bndry] = ...
    packagePeakStats(segs_rgn, segs_bndry, segs_matr_names, segs_PixelValues, segs_PixelList,...
    segs_PixelIdxList, segs_matr_fields, segs_peaks_matr, verb_pref, f_verb)
% Packages the TFpeak data (boundaries, pixels, values, statistics) from
% each segment into single matrix and cell arrays
%
% INPUTS:
%   segs_rgn: cell array of pixel indices of each region for each segment
%   segs_bndry: cell array with indices of boundaries for all TFpeaks in
%               each segment
%   segs_matr_names: names for each feature in segs_peaks_matr
%   segs_pixelValues: cell array of pixel values for each region for each
%                     segment
%   segs_PixelList
%   segs_PixelIdxList
%   segs_matr_fields: cell array with length of each feature in
%                     segs_peaks_matr
%   segs_peaks_matr: cell array with matrices of peak features for each
%                    segment
%   f_verb       -- number indicating depth of output text statements of progress.
%                   0 - no output.
%                   1 - output current function level.
%   verb_pref    -- prefix string for verbose output. defaults to ''.
%
% OUTPUTS:
%   matr_names      -- 1D cell array of names for each feature.
%   matr_fields     -- vector indicating number of matrix columns occupied by each feature.
%   peaks_matr      -- matrix of peak features. each row is a peak.
%   PixelIdxList    -- 1D cell array of vector lists of linear idx of all pixels for each region.
%   PixelList       -- 1D cell array of vector lists of row-col idx of all pixels for each region.
%   PixelValues     -- 1D cell array of vector lists of all pixel values for each region.
%   rgn             -- same as PixelIdxList.
%   bndry           -- 1D cell array of vector lists of linear idx of border pixels for each region.
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

if f_verb > 0
    disp([verb_pref 'Assembling peak statistics from segments...']);
end

% Determine number of non-empty peaks
num_peaks = 0;
first_nonempty = 0;
n_segs = length(segs_rgn);
for ii = 1:n_segs
    num_peaks = num_peaks + length(segs_rgn{ii});
    if first_nonempty==0 && ~isempty(segs_rgn{ii})
        first_nonempty = ii;
    end
end

% Allocate storage
matr_names = segs_matr_names{first_nonempty};
matr_fields = segs_matr_fields{first_nonempty};
peaks_matr = zeros(num_peaks,size(segs_peaks_matr{first_nonempty},2));
PixelIdxList = cell(num_peaks,1);
PixelList = cell(num_peaks,1);
PixelValues = cell(num_peaks,1);
rgn = cell(num_peaks,1);
bndry = cell(num_peaks,1);

% Extract from cell arrays
cnt_peaks = 0;
for ii = 1:n_segs
    num_add = length(segs_rgn{ii});
    peaks_matr((cnt_peaks+1):(cnt_peaks+num_add),:) = segs_peaks_matr{ii};
    PixelIdxList((cnt_peaks+1):(cnt_peaks+num_add)) = segs_PixelIdxList{ii};
    PixelList((cnt_peaks+1):(cnt_peaks+num_add)) = segs_PixelList{ii};
    PixelValues((cnt_peaks+1):(cnt_peaks+num_add)) = segs_PixelValues{ii};
    rgn((cnt_peaks+1):(cnt_peaks+num_add)) = segs_rgn{ii};
    bndry((cnt_peaks+1):(cnt_peaks+num_add)) = segs_bndry{ii};

    cnt_peaks = cnt_peaks + num_add;
end

end

