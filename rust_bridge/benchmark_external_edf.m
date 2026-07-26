function out_path = benchmark_external_edf(edf_path, staging_path, varargin)
%BENCHMARK_EXTERNAL_EDF  Head-to-head runDYNAMO benchmark on a user-supplied
%   EDF + staging file. Same JSON schema as `benchmark_runDYNAMO`, plus an
%   `external_edf` block recording the source file metadata so cross-host
%   comparisons stay apples-to-apples.
%
%   Use this when you want to know "is my real-patient run slow because the
%   data is longer, or because something is off?" — point this at the same
%   EDF the DYNAMOApp loads, compare its `total` against the bundled
%   `night` fixture's number, and the difference is the data-length /
%   pipeline ratio in isolation from DYNAMOApp wrapper overhead (CSV
%   save, EDF parse, plot rendering, UI drawnow).
%
%   Usage:
%       benchmark_external_edf( ...
%           '/path/to/recording.edf', ...
%           '/path/to/staging.csv', ...
%           'stages_col', 5, ...
%           'times_col',  1, ...
%           'channel',    'EEG Fpz-Cz', ...
%           'header_lines', 7, ...
%           'delimiter',    ',')
%
%   Required positional:
%       edf_path     - path to .edf / .edf+ file
%       staging_path - path to the delimited staging file
%
%   Required name-value:
%       'stages_col'  - integer, 1-based column of stage codes in staging file
%       'times_col'   - integer, 1-based column of time / epoch values
%       'channel'     - char, EDF channel label (or 'ChA-ChB' to rereference)
%
%   Optional name-value:
%       'header_lines' - integer, lines to skip in staging file (default: 0)
%       'delimiter'    - char, field separator in staging (default: ',')
%       'stage_vals_in'- 1x7 cell of stage strings (overrides default mapping;
%                        order: {Artifact, Wake, REM, N1, N2, N3, Unknown})
%       'backends'     - cellstr subset of {'rust','matlab'} (default: both)
%       'warmup'       - logical, do a discarded warm-up run per backend
%                        before timing (default: true)
%       'push'         - 'auto' (prompt), 'yes', or 'no' (default: 'auto')
%       'out_dir'      - where to write the JSON (default: benchmarks/runs/)
%       'patient_id'   - optional opaque label included in the JSON; useful
%                        for tracking same-EDF runs across machines without
%                        leaking PHI in the filename (default: '')
%
%   Output:
%       out_path - absolute path to the JSON file written, or '' if all
%                  backends errored (in which case nothing is written).

    p = inputParser;
    addRequired(p, 'edf_path', @(x) ischar(x) || isstring(x));
    addRequired(p, 'staging_path', @(x) ischar(x) || isstring(x));
    addParameter(p, 'stages_col', [], @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'times_col',  [], @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'channel',    '', @(x) (ischar(x) || isstring(x)) && ~isempty(char(x)));
    addParameter(p, 'header_lines', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'delimiter',    ',', @(x) ischar(x) || isstring(x));
    addParameter(p, 'stage_vals_in', {}, @iscell);
    addParameter(p, 'backends', {'rust','matlab'}, @iscellstr);
    addParameter(p, 'warmup', true, @islogical);
    addParameter(p, 'push', 'auto', @(x) any(strcmpi(x, {'auto','yes','no'})));
    here = fileparts(mfilename('fullpath'));
    addParameter(p, 'out_dir', fullfile(here, 'benchmarks', 'runs'), @ischar);
    addParameter(p, 'patient_id', '', @(x) ischar(x) || isstring(x));
    parse(p, edf_path, staging_path, varargin{:});
    S = p.Results;

    % Required name-values that addParameter can't enforce — check explicitly
    % so a missing one fails fast with a clear message rather than during
    % load_data with a cryptic error.
    assert(~isempty(S.stages_col), 'benchmark_external_edf:missingArg', ...
        'Required name-value ''stages_col'' not provided.');
    assert(~isempty(S.times_col), 'benchmark_external_edf:missingArg', ...
        'Required name-value ''times_col'' not provided.');
    assert(~isempty(char(S.channel)), 'benchmark_external_edf:missingArg', ...
        'Required name-value ''channel'' not provided.');
    assert(exist(char(S.edf_path), 'file') == 2, ...
        'EDF not found: %s', char(S.edf_path));
    assert(exist(char(S.staging_path), 'file') == 2, ...
        'Staging file not found: %s', char(S.staging_path));

    if ~exist(S.out_dir, 'dir'); mkdir(S.out_dir); end

    % Make load_data + runDYNAMO discoverable when invoked from any cwd.
    dev_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(genpath(dev_root));

    % --- system info ---
    sysinfo = collect_sysinfo();

    % --- repo SHAs ---
    shas.dynamo_sha = git_short_sha(dev_root);
    shas.dynamo_dirty = git_is_dirty(dev_root);
    rs_root = find_dynamo_rs_root(here);
    shas.dynamo_rs_sha = git_short_sha(rs_root);
    shas.dynamo_rs_dirty = git_is_dirty(rs_root);

    % --- load EDF + staging once, then time the runDYNAMO calls ---
    fprintf('Loading EDF: %s\n', char(S.edf_path));
    fprintf('       staging: %s\n', char(S.staging_path));
    fprintf('       channel: %s  (cols: stages=%d times=%d, header_lines=%d, delim=''%s'')\n', ...
        char(S.channel), S.stages_col, S.times_col, S.header_lines, char(S.delimiter));
    t_load = tic;
    if isempty(S.stage_vals_in)
        [data, Fs, stage_times, stage_vals] = load_data( ...
            char(S.edf_path), char(S.staging_path), ...
            S.stages_col, S.times_col, char(S.channel), ...
            'header_lines', S.header_lines, ...
            'delimiter',    char(S.delimiter));
    else
        [data, Fs, stage_times, stage_vals] = load_data( ...
            char(S.edf_path), char(S.staging_path), ...
            S.stages_col, S.times_col, char(S.channel), ...
            'header_lines', S.header_lines, ...
            'delimiter',    char(S.delimiter), ...
            'stage_vals_in', S.stage_vals_in);
    end
    load_time_s = toc(t_load);
    duration_s  = numel(data) / double(Fs);
    fprintf('Loaded in %.2fs.  duration=%.1f min  Fs=%g Hz  staged epochs=%d\n', ...
        load_time_s, duration_s/60, double(Fs), numel(stage_vals));

    % EDF metadata block included in the result JSON (no PHI by default —
    % we only record the file basename, length, sample rate, and stage
    % distribution; the patient_id field is opt-in).
    [~, edf_base, edf_ext] = fileparts(char(S.edf_path));
    [~, stg_base, stg_ext] = fileparts(char(S.staging_path));
    edf_info.edf_filename     = [edf_base edf_ext];
    edf_info.staging_filename = [stg_base stg_ext];
    edf_info.channel          = char(S.channel);
    edf_info.fs_hz            = double(Fs);
    edf_info.duration_s       = duration_s;
    edf_info.n_samples        = numel(data);
    edf_info.staged_epochs    = numel(stage_vals);
    edf_info.stage_histogram  = struct();
    for v = unique(stage_vals(:))'
        edf_info.stage_histogram.(sprintf('stage_%d', v)) = sum(stage_vals == v);
    end
    edf_info.load_time_s = load_time_s;
    edf_info.patient_id  = char(S.patient_id);

    % --- run each backend ---
    results = struct();
    for b = 1:numel(S.backends)
        backend = S.backends{b};
        fprintf('\n=== Benchmarking backend=''%s'' on external EDF ===\n', backend);
        try
            if S.warmup
                fprintf('  Warm-up run (discarded)...\n');
                run_once(data, Fs, stage_times, stage_vals, backend);
            end
            fprintf('  Timed run...\n');
            [timings, peaks, info] = run_once(data, Fs, stage_times, stage_vals, backend);
            results.(backend) = struct('timings', timings, 'peaks', peaks, ...
                'recording_duration_s', info.recording_duration_s, ...
                'pipeline_options', info.pipeline_options, ...
                'error', []);
        catch err
            results.(backend) = struct('timings', struct(), 'peaks', struct(), ...
                'error', struct('identifier', err.identifier, 'message', err.message));
            fprintf(2, '  Backend ''%s'' failed: %s\n', backend, err.message);
        end
    end

    % Bail if every backend errored — no useful data to record.
    all_failed = true;
    backend_names = fieldnames(results);
    for i = 1:numel(backend_names)
        if isempty(results.(backend_names{i}).error)
            all_failed = false; break;
        end
    end
    if all_failed
        fprintf(2, ['\nAll backends failed — not writing a benchmark JSON.\n' ...
                    'Fix the error(s) above and rerun.\n']);
        out_path = '';
        return;
    end

    % --- assemble record ---
    record = struct();
    record.schema_version = 2;
    record.timestamp = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
    record.hostname = sysinfo.hostname;
    record.os = sysinfo.os;
    record.os_version = sysinfo.os_version;
    record.arch = sysinfo.arch;
    record.cpu = sysinfo.cpu;
    record.cores = sysinfo.cores;
    record.ram_gb = sysinfo.ram_gb;
    record.matlab_version = version;
    record.dynamo_sha = shas.dynamo_sha;
    record.dynamo_dirty = shas.dynamo_dirty;
    record.dynamo_rs_sha = shas.dynamo_rs_sha;
    record.dynamo_rs_dirty = shas.dynamo_rs_dirty;
    record.fixture = 'external_edf';   % distinguishes from segment / night
    record.warmup = S.warmup;
    record.external_edf = edf_info;
    record.results = results;

    % --- write JSON ---
    stamp = datestr(now, 'yyyy-mm-dd-HHMMSS');
    safe_host = regexprep(sysinfo.hostname, '[^A-Za-z0-9_-]', '_');
    safe_edf  = regexprep(edf_base, '[^A-Za-z0-9_-]', '_');
    fname = sprintf('%s__%s__%s-%s__edf-%s.json', stamp, safe_host, ...
                    sysinfo.os, sysinfo.arch, safe_edf);
    out_path = fullfile(S.out_dir, fname);
    fid = fopen(out_path, 'w');
    fwrite(fid, jsonencode(record, 'PrettyPrint', true));
    fclose(fid);
    fprintf('\nBenchmark written: %s\n', out_path);

    % --- print summary ---
    print_summary(record);

    % --- commit + push ---
    maybe_push(out_path, S.push, sysinfo, shas);
