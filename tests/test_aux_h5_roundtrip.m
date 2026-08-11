function tests = test_aux_h5_roundtrip
%TEST_AUX_H5_ROUNDTRIP  writeAuxH5 stamp datasets + loadAuxData recovery
tests = functiontests(localfunctions);
end

function setupOnce(~)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('loadAuxData'))
    addpath(repo_root);
    init_DYNAMO();
end
end

function setup(testCase)
d = tempname();
mkdir(d);
testCase.TestData.dir = d;
end

function teardown(testCase)
if isfolder(testCase.TestData.dir)
    rmdir(testCase.TestData.dir, 's');
end
end

function test_stamped_roundtrip(testCase)
S = synthetic_aux_();
p = fullfile(testCase.TestData.dir, 'S1_auxiliary_data_C3.h5');
writeAuxH5(p, S, fixture_stamp_());

[aux, meta] = loadAuxData(p);
testCase.verifyEqual(meta.format, 2);
testCase.verifyEqual(meta.writer, 'dynamo-matlab');
testCase.verifyEqual(meta.writer_version, '1.0.0+abcdef123456');
testCase.verifyEqual(meta.kernel_version, 'matlab-native');
% The legacy code_version dataset carries the writer_version value.
testCase.verifyEqual(meta.code_version, meta.writer_version);

% Data datasets round-trip; stamp datasets must not leak into aux.
testCase.verifyEqual(aux.Fs, 100);
testCase.verifyEqual(aux.subjectID, 'S1');
testCase.verifyEqual(aux.SOpower_norm, S.SOpower_norm);
testCase.verifyEqual(aux.SOpower_t_start, 2.5);
testCase.verifyEqual(aux.artifact_spans, S.artifact_spans);
testCase.verifyEqual(aux.stage_vals, double(S.stage_vals));
testCase.verifyFalse(any(ismember({'format','writer','writer_version', ...
    'kernel_version','code_version'}, fieldnames(aux))));
% normalizeAuxStruct recognizes the compact schema.
testCase.verifyTrue(aux.is_compact);
end

function test_unstamped_file_tolerated(testCase)
% Two-argument write is the legacy layout: no stamp datasets, and the
% reader must tolerate their absence (empty format, '' strings).
S = synthetic_aux_();
p = fullfile(testCase.TestData.dir, 'legacy.h5');
writeAuxH5(p, S);

[aux, meta] = loadAuxData(p);
testCase.verifyEmpty(meta.format);
testCase.verifyEqual(meta.writer, '');
testCase.verifyEqual(meta.writer_version, '');
testCase.verifyEqual(aux.subjectID, 'S1');
end

function test_bad_stamp_rejected(testCase)
S = synthetic_aux_();
p = fullfile(testCase.TestData.dir, 'badstamp.h5');
bad = struct('writer', 'dynamo-matlab');    % missing the version keys
testCase.verifyError(@() writeAuxH5(p, S, bad), ?MException);
end

% -------------------------------------------------------------------------
function S = synthetic_aux_()
%SYNTHETIC_AUX_  Compact-schema auxiliary_data struct
%
%   Inputs:
%       none
%
%   Outputs:
%       S : struct - representative aux fields (native-grid SO-power,
%           spans, uint8 stages)
rng(3);
S = struct();
S.Fs = 100;
S.subjectID = 'S1';
S.SOpower_t_start = 2.5;
S.SOpower_freqrange = [0.3; 1.5];
S.SOpower_norm = rand(50, 1);
S.SOpower_norm_method = 'p2shift1234';
S.SOpower_window_params = [5; 0.5];
S.artifact_spans = [12 14.5; 100 101.25];
S.stage_times = 0:30:600;
S.stage_vals = uint8([5 5 3 2 2 2 1 1 4 4 2 2 5 5 3 2 2 2 1 1 4]);
end

function stamp = fixture_stamp_()
%FIXTURE_STAMP_  Deterministic stamp for byte-stable fixtures
%
%   Inputs:
%       none
%
%   Outputs:
%       stamp : struct - fixed writer/writer_version/kernel_version
stamp = struct('writer', 'dynamo-matlab', ...
    'writer_version', '1.0.0+abcdef123456', ...
    'kernel_version', 'matlab-native');
end
