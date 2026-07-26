function build_rust_mex()
%BUILD_RUST_MEX  Compile the MEX wrappers that bridge MATLAB to dynamo_rs.
%
%   Usage:
%       cd /path/to/DYNAM-O/rust_bridge
%       build_rust_mex
%
%   Prerequisites (must all be true before calling):
%     1. DYNAM-O_rs exists as a sibling checkout:
%          <workspace>/DYNAM-O_rs/
%     2. Cargo is available on PATH. This function builds the Rust crate
%        with its lockfile and remaps build-host paths, producing:
%          target/release/libdynamo_rs.{dylib,a}
%          include/dynamo_rs.h
%     3. A supported C compiler is configured via `mex -setup C`.
%
%   Produces in the current directory (with .mexmaca64 / .mexmaci64 /
%   .mexa64 / .mexw64 extension for the host platform):
%       extract_tfpeaks_mex
%       refine_peaks_mex
%       tfpeak_histogram_mex
%       mask_spectrogram_mex
%       multitaper_spectrogram_rust_mex
%       dpss_rust_mex
%       detect_artifacts_mex
%       baseline_mex
%       so_power_mex
%       so_phase_mex
%
%   The MEX binaries link against a copy of libdynamo_rs placed beside
%   them, using loader-relative lookup so the output is redistributable.

here           = canonical_path(fileparts(mfilename('fullpath'))); % DYNAM-O/rust_bridge
dev_root       = fileparts(here);                                % DYNAM-O
workspace_root = fileparts(dev_root);                            % parent of all three repos
rs_root        = fullfile(workspace_root, 'DYNAM-O_rs', 'rust');
assert(isfolder(rs_root), ...
    'DYNAM-O_rs Rust crate not found at %s. Check out DYNAM-O_rs beside DYNAM-O.', rs_root);
rs_root = canonical_path(rs_root);

build_rust_library(rs_root, workspace_root);

inc_dir   = fullfile(rs_root, 'include');
lib_dir   = fullfile(rs_root, 'target', 'release');

hdr = fullfile(inc_dir, 'dynamo_rs.h');
assert(exist(hdr, 'file') == 2, ...
    'dynamo_rs.h was not generated at %s.', hdr);

if ispc
    dylib_name = 'dynamo_rs.dll';
elseif ismac
    dylib_name = 'libdynamo_rs.dylib';
else
    dylib_name = 'libdynamo_rs.so';
end
dylib = fullfile(lib_dir, dylib_name);
assert(exist(dylib, 'file') == 2, ...
    '%s was not built at %s.', dylib_name, dylib);

% Use .c (not .cpp) — on Apple Silicon, MATLAB's mex auto-links the
% C++ MEX adapter (matlab::mex::Function) for .cpp files, pulling in
% symbols like mexCreateMexFunction that we don't provide. The classic
% void mexFunction(...) entry point only works reliably from .c files.
sources = {'extract_tfpeaks_mex.c', ...
    'refine_peaks_mex.c', ...
    'tfpeak_histogram_mex.c', ...
    'mask_spectrogram_mex.c', ...
    'multitaper_spectrogram_rust_mex.c', ...
    'dpss_rust_mex.c', ...
    'detect_artifacts_mex.c', ...
    'baseline_mex.c', ...
    'so_power_mex.c', ...
    'so_phase_mex.c'};

% Build options. Using the classic C MEX API (mxGetPr / mxGetData) —
% -R2018a would pull in mexAdapter symbols for .cpp files and fail to
% link on Apple Silicon. Classic API works everywhere and is enough
% since we don't use complex arrays.
common_args = { ['-I', inc_dir], ...
    ['-L', lib_dir], ...
    '-ldynamo_rs', ...
    '-outdir', here };

% Rpath/runtime-lookup strategy: redistributable builds need the MEX
% binary to find libdynamo_rs.* WITHOUT depending on absolute paths
% from the build host. We copy the shared library next to the MEX
% binary (in rust_bridge/) and point the rpath at the loader itself
% (`@loader_path` on macOS, `$ORIGIN` on Linux). Windows loads DLLs
% from the same directory as the loading .mex* file by default —
% copy alone suffices, no linker flag needed.
if ismac
    common_args = [common_args, ...
        {'LDFLAGS=$LDFLAGS -Wl,-rpath,@loader_path'}];
