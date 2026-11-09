function tests = test_label_peaks_by_mode
%TEST_LABEL_PEAKS_BY_MODE  Per-peak mode labels, membership, backgrounds and CSV inputs
tests = functiontests(localfunctions);
end

function setupOnce(~)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('label_peaks_by_mode'))
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

function test_argmax_labels_match_pk_count(testCase)
% Under argmax the labels pick out exactly the peaks behind PkCount, and
% peaks outside the SOPH stages are NaN rather than 0.
[st, params, bg] = two_power_modes_();
labels = label_peaks_by_mode(st, params, 'Background', bg);

in_nrem = ismember(st.PeakStage, 1:3);
testCase.verifyTrue(all(isnan(labels(~in_nrem))));
testCase.verifyFalse(any(isnan(labels(in_nrem))));

T = annotateModesWithPeakStats(params, 'power', st(in_nrem, :), 'argmax', bg);
counts = arrayfun(@(m) sum(labels == m), 1:height(params));
testCase.verifyEqual(counts(:), T.PkCount(:));
testCase.verifyGreaterThan(sum(labels == 0), 0);   % some NREM peaks are background
end

function test_background_sources_agree(testCase)
% The same background, given directly, as aggregate Bg* columns, or inside
% a fit object, gives the same labels.
[st, params, bg] = two_power_modes_();
from_value = label_peaks_by_mode(st, params, 'Background', bg);

agg = params;
agg.BgPowSlope(:) = bg(1);
agg.BgFreqSlope(:) = bg(2);
agg.BgOffset(:) = bg(3);
from_columns = label_peaks_by_mode(st, agg);

from_fitobj = label_peaks_by_mode(st, struct('params', params, 'fitobj', plane_fitobj_(bg)));

testCase.verifyEqual(from_columns, from_value);
testCase.verifyEqual(from_fitobj, from_value);
end

function test_power_needs_a_background(testCase)
% A bare power params table has nowhere to find the background, so the
% call must fail rather than label without it.
[st, params] = two_power_modes_();
testCase.verifyError(@() label_peaks_by_mode(st, params), 'label_peaks_by_mode:NoBackground');
end

function test_mixed_subject_rows_rejected(testCase)
% Aggregate rows whose backgrounds differ come from different subjects.
[st, params, bg] = two_power_modes_();
agg = params;
agg.BgPowSlope(:) = bg(1);
agg.BgFreqSlope(:) = bg(2);
agg.BgOffset(:) = [bg(3); bg(3) + 0.5];
testCase.verifyError(@() label_peaks_by_mode(st, agg), ?MException);
end

function test_overlap_labels_nearest_and_members_keep_all(testCase)
% Two modes whose 3-sigma contours overlap. A peak inside both is labeled
% with the nearer mode, and mode_members marks it in both.
params = power_params_([10 12 1 12 3 0; 8 13 1 13 3 0]);
st = peak_table_([12.1; 12.9; 30], [12.1; 12.9; 12], [2; 2; 2]);

[labels, members] = label_peaks_by_mode(st, params, 'Assign', '3 sigma', 'Background', [0 0 0]);

testCase.verifyEqual(labels, [1; 2; 0]);
testCase.verifyEqual(members, logical([1 1; 1 1; 0 0]));
end

function test_phase_ignores_background_and_uses_contour(testCase)
% Phase modes need no background, run the '0.95 p' contour in place of
% argmax, and are recognized even though phase params carry a SOpowerMean
% column of their own.
[st, ~, ~] = two_power_modes_();
params = array2table([1 13.5 1 0 0.8 0 0.3 12], 'VariableNames', ...
    {'Density','FreqMean','FreqStd','SOphaseMean','SOphaseStd','Theta','Volume','SOpowerMean'});

[labels, members] = label_peaks_by_mode(st, params);

in_nrem = ismember(st.PeakStage, 1:3);
contour = assign_mode_peaks(params{:, 1:6}, 'phase', st(in_nrem, :), '0.95 p', nan(1, 3));
testCase.verifyEqual(members(in_nrem, 1), contour);
testCase.verifyEqual(labels(in_nrem) == 1, contour);
testCase.verifyGreaterThan(sum(contour), 0);
end

function test_peaks_without_sopower_are_outside_the_soph(testCase)
% A NREM peak with no SOpower never entered the histogram, so it is NaN
% like a REM or wake peak, not 0 (in the SOPH but in no mode).
[st, params, bg] = two_power_modes_();
in_nrem = find(ismember(st.PeakStage, 1:3));
st.SOpower(in_nrem(1:5)) = NaN;

labels = label_peaks_by_mode(st, params, 'Background', bg);

in_soph = soph_peak_mask(st, 1:3);
testCase.verifyEqual(sum(in_soph), numel(in_nrem) - 5);
testCase.verifyTrue(all(isnan(labels(in_nrem(1:5)))));
testCase.verifyEqual(isnan(labels), ~in_soph);
end

