function tests = test_paramfit_csv_roundtrip
%TEST_PARAMFIT_CSV_ROUNDTRIP  writeParamfitCsv/loadParamfitCsv format 3 + legacy
tests = functiontests(localfunctions);
end

function setupOnce(~)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('writeParamfitCsv'))
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

function test_power_roundtrip(testCase)
pf = synthetic_paramfit_('power');
so_bins = 0:0.5:10;
freq_bins = 4:0.2:18;
p = fullfile(testCase.TestData.dir, 'S1_SOpower_paramfit_C3.csv');
writeParamfitCsv(p, pf, 'power', so_bins, freq_bins, fixture_stamp_(), ...
    'subjectID', 'S1');

[R, meta] = loadParamfitCsv(p);
testCase.verifyEqual(meta.format, 3);
testCase.verifyEqual(meta.writer, 'dynamo-matlab');
testCase.verifyEqual(meta.fit_type, 'power');
testCase.verifyEqual(meta.n_modes, 2);
testCase.verifyEqual(meta.subjectID, 'S1');
testCase.verifyEqual(meta.gof.rsquare, pf.gof.rsquare);
testCase.verifyEqual(meta.gof.sse, pf.gof.sse);
testCase.verifyEqual(meta.freq_bins, freq_bins);
testCase.verifyEqual(meta.so_bins, so_bins);
% No fit object in the fixture: background NaN, coef lists empty.
testCase.verifyTrue(isnan(meta.background.PowSlope));
testCase.verifyTrue(isnan(meta.unit_row));
testCase.verifyEmpty(meta.fitobj_coefnames);

% Table columns and values round-trip exactly (%.17g encoding).
expected_cols = [{'Density','FreqMean','FreqStd','SOpowerMean','SOpowerStd', ...
    'Theta','Volume','PrefPhase','Coupling'}, pk_cols_()];
testCase.verifyEqual(R.Properties.VariableNames, expected_cols);
testCase.verifyTrue(isequaln(R.Density, pf.params.Density));
testCase.verifyTrue(isequaln(R.PrefPhase, pf.params.PrefPhase));
testCase.verifyTrue(isequaln(R.PkCount, pf.params.PkCount));
testCase.verifyTrue(isequaln(R.PkSOphase, pf.params.PkSOphase));
end

function test_phase_cross_axis_sopowermean(testCase)
% The phase CSV inserts a cross-axis SOpowerMean column: the mean of the
% finite SO-power histogram column at each mode's nearest freq bin.
pf = synthetic_paramfit_('phase');
so_bins = linspace(-pi, pi, 9);
freq_bins = [10 12 14];
cross = [1 2 3; 5 NaN 7];   % SO-power histogram [n_SOpower x n_freq]
p = fullfile(testCase.TestData.dir, 'S1_SOphase_paramfit_C3.csv');
writeParamfitCsv(p, pf, 'phase', so_bins, freq_bins, fixture_stamp_(), ...
    'CrossHist', cross, 'CrossBins', [0 5]);

[R, meta] = loadParamfitCsv(p);
testCase.verifyEqual(meta.fit_type, 'phase');
expected_cols = [{'Density','FreqMean','FreqStd','SOphaseMean','SOphaseStd', ...
    'Theta','Volume','SOpowerMean'}, pk_cols_()];
testCase.verifyEqual(R.Properties.VariableNames, expected_cols);
% Mode FreqMeans in the fixture are 10.1 and 13.9, nearest bins 10 and
% 14: column means over finite entries are (1+5)/2 and (3+7)/2.
testCase.verifyEqual(R.SOpowerMean, [3; 5]);
end

function test_phase_without_crosshist_is_nan(testCase)
pf = synthetic_paramfit_('phase');
p = fullfile(testCase.TestData.dir, 'nocross.csv');
writeParamfitCsv(p, pf, 'phase', linspace(-pi, pi, 9), [10 12 14], fixture_stamp_());
R = loadParamfitCsv(p);
testCase.verifyTrue(all(isnan(R.SOpowerMean)));
end

