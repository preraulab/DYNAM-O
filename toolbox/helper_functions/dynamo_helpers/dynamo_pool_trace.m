function dynamo_pool_trace(label)
%DYNAMO_POOL_TRACE  Print parallel-pool state at a labelled checkpoint.
%
%   dynamo_pool_trace('after imgaussfilt')
%
%   Prints a one-line summary of the parallel pool state if the env var
%   DYNAMO_POOL_DEBUG is set. Used to bisect which line in the post-
%   runDYNAMO fit chain auto-spawns a pool on the rust backend. No-op
%   when DYNAMO_POOL_DEBUG is unset, so safe to leave in production.
%
%   Output format (single line):
%     [pool-trace] <ISO ts>  <label>  AutoCreate=<bool>  pool=<type|none>
%
%   AutoCreate is read from parallel.Settings.Pool.AutoCreate. pool is
%   the type of the active pool (e.g. parallel.ProcessPool, parallel.
%   ThreadPool) or "none". When the pool is non-empty, also prints
%   NumWorkers / Connected so we can see if it's still alive.

if isempty(getenv('DYNAMO_POOL_DEBUG'))
    return
end

% Best-effort: skip silently if Parallel Computing Toolbox is missing
% so the trace doesn't itself crash a run.
if exist('parallel.Settings', 'class') ~= 8
    return
end

ts = char(datetime('now', 'Format', 'HH:mm:ss.SSS'));

% parallel.Settings.Pool.AutoCreate returns a matlab.settings.Setting
% object, NOT a logical — mat2str() on it throws. Read .ActiveValue
% to get the underlying boolean. Fall back to coerce-to-logical (the
% Setting class implements logical conversion) if .ActiveValue isn't
% accessible (very old releases).
ac_str = '?';
try
    s = parallel.Settings.Pool.AutoCreate;
    if isprop(s, 'ActiveValue') || isa(s, 'matlab.settings.Setting')
        ac_str = mat2str(logical(s.ActiveValue));
    else
        ac_str = mat2str(logical(s));
    end
catch
    % Older release fallback — try direct logical coercion.
    try
        ac_str = mat2str(logical(parallel.Settings.Pool.AutoCreate));
    catch
    end
end

p = [];
try
    p = gcp('nocreate');
catch
end

if isempty(p)
    pool_str = 'none';
else
    pool_str = class(p);
    nw = '?'; connected = '?';
    try
        if isprop(p, 'NumWorkers')
            nw = num2str(p.NumWorkers);
        elseif isprop(p, 'NumThreads')
            nw = num2str(p.NumThreads);
        end
    catch
    end
    try
        if isprop(p, 'Connected')
            connected = mat2str(p.Connected);
        end
    catch
    end
    pool_str = sprintf('%s(N=%s,Connected=%s)', pool_str, nw, connected);
end

fprintf('[pool-trace] %s  %-40s  AutoCreate=%s  pool=%s\n', ts, label, ac_str, pool_str);
end
