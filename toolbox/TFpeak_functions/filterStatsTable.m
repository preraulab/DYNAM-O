function [filter_idx, dur_inds, bw_inds, pf_inds, ht_inds] = filterStatsTable(stats_table, dur_minmax, bw_minmax, freq_minmax, ht_db_min, verbose)
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
assert(nargin > 1, 'Must provide stats table');

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

verb_disp(verbose, ['Total peaks: ', num2str(size(stats_table,1))]);

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

verb_disp(verbose, ['Number of Peaks After Rejection: ', num2str(sum(filter_idx)), newline, newline]);
    
end

