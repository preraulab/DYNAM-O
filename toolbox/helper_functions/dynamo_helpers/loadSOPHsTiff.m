function [hist_mat, so_bins, freq_bins, meta] = loadSOPHsTiff(path)
%LOADSOPHSTIFF  Read a SOPH TIFF (per-subject or multi-page aggregate)
%
%   Usage:
%       [hist_mat, so_bins, freq_bins, meta] = loadSOPHsTiff(path)
%
%   Inputs:
%       path : char - SOPH .tiff path (f32 grayscale; a per-subject
%              single-page file or a multi-page aggregate with one page
%              per subject) -- required
%
%   Outputs:
%       hist_mat  : array - histograms [n_so x n_freq x n_pages] as
%                   double, page order preserved. A single-page file
%                   comes back as a plain [n_so x n_freq] matrix (the
%                   trailing singleton dimension drops), so per-subject
%                   loads are unchanged by the aggregate support.
%       so_bins   : double vector - SO-power or SO-phase bin centers
%                   (rows), from SOpower_bins / SOphase_bins /
%                   row_centers; shared by all pages. [] when the file
%                   carries no metadata.
%       freq_bins : double vector - frequency bin centers (columns,
%                   Hz), from freq_bins / col_centers. [] when absent.
%       meta      : struct - decoded metadata (the output order mirrors
%                   writeSOPHsTiff's inputs):
%                    .format         : 1 or 2. Integer '"format": 2' means
%                                      the stamped format 2; a string-
%                                      valued or absent format key means
%                                      the unstamped format 1
%                    .writer         : char ('' when absent)
%                    .writer_version : char ('' when absent)
%                    .kernel_version : char ('' when absent)
%                    .label          : char - 'sopower' | 'sophase' | ''
%                    .subjectID      : char - page 1's subject id
%                                      ('' when absent)
%                    .subject_ids    : string - 1 x n_pages, each page's
%                                      subject id ("" where a page
%                                      carries none)
%                    .n_subjects     : double - page count actually read
%                                      (== size(hist_mat, 3))
%                    .n_subjects_stamped : double - the aggregator's
%                                      n_subjects key (NaN when absent);
%                                      a mismatch with n_subjects means
%                                      the aggregation was incomplete
%                                      and draws a warning
%                    .source_formats : double vector ([] when absent)
%                    .source_writer_versions : string ([] when absent)
%                    .source_semantics : string - each source's
%                                      computation-semantics stamp,
%                                      "unstamped" entries for pre-stamp
%                                      sources ([] when absent)
%                    .raw            : struct - page 1's full decoded
%                                      JSON (aggregate-level keys live
%                                      here; empty struct when
%                                      absent/unparsable)
%                    .page_raw       : cell - each page's decoded JSON
%
%   Notes:
%       Writers emit both the Rust-native bin keys (row_centers /
%       col_centers) and the MATLAB aliases (SOpower_bins / SOphase_bins /
%       freq_bins); this reader accepts either. A missing or unparsable
%       ImageDescription yields empty bins and format 1 rather than an
%       error (reader rule 3: never fail on a missing stamp).
%
%       Aggregates put one subject per page; page 1's ImageDescription
%       additionally carries the aggregate-level keys (subject_ids,
%       n_subjects, source_formats, source_writer_versions,
%       source_semantics) on top of that subject's own metadata. Bin
%       centers are shared across pages because the aggregator refuses
%       mismatched axes, so page 1's bins label the whole stack. A page
%       sized differently from page 1 raises an error naming the page -
%       the aggregator never writes one, so it signals a file this
%       reader does not understand.
%
%   Example:
%       % Per-subject file - 2-D, as always:
%       [H, so_bins, freq_bins] = loadSOPHsTiff('S001_SOPHs_power_C3.tiff');
%       imagesc(so_bins, freq_bins, H'); axis xy
%
%       % Aggregate - one page per subject:
%       [H, so_bins, freq_bins, meta] = loadSOPHsTiff('SOPHs_power_C3.tiff');
%       imagesc(so_bins, freq_bins, mean(H, 3, 'omitnan')');
%       axis xy; title(sprintf('%d subjects', meta.n_subjects));
%
%   See also: writeSOPHsTiff, loadStatsTable, DYNAMO
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

assert(ischar(path) || (isstring(path) && isscalar(path)), 'path must be char or string.');
path = char(path);
if ~isfile(path)
    error('loadSOPHsTiff:fileNotFound', 'No such file: %s', path);
end

info = imfinfo(path);
n_pages = numel(info);

first = double(imread(path, 1));
hist_mat = zeros(size(first, 1), size(first, 2), n_pages);
hist_mat(:, :, 1) = first;

so_bins = [];
freq_bins = [];
meta = struct('format', 1, 'writer', '', 'writer_version', '', ...
    'kernel_version', '', 'label', '', 'subjectID', '', ...
    'subject_ids', strings(1, n_pages), ...
    'n_subjects', n_pages, 'n_subjects_stamped', NaN, ...
    'source_formats', [], 'source_writer_versions', strings(1, 0), ...
    'source_semantics', strings(1, 0), ...
    'raw', struct(), 'page_raw', {cell(1, n_pages)});

for k = 1:n_pages
    decoded = struct();
    try
        if isfield(info, 'ImageDescription') && ~isempty(info(k).ImageDescription)
            decoded = jsondecode(info(k).ImageDescription);
        end
    catch
        decoded = struct();
    end
    if ~isstruct(decoded)
        decoded = struct();
    end
    meta.page_raw{k} = decoded;
    meta.subject_ids(k) = page_subject_id_(decoded);
    if k > 1
        page = double(imread(path, k));
        if ~isequal(size(page), size(first))
            error('loadSOPHsTiff:pageSizeMismatch', ...
                '%s: page %d is %dx%d but page 1 is %dx%d - not a SOPH file this reader understands.', ...
                path, k, size(page, 1), size(page, 2), size(first, 1), size(first, 2));
        end
        hist_mat(:, :, k) = page;
    end
end

decoded = meta.page_raw{1};
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
meta.subjectID      = char(meta.subject_ids(1));

% SO-feature bins: MATLAB alias first, Rust-native key as fallback.
if isfield(decoded, 'SOpower_bins') && ~isempty(decoded.SOpower_bins)
    so_bins = double(decoded.SOpower_bins(:)');
elseif isfield(decoded, 'SOphase_bins') && ~isempty(decoded.SOphase_bins)
    so_bins = double(decoded.SOphase_bins(:)');
elseif isfield(decoded, 'row_centers') && ~isempty(decoded.row_centers)
    so_bins = double(decoded.row_centers(:)');
end
if isfield(decoded, 'freq_bins') && ~isempty(decoded.freq_bins)
    freq_bins = double(decoded.freq_bins(:)');
elseif isfield(decoded, 'col_centers') && ~isempty(decoded.col_centers)
    freq_bins = double(decoded.col_centers(:)');
end

% Aggregate-level keys (page 1 only; absent on per-subject files).
if isfield(decoded, 'n_subjects') && isnumeric(decoded.n_subjects) && isscalar(decoded.n_subjects)
    meta.n_subjects_stamped = double(decoded.n_subjects);
    if meta.n_subjects_stamped ~= n_pages
        warning('loadSOPHsTiff:pageCountMismatch', ...
            '%s: %d page(s) but the aggregator stamped n_subjects = %d - the aggregation may be incomplete.', ...
            path, n_pages, meta.n_subjects_stamped);
    end
end
if isfield(decoded, 'source_formats') && isnumeric(decoded.source_formats)
    meta.source_formats = double(decoded.source_formats(:)');
end
if isfield(decoded, 'source_writer_versions')
    meta.source_writer_versions = string_list_(decoded.source_writer_versions);
end
if isfield(decoded, 'source_semantics')
    meta.source_semantics = string_list_(decoded.source_semantics);
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


function id = page_subject_id_(d)
%PAGE_SUBJECT_ID_  A page's subject id, "" when it carries none
%
%   Inputs:
%       d : struct - decoded page JSON -- required
%
%   Outputs:
%       id : string - subjectID, falling back to subject_id
for name = ["subjectID", "subject_id"]
    if isfield(d, name) && (ischar(d.(name)) || isstring(d.(name)))
        id = strtrim(string(d.(name)));
        if strlength(id) > 0
            return;
        end
    end
end
id = "";
end


function s = string_list_(v)
%STRING_LIST_  Decoded JSON list as a string row vector
%
%   Inputs:
%       v : any - jsondecode result -- required. The aggregator writes
%           these lists with mixed element types (semantics stamps are
%           numbers, "unstamped" is a string), which jsondecode returns
%           as a numeric vector, a cell of mixed scalars, a cellstr, a
%           string array, or a bare char.
%
%   Outputs:
%       s : string - 1 x n, numbers rendered as digits (empty 1 x 0
%           when the value is none of the above)
s = strings(1, 0);
if isnumeric(v)
    s = string(double(v(:)'));
elseif iscell(v)
    s = strings(1, numel(v));
    for k = 1:numel(v)
        if isnumeric(v{k}) && isscalar(v{k})
            s(k) = string(double(v{k}));
        elseif ischar(v{k}) || isstring(v{k})
            s(k) = string(v{k});
        end
    end
elseif isstring(v)
    s = v(:)';
elseif ischar(v)
    s = string(v);
end
end
