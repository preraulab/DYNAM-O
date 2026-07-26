function printTimingSummary(timings)
%PRINTTIMINGSUMMARY  Pretty-print runDYNAMO stage timings as a sorted table.
%
%   printTimingSummary(timings)
%
%   Prints a right-aligned, dot-leadered table with per-stage percentages
%   of total wallclock. Pipeline stages are listed largest-first with
%   millisecond precision so small stages don't show as 0.0 s. Any fields
%   missing from the struct (stage didn't run — e.g., plot_on=false,
%   single-watershed) are silently omitted. timings.soph_histograms is the
%   outer wall for the full SOpowerphaseHistogram call; the sub-parts
%   (soph_sopower_hist, soph_sophase_hist, and the two optional compute
%   stages) are listed separately so the breakdown is visible. The outer
%   total is skipped to avoid double-counting in the summary.
order = { ...
    'pool_setup',           'Parallel pool setup'; ...
    'mex_build',            'MEX build / check'; ...
    'spect_pass1',          'Spectrogram (pass 1)'; ...
    'artifact',             'Artifact rejection'; ...
    'baseline_pass1',       'Baseline (pass 1)'; ...
    'extract_pass1',        'TF peak extraction (pass 1)'; ...
    'spect_pass2',          'Spectrogram (pass 2)'; ...
    'baseline_pass2',       'Baseline + mask (pass 2)'; ...
    'extract_pass2',        'TF peak extraction (pass 2)'; ...
    'refine',               'Peak refinement'; ...
    'peak_stage',           'Peak stage assignment'; ...
    'peak_sopower',         'Peak SO-power compute'; ...
    'peak_sophase',         'Peak SO-phase compute'; ...
    'soph_sopower_compute', 'SOPH: SO-power compute (if needed)'; ...
    'soph_sophase_compute', 'SOPH: SO-phase compute (if needed)'; ...
    'soph_sopower_hist',    'SOPH: SO-power histogram'; ...
    'soph_sophase_hist',    'SOPH: SO-phase histogram'; ...
    'plot_summary',         'Summary plot'; ...
    'fit_param_basis',      'Parametric basis fit'; ...
    'fit_spline_basis',     'Spline basis fit'};

total = timings.total;
if total <= 0, total = eps; end  % avoid /0 on degenerate runs

% Collect present stages, sort descending by time. Skip rows with
% exactly 0 value — treats "stage exists but didn't run" (e.g., the
% soph_sopower_compute field when SOpower is precomputed upstream)
% the same as "field never populated at all".
keys   = order(:, 1);
labels = order(:, 2);
pres   = cellfun(@(k) isfield(timings, k) && timings.(k) > 0, keys);
labels = labels(pres);
times  = cellfun(@(k) timings.(k), keys(pres));
[times_sorted, si] = sort(times, 'descend');
labels_sorted = labels(si);

width   = 70;
bar_top = repmat(char(9552), 1, width);   % ═
bar_sep = repmat(char(9472), 1, width);   % ─
fprintf('\n%s\n', bar_top);
fprintf(' %-*s\n', width-1, 'TIMING SUMMARY  (stages sorted by time, ms precision)');
fprintf('%s\n', bar_top);

sum_reported = 0;
for k = 1:numel(labels_sorted)
    t = times_sorted(k);
    sum_reported = sum_reported + t;
    pct = 100 * t / total;
    left = sprintf(' %s ', labels_sorted{k});
    right = sprintf(' %8.3f s   (%5.1f%%)', t, pct);
    fill_len = width - numel(left) - numel(right);
    if fill_len < 1, fill_len = 1; end
    fprintf('%s%s%s\n', left, repmat('.', 1, fill_len), right);
end

% "Other" catches any time between stages (tic/toc boundaries, arg
% parsing, unmeasured helpers). Printed only when it's non-trivial
% (>100 ms) so clean runs stay clean.
other = total - sum_reported;
if other > 0.1
    left = ' Other / overhead ';
    right = sprintf(' %8.3f s   (%5.1f%%)', other, 100 * other / total);
    fill_len = width - numel(left) - numel(right);
    if fill_len < 1, fill_len = 1; end
    fprintf('%s%s%s\n', left, repmat('.', 1, fill_len), right);
end

fprintf('%s\n', bar_sep);
left = ' Total ';
right = sprintf(' %8.3f s   (100.0%%)', total);
fill_len = width - numel(left) - numel(right);
if fill_len < 1, fill_len = 1; end
fprintf('%s%s%s\n', left, repmat('.', 1, fill_len), right);
fprintf('%s\n\n', bar_top);
end
