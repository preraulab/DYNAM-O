function v = dynamo_kernel_version()
%DYNAMO_KERNEL_VERSION  Kernel build identity for provenance stamping
%
%   Usage:
%       v = dynamo_kernel_version()
%
%   Inputs:
%       none
%
%   Outputs:
%       v : char - the dynamo_rs build that computes this session's
%           numbers, in the DYNAM-O provenance grammar
%           '<semver>+<sha12>[.dirty]'. Falls back to
%           'unknown+<sha12>[.dirty]' (from rust_bridge/build_manifest.json,
%           which records the sha but not the semver) when the version
%           gateway is not built, and to 'unknown' when neither source
%           is available.
%
%   Notes:
%       This is the `kernel_version` value the canonical-tree writers
%       record in every artifact (DesktopApp OUTPUT_FORMAT.md section 8).
%       Three sources, in order of trust:
%         1. dynamo_version_mex - reports the library actually LOADED by
%            this process (requires DYNAM-O_rs >= 0.2.1 binaries);
%         2. rust_bridge/build_manifest.json - what was on disk when the
%            bridge was last built;
%         3. 'unknown'.
%       Pure-MATLAB writers that did NOT use the Rust bridge for compute
%       must pass the literal 'matlab-native' instead of calling this.
%
%       The result is cached for the session (the loaded library cannot
%       change without clearing MEX functions, which also clears this).
%
%   Example:
%       stamp.kernel_version = dynamo_kernel_version();
%
%   See also: dynamo_version, check_rust_bridge, build_rust_mex
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

persistent cached
if ~isempty(cached)
    v = cached;
    return
end

v = 'unknown';

% Source 1: the loaded library itself.
if exist('dynamo_version_mex', 'file') == 3
    try
        v = dynamo_version_mex();
        cached = v;
        return
    catch
        % Gateway present but unloadable: fall through to the manifest.
    end
end

% Source 2: build-time provenance from the bridge manifest.
try
    this_dir  = fileparts(mfilename('fullpath'));
    repo_root = fileparts(fileparts(fileparts(this_dir)));
    manifest  = fullfile(repo_root, 'rust_bridge', 'build_manifest.json');
    if isfile(manifest)
        info = jsondecode(fileread(manifest));
        if isfield(info, 'dynamo_rs_sha') && ~isempty(info.dynamo_rs_sha)
            sha = info.dynamo_rs_sha(1:min(12, numel(info.dynamo_rs_sha)));
            if isfield(info, 'dynamo_rs_dirty') && isequal(info.dynamo_rs_dirty, true)
                sha = [sha '.dirty'];
            end
            v = ['unknown+' sha];
        end
    end
catch
    % Unreadable manifest: keep 'unknown'.
end

cached = v;
end
