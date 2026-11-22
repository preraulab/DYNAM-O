function [available, reason] = rust_backend_available(varargin)
%RUST_BACKEND_AVAILABLE  Whether the Rust MEX backend loads on this machine
%
%   Usage:
%       available = rust_backend_available()
%       [available, reason] = rust_backend_available()
%       available = rust_backend_available('force', true)
%
%   Inputs:
%       none
%
%   Name-Value Pairs:
%       'force' : logical - test again instead of returning the answer
%                 cached for this session (default: false)
%
%   Outputs:
%       available : logical - true when every MEX wrapper runDYNAMO needs
%                   is built for this platform and the Rust library they
%                   link against loads
%       reason    : char - why the backend is unavailable, with the
%                   command that fixes it. Empty when available is true.
%
%   Notes:
%       A MEX file can exist and still fail to load. The usual case is a
%       Linux libdynamo_rs.so built against a newer glibc than this
%       machine has, which fails with "version GLIBC_2.xx not found" on
%       the first call. exist(...) == 3 cannot see that, so this function
%       also calls dynamo_version_mex once. Every wrapper links the same
%       libdynamo_rs, so one successful call shows the library loads.
%
%       The first time the backend is found unavailable in a session, a
%       single warning gives the reason and the fix. The answer is then
%       cached, so runDYNAMO can ask on every run at no cost and without
%       repeating the warning.
%
%       Adds rust_bridge/ to the path, as runDYNAMO does for backend='rust'.
%
%   Example:
%       if ~rust_backend_available()
%           backend = 'matlab';
%       end
%
%   See also: runDYNAMO, check_rust_bridge, build_rust_mex, init_DYNAMO
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

persistent cached_available cached_reason

p = inputParser;
addParameter(p, 'force', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
parse(p, varargin{:});
force = logical(p.Results.force);

if ~isempty(cached_available) && ~force
    available = cached_available;
    reason = cached_reason;
    return
end

% rust_bridge/ sits at the repo root, three levels above this folder.
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(this_dir)));
bridge_dir = fullfile(repo_root, 'rust_bridge');
if isfolder(bridge_dir)
    addpath(bridge_dir);
end

build_hint = sprintf('To build it:  cd(''%s''); build_rust_mex', bridge_dir);

% The wrappers runDYNAMO calls under backend='rust'.
needed = {'extract_tfpeaks_mex', 'mask_spectrogram_mex', ...
    'refine_peaks_mex', 'tfpeak_histogram_mex'};
missing = {};
for k = 1:numel(needed)
    if exist(needed{k}, 'file') ~= 3
        missing{end+1} = needed{k}; %#ok<AGROW>
    end
end

available = true;
reason = '';
if ~isempty(missing)
    available = false;
    reason = sprintf('The Rust backend is not built for this platform (missing %s). %s', ...
        strjoin(missing, ', '), build_hint);
elseif exist('dynamo_version_mex', 'file') == 3
    % Load test: the first call loads libdynamo_rs.
    try
        dynamo_version_mex();
    catch err
        available = false;
        reason = sprintf('The Rust backend is built but does not load on this machine: %s %s', ...
            err.message, build_hint);
    end
end

if ~available
    warning('rust_backend_available:unavailable', ...
        '%s\nUntil then the MATLAB backend is used.', reason);
end

cached_available = available;
cached_reason = reason;
end
