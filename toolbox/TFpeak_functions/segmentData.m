function  [data_segs, x_segs] = segmentData(spect, stimes, sfreqs, seg_time, f_verb, verb_pref)
%SEGMENTDATA takes a full spectrogram and chunks it into separate segments
%
%   Usage:
%       [data_segs, x_segs] = segmentData(spect, stimes, sfreqs, seg_time, f_verb, verb_pref)
%
% INPUTS:
%   spect         -- 2D matrix of image data. defaults to peaks(100).
%   stimes        -- x axis of image data. default 1:size(data,2).
%   sfreqs        -- y axis of image data. default 1:size(data,1).
%   seg_time      -- seconds per seg to use (default = 30).
%   f_verb        -- number indicating depth of output text statements of progress.
%                   0 - no output.
%                   1 - output current function level.
%   verb_pref    -- prefix string for verbose output. defaults to ''.
%
% OUTPUTS:
%   data_segs: segmented spectrogram data
%   x_segs: x-values for segmented spectrogram data
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

%*************************
% Handle variable inputs *
%*************************
if nargin < 1 || isempty(spect)
    % The 2d matrix to be analyzed
    spect = abs(peaks(100))+randn(100)*.5;
    f_verb = 0;
end

if nargin < 2 || isempty(stimes)
    % x-axis
    stimes = 1:size(spect,2);
end

if nargin < 3 || isempty(sfreqs)
    % y axis
    sfreqs = 1:size(spect,1);
end

if nargin < 4 || isempty(seg_time)
    % maximum segment duration in seconds
    seg_time = 30;
end

if nargin < 17 || isempty(f_verb)
    % indicator for level of output verbosity
    f_verb = 0;
end

if nargin < 18 || isempty(verb_pref)
    % prefix string for verbose outputs
    verb_pref = '';
end


%************************
% Determine data segs *
%************************
% This seging prevents having a small segment at the end.
len_y = length(sfreqs);
len_x = length(stimes);
dt = stimes(2) - stimes(1);
max_area = floor((seg_time/dt) * len_y);
max_dx = floor(max_area/len_y);
n_segs = ceil(len_x/max_dx);
new_dx = ceil(len_x/n_segs);
data_segs = cell(n_segs,1);
x_segs = cell(n_segs,1);

if f_verb > 0
    disp([verb_pref 'Segmenting data into ' num2str(n_segs) ', ' num2str(seg_time) '-second intervals...']);
end

for ii = 1:n_segs
    idx1 = (ii-1)*new_dx+1;
    idx2 = min([ii*new_dx,len_x]);

    data_segs{ii} = spect(:,idx1:idx2);
    x_segs{ii} = stimes(idx1:idx2);
end


end

