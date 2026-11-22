function tests = test_rust_backend_available
%TEST_RUST_BACKEND_AVAILABLE  The Rust bridge load test and the MATLAB fallback
tests = functiontests(localfunctions);
end

function setupOnce(~)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('rust_backend_available'))
    addpath(repo_root);
    init_DYNAMO();
end
end

function test_outputs_are_consistent(testCase)
% available is a logical scalar. An available backend has no reason, an
% unavailable one gives a reason that names the build command.
warning_state = warning('off', 'rust_backend_available:unavailable');
restore = onCleanup(@() warning(warning_state));
[available, reason] = rust_backend_available('force', true);
testCase.verifyClass(available, 'logical');
testCase.verifySize(available, [1 1]);
if available
    testCase.verifyEmpty(reason);
else
    testCase.verifySubstring(reason, 'build_rust_mex');
end
end

function test_answer_is_cached(testCase)
% A second call without 'force' returns the same answer.
warning_state = warning('off', 'rust_backend_available:unavailable');
restore = onCleanup(@() warning(warning_state));
[first, first_reason] = rust_backend_available('force', true);
[second, second_reason] = rust_backend_available();
testCase.verifyEqual(second, first);
testCase.verifyEqual(second_reason, first_reason);
end

function test_available_means_the_wrappers_run(testCase)
% When the backend reports available, the version gateway actually loads.
warning_state = warning('off', 'rust_backend_available:unavailable');
restore = onCleanup(@() warning(warning_state));
available = rust_backend_available('force', true);
testCase.assumeTrue(available, 'Rust backend not built on this machine');
testCase.assumeEqual(exist('dynamo_version_mex', 'file'), 3);
v = dynamo_version_mex();
testCase.verifyTrue(ischar(v) && ~isempty(v));
end
