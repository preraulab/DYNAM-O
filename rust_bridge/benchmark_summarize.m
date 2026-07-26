function benchmark_summarize(varargin)
%BENCHMARK_SUMMARIZE  Aggregate rust_bridge/benchmarks/runs/*.json into a
%   single comparison table across machines + commits.
%
%   Usage:
%       benchmark_summarize()
%       benchmark_summarize('fixture', 'night')
%
%   Options:
%       'fixture'     — keep only runs of this fixture (default: all)
%       'filter_host' — regex on hostname (default: '')
%       'filter_arch' — regex on arch     (default: '')
%       'csv_out'     — path to write a CSV (default: '' = stdout only)

    p = inputParser;
    addParameter(p, 'fixture', '', @ischar);
    addParameter(p, 'filter_host', '', @ischar);
    addParameter(p, 'filter_arch', '', @ischar);
    addParameter(p, 'csv_out', '', @ischar);
    parse(p, varargin{:});
    S = p.Results;

    here = fileparts(mfilename('fullpath'));
    run_dir = fullfile(here, 'benchmarks', 'runs');
    files = dir(fullfile(run_dir, '*.json'));
    if isempty(files)
        fprintf('No benchmark runs under %s\n', run_dir);
        return;
    end

    % --- read + filter ---
    rows = {};
    for i = 1:numel(files)
        fpath = fullfile(files(i).folder, files(i).name);
        try
            rec = jsondecode(fileread(fpath));
        catch err
            fprintf(2, 'Skip %s: %s\n', files(i).name, err.message);
            continue;
        end
        if ~isempty(S.fixture) && ~strcmpi(rec.fixture, S.fixture), continue; end
        if ~isempty(S.filter_host) && isempty(regexp(rec.hostname, S.filter_host, 'once')), continue; end
        if ~isempty(S.filter_arch) && isempty(regexp(rec.arch, S.filter_arch, 'once')), continue; end

        backends = fieldnames(rec.results);
        for b = 1:numel(backends)
            r = rec.results.(backends{b});
            if ~isempty(r.error), continue; end
            row = struct();
            row.timestamp = rec.timestamp;
            row.host      = rec.hostname;
            row.os_arch   = sprintf('%s/%s', rec.os, rec.arch);
            row.cpu       = truncate(rec.cpu, 30);
            row.cores     = rec.cores;
            row.matlab    = matlab_ver_short(rec.matlab_version);
            row.dynamo_sha = rec.dynamo_sha;
            row.rs_sha    = rec.dynamo_rs_sha;
            row.fixture   = rec.fixture;
            row.backend   = backends{b};
            row.total_s   = getfield_or(r.timings, 'total', NaN);
            row.extract1_s = getfield_or(r.timings, 'extract_pass1', NaN);
            row.extract2_s = getfield_or(r.timings, 'extract_pass2', NaN);
            row.refine_s  = getfield_or(r.timings, 'refine', NaN);
            row.peaks_final = r.peaks.final;
            rows{end+1} = row; %#ok<AGROW>
        end
    end

    if isempty(rows)
        fprintf('No rows match filters.\n'); return;
    end

    % --- sort by (fixture, host, backend, timestamp) ---
    t = struct2table(cat(1, rows{:}));
    % Normalize string-type columns. With a single row, struct2table stores
    % char-vector fields as char arrays (not cellstr), which breaks brace
    % indexing below. Coercing to `string` gives a uniform array-of-strings
    % regardless of row count, indexable via `t.col(i)` consistently.
    string_cols = {'timestamp','host','os_arch','cpu','matlab', ...
                   'dev_sha','rs_sha','fixture','backend'};
    for c = string_cols
        if ismember(c{1}, t.Properties.VariableNames)
            t.(c{1}) = string(t.(c{1}));
        end
    end
    t = sortrows(t, {'fixture','host','backend','timestamp'});

    % --- print ---
    fprintf('\n');
    fprintf('%-19s %-28s %-14s %-8s %-10s %-10s %-8s %-8s %-8s\n', ...
        'timestamp', 'host', 'os/arch', 'backend', 'dynamo_sha', 'total_s', 'ext1_s', 'ext2_s', 'peaks');
    fprintf('%s\n', repmat('-', 1, 120));
    for i = 1:height(t)
        fprintf('%-19s %-28s %-14s %-8s %-10s %8.2f %8.2f %8.2f %8d\n', ...
            t.timestamp(i), truncate(char(t.host(i)), 28), t.os_arch(i), ...
            t.backend(i), t.dynamo_sha(i), t.total_s(i), t.extract1_s(i), ...
            t.extract2_s(i), t.peaks_final(i));
    end

    if ~isempty(S.csv_out)
        writetable(t, S.csv_out);
        fprintf('\nCSV written: %s\n', S.csv_out);
    end
end


function v = getfield_or(s, name, dflt)
    if isfield(s, name), v = s.(name); else, v = dflt; end
end


function s = truncate(s_in, n)
    s_in = char(s_in);
    if length(s_in) > n, s = [s_in(1:n-1) '…']; else, s = s_in; end
end


function s = matlab_ver_short(v)
    tok = regexp(v, 'R\d{4}[ab]', 'match', 'once');
    if isempty(tok), s = v; else, s = tok; end
end
