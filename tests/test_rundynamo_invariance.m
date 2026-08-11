function tests = test_rundynamo_invariance
%TEST_RUNDYNAMO_INVARIANCE  A/B guard: compute results unchanged by this branch
%
%   Compares a fresh runDYNAMO run on the bundled example data against a
%   baseline captured on the reference checkout (master) by
%   scripts/capture_invariance_baseline.m. The comparison is content
%   equality (isequaln) on the returned stats_table and the numeric SOPH
%   fields, run with SaveAppTree machinery entirely out of the loop (the
%   test calls runDYNAMO directly and writes nothing).
%
%   Workflow for the reviewer:
%       1. On master:      run scripts/capture_invariance_baseline.m
%       2. On this branch: run this test (run_all_tests picks it up)
%   Without a captured baseline the test is skipped via an assumption,
%   not failed.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('runDYNAMO'))
    addpath(repo_root);
    init_DYNAMO();
end
testCase.TestData.repo_root = repo_root;
testCase.TestData.baseline_path = fullfile(this_dir, 'invariance_baseline.mat');
end

function test_compute_matches_baseline(testCase)
bp = testCase.TestData.baseline_path;
testCase.assumeTrue(isfile(bp), sprintf( ...
    ['No invariance baseline at %s. Run scripts/capture_invariance_baseline.m ' ...
     'on the reference checkout (master) first, then re-run this test on the ' ...
     'branch under review.'], bp));
B = load(bp);

ex = fullfile(testCase.TestData.repo_root, 'example_data', 'example_data.mat');
testCase.assumeTrue(isfile(ex), 'bundled example_data.mat not present');
D = load(ex);

[stats_table, ~, ~, ~, ~, ~, ~, SOPHs] = runDYNAMO( ...
    D.data, D.Fs, D.stage_times, D.stage_vals, ...
    'time_range', B.time_range, 'backend', B.backend, ...
    'verbose', false, 'plot_on', false);
close all;

% NOTE: keep this extraction in sync with the identical helper in
% scripts/capture_invariance_baseline.m.
cmp = extract_comparables_(stats_table, SOPHs);

fields = fieldnames(B.cmp);
for ii = 1:numel(fields)
    f = fields{ii};
    testCase.verifyTrue(isfield(cmp, f), sprintf('run produced no ''%s''', f));
    if isfield(cmp, f)
        testCase.verifyTrue(isequaln(cmp.(f), B.cmp.(f)), ...
            sprintf('''%s'' differs from the captured baseline', f));
    end
end
end

% -------------------------------------------------------------------------
function cmp = extract_comparables_(stats_table, SOPHs)
%EXTRACT_COMPARABLES_  Collect the invariance-checked result content
%
%   Inputs:
%       stats_table : table - per-peak features from runDYNAMO -- required
%       SOPHs       : struct - histograms + fits from runDYNAMO -- required
%
%   Outputs:
%       cmp : struct - stats_table, the numeric SOPH fields, and the fit
%             numerics (params tables, spline coefs/fit) when present.
%             Fit objects (cfit/sfit/spline_obj) are deliberately
%             excluded: their equality semantics are opaque and the
%             numeric tables already pin the results.
cmp = struct();
cmp.stats_table = stats_table;
numeric_fields = {'SOpower_mat', 'SOphase_mat', 'SOpower_bins', 'SOphase_bins', ...
    'freq_bins', 'num_peaks_at_freq', 'SOpower_TIB', 'SOphase_TIB'};
for ii = 1:numel(numeric_fields)
    f = numeric_fields{ii};
    if isfield(SOPHs, f)
        cmp.(f) = SOPHs.(f);
    end
end
if isfield(SOPHs, 'SOpower_paramfit') && ~isempty(SOPHs.SOpower_paramfit)
    cmp.power_params = SOPHs.SOpower_paramfit.params;
end
if isfield(SOPHs, 'SOphase_paramfit') && ~isempty(SOPHs.SOphase_paramfit)
    cmp.phase_params = SOPHs.SOphase_paramfit.params;
end
if isfield(SOPHs, 'SOpower_splinefit') && ~isempty(SOPHs.SOpower_splinefit)
    cmp.power_spline_coefs = SOPHs.SOpower_splinefit.coefs;
    cmp.power_splinefit    = SOPHs.SOpower_splinefit.splinefit;
end
if isfield(SOPHs, 'SOphase_splinefit') && ~isempty(SOPHs.SOphase_splinefit)
    cmp.phase_spline_coefs = SOPHs.SOphase_splinefit.coefs;
    cmp.phase_splinefit    = SOPHs.SOphase_splinefit.splinefit;
end
end
