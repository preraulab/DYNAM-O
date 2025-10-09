function [staging, annotations] = read_staging(varargin)
%READ_STAGING  Read sleep staging data from a CSV file
%
%   Usage:
%       [staging, annotations] = read_staging(file_name, time_col, stage_col, 'Name', Value, ...)
%
%   Inputs:
%       file_name   : string - path to CSV file -- required
%       time_col    : integer - column number for time data (1-based) -- required
%       stage_col   : integer - column number for stage data (1-based) -- required
%
%   Name-Value Pairs:
%       'stage_vals'  : 1x7 cell array of strings or cell arrays with stage strings (default: predefined mapping)
%       'header_lines': integer - number of header lines to skip (default: 0)
%       'start_time'  : string in 'HH:MM:SS' format (default: nan) - reference start time
%       'epoch_dur'   : scalar - epoch duration in seconds (default: 30)
%       'plot_on'     : logical - if true, plot hypnogram with hypnoplot (default: true)
%
%   Outputs:
%       staging     : struct with fields:
%                       - times : vector of times in seconds
%                       - vals  : vector of stage values (0-6)
%       annotations : struct with fields (only for unmatched entries):
%                       - times      : vector of times in seconds
%                       - annotation : cell array of annotation strings

    % ---------------- Default stage mappings ----------------
    default_stage_vals = {{'art', 'artifact', 'A', '6'}, ...
                          {'wake', 'W', '5'}, ...
                          {'REM', 'R', '4'}, ...
                          {'N1', 'Stage 1', '1'}, ...
                          {'N2', 'Stage 2', '2'}, ...
                          {'N3', 'Stage 3', '3'}, ...
                          {'Unk', 'U', 'Unknown', '0'}};

    % ---------------- Input parser ----------------
    p = inputParser;
    p.KeepUnmatched = true;

    addRequired(p, 'file_name', @(x) ischar(x) || isstring(x));
    addRequired(p, 'time_col', @(x) isnumeric(x) && isscalar(x) && x>0 && mod(x,1)==0);
    addRequired(p, 'stage_col', @(x) isnumeric(x) && isscalar(x) && x>0 && mod(x,1)==0);

    addOptional(p, 'stage_vals', default_stage_vals, @(x) isempty(x) || (iscell(x) && numel(x)==7));
    addOptional(p, 'header_lines', 0, @(x) isnumeric(x) && isscalar(x) && x>=0);
    addOptional(p, 'start_time', NaN, @(x) ischar(x) || isstring(x) || isnan(x));
    addOptional(p, 'epoch_dur', 30, @(x) isnumeric(x) && isscalar(x) && x>0);
    addOptional(p, 'plot_on', true, @(x) islogical(x) && isscalar(x));

    parse(p, varargin{:});

    file_name   = p.Results.file_name;
    time_col    = p.Results.time_col;
    stage_col   = p.Results.stage_col;
    stage_vals  = p.Results.stage_vals;
    header_lines= p.Results.header_lines;
    start_time  = p.Results.start_time;
    epoch_dur   = p.Results.epoch_dur;
    plot_on     = p.Results.plot_on;

    if isempty(stage_vals)
        stage_vals = default_stage_vals;
    end

    % ---------------- Validate stage_vals ----------------
    if iscell(stage_vals) && numel(stage_vals)==7 && ~iscell(stage_vals{1})
        stage_vals = cellfun(@(x) {x}, stage_vals, 'UniformOutput', false);
    end

    if ~exist(file_name, 'file')
        error('File "%s" does not exist.', file_name);
    end

    % ---------------- Read CSV ----------------
    raw_data = readcell(file_name, 'Delimiter', ',', 'NumHeaderLines', header_lines);

    num_cols = size(raw_data, 2);
    if time_col > num_cols
        error('time_col (%d) exceeds number of columns (%d).', time_col, num_cols);
    end
    if stage_col > num_cols
        error('stage_col (%d) exceeds number of columns (%d).', stage_col, num_cols);
    end

    time_data  = string(raw_data(:, time_col));
    stage_data = string(raw_data(:, stage_col));

    % ---------------- Time conversion ----------------
    times_seconds = convert_time_to_seconds(time_data, start_time, epoch_dur);

    % ---------------- Stage processing ----------------
    [stage_values, unmatched_idx] = process_stage_data(stage_data, stage_vals);

    % ---------------- Outputs ----------------
    staging.times = times_seconds(:);
    staging.vals  = stage_values(:);

    if isempty(unmatched_idx)
        annotations = struct([]); % return empty
    else
        annotations.times = times_seconds(unmatched_idx);
        annotations.annotation = stage_data(unmatched_idx);
    end

    % ---------------- Optional plotting ----------------
    if plot_on
        figure;
        hypnoplot(staging.times, staging.vals);
    end
