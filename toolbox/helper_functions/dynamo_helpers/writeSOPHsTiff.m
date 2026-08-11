function writeSOPHsTiff(path, hist_mat, so_bins, freq_bins, kind, stamp, varargin)
%WRITESOPHSTIFF  Write a SOPH histogram as a stamped f32 TIFF (format 2)
%
%   Usage:
%       writeSOPHsTiff(path, SOpower_mat, SOpower_bins, freq_bins, 'sopower', stamp)
%       writeSOPHsTiff(path, SOphase_mat, SOphase_bins, freq_bins, 'sophase', stamp, ...
%           'subjectID', 'S001')
%
%   Inputs:
%       path      : char - output .tiff path (parent dirs created) -- required
%       hist_mat  : matrix - histogram [n_so x n_freq] (SO-feature bins
%                   along rows, frequency along columns, the orientation
%                   SOpowerphaseHistogram returns) -- required
%       so_bins   : vector - SO-feature bin centers (rows) -- required
%       freq_bins : vector - frequency bin centers (columns, Hz) -- required
%       kind      : char - 'sopower' or 'sophase' -- required
%       stamp     : struct - provenance stamp from dynamo_stamp -- required
%
%   Name-Value Pairs:
%       'subjectID' : char - embedded in the metadata JSON (default: '')
%
%   Outputs:
%       none (side effects only)
%
%   Notes:
%       Single-page f32 grayscale TIFF via DYNAMO.writeTiff, with the
%       ImageDescription format-2 JSON of DesktopApp OUTPUT_FORMAT.md
%       sections 2.2 and 8.2: label, rows, cols, both the Rust-native bin
%       keys (row_centers/col_centers) and the MATLAB aliases
%       (SOpower_bins/SOphase_bins + freq_bins), subjectID, an integer
%       format of 2, pixel_format 'f32 row-major', and the provenance
%       stamp keys. Readers treat a string-valued or absent format as
%       the unstamped format 1.
%
%   Example:
%       stamp = dynamo_stamp();
%       writeSOPHsTiff('S001_SOPHs_power_C3.tiff', SOPHs.SOpower_mat, ...
%           SOPHs.SOpower_bins, SOPHs.freq_bins, 'sopower', stamp, ...
%           'subjectID', 'S001');
%
%   See also: loadSOPHsTiff, dynamo_stamp, writeSplinefitTiff, DYNAMO
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

p = inputParser;
addRequired(p, 'path', @(x) validateattributes(x, {'char','string'}, {'scalartext','nonempty'}));
addRequired(p, 'hist_mat', @(x) validateattributes(x, {'numeric'}, {'2d','nonempty'}));
addRequired(p, 'so_bins', @(x) validateattributes(x, {'numeric'}, {'vector'}));
addRequired(p, 'freq_bins', @(x) validateattributes(x, {'numeric'}, {'vector'}));
addRequired(p, 'kind', @(x) any(validatestring(lower(char(x)), {'sopower','sophase'})));
addRequired(p, 'stamp', @(x) validateattributes(x, {'struct'}, {'scalar'}));
addParameter(p, 'subjectID', '', @(x) validateattributes(x, {'char','string'}, {'scalartext'}));
parse(p, path, hist_mat, so_bins, freq_bins, kind, stamp, varargin{:});
path      = char(p.Results.path);
hist_mat  = double(p.Results.hist_mat);
so_bins   = double(p.Results.so_bins(:)');
freq_bins = double(p.Results.freq_bins(:)');
kind      = lower(char(p.Results.kind));
stamp     = p.Results.stamp;
subjectID = char(p.Results.subjectID);

assert(all(isfield(stamp, {'writer','writer_version','kernel_version'})), ...
    'stamp must carry writer, writer_version, and kernel_version (see dynamo_stamp).');
assert(size(hist_mat, 1) == numel(so_bins), ...
    'hist_mat has %d rows but so_bins has %d centers (expected [n_so x n_freq]).', ...
    size(hist_mat, 1), numel(so_bins));
assert(size(hist_mat, 2) == numel(freq_bins), ...
    'hist_mat has %d columns but freq_bins has %d centers (expected [n_so x n_freq]).', ...
    size(hist_mat, 2), numel(freq_bins));

% Metadata JSON. Field order mirrors the Rust write_soph_tiff_with_meta;
% jsonencode preserves struct field order.
meta = struct();
meta.label = kind;
meta.rows = size(hist_mat, 1);
meta.cols = size(hist_mat, 2);
meta.row_centers = so_bins;
meta.col_centers = freq_bins;
if strcmp(kind, 'sopower')
    meta.SOpower_bins = so_bins;
else
    meta.SOphase_bins = so_bins;
end
meta.freq_bins = freq_bins;
meta.subjectID = subjectID;
meta.format = 2;
meta.pixel_format = 'f32 row-major';
meta.writer = char(stamp.writer);
meta.writer_version = char(stamp.writer_version);
meta.kernel_version = char(stamp.kernel_version);

outdir = fileparts(path);
if ~isempty(outdir) && ~isfolder(outdir)
    mkdir(outdir);
end

DYNAMO.writeTiff(path, hist_mat, meta);
end
