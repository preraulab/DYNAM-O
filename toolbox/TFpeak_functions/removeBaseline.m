function [spect, bl_threshold] = removeBaseline(spect, baseline, bl_thresh, CI_upper_bl, f_verb)
% REMOVEBASELINE subtract percentile baseline from spectrogram 
%
%   Usage:
%       [spect, bl_threshold] = removeBaseline(spect, baseline, bl_thresh, CI_upper_bl, f_verb)
%
% INPUTS:
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
% OUTPUTS:
%   spect: spect input with baseline subtracted
%   wshed_threshold: optional threhsold used to remove noise TFpeaks later
%
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
    disp('Removing baseline...');
end

% Remove baseline. Subtraction in dB equivalent to subtraction in non-dB.
spect = spect./repmat(baseline,1,size(spect,2));

if bl_thresh == true  % Get threshold used to remove low pow data
    if isempty(CI_upper_bl)
        error('If bl_thresh is true, input CI_upper_bl must be provided')
    else
        bl_threshold = CI_upper_bl./baseline';
    end
else
    bl_threshold = [];
end

end