end

% ============================================================
function times_seconds = convert_time_to_seconds(time_data, start_time, epoch_dur)
    numeric_data = str2double(time_data);

    % ---------- Case 1: perfect ascending integers ----------
    if all(~isnan(numeric_data)) && all(mod(numeric_data,1)==0) && all(diff(numeric_data) >= 0)
        vals = numeric_data(:);
        start_sec = parse_start_time(start_time);
        times_seconds = start_sec + vals * epoch_dur;
        return;
    end

    % ---------- Case 2: numeric but not pure integers (seconds) ----------
    if all(~isnan(numeric_data))
        vals = numeric_data(:);
        start_sec = parse_start_time(start_time);
        times_seconds = start_sec + vals;
        return;
    end

    % ---------- Case 3: time strings ----------
    raw_seconds = nan(size(time_data));
    for i = 1:numel(time_data)
        tstr = strtrim(char(time_data(i)));
        parts = regexp(tstr, '^(\d{1,2}):(\d{2}):(\d{2})$', 'tokens');
        if ~isempty(parts)
            hh = str2double(parts{1}{1});
            mm = str2double(parts{1}{2});
            ss = str2double(parts{1}{3});
            raw_seconds(i) = hh*3600 + mm*60 + ss;
        end
    end

    raw_seconds = handle_midnight_crossover(raw_seconds);

    if ischar(start_time) || isstring(start_time)
        st = regexp(char(start_time), '^(\d{1,2}):(\d{2}):(\d{2})$', 'tokens');
        if ~isempty(st)
            hh = str2double(st{1}{1});
            mm = str2double(st{1}{2});
            ss = str2double(st{1}{3});
            ref_sec = hh*3600 + mm*60 + ss;
            times_seconds = raw_seconds - ref_sec;
            return;
        end
    end

    first_valid = raw_seconds(find(~isnan(raw_seconds),1,'first'));
    if isempty(first_valid)
        error('Dimension mismatch. Check for header lines to remove');
    end

    times_seconds = raw_seconds - first_valid;
end

% ============================================================
function start_sec = parse_start_time(start_time)
    if ischar(start_time) || isstring(start_time)
        st = regexp(char(start_time), '^(\d{1,2}):(\d{2}):(\d{2})$', 'tokens');
        if ~isempty(st)
            hh = str2double(st{1}{1});
            mm = str2double(st{1}{2});
            ss = str2double(st{1}{3});
            start_sec = hh*3600 + mm*60 + ss;
            return;
        end
    end
    start_sec = 0;
end

% ============================================================
function adjusted_times = handle_midnight_crossover(raw_seconds)
    adjusted_times = raw_seconds;
    day_sec = 24*3600;
    for i = 2:length(adjusted_times)
        if adjusted_times(i) < adjusted_times(i-1) - 12*3600
            adjusted_times(i:end) = adjusted_times(i:end) + day_sec;
        end
    end
end

% ============================================================
function [stage_values, unmatched_idx] = process_stage_data(stage_data, stage_vals)
    stage_numbers = [6, 5, 4, 3, 2, 1, 0]; % Artifact → Unknown
    stage_values = nan(size(stage_data));   % start unassigned

    for stage_idx = 1:length(stage_vals)
        strs = lower(string(stage_vals{stage_idx}));
        for i = 1:length(stage_data)
            cur = lower(string(stage_data(i)));
            if any(contains(cur, strs))
                stage_values(i) = stage_numbers(stage_idx);
            end
        end
    end

    unmatched_idx = find(isnan(stage_values));
    stage_values(unmatched_idx) = 6; % default unmatched to Artifact
end
