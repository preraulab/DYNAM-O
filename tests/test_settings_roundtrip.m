function tests = test_settings_roundtrip
%TEST_SETTINGS_ROUNDTRIP  Round-trip the JSON settings writer + loader.
%
%   Verifies generate_run_log → load_run_log preserves every default
%   option struct DYNAM-O ships, and that the file extension is .json
%   (so old `run()`-based MATLAB-code loading paths can never trigger).
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('runDYNAMO'))
    addpath(repo_root); DYNAMO_addpath();
end
testCase.TestData.tmpDir = tempname;
mkdir(testCase.TestData.tmpDir);

% The full set of DYNAM-O option structs the GUI persists.
testCase.TestData.structs = { ...
    detection_opts(), ...
    baseline_opts(), ...
    SOpowerphasehist_opts(), ...
    param_basis_opts('power'), ...
    param_basis_opts('phase'), ...
    spline_basis_opts('power'), ...
    spline_basis_opts('phase')};
testCase.TestData.names = { ...
    'detection_options', 'baseline_options', 'SOPH_options', ...
    'param_basis_power_options', 'param_basis_phase_options', ...
    'spline_basis_power_options', 'spline_basis_phase_options'};

% Single write + read shared across every assertion sub-test.
[~, fname] = generate_run_log(testCase.TestData.structs, ...
    testCase.TestData.names, ...
    'run_start', '20260505_103000', ...
    'file_path', testCase.TestData.tmpDir);
testCase.TestData.fname = fname;
testCase.TestData.S = load_run_log(fullfile(testCase.TestData.tmpDir, fname));
end

function teardownOnce(testCase)
if isfolder(testCase.TestData.tmpDir)
    rmdir(testCase.TestData.tmpDir, 's');
end
end

function test_extension_is_json(testCase)
testCase.verifyEqual(extension(testCase.TestData.fname), '.json', ...
    'Settings writer must emit .json (not .txt — code-injection vector).');
end

function test_no_matlab_code_in_payload(testCase)
% A byte-level guard: even a malformed jsonencode shouldn't slip an `eval`
% or `system` token into the file. Reject obvious red flags.
text = fileread(fullfile(testCase.TestData.tmpDir, testCase.TestData.fname));
testCase.verifyEmpty(regexp(text, '(^|[^\w])(eval|system|run)\s*\(', 'once'), ...
    'Settings file contains a MATLAB-code-looking call.');
end

function test_top_level_schema(testCase)
S = testCase.TestData.S;
testCase.verifyTrue(isstruct(S));
testCase.verifyTrue(isfield(S, 'run_start'));
testCase.verifyTrue(isfield(S, 'schema_version'));
testCase.verifyTrue(isfield(S, 'options'));
testCase.verifyEqual(S.run_start, '20260505_103000');
end

function test_all_options_round_trip(testCase)
% Each named option struct present in the input must reappear under
% S.options with bit-equal scalar/numeric/string fields. (Nested
% structs may have minor cell-vs-array reshape from jsondecode; we
% verify field-by-field with isequaln on numerics/chars.)
S = testCase.TestData.S;
for k = 1:numel(testCase.TestData.names)
    name = testCase.TestData.names{k};
    orig = testCase.TestData.structs{k};
    testCase.verifyTrue(isfield(S.options, name), ...
        sprintf('Missing %s in round-tripped options.', name));
    rt = S.options.(name);
    fields = fieldnames(orig);
    for f = 1:numel(fields)
        fn = fields{f};
        testCase.verifyTrue(isequaln(orig.(fn), rt.(fn)), ...
            sprintf('%s.%s did not round-trip.', name, fn));
    end
end
end

function ext = extension(fname)
[~, ~, ext] = fileparts(fname);
end
