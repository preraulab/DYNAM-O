function out_file = capture_invariance_baseline(varargin)
%CAPTURE_INVARIANCE_BASELINE  Record a compute baseline for the invariance test
%
%   Usage:
%       capture_invariance_baseline()
%       out_file = capture_invariance_baseline('Backend', 'matlab')
%
%   Inputs:
%       none (name-value pairs only)
%
%   Name-Value Pairs:
%       'TimeRange' : 1x2 double - analysis range in seconds
%                     (default: [8420 13446], the bundled example segment)
%       'Backend'   : char - 'rust' | 'matlab' | '' for auto: rust when
%                     the MEX bridge is built, matlab otherwise
%                     (default: '')
%       'OutFile'   : char - baseline .mat destination
%                     (default: tests/invariance_baseline.mat)
%
%   Outputs:
%       out_file : char - path of the written baseline .mat
%
%   Notes:
%       Run this on the REFERENCE checkout (master) before checking out
%       the branch under review; tests/test_rundynamo_invariance.m then
%       reruns the identical compute call on the branch and requires
%       isequaln equality against this capture. The baseline records the
%       backend it ran with so both sides use the same kernel; comparing
%       across backends is meaningless.
%
%       The saved cmp struct mirrors extract_comparables_ in the test.
%       Keep the two helpers in sync.
%
%   Example:
%       % on master
%       capture_invariance_baseline();
%       % git checkout feature/...; then in MATLAB
%       run_all_tests
%
%   See also: test_rundynamo_invariance, ab_rundynamo, runDYNAMO
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('runDYNAMO'))
    addpath(repo_root);
    init_DYNAMO();
end

p = inputParser;
addParameter(p, 'TimeRange', [8420 13446], ...
    @(x) validateattributes(x, {'numeric'}, {'vector', 'numel', 2, 'increasing'}));
addParameter(p, 'Backend', '', ...
    @(x) isempty(x) || any(validatestring(lower(char(x)), {'rust', 'matlab'})));
addParameter(p, 'OutFile', fullfile(repo_root, 'tests', 'invariance_baseline.mat'), ...
    @(x) validateattributes(x, {'char', 'string'}, {'scalartext', 'nonempty'}));
parse(p, varargin{:});
time_range = double(p.Results.TimeRange(:)');
backend    = lower(char(p.Results.Backend));
out_file   = char(p.Results.OutFile);

% Auto backend: rust when the MEX bridge is present, else pure MATLAB.
if isempty(backend)
    if exist('extract_tfpeaks_mex', 'file') == 3
        backend = 'rust';
    else
        backend = 'matlab';
    end
end

ex = fullfile(repo_root, 'example_data', 'example_data.mat');
assert(isfile(ex), 'bundled example_data.mat not found at %s', ex);
D = load(ex);

fprintf('capture_invariance_baseline: backend=%s, time_range=[%g %g]\n', ...
    backend, time_range(1), time_range(2));

[stats_table, ~, ~, ~, ~, ~, ~, SOPHs] = runDYNAMO( ...
    D.data, D.Fs, D.stage_times, D.stage_vals, ...
    'time_range', time_range, 'backend', backend, ...
    'verbose', true, 'plot_on', false);
close all;

% NOTE: keep this extraction in sync with the identical helper in
% tests/test_rundynamo_invariance.m.
cmp = extract_comparables_(stats_table, SOPHs); %#ok<NASGU>

captured_with = dynamo_version(); %#ok<NASGU>
captured_at = char(datetime('now', 'TimeZone', 'UTC')); %#ok<NASGU>
save(out_file, 'cmp', 'time_range', 'backend', 'captured_with', 'captured_at', '-v7.3');
fprintf('baseline written: %s\n', out_file);
end


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
