function in_soph = soph_peak_mask(stats_table, soph_stages)
%SOPH_PEAK_MASK  Rows of a TF-peak stats table that built the SOPH histograms
%
%   Usage:
%       in_soph = soph_peak_mask(stats_table, soph_stages)
%
%   Inputs:
%       stats_table : table - TF-peak stats table with PeakStage and SOpower
%                     columns -- required
%       soph_stages : double - sleep stages the SOPHs were built from, e.g.
%                     SOPH_options.SOPH_stages -- required
%
%   Outputs:
%       in_soph : Nx1 logical - true for each peak in one of soph_stages
%                 with a finite SOpower
%
%   Notes:
%       This is the peak population the modes were fit to, and so the only
%       peaks that can belong to a mode. It is the same rule as
%       DYNAMO.reconstructHistPeakidx and the Rust pipeline's in_hist mask.
%       A peak with no SOpower never entered a histogram, even when its
%       stage is right.
%
%   Example:
%       in_soph = soph_peak_mask(dynamo_obj.stats_table, dynamo_obj.SOPH_options.SOPH_stages);
%       soph_peaks = dynamo_obj.stats_table(in_soph, :);
%
%   See also: annotateModesWithPeakStats, label_peaks_by_mode
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

assert(istable(stats_table), 'stats_table must be a table, not a %s.', class(stats_table));
assert(all(ismember({'PeakStage', 'SOpower'}, stats_table.Properties.VariableNames)), ...
    'stats_table needs PeakStage and SOpower columns.');

in_soph = ismember(stats_table.PeakStage, soph_stages) & ~isnan(stats_table.SOpower);
end
