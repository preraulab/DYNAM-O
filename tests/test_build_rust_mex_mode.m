function tests = test_build_rust_mex_mode
%TEST_BUILD_RUST_MEX_MODE  Validate the explicit parent-build mode.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
import matlab.unittest.fixtures.PathFixture
testCase.applyFixture(PathFixture(fullfile(repo_root, 'rust_bridge')));
end

function teardownOnce(~)
clear build_rust_mex
end

function test_rejects_unknown_mode(testCase)
testCase.verifyError(@() build_rust_mex('unknown'), ...
    'build_rust_mex:InvalidMode');
end

function test_rejects_non_character_mode(testCase)
testCase.verifyError(@() build_rust_mex(false), ...
    'build_rust_mex:InvalidMode');
end