function test_legacy_version_key(testCase)
% Legacy preamble keys: '# version:' maps to format, '# code_version:'
% to writer_version.
p = fullfile(testCase.TestData.dir, 'legacy.csv');
fid = fopen(p, 'w');
fprintf(fid, '# DYNAM-O parametric fit\n');
fprintf(fid, '# version: 1\n');
fprintf(fid, '# code_version: gui-app@1f2e3d\n');
fprintf(fid, 'Density,FreqMean,FreqStd,SOpowerMean,SOpowerStd,Theta,Volume\n');
fprintf(fid, '1,11,0.5,4,1.5,0,4.71238898038469\n');
fclose(fid);

[R, meta] = loadParamfitCsv(p);
testCase.verifyEqual(meta.format, 1);
testCase.verifyEqual(meta.writer_version, 'gui-app@1f2e3d');
testCase.verifyEqual(height(R), 1);
end

function test_bare_csv_is_format1(testCase)
% No preamble at all: format 1 by inference (reader rule 2).
p = fullfile(testCase.TestData.dir, 'bare.csv');
fid = fopen(p, 'w');
fprintf(fid, 'Density,FreqMean,FreqStd,SOpowerMean,SOpowerStd,Theta,Volume\n');
fprintf(fid, '1,11,0.5,4,1.5,0,4.71238898038469\n');
fclose(fid);
[~, meta] = loadParamfitCsv(p);
testCase.verifyEqual(meta.format, 1);
end

% -------------------------------------------------------------------------
function pf = synthetic_paramfit_(fit_type)
%SYNTHETIC_PARAMFIT_  Two-mode paramfit struct without a fit object
%
%   Inputs:
%       fit_type : char - 'power' or 'phase' -- required
%
%   Outputs:
%       pf : struct - .params (annotated table), .fitobj = [], .gof
switch fit_type
    case 'power'
        base = {'Density','FreqMean','FreqStd','SOpowerMean','SOpowerStd','Theta','Volume'};
        extra = {'PrefPhase','Coupling'};
        vals = [2.5 10.1 0.75 4 1.5 0.1 17.671458676442588; ...
                1.25 13.9 1.5 6 2 -0.2 23.561944901923447];
        extra_vals = [-1.2 0.35; 0.8 NaN];
    case 'phase'
        base = {'Density','FreqMean','FreqStd','SOphaseMean','SOphaseStd','Theta','Volume'};
        extra = {};
        vals = [0.02 10.1 0.75 -1.1 0.9 0 0.35; ...
                0.01 13.9 1.5 2.2 0.5 0 0.15];
        extra_vals = zeros(2, 0);
end
T = array2table([vals, extra_vals], 'VariableNames', [base, extra]);
% Pk* summary columns (schema-stable trailing block).
T.PkCount     = [12; 0];
T.PkFreq      = [10.05; NaN];
T.PkDuration  = [0.9; NaN];
T.PkBandwidth = [1.8; NaN];
T.PkHeight    = [4.2; NaN];
T.PkVolume    = [6.5; NaN];
T.PkArea      = [2.1; NaN];
T.PkPeakiness = [1.1; NaN];
T.PkSOpower   = [3.3; NaN];
T.PkSOphase   = [-0.5; NaN];

pf = struct('params', T, 'fitobj', [], ...
    'gof', struct('sse', 0.125, 'rsquare', 0.9375, 'dfe', 100, ...
                  'adjrsquare', 0.9325, 'rmse', 0.035355339059327376), ...
    'model_SOPH', [], 'wshed_img', []);
end

function c = pk_cols_()
%PK_COLS_  The ten Pk* column names in schema order
%
%   Inputs:
%       none
%
%   Outputs:
%       c : cell - column names matching annotateModesWithPeakStats
c = {'PkCount','PkFreq','PkDuration','PkBandwidth','PkHeight', ...
     'PkVolume','PkArea','PkPeakiness','PkSOpower','PkSOphase'};
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