end


% =====================================================================
% run_once — single timed runDYNAMO invocation
% =====================================================================
function [timings, peaks, info] = run_once(data, Fs, stage_times, stage_vals, backend)
    % show_pbar=false on the detection_options struct skips the (now
    % defunct anyway) waitbar widget, plot_on=false skips the summary
    % figure. fit_param_basis / fit_spline_basis are also off — their
    % MATLAB-side cost would otherwise add ~5-10s of noise that's
    % unrelated to the extract speedup we care about.
    det_opts = detection_opts();
    det_opts.show_pbar = false;
    det_opts.backend = backend;

    [stats_table, ~, ~, ~, data_time_range, ~, ~, ~, timings] = runDYNAMO( ...
        data, Fs, stage_times, stage_vals, [], ...
        baseline_opts(), det_opts, SOpowerphasehist_opts(), ...
        'fit_param_basis', false, 'fit_spline_basis', false, ...
        'plot_on', false, 'verbose', true);
    peaks.final = height(stats_table);
    info.recording_duration_s = data_time_range(2) - data_time_range(1);
    info.pipeline_options = pipeline_options_snapshot(det_opts);
end


function snap = pipeline_options_snapshot(det_opts)
    % Capture only the detection_options fields that materially affect
    % timing / parity. Mirrors benchmark_runDYNAMO's snapshot so the
    % two scripts produce comparable JSON layouts.
    keys = {'backend', 'seg_time', 'downsample_spect', ...
            'merge_thresh', 'quality_setting', 'parallel_mode'};
    snap = struct();
    for i = 1:numel(keys)
        if isfield(det_opts, keys{i})
            snap.(keys{i}) = det_opts.(keys{i});
        end
    end
