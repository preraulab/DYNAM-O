function [spect, bl_threshold] = removeBaseline(spect, baseline, bl_thresh, CI_upper_bl, f_verb)
% REMOVEBASELINE subtract percentile baseline from spectrogram 
%
%   Usage:
%       [spect, bl_threshold] = removeBaseline(spect, baseline, bl_thresh, CI_upper_bl, f_verb)
%
%   Inputs:
%   spect        --  2D image data used to extract TFpeaks [freq, time] --required
%   baseline     --  1D baseline spectrum used to normalize the spectrogram. default []
%   bl_thresh    -- flag indicating use of baseline thresholding to reduce volume of data
%                   being run through watershed and merging. Default = []
%   CI_upper_bl  -- upper confidence interval of the baseline, used to
%                   compute the threshold used in bl_thresh. Default = []
%   f_verb       -- number indicating depth of output text statements of progress.
%                   0 - no output.
%                   1 - output current function level.
%                   defaults to 0. >2 is not recommended unless data is single chunk.
%
%   Outputs:
%   spect: spect input with baseline subtracted
%   wshed_threshold: optional threhsold used to remove noise TFpeaks later
%
%
%
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
if nargin<1 || isempty(spect)
    error('Spectrogram must be specificied')
end

if nargin<2 || isempty(baseline)
    error('Baseline must be specificied')
end

if nargin<3 || isempty(bl_thresh)
    bl_thresh = [];
end

if nargin<4 || isempty(CI_upper_bl)
    CI_upper_bl = [];
end

if nargin<5 || isempty(f_verb)
    f_verb = 1;
end

if f_verb > 0
    disp('Removing baseline...');
end

% Remove baseline. Subtraction in dB equivalent to division in non-dB.
spect = spect./repmat(baseline,1,size(spect,2));

if ~isempty(bl_thresh) && bl_thresh ~= 0  % Get threshold used to remove low pow data
    if isempty(CI_upper_bl)
        error('If bl_thresh is true, input CI_upper_bl must be provided')
    else
        bl_threshold = CI_upper_bl./baseline';
    end
else
    bl_threshold = [];
end

end
