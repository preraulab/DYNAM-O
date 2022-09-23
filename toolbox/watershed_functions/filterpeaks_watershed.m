function [feature_matrix, feature_names, xywcntrd, combined_mask] = filterpeaks_watershed(peaks_matr, matr_fields, matr_names, pixel_values, dur_minmax, bw_minmax, freq_minmax, ht_db_min)
%FILTERPEAKS_WATERSHED 
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

%% Deal with Inputs

assert(nargin >= 3, 'Must provide at least 3 arguments (peaks_matr, matr_fields, matr_names');

if nargin < 4 || isempty(pixel_values)
    pixel_values = [];
end

if nargin < 5 || isempty(dur_minmax)
    dur_minmax = [0.5, 5];
end

if nargin < 6 || isempty(bw_minmax)
    bw_minmax = [2, 15];
end

if nargin < 7 || isempty(freq_minmax)
    freq_minmax = [0, 40];
end

if nargin < 8 || isempty(ht_db_min)
    ht_db_min = 7.63;
end

%% Extract features from peaks matrix
[feature_matrix, feature_names, ~, ~, ~, ~, xywcntrd] = extract_params_watershed(peaks_matr, matr_fields, matr_names, pixel_values);

disp(['Total peaks: ', num2str(size(feature_matrix,1))])

%% Filter features
%Filter for duration
feature_ind = strcmp(feature_names,'Duration');
dur_inds = (feature_matrix(:,feature_ind) > dur_minmax(1)) & (feature_matrix(:,feature_ind) < dur_minmax(2));

%Filter for bandwidth
feature_ind = strcmp(feature_names,'Bandwidth');
bw_inds = (feature_matrix(:,feature_ind) > bw_minmax(1)) & (feature_matrix(:,feature_ind) < bw_minmax(2));

%Filter for peak frequency
feature_ind = strcmp(feature_names,'Peak Frequency');
pf_inds = (feature_matrix(:,feature_ind) > freq_minmax(1)) & (feature_matrix(:,feature_ind) < freq_minmax(2));

%Filter for peak height
feature_ind = strcmp(feature_names,'Height');
ht_inds = pow2db(feature_matrix(:,feature_ind)) > ht_db_min;

combined_mask = dur_inds & bw_inds & pf_inds & ht_inds;

feature_matrix = feature_matrix(combined_mask, :);
xywcntrd = xywcntrd(combined_mask, :);

disp(['Number of Peaks After Rejection: ', num2str(sum(combined_mask))])

end