end


% =====================================================================
% Shared helpers — duplicated from benchmark_runDYNAMO.m intentionally
% so this file is self-contained. If we add a third benchmark variant
% they should be lifted into benchmark_helpers.m.
% =====================================================================
function sysinfo = collect_sysinfo()
    sysinfo.hostname = char(java.net.InetAddress.getLocalHost.getHostName);
    if ispc
        sysinfo.os = 'windows';
        [~, vstr] = system('ver');
        sysinfo.os_version = strtrim(vstr);
        sysinfo.arch = getenv('PROCESSOR_ARCHITECTURE');
        [~, cpu] = system('wmic cpu get name /value');
        sysinfo.cpu = strtrim(regexprep(cpu, '.*Name=', ''));
    elseif ismac
        sysinfo.os = 'darwin';
        [~, v] = system('sw_vers -productVersion'); sysinfo.os_version = strtrim(v);
        [~, a] = system('uname -m');                sysinfo.arch = strtrim(a);
        [~, c] = system('sysctl -n machdep.cpu.brand_string'); sysinfo.cpu = strtrim(c);
    else
        sysinfo.os = 'linux';
        [~, v] = system('uname -r');                sysinfo.os_version = strtrim(v);
        [~, a] = system('uname -m');                sysinfo.arch = strtrim(a);
        [~, c] = system('grep -m1 "model name" /proc/cpuinfo | cut -d: -f2');
        sysinfo.cpu = strtrim(c);
    end
    sysinfo.cores = feature('numCores');
    sysinfo.ram_gb = round(memory_total_gb(), 1);