elseif isunix
    % Linux: need '$ORIGIN' to reach the linker LITERALLY so it gets
    % embedded in DT_RUNPATH; the dynamic loader expands it at load
    % time to the directory of the loaded .mex*. MATLAB's mex shells
    % out to gcc, so we must escape the leading $ to prevent shell
    % expansion (unescaped $ORIGIN -> empty string at shell time,
    % producing an empty RUNPATH -> MEX can't find libdynamo_rs.so
    % at runtime, manifesting as 'Invalid MEX-file: libdynamo_rs.so:
    % cannot open shared object file: No such file or directory').
    common_args = [common_args, ...
        {'LDFLAGS=$LDFLAGS -Wl,-rpath,\$ORIGIN'}];
end

for i = 1:numel(sources)
    src = fullfile(here, sources{i});
    fprintf('Building %s ...\n', sources{i});
    try
        mex(common_args{:}, src);
    catch err
        fprintf(2, '\nBuild FAILED for %s:\n  %s\n', sources{i}, err.message);
        rethrow(err);
    end
end

% Copy the shared library alongside the MEX files so rpath (@loader_path /
% $ORIGIN) resolves on any host, not just this one.
dst_dylib = fullfile(here, dylib_name);
fprintf('\nCopying %s -> rust_bridge/%s ...\n', dylib_name, dylib_name);
[copied, copy_message] = copyfile(dylib, dst_dylib);
if ~copied
    error('build_rust_mex:LibraryCopyFailed', ...
        'Failed to copy %s: %s', dylib_name, copy_message);
end
copy_filter_cache(rs_root, here);
if ispc
    % Windows also needs the import library (.dll.lib) at link time
    % but NOT at runtime; skip copying the .lib here.
end

if ismac
    % By default Rust cdylibs embed their absolute build-path as their
    % LC_ID_DYLIB (install name), and anything linked against them
    % records that absolute path as the load reference — which ignores
    % our @loader_path rpath and breaks redistributable builds.
    % Rewrite both the dylib's own id and each MEX's load reference
    % to @rpath/libdynamo_rs.dylib so the loader uses the rpath we
    % embedded.  Prefer /usr/bin/install_name_tool (Apple's) over any
    % MacPorts / Homebrew shadow — older third-party copies choke on
    % modern LC_BUILD_VERSION load commands.
    install_name_tool = '/usr/bin/install_name_tool';
    otool = '/usr/bin/otool';
    new_ref = '@rpath/libdynamo_rs.dylib';

    run_checked(sprintf('%s -id %s %s', ...
        shell_quote(install_name_tool), shell_quote(new_ref), ...
        shell_quote(dst_dylib)), ...
        sprintf('Setting the install name for %s', dst_dylib));
    id_out = run_checked(sprintf('%s -D %s', ...
        shell_quote(otool), shell_quote(dst_dylib)), ...
        sprintf('Reading the install name for %s', dst_dylib));
    if ~any(strcmp(strtrim(strsplit(id_out, newline)), new_ref))
        error('build_rust_mex:InstallNameVerificationFailed', ...
            'Expected install name %s in %s.', new_ref, dst_dylib);
    end

    % The MEX's recorded load reference depends on the dylib's install
    % name at link time, which varies across Rust toolchain versions
    % (bare 'libdynamo_rs.dylib', 'target/release/libdynamo_rs.dylib',
    % 'target/release/deps/libdynamo_rs.dylib', or — if maturin's
    % --features python build was run first — '@rpath/dynamo_rs.abi3.so').
    % Discover the actual reference per MEX via `otool -L` and rewrite
    % that exact string. Without this, a hard-coded source path silently
    % fails to match and the MEX is left pointing at target/release/, so
    % a later `maturin develop --features python` (step 5 of bootstrap.sh)
    % overwrites that file with a PyO3 extension and the MEX dies at
    % runtime with 'symbol not found in flat namespace _PyBaseObject_Type'.
    for i = 1:numel(sources)
        [~, base, ~] = fileparts(sources{i});
        mex_path = fullfile(here, [base '.' mexext]);
        if ~isfile(mex_path)
            error('build_rust_mex:MissingMexOutput', ...
                'MEX build did not produce %s.', mex_path);
        end
        otool_out = run_checked(sprintf('%s -L %s', ...
            shell_quote(otool), shell_quote(mex_path)), ...
            sprintf('Reading load references for %s', mex_path));
        cur_ref = find_dynamo_reference(otool_out, mex_path);
        if strcmp(cur_ref, new_ref)
            continue;  % already correct
        end
        run_checked(sprintf('%s -change %s %s %s', ...
            shell_quote(install_name_tool), shell_quote(cur_ref), ...
            shell_quote(new_ref), shell_quote(mex_path)), ...
            sprintf('Rewriting the load reference for %s', mex_path));
        verify_out = run_checked(sprintf('%s -L %s', ...
            shell_quote(otool), shell_quote(mex_path)), ...
            sprintf('Verifying load references for %s', mex_path));
        verify_ref = find_dynamo_reference(verify_out, mex_path);
        if ~strcmp(verify_ref, new_ref)
            error('build_rust_mex:LoadReferenceVerificationFailed', ...
                'Expected load reference %s in %s, found %s.', ...
                new_ref, mex_path, verify_ref);
        end
    end
end

fprintf('\nBuilt MEX binaries in %s:\n', here);
d = dir(fullfile(here, ['*.' mexext]));
for i = 1:numel(d)
    fprintf('  %s (%.0f KB)\n', d(i).name, d(i).bytes / 1024);
end
fprintf('  %s (%.0f KB) [shared library, required at runtime]\n', ...
    dylib_name, dir(dst_dylib).bytes / 1024);

fprintf('\nTo sanity-check:\n');
fprintf('  extract_tfpeaks_mex(zeros(2), [0 1], [0 1], [], struct(''seg_time'',30,''downsample_f'',1,''downsample_t'',1,''merge_thresh'',11,''trim_vol'',0.8,''dur_min'',1,''dur_max'',5,''bw_min'',1,''bw_max'',15,''freq_min'',-inf,''freq_max'',inf,''ht_db_min'',-inf))\n');
end

function build_rust_library(rs_root, workspace_root)
% Build from the current sibling checkout while replacing host paths in
% compiler-generated source locations with stable virtual prefixes.
lockfile = fullfile(rs_root, 'Cargo.lock');
assert(exist(lockfile, 'file') == 2, ...
    'Cargo.lock not found at %s. Release builds require the tracked lockfile.', lockfile);

old_dir = pwd;
old_encoded_flags = getenv('CARGO_ENCODED_RUSTFLAGS');
cleanup = onCleanup(@() restore_build_environment(old_dir, old_encoded_flags));

setenv('CARGO_ENCODED_RUSTFLAGS', release_rustflags(rs_root, workspace_root));
cd(rs_root);
fprintf('Building dynamo_rs with locked dependencies and remapped paths ...\n');
[rc, cargo_out] = system('cargo build --release --lib --locked 2>&1');
fprintf('%s', cargo_out);
if rc ~= 0
    error('build_rust_mex:CargoBuildFailed', ...
        'cargo build --release --lib --locked failed with exit code %d.', rc);
end
end

function restore_build_environment(old_dir, old_encoded_flags)
setenv('CARGO_ENCODED_RUSTFLAGS', old_encoded_flags);
cd(old_dir);
end

function copy_filter_cache(rs_root, here)
source_dir = fullfile(fileparts(rs_root), 'data_matlab_filters');
assert(isfolder(source_dir), ...
    'MATLAB filter cache not found at %s.', source_dir);
source_files = dir(fullfile(source_dir, '*.npy'));
assert(numel(source_files) == 42, ...
    'Expected 42 MATLAB filter-cache .npy files at %s; found %d.', ...
    source_dir, numel(source_files));
[~, order] = sort({source_files.name});
source_files = source_files(order);

destination_dir = fullfile(here, 'data_matlab_filters');
if ~isfolder(destination_dir)
    mkdir(destination_dir);
end
old_files = dir(fullfile(destination_dir, '*.npy'));
for i = 1:numel(old_files)
    delete(fullfile(destination_dir, old_files(i).name));
end
for i = 1:numel(source_files)
    [copied, message] = copyfile( ...
        fullfile(source_dir, source_files(i).name), ...
        fullfile(destination_dir, source_files(i).name));
    if ~copied
        error('build_rust_mex:FilterCacheCopyFailed', ...
            'Failed to copy %s: %s', source_files(i).name, message);
    end
end
fprintf('Copied %d filter-cache files -> rust_bridge/data_matlab_filters.\n', ...
    numel(source_files));
end

function encoded = release_rustflags(rs_root, workspace_root)
% CARGO_ENCODED_RUSTFLAGS uses ASCII unit separator rather than whitespace,
% so checkout paths containing spaces remain a single rustc argument.
sources = {};
targets = {};

user_home = getenv('HOME');
if isempty(user_home)
    user_home = getenv('USERPROFILE');
end
if ~isempty(user_home)
    sources{end + 1} = user_home;
    targets{end + 1} = '/build/user';
end

cargo_home = getenv('CARGO_HOME');
if isempty(cargo_home) && ~isempty(user_home)
    cargo_home = fullfile(user_home, '.cargo');
end
if ~isempty(cargo_home)
    sources{end + 1} = cargo_home;
    targets{end + 1} = '/build/cargo';
end

rustup_home = getenv('RUSTUP_HOME');
if isempty(rustup_home) && ~isempty(user_home)
    rustup_home = fullfile(user_home, '.rustup');
end
if ~isempty(rustup_home)
    sources{end + 1} = rustup_home;
    targets{end + 1} = '/build/rustup';
end

sources{end + 1} = tempdir;
targets{end + 1} = '/build/tmp';
sources{end + 1} = workspace_root;
targets{end + 1} = '/workspace';
sources{end + 1} = rs_root;
targets{end + 1} = '/workspace/DYNAM-O_rs/rust';

flags = {};
for i = 1:numel(sources)
    variants = path_variants(sources{i});
    for j = 1:numel(variants)
        flag = ['--remap-path-prefix=' variants{j} '=' targets{i}];
        if ~any(strcmp(flags, flag))
            flags{end + 1} = flag; %#ok<AGROW>
        end
    end
end
flags{end + 1} = '--remap-path-scope=object';
encoded = strjoin(flags, char(31));
end

function variants = path_variants(path)
path = strip_trailing_separator(char(path));
variants = {path, canonical_path(path)};
if ispc
    variants = [variants, strrep(variants, '\', '/')];
end
variants = unique(variants, 'stable');
end

function path = canonical_path(path)
path = char(path);
try
    file = javaObject('java.io.File', path);
    path = char(file.getCanonicalPath());
catch
    if isfolder(path)
        old_dir = pwd;
        cleanup = onCleanup(@() cd(old_dir));
        cd(path);
        path = pwd;
    end
end
path = strip_trailing_separator(path);
end

function path = strip_trailing_separator(path)
while numel(path) > 1 && any(path(end) == ['/' '\'])
    if ispc && numel(path) == 3 && path(2) == ':'
        break;
    end
    path(end) = [];
end
end

function output = run_checked(command, description)
[rc, output] = system(command);
if rc ~= 0
    error('build_rust_mex:CommandFailed', ...
        '%s failed with exit code %d:\n%s', description, rc, output);
end
end

function ref = find_dynamo_reference(otool_out, mex_path)
lines = strsplit(otool_out, newline);
for i = 1:numel(lines)
    line = strtrim(lines{i});
    if isempty(regexp(line, ...
            '(libdynamo_rs\.dylib|dynamo_rs\.abi3\.so)', 'once'))
        continue;
    end
    token = regexp(line, ...
        '^(.*?)\s+\(compatibility version', 'tokens', 'once');
    if isempty(token)
        error('build_rust_mex:UnparseableLoadReference', ...
            'Could not parse the dynamo_rs load reference in %s:\n%s', ...
            mex_path, line);
    end
    ref = strtrim(token{1});
    return;
end
error('build_rust_mex:MissingLoadReference', ...
    'No dynamo_rs load reference found in %s.', mex_path);
end

function quoted = shell_quote(value)
% Quote one argument for the POSIX shell used by MATLAB system on macOS.
single_quote = char(39);
double_quote = char(34);
escaped_quote = [single_quote double_quote single_quote double_quote single_quote];
quoted = [single_quote strrep(char(value), single_quote, escaped_quote) single_quote];
end
