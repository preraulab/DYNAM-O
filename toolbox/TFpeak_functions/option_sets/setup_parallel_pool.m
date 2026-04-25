function setup_parallel_pool(parallel_mode)
%SETUP_PARALLEL_POOL  Create or reuse a parallel pool.
%
%   setup_parallel_pool('')            default ('Processes')
%   setup_parallel_pool('Processes')   force ProcessPool (default; allows MEX)
%   setup_parallel_pool('Threads')     force ThreadPool (disables trim MEX)
%
%   ProcessPool is the default on every host. ThreadPool is supported as
%   an explicit override but disables `trim_region_mex` (MATLAB cannot
%   execute MEX functions inside a ThreadPool worker). The trim MATLAB
%   fallback produces bit-identical output; the override is purely a
%   performance trade-off.
%
%   If a pool of the correct type already exists, it is kept. If a pool
%   of the wrong type exists, it is deleted and replaced. If no Parallel
%   Computing Toolbox is installed, this function does nothing.

% Check for Parallel Computing Toolbox
v = ver;
if ~any(strcmp({v.Name}, 'Parallel Computing Toolbox'))
    return
end

% Default: ProcessPool on every host. ThreadPool only if the caller
% explicitly asks for it.
if isempty(parallel_mode)
    parallel_mode = 'Processes';
end

pool = gcp('nocreate');

switch parallel_mode
    case 'Threads'
        if isempty(pool) || ~isa(pool, 'parallel.ThreadPool')
            if ~isempty(pool), delete(pool); end
            parpool('Threads');
        end

    case 'Processes'
        if isempty(pool) || ~isa(pool, 'parallel.ProcessPool')
            if ~isempty(pool), delete(pool); end
            parpool('local');
        end

    otherwise
        error('parallel_mode must be '''', ''Processes'', or ''Threads''.');
end
end
