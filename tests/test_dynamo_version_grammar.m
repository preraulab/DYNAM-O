function tests = test_dynamo_version_grammar
%TEST_DYNAMO_VERSION_GRAMMAR  Stamp grammar assertions for version/stamp plumbing
tests = functiontests(localfunctions);
end

function setupOnce(~)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('dynamo_stamp'))
    addpath(repo_root);
    init_DYNAMO();
end
end

function test_version_grammar(testCase)
% First output follows '<semver>+<sha12>[.dirty]' or is 'unknown'.
v = dynamo_version();
pat = '^(unknown|\d+\.\d+\.\d+\+[0-9a-f]{12}(\.dirty)?)$';
testCase.verifyTrue(~isempty(regexp(v, pat, 'once')), ...
    sprintf('dynamo_version ''%s'' violates the stamp grammar', v));
end

function test_legacy_display_form(testCase)
% Second output keeps the branch@sha7 display form, never fed to stamps.
[~, legacy] = dynamo_version();
pat = '^(unknown|[^@]+@[0-9a-f]{7}(\.dirty)?)$';
testCase.verifyTrue(~isempty(regexp(legacy, pat, 'once')), ...
    sprintf('legacy display form ''%s'' unexpected', legacy));
end

function test_semver_constant_feeds_version(testCase)
% In a git checkout the semver half must be DYNAMO_TOOLBOX_VERSION.
v = dynamo_version();
testCase.assumeFalse(strcmp(v, 'unknown'), 'no git metadata in this checkout');
testCase.verifyTrue(startsWith(v, [DYNAMO_TOOLBOX_VERSION() '+']));
end

function test_stamp_default_fields(testCase)
stamp = dynamo_stamp();
testCase.verifyEqual(sort(fieldnames(stamp)), ...
    sort({'writer'; 'writer_version'; 'kernel_version'}));
testCase.verifyEqual(stamp.writer, 'dynamo-matlab');
testCase.verifyEqual(stamp.writer_version, dynamo_version());
testCase.verifyTrue(ischar(stamp.kernel_version) && ~isempty(stamp.kernel_version));
end

function test_stamp_matlab_native_override(testCase)
stamp = dynamo_stamp('matlab-native');
testCase.verifyEqual(stamp.kernel_version, 'matlab-native');
testCase.verifyEqual(stamp.writer, 'dynamo-matlab');
end
