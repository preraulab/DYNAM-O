function tests = test_read_staging_next_day
%TEST_READ_STAGING_NEXT_DAY  Staging clock times that fall before the recording start time
%
%   Staging time strings carry no date. A first staging time with an
%   earlier clock time than the recording start is either a first scored
%   epoch after midnight (valid, read as the next day) or staging that
%   truly begins before the recording (invalid). read_staging tells them
%   apart with 'record_duration', which load_data passes.
%
%   These tests need a read_staging that has the 'record_duration'
%   option. With an older sleep submodule they are filtered.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('runDYNAMO'))
    addpath(repo_root); init_DYNAMO();
end
reader_source = fileread(which('read_staging'));
testCase.TestData.reader_has_option = contains(reader_source, 'record_duration');
testCase.TestData.folder = tempname;
mkdir(testCase.TestData.folder);
end

function teardownOnce(testCase)
rmdir(testCase.TestData.folder, 's');
end

function test_first_scored_epoch_after_midnight(testCase)
% Recording starts 21:44, scoring starts 01:55: 4 h 11 min in.
assumeTrue(testCase, testCase.TestData.reader_has_option, 'read_staging has no record_duration option');
file_name = write_staging(testCase, 'after_midnight.csv', ["01:55:00"; "01:55:30"; "01:56:00"]);
staging = read_staging(file_name, 1, 2, 'start_time', '21:44:00', 'record_duration', 8*3600, 'plot_on', false);
first_scored = 4*3600 + 11*60;
verifyEqual(testCase, staging.times', [0, first_scored, first_scored + 30, first_scored + 60]);
end

function test_staging_before_the_recording_is_refused(testCase)
% Recording starts 21:44, staging starts 21:40. Read as the next day this
% is 23 h 56 min in, past the end of an 8 h recording.
assumeTrue(testCase, testCase.TestData.reader_has_option, 'read_staging has no record_duration option');
file_name = write_staging(testCase, 'before_start.csv', ["21:40:00"; "21:40:30"; "21:41:00"]);
read_it = @() read_staging(file_name, 1, 2, 'start_time', '21:44:00', 'record_duration', 8*3600, 'plot_on', false);
verifyError(testCase, read_it, 'read_staging:StagingBeforeRecording');
end

function test_midnight_crossing_inside_the_staging_is_unchanged(testCase)
% Rows that cross midnight after the start keep their offsets.
assumeTrue(testCase, testCase.TestData.reader_has_option, 'read_staging has no record_duration option');
file_name = write_staging(testCase, 'crossing.csv', ["23:59:00"; "23:59:30"; "00:00:00"; "00:00:30"]);
staging = read_staging(file_name, 1, 2, 'start_time', '21:44:00', 'record_duration', 8*3600, 'plot_on', false);
first_scored = 2*3600 + 15*60;
verifyEqual(testCase, staging.times', [0, first_scored, first_scored + 30, first_scored + 60, first_scored + 90]);
end

function file_name = write_staging(testCase, name, clock_times)
% Write a two-column staging file, clock time then stage
file_name = fullfile(testCase.TestData.folder, name);
writelines(clock_times + ",N2", file_name);
end
