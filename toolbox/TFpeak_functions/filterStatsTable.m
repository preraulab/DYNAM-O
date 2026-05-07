function [filter_idx, dur_inds, bw_inds, pf_inds, ht_inds] = filterStatsTable(stats_table, dur_minmax, bw_minmax, freq_minmax, ht_db_min, verbose)
%FILTERSTATSTABLE  Get indices of TF peaks passing duration, bandwidth, frequency, and height criteria
%
%   Usage:
%       [filter_idx, dur_inds, bw_inds, pf_inds, ht_inds] = ...
%           filterStatsTable(stats_table, dur_minmax, bw_minmax, freq_minmax, ht_db_min, verbose)
%
%   Required Inputs:
%       stats_table:  table - peak statistics table (output of computePeakStatsTable) -- required
%
%   Optional Inputs:
%       dur_minmax:   [1x2] double - [min, max] duration range in seconds (default: [0.5, 5])
%       bw_minmax:    [1x2] double - [min, max] bandwidth range in Hz (default: [2, 15])
%       freq_minmax:  [1x2] double - [min, max] peak frequency range in Hz (default: [0, 40])
%       ht_db_min:    double - minimum peak height in dB (default: 7.63)
%       verbose:      logical - print rejection summary (default: false)
%
%   Outputs:
%       filter_idx:   [Px1] logical - true for peaks passing all criteria
%       dur_inds:     [Px1] logical - true for peaks passing duration criterion
%       bw_inds:      [Px1] logical - true for peaks passing bandwidth criterion
%       pf_inds:      [Px1] logical - true for peaks passing frequency criterion
%       ht_inds:      [Px1] logical - true for peaks passing height criterion
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
%% Deal with Inputs
assert(nargin > 1, 'Must provide stats table');
assert(~isempty(stats_table),'Stats table is empty.');

if nargin < 2 || isempty(dur_minmax)
    dur_minmax = [0.5, 5];
end

if nargin < 3 || isempty(bw_minmax)
    bw_minmax = [2, 15];
end

if nargin < 4 || isempty(freq_minmax)
    freq_minmax = [0, 40];
end

if nargin < 5 || isempty(ht_db_min)
    ht_db_min = 7.63;
end

if nargin < 6 || isempty(verbose)
    verbose = false;
end

if verbose
    disp(['Total peaks: ', num2str(size(stats_table,1))]);
end

%% Filter features
%Filter for duration
dur_inds = (stats_table.Duration > dur_minmax(1)) & (stats_table.Duration < dur_minmax(2));

%Filter for bandwidth
bw_inds = (stats_table.Bandwidth > bw_minmax(1)) & (stats_table.Bandwidth < bw_minmax(2));

%Filter for peak frequency
pf_inds = (stats_table.PeakFrequency > freq_minmax(1)) & (stats_table.PeakFrequency < freq_minmax(2));

%Filter for peak height
ht_inds = pow2db(stats_table.Height) > ht_db_min;

filter_idx = dur_inds & bw_inds & pf_inds & ht_inds;

if verbose
    disp(['Number of Peaks After Rejection: ', num2str(sum(filter_idx)), newline]);
end
    
end

