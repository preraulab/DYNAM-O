function [hist_mat, meta] = loadSOPHsTiff(path)
%LOADSOPHSTIFF  Read a SOPH TIFF and its ImageDescription metadata
%
%   Usage:
%       [hist_mat, meta] = loadSOPHsTiff(path)
%
%   Inputs:
%       path : char - SOPH .tiff path (single-page f32 grayscale) -- required
%
%   Outputs:
%       hist_mat : matrix - histogram [n_so x n_freq] as double
%       meta     : struct - decoded metadata:
%                    .format         : 1 or 2. Integer '"format": 2' means
%                                      the stamped format 2; a string-
%                                      valued or absent format key means
%                                      the unstamped format 1
%                    .writer         : char ('' when absent)
%                    .writer_version : char ('' when absent)
%                    .kernel_version : char ('' when absent)
%                    .label          : char - 'sopower' | 'sophase' | ''
%                    .subjectID      : char ('' when absent)
%                    .so_bins        : double vector - SO-feature bin
%                                      centers, from SOpower_bins /
%                                      SOphase_bins / row_centers
%                    .freq_bins      : double vector - from freq_bins /
%                                      col_centers
%                    .raw            : struct - the full decoded JSON
%                                      (empty struct when absent/unparsable)
%
%   Notes:
%       Writers emit both the Rust-native bin keys (row_centers /
%       col_centers) and the MATLAB aliases (SOpower_bins / SOphase_bins /
%       freq_bins); this reader accepts either. A missing or unparsable
%       ImageDescription yields empty bins and format 1 rather than an
%       error (reader rule 3: never fail on a missing stamp).
%
%   Example:
%       [H, meta] = loadSOPHsTiff('S001_SOPHs_power_C3.tiff');
%       imagesc(meta.so_bins, meta.freq_bins, H'); axis xy
%
%   See also: writeSOPHsTiff, loadStatsTable, DYNAMO
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

assert(ischar(path) || (isstring(path) && isscalar(path)), 'path must be char or string.');
path = char(path);
if ~isfile(path)
    error('loadSOPHsTiff:fileNotFound', 'No such file: %s', path);
end

hist_mat = double(imread(path, 1));

meta = struct('format', 1, 'writer', '', 'writer_version', '', ...
    'kernel_version', '', 'label', '', 'subjectID', '', ...
    'so_bins', [], 'freq_bins', [], 'raw', struct());

decoded = struct();
try
    info = imfinfo(path);
    if isfield(info, 'ImageDescription') && ~isempty(info(1).ImageDescription)
        decoded = jsondecode(info(1).ImageDescription);
    end
catch
    decoded = struct();
end
if ~isstruct(decoded)
    decoded = struct();
end
meta.raw = decoded;

% Integer format key means the stamped format 2; a string-valued format
% (the old 'f32 row-major' pixel-layout note) or an absent key means 1.
if isfield(decoded, 'format') && isnumeric(decoded.format) && isscalar(decoded.format)
    meta.format = double(decoded.format);
end

meta.writer         = char_field_(decoded, 'writer');
meta.writer_version = char_field_(decoded, 'writer_version');
meta.kernel_version = char_field_(decoded, 'kernel_version');
meta.label          = char_field_(decoded, 'label');
meta.subjectID      = char_field_(decoded, 'subjectID');
if isempty(meta.subjectID)
    meta.subjectID = char_field_(decoded, 'subject_id');
end

% SO-feature bins: MATLAB alias first, Rust-native key as fallback.
if isfield(decoded, 'SOpower_bins') && ~isempty(decoded.SOpower_bins)
    meta.so_bins = double(decoded.SOpower_bins(:)');
elseif isfield(decoded, 'SOphase_bins') && ~isempty(decoded.SOphase_bins)
    meta.so_bins = double(decoded.SOphase_bins(:)');
elseif isfield(decoded, 'row_centers') && ~isempty(decoded.row_centers)
    meta.so_bins = double(decoded.row_centers(:)');
end
if isfield(decoded, 'freq_bins') && ~isempty(decoded.freq_bins)
    meta.freq_bins = double(decoded.freq_bins(:)');
elseif isfield(decoded, 'col_centers') && ~isempty(decoded.col_centers)
    meta.freq_bins = double(decoded.col_centers(:)');
end
end


function s = char_field_(d, name)
%CHAR_FIELD_  Fetch a struct field as trimmed char, '' when absent
%
%   Inputs:
%       d    : struct - decoded JSON -- required
%       name : char - field name -- required
%
%   Outputs:
%       s : char - field value, or '' when missing/non-text
s = '';
if isfield(d, name) && (ischar(d.(name)) || isstring(d.(name)))
    s = char(strtrim(string(d.(name))));
end
end
