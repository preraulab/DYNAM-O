function [run_lengths, run_inds, run_values, filtered_vector] = get_chunks(data, min_len, max_len)
% GET_CHUNKS Extract consecutive runs of equal values from a vector
%
% [run_lengths, run_inds, run_values, filtered_vector] = GET_CHUNKS(data, min_len, max_len)
%
% Inputs:
% - data: a vector.
% - min_len: minimum length of consecutive runs.
% - max_len: maximum length of consecutive runs.
%
% Outputs:
% - run_lengths: vector containing the length of each consecutive run.
% - run_inds: cell array containing the start and end indices of each consecutive run.
% - run_values: the value of each run
% - filtered_vector: binary vector with ones at the positions of the extracted
% consecutive runs.
%
% If min_len and max_len are not specified, all consecutive runs of the
% specified value are returned. If only min_len is specified, all runs of
% length min_len or longer are returned. If both min_len and max_len are
% specified, runs with length between min_len and max_len (inclusive) are
% returned.
%
%
% Examples:
%   x = [2 2 5 5 5 6 6 6 6 4 7 2 2 2];
%   [lengths, runs] = get_chunks(x, 2, 4, 1)
%
%   % returns lengths = [ 2 3 4 3] and run_inds =  {[1 2]} {[3 4 5]} {[6 7 8 9]} {[12 13 14]}.
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

last_val = data(1);
% Iterate through binary vector
for ii = 1:len
    if data(ii)==last_val
        % Increment current run
        cur_len = cur_len + 1;
    elseif ii>1 && data(ii)~=last_val
        if cur_len >= min_len && cur_len <= max_len
            % End current run
            cur_run = cur_run + 1;
            runs_start = (ii - cur_len);
            runs_end = (ii - 1);
            run_inds{cur_run} = runs_start:runs_end;
            run_lengths(cur_run) = cur_len;
        end
        % Reset current run
        cur_len = 1;
        last_val = data(ii);
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

%Get the values for each run
if nargout >= 3
    run_values =  cellfun(@(y)data(y(1)),run_inds);
end

%Create the filtered binary vector if needed
if nargout == 4
    filtered_vector = zeros(size(data));
    filtered_vector([run_inds{:}]) = 1;
end

end

