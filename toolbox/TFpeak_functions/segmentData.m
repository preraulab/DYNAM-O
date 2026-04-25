function  [data_segs, x_segs, x_inds] = segmentData(spect, stimes, sfreqs, seg_time, f_verb, verb_pref)
%SEGMENTDATA  Chunk a spectrogram into fixed-duration segments
%
%   Usage:
%       [data_segs, x_segs, x_inds] = segmentData(spect, stimes, sfreqs, seg_time, f_verb, verb_pref)
%
%   Required Inputs:
%       spect:     [F x T] double - spectrogram data
%
%   Optional Inputs:
%       stimes:    [1 x T] double - spectrogram time axis (s) (default: 1:size(spect,2))
%       sfreqs:    [1 x F] double - spectrogram frequency axis (Hz) (default: 1:size(spect,1))
%       seg_time:  double - target segment duration (s) (default: 30)
%       f_verb:    integer - verbosity: 0 silent, 1 current level (default: 0)
%       verb_pref: char - prefix string for verbose output (default: '')
%
%   Outputs:
%       data_segs: [1 x S] cell - segmented spectrogram data
%       x_segs:    [1 x S] cell - time values within each segment (s)
%       x_inds:    [1 x S] cell - column indices of each segment into the original spect
%
%   See Also: runSegmentedData, extractTFPeaks
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
%   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
%   GITHUB     https://github.com
%
%   ATTRIBUTION
%   If you use this toolbox, please cite:
%
%   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
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
