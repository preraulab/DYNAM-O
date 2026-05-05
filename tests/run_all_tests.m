function result = run_all_tests(varargin)
%RUN_ALL_TESTS  Run every test_*.m in tests/ via matlab.unittest.
%
%   Usage (interactive):
%       run_all_tests
%       run_all_tests('Strict', true)
%
%   Usage (CI / matlab -batch):
%       matlab -batch "addpath('<repo>'); DYNAMO_addpath; cd tests; run_all_tests"
%
%   Returns the matlab.unittest.TestResult array. Errors out via
%   assertSuccess so a -batch invocation exits non-zero on any failure.

p = inputParser;
addParameter(p, 'Strict', true, @islogical);
addParameter(p, 'Verbosity', 'Concise');
parse(p, varargin{:});

this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('runDYNAMO'))
    addpath(repo_root);
    DYNAMO_addpath();
end

import matlab.unittest.TestSuite
import matlab.unittest.TestRunner
import matlab.unittest.plugins.TestRunProgressPlugin

suite = TestSuite.fromFolder(this_dir);
runner = TestRunner.withTextOutput('OutputDetail', p.Results.Verbosity);
runner.addPlugin(TestRunProgressPlugin.withVerbosity(p.Results.Verbosity));

result = runner.run(suite);
disp(table(result));

if p.Results.Strict
    assertSuccess(result);
end
end
