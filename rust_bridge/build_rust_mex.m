function build_rust_mex()
%BUILD_RUST_MEX  Compile the 5 MEX wrappers that bridge MATLAB to dynamo_rs.
%
%   Usage:
%       cd /path/to/DYNAM-O_dev/rust_bridge
%       build_rust_mex
%
%   Prerequisites (must all be true before calling):
%     1. DYNAM-O_rs exists as a sibling checkout:
%          ~/code/toolboxes/DYNAM-O_rs/
%     2. The Rust crate has been built:
%          cd ~/code/toolboxes/DYNAM-O_rs/rust
%          cargo build --release
%        producing:
%          target/release/libdynamo_rs.{dylib,a}
%          include/dynamo_rs.h
%     3. A supported C++ compiler is configured via `mex -setup C++`.
%
%   Produces in the current directory (with .mexmaca64 / .mexmaci64 /
%   .mexa64 / .mexw64 extension for the host platform):
%       extract_tfpeaks_mex
%       refine_peaks_mex
%       tfpeak_histogram_mex
%       mask_spectrogram_mex
%       multitaper_spectrogram_rust_mex
%
%   The MEX binaries link against libdynamo_rs.dylib at runtime. We embed
%   an rpath pointing at DYNAM-O_rs/rust/target/release so MATLAB can find
%   the dylib without DYLD_LIBRARY_PATH hacks. For a standalone `mcc` build
%   the dylib needs to be copied next to the .app bundle (see Phase 7 notes).

here      = fileparts(mfilename('fullpath'));              % DYNAM-O_dev/rust_bridge
dev_root  = fileparts(here);                               % DYNAM-O_dev
rs_root   = fullfile(dev_root, '..', 'DYNAM-O_rs', 'rust');
inc_dir   = fullfile(rs_root, 'include');
lib_dir   = fullfile(rs_root, 'target', 'release');

hdr = fullfile(inc_dir, 'dynamo_rs.h');
assert(exist(hdr, 'file') == 2, ...
    'dynamo_rs.h not found at %s. Run `cargo build --release` in DYNAM-O_rs/rust first.', hdr);

if ispc
    dylib_name = 'dynamo_rs.dll';
elseif ismac
    dylib_name = 'libdynamo_rs.dylib';
else
    dylib_name = 'libdynamo_rs.so';
end
dylib = fullfile(lib_dir, dylib_name);
assert(exist(dylib, 'file') == 2, ...
    '%s not found at %s. Run `cargo build --release` in DYNAM-O_rs/rust.', dylib_name, dylib);

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
copyfile(dylib, dst_dylib);
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
    new_ref = '@rpath/libdynamo_rs.dylib';

    system(sprintf('%s -id %s %s', install_name_tool, new_ref, dst_dylib));

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
        if exist(mex_path, 'file') ~= 3
            continue;
        end
        [rc, otool_out] = system(sprintf('otool -L %s', mex_path));
        if rc ~= 0
            warning('otool -L failed for %s; skipping install_name rewrite.', mex_path);
            continue;
        end
        cur_ref = '';
        lines = strsplit(otool_out, newline);
        for k = 1:numel(lines)
            ln = strtrim(lines{k});
            % Match any reference to our crate, in whatever form the
            % linker recorded it (plain cdylib or PyO3 abi3 extension).
            if ~isempty(regexp(ln, '(libdynamo_rs\.dylib|dynamo_rs\.abi3\.so)', 'once'))
                tok = regexp(ln, '^(\S+)', 'tokens', 'once');
                if ~isempty(tok)
                    cur_ref = tok{1};
                    break;
                end
            end
        end
        if isempty(cur_ref)
            warning('No libdynamo_rs reference found in %s; skipping.', mex_path);
            continue;
        end
        if strcmp(cur_ref, new_ref)
            continue;  % already correct
        end
        system(sprintf('%s -change %s %s %s', ...
            install_name_tool, cur_ref, new_ref, mex_path));
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
