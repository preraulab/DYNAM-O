function tests = test_aggregate_paramfit_guard
%TEST_AGGREGATE_PARAMFIT_GUARD  Format-pooling rules in aggregate_DYNAMO_outputs
tests = functiontests(localfunctions);
end

function setupOnce(~)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('aggregate_DYNAMO_outputs'))
    addpath(repo_root);
    init_DYNAMO();
end
end

function setup(testCase)
% Channel dir named C3 so the *_SOpower_paramfit_C3.csv suffix matches.
d = fullfile(tempname(), 'C3');
mkdir(fullfile(d, 'param_basis'));
testCase.TestData.chanDir = d;
end

function teardown(testCase)
root = fileparts(testCase.TestData.chanDir);
if isfolder(root)
    rmdir(root, 's');
end
end

function test_v1_with_v3_hard_errors(testCase)
% sqrt(2)-sigma widths (format 1) must never pool with true-sigma 2/3.
d = testCase.TestData.chanDir;
write_min_paramfit_(d, 'A', {'# version: 1'});
write_min_paramfit_(d, 'B', {'# format: 3', '# writer_version: 1.0.0+abcdef123456'});
call = @() aggregate_DYNAMO_outputs(d, 'Formats', {'paramfit_csv'});
testCase.verifyError(call, 'aggregate_DYNAMO_outputs:mixedParamfitFormats');
end

function test_bare_counts_as_v1(testCase)
% A preamble-free CSV infers format 1 and triggers the same hard error.
d = testCase.TestData.chanDir;
write_min_paramfit_(d, 'A', {});
write_min_paramfit_(d, 'B', {'# format: 3'});
call = @() aggregate_DYNAMO_outputs(d, 'Formats', {'paramfit_csv'});
testCase.verifyError(call, 'aggregate_DYNAMO_outputs:mixedParamfitFormats');
end

function test_v2_with_v3_warns_and_pools(testCase)
% Formats 2 and 3 share numerics: pooled, with a recorded warning.
d = testCase.TestData.chanDir;
write_min_paramfit_(d, 'A', {'# version: 2', '# code_version: gui-app@1f2e3d'});
write_min_paramfit_(d, 'B', {'# format: 3', '# writer_version: 1.0.0+abcdef123456'});
result = aggregate_DYNAMO_outputs(d, 'Formats', {'paramfit_csv'});
testCase.verifyEqual(height(result.paramPower.csv_table), 2);
testCase.verifyTrue(any(contains(string(result.warnings), 'mix formats 2 and 3')));
end

function test_mixed_writer_versions_warn(testCase)
d = testCase.TestData.chanDir;
write_min_paramfit_(d, 'A', {'# format: 3', '# writer_version: 1.0.0+aaaaaaaaaaaa'});
write_min_paramfit_(d, 'B', {'# format: 3', '# writer_version: 1.0.0+bbbbbbbbbbbb'});
result = aggregate_DYNAMO_outputs(d, 'Formats', {'paramfit_csv'});
testCase.verifyEqual(height(result.paramPower.csv_table), 2);
testCase.verifyTrue(any(contains(string(result.warnings), 'different writer builds')));
end

function test_uniform_v3_is_clean(testCase)
d = testCase.TestData.chanDir;
write_min_paramfit_(d, 'A', {'# format: 3', '# writer_version: 1.0.0+abcdef123456'});
write_min_paramfit_(d, 'B', {'# format: 3', '# writer_version: 1.0.0+abcdef123456'});
result = aggregate_DYNAMO_outputs(d, 'Formats', {'paramfit_csv'});
testCase.verifyEqual(height(result.paramPower.csv_table), 2);
testCase.verifyEmpty(result.warnings);
end

% -------------------------------------------------------------------------
function write_min_paramfit_(chanDir, subj, preamble)
%WRITE_MIN_PARAMFIT_  Minimal one-mode power paramfit CSV fixture
%
%   Inputs:
%       chanDir  : char - channel directory (.../C3) -- required
%       subj     : char - subject ID for the filename -- required
%       preamble : cell - '#' lines to place before the header (may be
%                  empty for a bare file) -- required
%
%   Outputs:
%       none (side effects only)
p = fullfile(chanDir, 'param_basis', sprintf('%s_SOpower_paramfit_C3.csv', subj));
fid = fopen(p, 'w');
assert(fid > 0, 'could not open fixture %s', p);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
for ii = 1:numel(preamble)
    fprintf(fid, '%s\n', preamble{ii});
end
fprintf(fid, 'Density,FreqMean,FreqStd,SOpowerMean,SOpowerStd,Theta,Volume\n');
fprintf(fid, '1,11,0.5,4,1.5,0,4.71238898038469\n');
end
