function [run_lengths, run_inds, filtered_vector] = consecutive_runs(data, min_len, max_len, value)
% CONSECUTIVE_RUNS Extract consecutive runs of a specified value from a binary
% vector.
%
% [run_lengths, run_inds, filtered_vector] = CONSECUTIVE_RUNS(data, min_len, max_len, value)
%
% Inputs:
% - data: a binary vector.
% - min_len: minimum length of consecutive runs.
% - max_len: maximum length of consecutive runs.
% - value: the value to extract consecutive runs of. If not provided, the
% function will extract consecutive runs of ones.
%
% Outputs:
% - run_lengths: vector containing the length of each consecutive run.
% - run_inds: cell array containing the start and end indices of each consecutive run.
% - filtered_vector: binary vector with ones at the positions of the extracted
% consecutive runs.
%
% If min_len and max_len are not specified, all consecutive runs of the
% specified value are returned. If only min_len is specified, all runs of
% length min_len or longer are returned. If both min_len and max_len are
% specified, runs with length between min_len and max_len (inclusive) are
% returned.
%
% If the value argument is not specified, the function extracts consecutive
% runs of ones.
%
% Examples:
%   lengths = consecutive_runs([1 0 1 1 0 1 1 1 0 0])
%   % returns [1 3]
%   [lengths, runs] = consecutive_runs([0 0 1 1 0 1 1 1 0 0 1], 2, 4, 1)
%   % returns lengths = [2 3] and run_inds = {[3 4], [6 8]}.
%
%    Copyright 2023 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%    Authors: Michael J. Prerau

%Default lengths impose no filtering
if nargin <2
    min_len=1;
end

if nargin <3
    max_len=inf;
end

%Check for valid lengths
if min_len>=max_len
    error('Min size must be less than max size');
end

%Select a single value if necessary
if nargin == 4
    data = data==value;
end

% Determine length of data
len = length(data);

% Compute maximum number of runs based on min_len
max_runs = floor(len / min_len);

% Initialize output variables
run_inds = cell(1, max_runs); % Preallocate cell array for maximum possible number of runs
run_lengths = zeros(1, max_runs); % Preallocate vector for maximum possible number of runs

% Initialize run variables
cur_run = 0;
cur_len = 0;

% Iterate through binary vector
for ii = 1:len
    if data(ii)
        % Increment current run
        cur_len = cur_len + 1;
    elseif ii>1 && data(ii-1)
        if cur_len >= min_len && cur_len <= max_len
            % End current run
            cur_run = cur_run + 1;
            runs_start = (ii - cur_len);
            runs_end = (ii - 1);
            run_inds{cur_run} = runs_start:runs_end;
            run_lengths(cur_run) = cur_len;
        end
        % Reset current run
        cur_len = 0;
    end
end

if data(len) && cur_len >= min_len && cur_len <= max_len
    % End current run
    cur_run = cur_run + 1;
    runs_start = (len - cur_len + 1);
    runs_end = (len);
    run_inds{cur_run} = runs_start:runs_end;
    run_lengths(cur_run) = cur_len;
end

% Trim output vectors to only include filled cells
run_inds = run_inds(1:cur_run);
run_lengths = run_lengths(1:cur_run);

%Create the filtered binary vector if needed
if nargout == 3
    filtered_vector = zeros(size(data));
    filtered_vector([run_inds{:}]) = 1;
end

end

