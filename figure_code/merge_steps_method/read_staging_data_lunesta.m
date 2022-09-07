function [data] = read_staging_data_lunesta(filename)
%% Function for importing data from Lunesta text files
%% Initialize variables.
% filename = '/data/preraugp/archive/Lunesta Study/sleep_stages/xLun03-Night2.txt.vmrk';
delimiter = ',';
startRow = find_text_in_file(filename,'Mk1=New Segment');

%% Format string for each line of text:
%   column1: text (%q)
%	column2: text (%q)
%   column3: double (%f)
%	column4: double (%f)
%   column5: double (%f)
%	column6: text (%q)
% For more information, see the TEXTSCAN documentation.
formatSpec = '%q%q%f%f%f%q%[^\n\r]';

%% Open the text file.
fileID = fopen(filename,'r');

%% Read columns of data according to format string.
% This call is based on the structure of the file used to generate this
% code. If an error occurs for a different file, try regenerating the code
% from the Import Tool.
% textscan(fileID, '%[^\n\r]', startRow-1, 'WhiteSpace', '', 'ReturnOnError', false);
dataArray = textscan(fileID, formatSpec,'Delimiter', delimiter, 'headerlines',startRow,'ReturnOnError', false);

%% Close the text file.
fclose(fileID);

%% Post processing for unimportable data.
% No unimportable data rules were applied during the import, so no post
% processing code is included. To generate code which works for
% unimportable data, select unimportable cells in a file and regenerate the
% script.

%% Create output variable
dataArray([3, 4, 5]) = cellfun(@(x) num2cell(x), dataArray([3, 4, 5]), 'UniformOutput', false);

% Note : rescored files have some parsing issue such that the last 2 empty
% columns have different number of empty elements and this concatentaion
% did not work.

data = [dataArray{1:end-1}];
% data = horzcat(dataArray{1:end-1});

%% Clear temporary variables
clearvars filename delimiter startRow formatSpec fileID dataArray ans;