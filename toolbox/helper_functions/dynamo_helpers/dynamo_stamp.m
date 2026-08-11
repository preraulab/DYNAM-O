function stamp = dynamo_stamp(kernel)
%DYNAMO_STAMP  Provenance stamp struct for the canonical-tree writers
%
%   Usage:
%       stamp = dynamo_stamp()                  % Rust-kernel compute
%       stamp = dynamo_stamp('matlab-native')   % pure-MATLAB compute
%
%   Inputs:
%       kernel : char - kernel identity to record (optional). Omit to use
%                dynamo_kernel_version(), which reports the dynamo_rs
%                build loaded by this session. Pass the literal
%                'matlab-native' when the numbers being written were
%                computed on the pure-MATLAB path (backend 'matlab').
%                Any other char is recorded verbatim, which lets callers
%                reuse a value they already resolved.
%
%   Outputs:
%       stamp : struct - the three writer-side stamp keys from DesktopApp
%               OUTPUT_FORMAT.md section 8.1:
%                 .writer         : 'dynamo-matlab'
%                 .writer_version : dynamo_version() grammar
%                                   '<semver>+<sha12>[.dirty]' | 'unknown'
%                 .kernel_version : kernel build grammar, or the literal
%                                   'matlab-native' / 'unknown'
%
%   Notes:
%       The per-artifact 'format' integer is NOT part of this struct. It
%       is a property of each artifact schema, so each writer hardcodes
%       its own current format number.
%
%   Example:
%       stamp = dynamo_stamp();
%       writeStatsTableCsv(csv_path, stats_table, stamp, 'subjectID', subj);
%
%   See also: dynamo_version, dynamo_kernel_version, writeStatsTableCsv,
%             writeParamfitCsv, writeSOPHsTiff, writeSplinefitTiff, writeAuxH5
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

if nargin < 1 || isempty(kernel)
    kernel = dynamo_kernel_version();
end

stamp = struct( ...
    'writer',         'dynamo-matlab', ...
    'writer_version', dynamo_version(), ...
    'kernel_version', char(kernel));
end
