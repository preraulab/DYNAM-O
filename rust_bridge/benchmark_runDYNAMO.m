function out_path = benchmark_runDYNAMO(varargin)
%BENCHMARK_RUNDYNAMO  Run runDYNAMO on a fixture, capture timing + peak
%   counts + system info, write a per-run JSON to rust_bridge/benchmarks/
%   runs/, and (optionally) commit + push.
%
%   Usage:
%       benchmark_runDYNAMO()
%       benchmark_runDYNAMO('fixture', 'night')
%       benchmark_runDYNAMO('backends', {'rust','matlab'})
%       benchmark_runDYNAMO('push', 'yes')
%
%   Name-value options:
%       'fixture'  — 'segment' | 'night' (default: 'night')
%       'backends' — cellstr subset of {'rust','matlab'} (default: both)
%       'warmup'   — do a discarded warm-up run per backend before timing
%                    to remove MATLAB JIT / cache / parpool spin-up noise
%                    (default: true; adds ~30-160s per backend)
%       'push'     — 'auto' (prompt), 'yes' (push without asking),
%                    'no' (commit locally but don't push; default: 'auto')
%       'out_dir'  — where to write the JSON (default:
%                    rust_bridge/benchmarks/runs/)
%
%   Output:
%       out_path — absolute path to the JSON file written.
%
%   The JSON schema captures:
%       timestamp, hostname, os, os_version, arch, cpu, cores, ram_gb,
%       matlab_version, dynamo_dev_sha, dynamo_rs_sha, fixture, warmup,
%       per-backend: { peaks, timings, error (if any) }
%
%   Aggregated with: benchmark_summarize() in the same dir, which globs
%   runs/*.json and prints a comparison table.

    p = inputParser;
    addParameter(p, 'fixture', 'night', @(x) any(strcmpi(x, {'segment','night'})));
    addParameter(p, 'backends', {'rust','matlab'}, @iscellstr);
    addParameter(p, 'warmup', true, @islogical);
    addParameter(p, 'push', 'auto', @(x) any(strcmpi(x, {'auto','yes','no'})));
    here = fileparts(mfilename('fullpath'));
    addParameter(p, 'out_dir', fullfile(here, 'benchmarks', 'runs'), @ischar);
    parse(p, varargin{:});
    S = p.Results;

    if ~exist(S.out_dir, 'dir'); mkdir(S.out_dir); end

    % --- system info ---
    sysinfo = collect_sysinfo();

    % --- repo SHAs (best-effort; empty if not a git checkout) ---
    shas.dynamo_dev_sha = git_short_sha(fileparts(here));  % DYNAM-O_dev root
    shas.dynamo_dev_dirty = git_is_dirty(fileparts(here));
    rs_root = find_dynamo_rs_root(here);
    shas.dynamo_rs_sha = git_short_sha(rs_root);
    shas.dynamo_rs_dirty = git_is_dirty(rs_root);

    % --- run each backend ---
    results = struct();
    for b = 1:numel(S.backends)
        backend = S.backends{b};
        fprintf('\n=== Benchmarking backend=''%s'' (fixture=''%s'') ===\n', backend, S.fixture);
        try
            if S.warmup
                fprintf('  Warm-up run (discarded)...\n');
                run_once(S.fixture, backend);
            end
            fprintf('  Timed run...\n');
            [timings, peaks, info] = run_once(S.fixture, backend);
            results.(backend) = struct('timings', timings, 'peaks', peaks, ...
                'recording_duration_s', info.recording_duration_s, ...
                'pipeline_options', info.pipeline_options, ...
                'error', []);
        catch err
            results.(backend) = struct('timings', struct(), 'peaks', struct(), ...
                'error', struct('identifier', err.identifier, ...
                                'message', err.message));
            fprintf(2, '  Backend ''%s'' failed: %s\n', backend, err.message);
        end
    end

    % --- bail out if every backend errored (no useful data to record) ---
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
    record.schema_version = 1;
    record.timestamp = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
    record.hostname = sysinfo.hostname;
    record.os = sysinfo.os;
    record.os_version = sysinfo.os_version;
    record.arch = sysinfo.arch;
    record.cpu = sysinfo.cpu;
    record.cores = sysinfo.cores;
    record.ram_gb = sysinfo.ram_gb;
    record.matlab_version = version;
    record.dynamo_dev_sha = shas.dynamo_dev_sha;
    record.dynamo_dev_dirty = shas.dynamo_dev_dirty;
    record.dynamo_rs_sha = shas.dynamo_rs_sha;
    record.dynamo_rs_dirty = shas.dynamo_rs_dirty;
    record.fixture = S.fixture;
    record.warmup = S.warmup;
    record.results = results;

    % --- write JSON ---
    stamp = datestr(now, 'yyyy-mm-dd-HHMMSS');
    safe_host = regexprep(sysinfo.hostname, '[^A-Za-z0-9_-]', '_');
    fname = sprintf('%s__%s__%s-%s.json', stamp, safe_host, sysinfo.os, sysinfo.arch);
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


function [timings, peaks, info] = run_once(fixture, backend)
    % show_pbar lives on the detection_options struct, not as a top-level
    % runDYNAMO name-value. Building the struct explicitly lets us turn
    % off the waitbar, which serves two purposes:
    %   (a) avoids the runSegmentedData.m MATLAB waitbar, which on some
    %       macOS + MATLAB R2025b combinations triggers a Qt / fontations
    %       GUI-thread SIGSEGV (see crash dump from 2026-04-24: EXC_BAD_ACCESS
    %       in QT GuiThread inside blink$cxxbridge1$crash_in_rust_with_overflow);
    %   (b) benchmark runs don't need progress output anyway.
    det_opts = detection_opts();
    det_opts.show_pbar = false;
    det_opts.backend = backend;  % redundant with the top-level 'backend'
                                  % name-value below, but harmless and
                                  % keeps the struct self-documenting
    % Capture data_time_range so the JSON records how many seconds of EEG
    % were actually processed — lets cross-fixture / cross-host comparisons
    % normalize timings by recording duration.
    [stats_table, ~, ~, ~, data_time_range, ~, ~, ~, timings] = runDYNAMO(fixture, ...
        'backend', backend, 'plot_on', false, ...
        'detection_options', det_opts);
    peaks.final = height(stats_table);
    info.recording_duration_s = data_time_range(2) - data_time_range(1);
    info.pipeline_options = pipeline_options_snapshot(det_opts);
end


function snap = pipeline_options_snapshot(det_opts)
    % Capture only the detection_options fields that materially affect
    % timing / parity. Keeps the JSON small and avoids leaking other
    % implementation-specific knobs that aren't comparable across
    % toolbox versions. If the user changed quality_setting via the
    % options app or detection_opts() default, this surfaces it.
    keys = {'backend', 'seg_time', 'downsample_spect', ...
            'merge_thresh', 'quality_setting', 'parallel_mode'};
    snap = struct();
    for i = 1:numel(keys)
        if isfield(det_opts, keys{i})
            snap.(keys{i}) = det_opts.(keys{i});
        end
    end
end


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
            gb = str2double(strtrim(r)) / 1024^2;  % MemTotal is in kB
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
    % Canonical layout: DYNAM-O_dev/rust_bridge  sibling to  DYNAM-O_rs
    candidates = {
        fullfile(fileparts(fileparts(rust_bridge_dir)), 'DYNAM-O_rs'), ...
        fullfile(fileparts(fileparts(rust_bridge_dir)), 'DYNAM-O_rs-rust-bridge')
    };
    for i = 1:numel(candidates)
        if exist(fullfile(candidates{i}, '.git'), 'dir') || ...
           exist(fullfile(candidates{i}, '.git'), 'file')
            rs_root = candidates{i}; return;
        end
    end
    rs_root = '';
end


function print_summary(record)
    fprintf('\n');
    fprintf('───────────────────────────────────────────────────────────────\n');
    fprintf(' Benchmark summary\n');
    fprintf('───────────────────────────────────────────────────────────────\n');
    fprintf('  Host: %s  (%s %s / %s, %d cores, %.1f GB RAM)\n', ...
        record.hostname, record.os, record.os_version, record.arch, ...
        record.cores, record.ram_gb);
    fprintf('  CPU:  %s\n', record.cpu);
    fprintf('  MATLAB: %s\n', record.matlab_version);
    fprintf('  DYNAM-O_dev: %s%s  |  DYNAM-O_rs: %s%s\n', ...
        record.dynamo_dev_sha, dirty_mark(record.dynamo_dev_dirty), ...
        record.dynamo_rs_sha,  dirty_mark(record.dynamo_rs_dirty));
    fprintf('  Fixture: %s  (warmup=%s)\n', record.fixture, bool2str(record.warmup));
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
    % Commit + push the single benchmark JSON file. Never touch unrelated
    % uncommitted work — we only `git add` the exact path we just wrote.
    here = fileparts(fileparts(out_path));  % rust_bridge
    repo = fileparts(here);                  % DYNAM-O_dev
    rel = strrep(strrep(out_path, [repo filesep], ''), '\', '/');
    msg = sprintf('bench: %s %s/%s (dynamo_dev @ %s, dynamo_rs @ %s)', ...
        sysinfo.hostname, sysinfo.os, sysinfo.arch, ...
        shas.dynamo_dev_sha, shas.dynamo_rs_sha);

    fprintf('\nCommit + push result file?\n');
    fprintf('  file: %s\n', rel);
    fprintf('  message: %s\n', msg);

    switch lower(push_mode)
        case 'no'
            fprintf('  push=''no'': staging only.\n');
            do_add = true; do_commit = false; do_push = false;
        case 'yes'
            do_add = true; do_commit = true; do_push = true;
        otherwise  % 'auto'
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
