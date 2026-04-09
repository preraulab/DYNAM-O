function [ freq_TFpeaks ] = extract_freq_clusters(freq_TFpeaks, sel_freqs)
%EXTRACT_FREQ_CLUSTERS  Identify indices of TF peaks falling within the extent of each frequency cluster
%
%   Usage:
%       freq_TFpeaks = extract_freq_clusters(freq_TFpeaks, sel_freqs)
%
%   Inputs:
%       freq_TFpeaks: table - frequency cluster table with fields:
%                      .peak_lower_freq:        lower frequency bound of each cluster (Hz)
%                      .peak_upper_freq:        upper frequency bound of each cluster (Hz)
%                      .boundary_from_lastpeak: frequency boundary between adjacent clusters (Hz)
%       sel_freqs:    [1xP] double - selected TF peak frequencies (Hz)
%
%   Outputs:
%       freq_TFpeaks: table - input table with TFpeak_idx cell column added, containing logical
%                    indices into sel_freqs for each cluster
%
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
for ii = 1:size(freq_TFpeaks,1)
    low_bound = freq_TFpeaks.peak_lower_freq(ii) - (freq_TFpeaks.peak_upper_freq(ii) - freq_TFpeaks.peak_lower_freq(ii))/2;
    low_bound = max(freq_TFpeaks.boundary_from_lastpeak(ii), low_bound);
    
    high_bound = freq_TFpeaks.peak_upper_freq(ii) + (freq_TFpeaks.peak_upper_freq(ii) - freq_TFpeaks.peak_lower_freq(ii))/2;
    if ii ~= size(freq_TFpeaks,1)
        high_bound = min(freq_TFpeaks.boundary_from_lastpeak(ii+1), high_bound);
    end
    
    % identify the indices 
    peak_indices = sel_freqs >= low_bound & sel_freqs <= high_bound;
    freq_TFpeaks.TFpeak_idx(ii) = {peak_indices};
end

