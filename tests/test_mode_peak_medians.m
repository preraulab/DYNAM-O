function tests = test_mode_peak_medians
%TEST_MODE_PEAK_MEDIANS  Pk* median aggregation + the PkPower column
tests = functiontests(localfunctions);
end

function setupOnce(~)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('annotateModesWithPeakStats'))
    addpath(repo_root);
    init_DYNAMO();
end
end

function test_median_resists_a_tail_event(testCase)
% Three member peaks, the third a giant tail event: the median must sit at
% the middle value where a mean would be dragged to ~343. Mirrors the Rust
% mode_peaks test medians_resist_a_tail_event (same fixture).
st = peak_table_([13.0; 13.1; 13.2], [5.0; 5.5; 6.0], [10; 20; 999]);
s = mode_peak_stats(st, true(3, 1));
testCase.verifyEqual(s.count, 3);
testCase.verifyEqual(s.Height, 20, 'AbsTol', 1e-12);
testCase.verifyEqual(s.SOpower, 5.5, 'AbsTol', 1e-12);
% Even counts average the two middle values (Rust / numpy parity).
s2 = mode_peak_stats(st, [true; true; false]);
testCase.verifyEqual(s2.Height, 15, 'AbsTol', 1e-12);
end

function test_pkpower_reanchors_to_the_baseline(testCase)
% PkPower = median over member peaks of pow2db(Height x
% baseline(PeakFrequency)) with clamped linear interpolation - the
% analytic points pin the Rust peak_power_db fixture: baseline [0.1, 0.4]
% on [10, 20] Hz.
% Single member at 15 Hz, Height 40: interpolated baseline 0.25 ->
% pow2db(40 x 0.25) = 10 dB exactly.
T = mode_table_(15, 1);
bl = struct('values', [0.1, 0.4], 'freqs', [10, 20]);
out1 = annotateModesWithPeakStats(T, 'power', peak_table_(15, 0, 40), ...
    '0.99 p', nan(1, 3), bl);
testCase.verifyEqual(out1.PkPower(1), 10, 'AbsTol', 1e-12);
% Three members, clamped at both axis ends: per-peak powers are
% [10, pow2db(10 x 0.1), pow2db(10 x 0.4)] -> median pow2db(4).
st = peak_table_([15; 10; 25], [0; 0; 0], [40; 10; 10]);
out = annotateModesWithPeakStats(T, 'power', st, '0.99 p', nan(1, 3), bl);
testCase.verifyEqual(out.PkPower(1), pow2db(4), 'AbsTol', 1e-12);
% Without a baseline the column is still present, as NaN.
out2 = annotateModesWithPeakStats(T, 'power', st, '0.99 p', nan(1, 3));
testCase.verifyTrue(ismember('PkPower', out2.Properties.VariableNames));
testCase.verifyTrue(all(isnan(out2.PkPower)));
end

function test_pk_columns_in_schema_order(testCase)
% The eleven Pk* columns appear in the shared cross-implementation order.
T = mode_table_(13, 1);
st = peak_table_(13, 5, 10);
out = annotateModesWithPeakStats(T, 'power', st, 'argmax', [0 0 0]);
vn = out.Properties.VariableNames;
want = {'PkCount','PkFreq','PkDuration','PkBandwidth','PkHeight', ...
        'PkPower','PkVolume','PkArea','PkPeakiness','PkSOpower','PkSOphase'};
testCase.verifyEqual(vn(end-numel(want)+1:end), want);
end


function T = mode_table_(fmean, n)
%MODE_TABLE_  Minimal params table with N identical wide modes at FMEAN
%
%   Inputs:
%       fmean : double - mode frequency center (Hz) -- required
%       n     : double - number of mode rows -- required
%
%   Outputs:
%       T : table - [Density FreqMean FreqStd SOpowerMean SOpowerStd Theta]
rows = repmat([10, fmean, 20, 0, 50, 0], n, 1);
T = array2table(rows, 'VariableNames', ...
    {'Density','FreqMean','FreqStd','SOpowerMean','SOpowerStd','Theta'});
end

function st = peak_table_(freq, sopower, height)
%PEAK_TABLE_  Minimal stats table with the columns the Pk machinery reads
%
%   Inputs:
%       freq    : [n x 1] double - PeakFrequency -- required
%       sopower : [n x 1] double - SOpower -- required
%       height  : [n x 1] double - Height (linear prominence) -- required
%
%   Outputs:
%       st : table - one row per peak, zero-filled remaining properties
n = numel(freq);
z = zeros(n, 1);
st = table(freq(:), z, z, height(:), z, z, z, sopower(:), z, ...
    'VariableNames', {'PeakFrequency','Duration','Bandwidth','Height', ...
                      'Volume','Area','Peakiness','SOpower','SOphase'});
end
