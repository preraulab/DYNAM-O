function manifest_path = write_rust_bridge_manifest(bridge_dir, rs_root, dylib_name)
%WRITE_RUST_BRIDGE_MANIFEST  Record what the committed MEX binaries were built from
%
%   Usage:
%       manifest_path = write_rust_bridge_manifest(bridge_dir, rs_root, dylib_name)
%
%   Inputs:
%       bridge_dir : char - directory holding the built MEX files and the
%                    shared library (normally rust_bridge/) -- required
%       rs_root    : char - path to the DYNAM-O_rs Rust crate the library
%                    was built from (the directory holding Cargo.toml) -- required
%       dylib_name : char - platform shared-library filename, e.g.
%                    'libdynamo_rs.dylib' -- required
%
%   Outputs:
%       manifest_path : char - full path to the manifest that was written
%
%   Notes:
%       The MEX binaries and the shared library are committed to the repo,
%       so a checkout can easily end up with binaries older than the Rust
%       source beside them. That mismatch is silent: the binaries still
%       load and still return numbers, they are just computed by whatever
%       the Rust looked like on the build host.
%
%       Provenance used to be recoverable only from the git commit subject
%       that added the binaries, which fails in three ways. The convention
%       is easy to break (and was broken -- the binaries in the tree were
%       committed with a subject carrying no SHA, which silently disabled
%       the drift check in refresh.sh). It needs a git checkout, so a
%       tarball or a copied directory carries no provenance at all. And it
%       cannot be read from MATLAB without shelling out.
%
%       This manifest fixes all three: it travels with the artifacts, it is
%       plain JSON, and it is written by the build itself rather than by a
%       human remembering a commit-message format.
%
%   See also: check_rust_bridge, build_rust_mex
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

assert(isfolder(bridge_dir), 'write_rust_bridge_manifest:noBridgeDir', ...
    'Bridge directory not found: %s', bridge_dir);

rs_repo = fileparts(rs_root);   % rs_root is <repo>/rust; the git repo is its parent

info = struct();
info.schema           = 1;
info.built_utc        = char(datetime('now', 'TimeZone', 'UTC', ...
                              'Format', 'uuuu-MM-dd''T''HH:mm:ss''Z'''));
info.mexext           = mexext;
info.matlab_release   = version('-release');
info.dylib            = dylib_name;
info.dynamo_rs_sha    = git_capture(rs_repo, 'rev-parse HEAD');
info.dynamo_rs_branch = git_capture(rs_repo, 'rev-parse --abbrev-ref HEAD');

% A dirty source tree means the SHA does not fully describe the build, so
% record it rather than let the manifest overstate what it knows.
status = git_capture(rs_repo, 'status --porcelain');
info.dynamo_rs_dirty = ~isempty(status);

d = dir(fullfile(bridge_dir, ['*.' mexext]));
info.mex_files = sort({d.name});

manifest_path = fullfile(bridge_dir, 'build_manifest.json');
fid = fopen(manifest_path, 'w');
assert(fid >= 0, 'write_rust_bridge_manifest:cannotWrite', ...
    'Could not open %s for writing.', manifest_path);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', jsonencode(info, 'PrettyPrint', true));

if info.dynamo_rs_dirty
    warning('write_rust_bridge_manifest:dirtySource', ...
        ['DYNAM-O_rs had uncommitted changes at build time, so SHA %s ' ...
         'does not fully describe these binaries.'], short_sha(info.dynamo_rs_sha));
end
end


function out = git_capture(repo, args)
% Run a git command in `repo`, returning '' rather than erroring when git
% is unavailable or the directory is not a checkout. Provenance is
% best-effort: a missing field is honest, a build failure is not.
out = '';
if ~isfolder(repo)
    return
end
[rc, raw] = system(sprintf('git -C "%s" %s 2>/dev/null', repo, args));
if rc == 0
    out = strtrim(raw);
end
end


function s = short_sha(sha)
if numel(sha) >= 7
    s = sha(1:7);
else
    s = sha;
end
end