end


function gb = memory_total_gb()
    try
        if ispc
            [~, r] = system('wmic ComputerSystem get TotalPhysicalMemory /value');
            tok = regexp(r, 'TotalPhysicalMemory=(\d+)', 'tokens', 'once');
            if isempty(tok), gb = NaN; return; end
            gb = str2double(tok{1}) / 1024^3;
        elseif ismac
            [~, r] = system('sysctl -n hw.memsize');
            gb = str2double(strtrim(r)) / 1024^3;
        else
            [~, r] = system('grep MemTotal /proc/meminfo | awk ''{print $2}''');
            gb = str2double(strtrim(r)) / 1024^2;
        end
    catch
        gb = NaN;
    end
end


function sha = git_short_sha(repo_root)
    [rc, out] = system(sprintf('git -C %s rev-parse --short HEAD 2>/dev/null', ...
        quote(repo_root)));
    if rc == 0, sha = strtrim(out); else, sha = ''; end
end


function d = git_is_dirty(repo_root)
    [rc, out] = system(sprintf('git -C %s status --porcelain 2>/dev/null | head -1', ...
        quote(repo_root)));
    d = (rc == 0) && ~isempty(strtrim(out));
end


function q = quote(path_str)
    q = ['"' strrep(path_str, '"', '\"') '"'];
end


function rs_root = find_dynamo_rs_root(rust_bridge_dir)
    rs_root = fullfile(fileparts(fileparts(rust_bridge_dir)), 'DYNAM-O_rs');
    if ~(exist(fullfile(rs_root, '.git'), 'dir') || ...
         exist(fullfile(rs_root, '.git'), 'file'))
        rs_root = '';
    end
end


