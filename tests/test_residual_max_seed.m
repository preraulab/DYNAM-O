function tests = test_residual_max_seed
%TEST_RESIDUAL_MAX_SEED  Verify matching-pursuit seed width priors.
tests = functiontests(localfunctions);
end

function setupOnce(~)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('residual_max_seed'))
    addpath(repo_root);
    init_DYNAMO();
end
end

function test_empty_modes_use_unscaled_fallbacks(testCase)
SOPH = [0, 0; 0, 3];
model_SOPH = zeros(size(SOPH));

[seed_row, found] = residual_max_seed( ...
    SOPH, model_SOPH, [10, 20], [1, 2], [], 0);

testCase.verifyTrue(found);
testCase.verifyEqual(seed_row, [3, 2, 1, 20, 5, 0]);
end

function test_invalid_medians_use_unscaled_fallbacks(testCase)
SOPH = [0, 0; 0, 3];
model_SOPH = zeros(size(SOPH));
accepted_modes = [1, 1, 0, 10, 0, 0];

[seed_row, found] = residual_max_seed( ...
    SOPH, model_SOPH, [10, 20], [1, 2], accepted_modes, 0);

testCase.verifyTrue(found);
testCase.verifyEqual(seed_row, [3, 2, 1, 20, 5, 0]);
end
