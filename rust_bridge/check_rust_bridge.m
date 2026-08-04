function [ok, report] = check_rust_bridge(varargin)
%CHECK_RUST_BRIDGE  Verify the committed MEX binaries match the Rust source beside them
%
%   Usage:
%       check_rust_bridge()
%       ok = check_rust_bridge('quiet', true)
%       [ok, report] = check_rust_bridge()
%
%   Inputs:
%       none
%
%   Name-Value Pairs:
%       'quiet' : logical - suppress the warning and only return the
%                 verdict (default: false)
%
%   Outputs:
%       ok     : logical - true when the binaries are known to match the
%                Rust source, OR when there is no bridge to check. False
%                only when a genuine mismatch is detected.
%       report : struct - fields `state` (char, one of 'ok', 'stale',
%                'dirty', 'no_manifest', 'no_bridge', 'unknown'),
%                `message` (char), and, when a manifest was read,
%                `manifest` (struct).
%
%   Notes:
%       Fails OPEN by design. An unverifiable bridge warns but does not
%       block, because a missing sibling checkout is the normal state for
%       an end user who was handed a repo rather than bootstrapping one.
%       The thing worth being loud about is a bridge that is provably
%       stale, since that produces plausible numbers from stale code.
%
%       Cheap enough for startup: one file read plus at most one `git
%       rev-parse`, and it returns immediately when rust_bridge/ has no
%       binaries for this platform.
%
%   Example:
%       [ok, report] = check_rust_bridge('quiet', true);
%       if ~ok, disp(report.message); end
%
%   See also: write_rust_bridge_manifest, build_rust_mex, init_DYNAMO
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

p = inputParser;
addParameter(p, 'quiet', false, @(x) validateattributes(x, {'logical','numeric'}, {'binary','scalar'}));
parse(p, varargin{:});
quiet = logical(p.Results.quiet);

bridge_dir = fileparts(mfilename('fullpath'));
report = struct('state', 'unknown', 'message', '');

% Nothing built for this platform: not an error, just nothing to verify.
if isempty(dir(fullfile(bridge_dir, ['*.' mexext])))
    report.state   = 'no_bridge';
    report.message = 'No MEX binaries for this platform; nothing to verify.';
    ok = true;
    return
end

manifest_path = fullfile(bridge_dir, 'build_manifest.json');
if ~isfile(manifest_path)
    report.state = 'no_manifest';
    report.message = sprintf(['rust_bridge has MEX binaries but no build_manifest.json, so ' ...
        'there is no way to tell what Rust source they were built from. ' ...
        'Rebuild with build_rust_mex to record provenance.']);
    ok = true;
    emit(quiet, report.message);
    return
end

try
    report.manifest = jsondecode(fileread(manifest_path));
catch err
    report.state   = 'no_manifest';
    report.message = sprintf('Could not read %s: %s', manifest_path, err.message);
    ok = true;
    emit(quiet, report.message);
    return
end
m = report.manifest;

% The Rust checkout normally sits beside DYNAM-O in the bootstrap layout.
repo_root = fileparts(bridge_dir);
rs_repo   = fullfile(fileparts(repo_root), 'DYNAM-O_rs');
built_sha = getfield_or(m, 'dynamo_rs_sha', '');
current   = '';
if isfolder(rs_repo)
    [rc, raw] = system(sprintf('git -C "%s" rev-parse HEAD 2>/dev/null', rs_repo));
    if rc == 0
        current = strtrim(raw);
    end
end

if getfield_or(m, 'dynamo_rs_dirty', false)
    report.state = 'dirty';
    report.message = sprintf(['rust_bridge binaries were built from a DYNAM-O_rs tree with ' ...
        'uncommitted changes (@ %s), so their provenance is approximate.'], short(built_sha));
    ok = true;
    emit(quiet, report.message);
    return
end

if isempty(current) || isempty(built_sha)
    report.state = 'unknown';
    report.message = sprintf(['rust_bridge binaries record DYNAM-O_rs @ %s, but the current ' ...
        'DYNAM-O_rs checkout could not be read, so staleness is unverified.'], short(built_sha));
    ok = true;
    emit(quiet, report.message);
    return
end

if strcmp(built_sha, current)
    report.state   = 'ok';
    report.message = sprintf('rust_bridge binaries match DYNAM-O_rs @ %s.', short(built_sha));
    ok = true;
    return
end

report.state = 'stale';
report.message = sprintf(['rust_bridge binaries are STALE: built at DYNAM-O_rs @ %s, but ' ...
    'DYNAM-O_rs is now at @ %s. They will load and return numbers computed by the OLD ' ...
    'Rust source. Rebuild with:  run(fullfile(''%s'', ''build_rust_mex.m''))'], ...
    short(built_sha), short(current), bridge_dir);
ok = false;
emit(quiet, report.message);
end


function emit(quiet, msg)
if ~quiet
    warning('check_rust_bridge:mismatch', '%s', msg);
end
end


function v = getfield_or(s, name, default)
if isstruct(s) && isfield(s, name)
    v = s.(name);
else
    v = default;
end
end


function s = short(sha)
if ischar(sha) && numel(sha) >= 7
    s = sha(1:7);
elseif isempty(sha)
    s = '<unknown>';
else
    s = sha;
end
end
