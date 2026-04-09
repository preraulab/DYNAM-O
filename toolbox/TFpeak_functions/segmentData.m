function  [data_segs, x_segs, x_inds] = segmentData(spect, stimes, sfreqs, seg_time, f_verb, verb_pref)
%SEGMENTDATA takes a full spectrogram and chunks it into separate segments
%
%   Usage:
%       [data_segs, x_segs, x_inds] = segmentData(spect, stimes, sfreqs, seg_time, f_verb, verb_pref)
%
%   Inputs:
%   spect         -- 2D matrix of image data. defaults to peaks(100).
%   stimes        -- x axis of image data. default 1:size(data,2).
%   sfreqs        -- y axis of image data. default 1:size(data,1).
%   seg_time      -- seconds per seg to use (default = 30).
%   f_verb        -- number indicating depth of output text statements of progress.
%                   0 - no output.
%                   1 - output current function level.
%   verb_pref    -- prefix string for verbose output. defaults to ''.
%
%   Outputs:
%   data_segs: segmented spectrogram data
%   x_segs: x-values for segmented spectrogram data
%   x_inds: x-value indices for segmented spectrogram data
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
%   He, M., Prerau, M. J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%    in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%    for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
if nargin < 1 || isempty(spect)
    % The 2d matrix to be analyzed
    error('Spectrogram must be specified')
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

if nargin < 5 || isempty(f_verb)
    % indicator for level of output verbosity
    f_verb = 0;
end

if nargin < 6 || isempty(verb_pref)
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
x_inds = cell(n_segs,1);

if f_verb > 0
    disp([verb_pref 'Segmenting data into ' num2str(n_segs) ', ' num2str(seg_time) '-second intervals...']);
end

for ii = 1:n_segs
    idx1 = (ii-1)*new_dx+1;
    idx2 = min([ii*new_dx,len_x]);

    data_segs{ii} = spect(:,idx1:idx2);
    x_segs{ii} = stimes(idx1:idx2);
    x_inds{ii} = idx1:idx2;
end

end
