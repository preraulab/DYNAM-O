function tests = test_soph_binning
%TEST_SOPH_BINNING  Analytic SOPH histogram binning (no golden snapshot).
%
%   Drive the MATLAB SOPH histogram builder (TFPeakHistogram, backend
%   'matlab') with synthetic peaks at KNOWN (frequency, SO-feature)
%   locations and verify the 2-D histogram bins them analytically: right
%   counts in the right (c, freq) bins, and circular wrap on the phase
%   axis. Mirrors the Rust soph_binning test.
tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<*INUSD>
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('runDYNAMO'))
    addpath(repo_root); init_DYNAMO();
end
end

function test_sopower_binning(testCase)
% Peaks at known (freq, SO-power): 3@(13,10), 2@(11,5), 1@(15,0).
peak_freq = [13 13 13 11 11 15];
peak_c    = [10 10 10 5  5  0];
% Minimal time series (compute_rate=false + min_time_in_bin=0 -> raw counts).
Cmetric = [0 5 10 15 20];
stages  = 2 * ones(1, 5);
valid   = true(1, 5);

[Cmat, freq_cbins, C_cbins] = TFPeakHistogram(Cmetric, stages, 1.0, valid, valid, ...
    peak_freq, peak_c, ...
    'C_range', [0 20], 'C_binsizestep', [5 5], ...          % centers 0,5,10,15,20
    'freq_range', [10 16], 'freq_binsizestep', [1 1], ...   % centers 10..16
    'compute_rate', false, 'min_time_in_bin', 0, 'norm_dim', 0, ...
    'backend', 'matlab', 'verbose', false);

fb = @(v) nearest(freq_cbins, v);
cb = @(v) nearest(C_cbins, v);
testCase.verifyEqual(Cmat(cb(10), fb(13)), 3, 'AbsTol', 1e-9);
testCase.verifyEqual(Cmat(cb(5),  fb(11)), 2, 'AbsTol', 1e-9);
testCase.verifyEqual(Cmat(cb(0),  fb(15)), 1, 'AbsTol', 1e-9);
testCase.verifyEqual(sum(Cmat(:)), 6, 'AbsTol', 1e-9);
end

function test_sophase_circular(testCase)
% Two peaks straddle the +/-pi wrap; one at the center. None should drop.
peak_freq = [13 13 13];
peak_c    = [pi - 0.05, -pi + 0.05, 0];
Cmetric = linspace(-pi, pi, 8);
stages  = 2 * ones(1, numel(Cmetric));
valid   = true(1, numel(Cmetric));

Cmat = TFPeakHistogram(Cmetric, stages, 1.0, valid, valid, ...
    peak_freq, peak_c, ...
    'circular_Cmetric', true, 'circular_bounds', [-pi pi], ...
    'C_range', [-pi pi], 'C_binsizestep', [2*pi/8 2*pi/8], ...
    'freq_range', [11.5 14.5], 'freq_binsizestep', [1 1], ...
    'compute_rate', false, 'min_time_in_bin', 0, 'norm_dim', 0, ...
    'backend', 'matlab', 'verbose', false);

testCase.verifyEqual(sum(Cmat(:)), 3, 'AbsTol', 1e-9);  % no peaks dropped at the wrap
end

function i = nearest(centers, v)
[~, i] = min(abs(centers(:) - v));
end