function test_csv_inputs_match_tables(testCase)
% A CLI run leaves only CSVs. Reading them must give the same labels as
% passing the tables and background directly, and the two files must
% name the same subject.
[st, params, bg] = two_power_modes_();
d = testCase.TestData.dir;
stats_csv = fullfile(d, 'S1_stats_table_C3.csv');
paramfit_csv = fullfile(d, 'S1_SOpower_paramfit_C3.csv');
writeStatsTableCsv(stats_csv, st, fixture_stamp_(), 'subjectID', 'S1');
paramfit = struct('params', params, 'fitobj', plane_fitobj_(bg), 'gof', [], 'peak_assign', 'argmax 1.5 sigma');
writeParamfitCsv(paramfit_csv, paramfit, 'power', -5:0.25:25, 2:0.2:16, fixture_stamp_(), 'subjectID', 'S1');

from_csv = label_peaks_by_mode(stats_csv, paramfit_csv);
from_tables = label_peaks_by_mode(st, params, 'Background', bg);
testCase.verifyEqual(from_csv, from_tables);

other_csv = fullfile(d, 'S2_SOpower_paramfit_C3.csv');
writeParamfitCsv(other_csv, paramfit, 'power', -5:0.25:25, 2:0.2:16, fixture_stamp_(), 'subjectID', 'S2');
testCase.verifyError(@() label_peaks_by_mode(stats_csv, other_csv), ?MException);
end


function [st, params, bg] = two_power_modes_()
%TWO_POWER_MODES_  Seeded peaks over two power modes and a tilted background
%
%   Inputs:
%       none
%
%   Outputs:
%       st     : table - 2000 peaks spread over 4-16 Hz and 0-25 dB, all
%                five stages represented
%       params : table - a sigma-like and a theta-alpha-like power mode
%       bg     : 1x3 double - background [PowSlope FreqSlope Offset]
rng_state = rng(7);
restore = onCleanup(@() rng(rng_state));
n = 2000;
st = peak_table_(4 + 12 * rand(n, 1), 25 * rand(n, 1), randi(5, n, 1));
params = power_params_([10 13.5 0.6 12 2 0; 6 8 0.8 15 3 0]);
bg = [0.05 0.02 0.1];
end

function params = power_params_(rows)
%POWER_PARAMS_  Power params table from [Density FreqMean FreqStd SOpowerMean SOpowerStd Theta] rows
%
%   Inputs:
%       rows : Mx6 double - one mode per row -- required
%
%   Outputs:
%       params : table - the six shape columns plus Volume
params = array2table([rows, ones(size(rows, 1), 1)], 'VariableNames', ...
    {'Density','FreqMean','FreqStd','SOpowerMean','SOpowerStd','Theta','Volume'});
end

function st = peak_table_(freq, sopower, stage)
%PEAK_TABLE_  Stats table in the canonical 14-column layout
%
%   Inputs:
%       freq    : Nx1 double - PeakFrequency (Hz) -- required
%       sopower : Nx1 double - SOpower (dB) -- required
%       stage   : Nx1 double - PeakStage -- required
%
%   Outputs:
%       st : table - one row per peak, other properties filled with
%            simple distinct values
n = numel(freq);
k = (1:n).';
st = table();
st.PeakTime      = k;
st.PeakFrequency = freq(:);
st.Duration      = 0.5 + mod(k, 7) / 4;
st.Bandwidth     = 1 + mod(k, 5) / 2;
st.Height        = 1 + mod(k, 11);
st.Volume        = 2 + mod(k, 13);
st.SegmentNum    = ones(n, 1);
st.Area          = 1 + mod(k, 3);
st.Peakiness     = 1 + mod(k, 4) / 4;
st.bbox_tl_s     = k - 0.25;
st.bbox_tl_Hz    = freq(:) - 0.5;
st.PeakStage     = stage(:);
st.SOpower       = sopower(:);
st.SOphase       = mod(k, 63) / 10 - pi;
end

function fitobj = plane_fitobj_(bg)
%PLANE_FITOBJ_  Fit object whose xxx/yyy/zzz coefficients are a known plane
%
%   Inputs:
%       bg : 1x3 double - [PowSlope FreqSlope Offset] -- required
%
%   Outputs:
%       fitobj : sfit - exact fit of bg(1)*P + bg(2)*F + bg(3), carrying
%                the coefficient names get_fit_background reads
[P, F] = meshgrid(0:25, 4:16);
Z = bg(1) * P + bg(2) * F + bg(3);
plane = fittype('xxx*x + yyy*y + zzz', 'independent', {'x', 'y'}, ...
    'dependent', 'z', 'coefficients', {'xxx', 'yyy', 'zzz'});
fitobj = fit([P(:) F(:)], Z(:), plane, 'StartPoint', [0 0 0]);
end

function stamp = fixture_stamp_()
%FIXTURE_STAMP_  Deterministic stamp for the CSV writers
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
