function tests = test_soph_tiff_roundtrip
%TEST_SOPH_TIFF_ROUNDTRIP  SOPH + splinefit TIFF writers/readers (format 2)
tests = functiontests(localfunctions);
end

function setupOnce(~)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('writeSOPHsTiff'))
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

function test_soph_roundtrip(testCase)
rng(7);
H = rand(11, 21) * 5;
H(3, 4) = NaN;                      % masked bin must survive as NaN
so_bins = linspace(0, 10, 11);
freq_bins = linspace(4, 18, 21);
p = fullfile(testCase.TestData.dir, 'S1_SOPHs_power_C3.tiff');
writeSOPHsTiff(p, H, so_bins, freq_bins, 'sopower', fixture_stamp_(), ...
    'subjectID', 'S1');

[Hr, meta] = loadSOPHsTiff(p);
% Pixels are f32 on disk; compare at single precision, NaN-tolerant.
testCase.verifyTrue(isequaln(single(Hr), single(H)));
testCase.verifyEqual(meta.format, 2);
testCase.verifyEqual(meta.label, 'sopower');
testCase.verifyEqual(meta.subjectID, 'S1');
testCase.verifyEqual(meta.writer, 'dynamo-matlab');
testCase.verifyEqual(meta.writer_version, '1.0.0+abcdef123456');
testCase.verifyEqual(meta.kernel_version, 'matlab-native');
testCase.verifyEqual(meta.so_bins, so_bins, 'AbsTol', 1e-12);
testCase.verifyEqual(meta.freq_bins, freq_bins, 'AbsTol', 1e-12);
% Both key families must be present for cross-tool readers.
testCase.verifyTrue(isfield(meta.raw, 'row_centers'));
testCase.verifyTrue(isfield(meta.raw, 'SOpower_bins'));
testCase.verifyEqual(char(meta.raw.pixel_format), 'f32 row-major');
end

function test_soph_shape_mismatch_errors(testCase)
% Row-count mismatch must refuse to write. The guard is an assert, whose
% MException carries an empty identifier, so match on the class.
p = fullfile(testCase.TestData.dir, 'bad.tiff');
call = @() writeSOPHsTiff(p, rand(11, 21), linspace(0, 10, 12), ...
    linspace(4, 18, 21), 'sopower', fixture_stamp_());
testCase.verifyError(call, ?MException);
testCase.verifyFalse(isfile(p));
end

function test_splinefit_roundtrip(testCase)
rng(11);
S = synthetic_splinefit_();
p = fullfile(testCase.TestData.dir, 'S1_SOpower_splinefit_C3.tiff');
writeSplinefitTiff(p, S, 'power', fixture_stamp_(), 'subjectID', 'S1');

% Page 1: coefs (carries the metadata). Page 2: fit-window splinefit.
coefs_r = double(imread(p, 1));
fit_r   = double(imread(p, 2));
testCase.verifyTrue(isequaln(single(coefs_r), single(S.coefs)));
testCase.verifyTrue(isequaln(single(fit_r), single(S.splinefit)));

info = imfinfo(p);
meta = jsondecode(info(1).ImageDescription);
testCase.verifyEqual(meta.format, 2);
testCase.verifyEqual(char(meta.label), 'splinefit');
testCase.verifyEqual(char(meta.page1), 'coefs');
testCase.verifyEqual(char(meta.page2), 'splinefit');
% knots_x/knots_y carry the augmented sequences (augknt(k,3): two extra
% end-knot copies per side).
testCase.verifyEqual(numel(meta.knots_x), numel(S.knots_x) + 4);
testCase.verifyEqual(meta.knots_x(1), meta.knots_x(3));
testCase.verifyEqual(meta.knots_x(end), meta.knots_x(end - 2));
testCase.verifyEqual(meta.freq_bins(:)', S.fit_freq_bins, 'AbsTol', 1e-12);
testCase.verifyEqual(meta.SOpower_bins(:)', S.fit_SOfeature_bins, 'AbsTol', 1e-12);
testCase.verifyEqual(char(meta.writer), 'dynamo-matlab');
end

function test_splinefit_missing_fit_bins_errors(testCase)
S = synthetic_splinefit_();
S.fit_SOfeature_bins = [];
p = fullfile(testCase.TestData.dir, 'nofitbins.tiff');
testCase.verifyError(@() writeSplinefitTiff(p, S, 'power', fixture_stamp_()), ...
    'writeSplinefitTiff:missingFitBins');
end

% -------------------------------------------------------------------------
function S = synthetic_splinefit_()
%SYNTHETIC_SPLINEFIT_  Splinefit struct with consistent shapes
%
%   Inputs:
%       none
%
%   Outputs:
%       S : struct - coefs [m_y x m_x], splinefit [n_so x n_freq] on the
%           fit-domain bins, base knots, and the fit-domain bin vectors
n_so = 8;
n_freq = 13;
S = struct();
S.coefs = rand(9, 7);                      % (num_knots_y+2) x (num_knots_x+2)
S.splinefit = rand(n_so, n_freq);
S.spline_obj = [];
S.knots_x = [(-0.1) linspace(0, 10, 5) 10.1];
S.knots_y = [3.9 linspace(4, 18, 7) 18.1];
S.fit_SOfeature_bins = linspace(0, 10, n_so);
S.fit_freq_bins = linspace(4, 18, n_freq);
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
