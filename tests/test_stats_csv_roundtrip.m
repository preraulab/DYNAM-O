function tests = test_stats_csv_roundtrip
%TEST_STATS_CSV_ROUNDTRIP  writeStatsTableCsv/loadStatsTable formats 1-3
tests = functiontests(localfunctions);
end

function setupOnce(~)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('writeStatsTableCsv'))
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

function test_write_read_roundtrip(testCase)
T = synthetic_stats_table_();
p = fullfile(testCase.TestData.dir, 'S1_stats_table_C3.csv');
writeStatsTableCsv(p, T, fixture_stamp_(), 'subjectID', 'S1');

[R, meta] = loadStatsTable(p);
testCase.verifyEqual(meta.format, 3);
testCase.verifyEqual(meta.writer, 'dynamo-matlab');
testCase.verifyEqual(meta.writer_version, '1.0.0+abcdef123456');
testCase.verifyEqual(meta.kernel_version, 'matlab-native');
testCase.verifyEqual(meta.subjectID, 'S1');

% Shortest-round-trip encoding makes the numeric round trip exact,
% including the NaN SOpower entry (isequaln treats NaN as equal).
testCase.verifyTrue(isequaln(R.PeakTime, T.PeakTime));
testCase.verifyTrue(isequaln(R.SOpower, T.SOpower));
testCase.verifyTrue(isequaln(R.SOphase, T.SOphase));
testCase.verifyTrue(isequaln(R.SegmentNum, double(T.SegmentNum)));
% BoundingBox decomposes to its top-left pair only.
testCase.verifyTrue(isequaln(R.bbox_tl_s, T.BoundingBox(:, 1)));
testCase.verifyTrue(isequaln(R.bbox_tl_Hz, T.BoundingBox(:, 2)));
% Non-schema columns must not leak into the file.
testCase.verifyFalse(ismember('HeightData', R.Properties.VariableNames));
end

function test_header_byte_identical(testCase)
% The header line must match the Rust write_stats_csv header exactly.
T = synthetic_stats_table_();
p = fullfile(testCase.TestData.dir, 'hdr.csv');
writeStatsTableCsv(p, T, fixture_stamp_());

fid = fopen(p, 'r');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
line = fgetl(fid);
while ischar(line) && startsWith(line, '#')
    line = fgetl(fid);
end
expected = ['PeakTime,PeakFrequency,Duration,Bandwidth,Height,Volume,' ...
    'SegmentNum,Area,Peakiness,bbox_tl_s,bbox_tl_Hz,PeakStage,SOpower,SOphase'];
testCase.verifyEqual(line, expected);
end

function test_v1_fixture(testCase)
% Hand-written legacy 16-column file: reads as format 1, mapped onto the
% canonical 14 columns with the redundant extent pair dropped.
p = fullfile(testCase.TestData.dir, 'v1.csv');
fid = fopen(p, 'w');
fprintf(fid, ['PeakTime,PeakFrequency,Duration,Bandwidth,Height,Volume,' ...
    'SegmentNum,Area,Peakiness,bbox_tl_s,bbox_tl_Hz,bbox_width_s,' ...
    'bbox_height_Hz,PeakStage,SOpower,SOphase\n']);
fprintf(fid, '10.5,12.25,1.5,2,3.75,8.5,1,3,1.25,10,11.25,1.5,2,2,0.5,-1.5\n');
fclose(fid);

[R, meta] = loadStatsTable(p);
testCase.verifyEqual(meta.format, 1);
testCase.verifyEqual(width(R), 14);
testCase.verifyEqual(R.Properties.VariableNames{10}, 'bbox_tl_s');
testCase.verifyEqual(R.Duration, 1.5);
testCase.verifyFalse(ismember('bbox_width_s', R.Properties.VariableNames));
end

function test_v2_fixture(testCase)
% Bare canonical 14-column file: format 2, empty stamp fields.
p = fullfile(testCase.TestData.dir, 'v2.csv');
fid = fopen(p, 'w');
fprintf(fid, ['PeakTime,PeakFrequency,Duration,Bandwidth,Height,Volume,' ...
    'SegmentNum,Area,Peakiness,bbox_tl_s,bbox_tl_Hz,PeakStage,SOpower,SOphase\n']);
fprintf(fid, '10.5,12.25,1.5,2,3.75,8.5,1,3,1.25,10,11.25,2,0.5,-1.5\n');
fclose(fid);

[R, meta] = loadStatsTable(p);
testCase.verifyEqual(meta.format, 2);
testCase.verifyEqual(meta.writer, '');
testCase.verifyEqual(height(R), 1);
end

function test_bad_header_errors(testCase)
p = fullfile(testCase.TestData.dir, 'bad.csv');
fid = fopen(p, 'w');
fprintf(fid, 'subjectID,PeakTime,BoundingBox\n');
fprintf(fid, 'S1,10.5,[10 11 1 2]\n');
fclose(fid);
testCase.verifyError(@() loadStatsTable(p), 'loadStatsTable:badHeader');
end

function test_missing_column_errors(testCase)
T = synthetic_stats_table_();
T = removevars(T, 'SOphase');
p = fullfile(testCase.TestData.dir, 'missing.csv');
testCase.verifyError(@() writeStatsTableCsv(p, T, fixture_stamp_()), ...
    'writeStatsTableCsv:missingColumn');
end

% -------------------------------------------------------------------------
function T = synthetic_stats_table_()
%SYNTHETIC_STATS_TABLE_  Small stats_table with awkward values
%
%   Inputs:
%       none
%
%   Outputs:
%       T : table - 4 rows with a BoundingBox matrix column, a NaN
%           SOpower, an irrational SOphase, and a non-schema HeightData
%           cell column that the writer must drop
T = table();
T.PeakTime      = [10.123456789012; 20.5; 1/3; 40000.25];
T.PeakFrequency = [11.05; 13.4; 9.999999; 15];
T.Duration      = [1.5; 0.75; 2.25; 0.5];
T.Bandwidth     = [2; 1.6; 3.2; 0.8];
T.Height        = [3.75; 100.5; 0.001234567890123456; 7];
T.Volume        = [8.5; 20; 0.25; 3.125];
T.SegmentNum    = [1; 2; 3; 4];
T.Area          = [3; 5.5; 0.125; 2];
T.Peakiness     = [1.25; NaN; 2.5; 0.75];
T.BoundingBox   = [10 11 1.5 2; 20 12 0.75 1.6; 0.25 8 2.25 3.2; 39999 14 0.5 0.8];
T.PeakStage     = [2; 4; 1; 5];
T.SOpower       = [0.5; NaN; -1.25; 2.5];
T.SOphase       = [-1.5; pi/4; 0; -pi + 1e-9];
T.HeightData    = {rand(3,1); rand(2,1); rand(4,1); rand(1,1)};
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
