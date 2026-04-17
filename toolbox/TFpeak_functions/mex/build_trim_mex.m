function build_trim_mex(varargin)
%BUILD_TRIM_MEX  Compile trim_region_mex for the current platform.
%
%   Usage:
%       build_trim_mex              % build if missing or source is newer
%       build_trim_mex('force')     % rebuild even if up to date
%       build_trim_mex('verbose')   % show the mex command line
%       build_trim_mex('force','verbose')
%
%   Platforms:
%       macOS   -> .mexmaca64 / .mexmaci64   (Xcode + clang)
%       Linux   -> .mexa64                   (gcc/g++ with C++17 support)
%       Windows -> .mexw64                   (MSVC or MinGW-w64)
%
%   Requirements before running:
%       - MATLAB's MEX compiler configured for C++ :
%           >> mex -setup cpp
%         If this errors, install the platform toolchain:
%           Linux:   sudo apt install build-essential      (or equivalent)
%           Windows: MSVC Build Tools OR MinGW-w64 via Add-Ons
%           macOS:   xcode-select --install
%
%   Target: trim_region_mex — per-region morphology for trimWshedRegions
%   (consolidates imfill + bwconncomp + pick-largest + boundary into one
%   C++ call per region).
%
%   Output:
%       trim_region_mex.<mexext> dropped next to this .m so addpath picks
%       it up. Skips if the binary is newer than the source unless
%       'force' is passed.

force   = any(strcmpi(varargin, 'force'));
verbose = any(strcmpi(varargin, 'verbose'));

here = fileparts(mfilename('fullpath'));

fprintf('=== DYNAM-O MEX builder ===\n');
fprintf('platform: %s  (mexext: %s)\n', computerLabel(), mexext);
fprintf('matlab:   %s\n', version);
fprintf('outdir:   %s\n\n', here);

% Targets: {source, pretty-name}. Add new MEX here to have it built.
targets = { ...
    'trim_region_mex.cpp', 'trim_region_mex'};

% Sanity-check mex is configured for C++ before diving in
try
    cc = mex.getCompilerConfigurations('C++', 'Selected');
    if isempty(cc)
        error('no_cpp_compiler');
    end
    fprintf('c++ compiler: %s (%s)\n\n', cc.Name, cc.Version);
catch
    error(['No C++ compiler configured for MATLAB. Run:\n' ...
           '    >> mex -setup cpp\n' ...
           'and install one of the supported toolchains ' ...
           '(see "help build_trim_mex" for platform hints).']);
end

results = struct('name', {}, 'status', {}, 'detail', {});
any_failed = false;

for i = 1:size(targets,1)
    [src_name, out_name] = targets{i, :};
    src = fullfile(here, src_name);
    out = fullfile(here, [out_name '.' mexext]);

    if ~exist(src, 'file')
        fprintf('SKIP  %-18s : source not found (%s)\n', out_name, src_name);
        results(end+1) = struct('name', out_name, 'status', 'skip', ...
                                'detail', 'missing source'); %#ok<AGROW>
        continue
    end

    if ~force && exist(out, 'file')
        si = dir(src);  oi = dir(out);
        if ~isempty(oi) && oi.datenum >= si.datenum
            fprintf('OK    %-18s : up to date (pass ''force'' to rebuild)\n', out_name);
            results(end+1) = struct('name', out_name, 'status', 'up-to-date', ...
                                    'detail', out); %#ok<AGROW>
            continue
        end
    end

    fprintf('BUILD %-18s : %s\n', out_name, src_name);
    try
        compile_one(src, here, verbose);
        fprintf('      -> %s\n', out);
        results(end+1) = struct('name', out_name, 'status', 'built', ...
                                'detail', out); %#ok<AGROW>
    catch ME
        fprintf(2, '      FAILED: %s\n', ME.message);
        results(end+1) = struct('name', out_name, 'status', 'failed', ...
                                'detail', ME.message); %#ok<AGROW>
        any_failed = true;
    end
end

fprintf('\n=== Summary ===\n');
for r = results
    fprintf('  %-18s %s\n', r.name, r.status);
end

if any_failed
    fprintf(2, '\nOne or more targets failed to build.\n');
    fprintf(2, 'Try:  mex -setup cpp   then rerun: build_trim_mex force\n');
else
    fprintf('\nAll MEX targets are in place. Make sure %s is on the path.\n', here);
end
end

% ----------------------------------------------------------------------

function compile_one(src, outdir, verbose)
% Modern CppMexFunction API (-R2018a). Required on arm64 macOS for .cpp
% sources: MATLAB auto-links a cppmex template that references
% mexFunctionAdapter regardless of the -R flag, so the source must
% subclass matlab::mex::Function. Linux/Windows tolerate the flag too.
flags = {'-O', '-R2018a'};
if verbose
    flags{end+1} = '-v';
end

if ispc
    % MSVC default flags; COMPFLAGS override adds C++17 + exceptions.
    flags{end+1} = 'COMPFLAGS=$COMPFLAGS /std:c++17 /EHsc';
else
    % gcc (Linux) and clang (macOS) both accept -std=c++17 -O3.
    % -fvisibility=hidden matches the MEX runtime's symbol policy.
    flags{end+1} = 'CXXFLAGS=$CXXFLAGS -std=c++17 -O3 -fvisibility=hidden';
end

mex(flags{:}, '-outdir', outdir, src);
end

function s = computerLabel()
if ismac
    if strcmp(computer('arch'), 'maca64')
        s = 'macOS (Apple Silicon)';
    else
        s = 'macOS (Intel)';
    end
elseif isunix
    s = 'Linux';
elseif ispc
    s = 'Windows';
else
    s = computer;
end
end