function print_summary(record)
    fprintf('\n');
    fprintf('───────────────────────────────────────────────────────────────\n');
    fprintf(' External-EDF benchmark summary\n');
    fprintf('───────────────────────────────────────────────────────────────\n');
    fprintf('  Host: %s  (%s %s / %s, %d cores, %.1f GB RAM)\n', ...
        record.hostname, record.os, record.os_version, record.arch, ...
        record.cores, record.ram_gb);
    fprintf('  CPU:  %s\n', record.cpu);
    fprintf('  MATLAB: %s\n', record.matlab_version);
    fprintf('  DYNAM-O: %s%s  |  DYNAM-O_rs: %s%s\n', ...
        record.dynamo_sha, dirty_mark(record.dynamo_dirty), ...
        record.dynamo_rs_sha,  dirty_mark(record.dynamo_rs_dirty));
    fprintf('  EDF:    %s  channel=%s  duration=%.1f min  Fs=%g Hz\n', ...
        record.external_edf.edf_filename, record.external_edf.channel, ...
        record.external_edf.duration_s/60, record.external_edf.fs_hz);
    fprintf('  Warmup: %s\n', bool2str(record.warmup));
    fprintf('\n');
    backends = fieldnames(record.results);
    for i = 1:numel(backends)
        b = backends{i};
        r = record.results.(b);
        if ~isempty(r.error)
            fprintf('  [%s] ERROR: %s\n', b, r.error.message);
            continue;
        end
        t = r.timings;
        fprintf('  [%s]  total=%.2fs  peaks(final)=%d\n', b, ...
            getfield_or(t, 'total', NaN), r.peaks.final);
    end
    fprintf('───────────────────────────────────────────────────────────────\n');
end


function v = getfield_or(s, name, dflt)
    if isfield(s, name), v = s.(name); else, v = dflt; end
end
function s = dirty_mark(d), if d, s = '[dirty]'; else, s = ''; end, end
function s = bool2str(b),    if b, s = 'true';   else, s = 'false'; end, end


function maybe_push(out_path, push_mode, sysinfo, shas)
    here = fileparts(fileparts(out_path));   % rust_bridge
    repo = fileparts(here);                   % DYNAM-O
    rel = strrep(strrep(out_path, [repo filesep], ''), '\', '/');
    msg = sprintf('bench(edf): %s %s/%s (dynamo @ %s, dynamo_rs @ %s)', ...
        sysinfo.hostname, sysinfo.os, sysinfo.arch, ...
        shas.dynamo_sha, shas.dynamo_rs_sha);

    fprintf('\nCommit + push result file?\n');
    fprintf('  file: %s\n', rel);
    fprintf('  message: %s\n', msg);

    switch lower(push_mode)
        case 'no'
            fprintf('  push=''no'': staging only.\n');
            do_add = true; do_commit = false; do_push = false;
        case 'yes'
            do_add = true; do_commit = true; do_push = true;
        otherwise
            yn = input('  Commit + push now? [Y/n] ', 's');
            if isempty(yn) || strncmpi(yn, 'y', 1)
                do_add = true; do_commit = true; do_push = true;
            else
                fprintf('  Skipping git.\n');
                return;
            end
    end

    if do_add
        [rc, out] = sh(sprintf('git -C %s add -- %s', quote(repo), quote(rel)));
        if rc ~= 0, fprintf(2, 'git add failed: %s\n', out); return; end
    end
    if do_commit
        [rc, out] = sh(sprintf('git -C %s commit -m %s', quote(repo), quote(msg)));
        if rc ~= 0, fprintf(2, 'git commit failed: %s\n', out); return; end
        fprintf('  committed.\n');
    end
    if do_push
        [rc, out] = sh(sprintf('git -C %s push 2>&1', quote(repo)));
        if rc ~= 0
            fprintf(2, 'git push failed: %s\n', out);
            fprintf(2, 'Commit is local; push manually when ready.\n');
        else
            fprintf('  pushed.\n');
        end
    end
end


function [rc, out] = sh(cmd)
    [rc, out] = system(cmd);
end
