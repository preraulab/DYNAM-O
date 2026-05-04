function result = aggregate_DYNAMO_outputs(channelDir, opts)
%AGGREGATE_DYNAMO_OUTPUTS  Stack per-subject DYNAMO outputs in one channel folder.
%
%   result = aggregate_DYNAMO_outputs(channelDir)
%   result = aggregate_DYNAMO_outputs(channelDir, 'Files', cellOfPaths)
%
%   Walks a DYNAMO channel directory (the parent of param_basis/, SOPHs/,
%   etc.), dedupes per-subject filename variants, and returns in-memory
%   stacked artifacts ready to be written to disk.
%
%   When 'Files' is provided (a cell array of absolute paths supplied by
%   the JSONL run-index), the function uses that list as the source of
%   truth and skips dir() entirely — eliminating the per-category
%   filesystem scans that dominate aggregation cost on slow drives. When
%   'Files' is empty (the default, or when the index has no record), the
%   function falls back to dir()-based discovery as before.
%
%   The caller is responsible for serializing result.* to the appropriate
%   files; this function does no I/O of its own beyond reads.
%
%   The four categories returned are:
%       result.paramPower  — power paramfit table aggregate
%       result.paramPhase  — phase paramfit table aggregate
%       result.sophsPower  — SO-power histogram stack
%       result.sophsPhase  — SO-phase histogram stack
%
%   Each is a struct with these (possibly empty) fields:
%       .csv_table      — table of vertically-concatenated per-subject rows
%                         with an 'ID' column prepended; populated only when
%                         per-subject .csv files were found.
%       .mat_table      — same shape, sourced from per-subject .mat files.
%                         (Tables only — used for paramfit categories.)
%       .mat_struct     — for SOPHs categories: struct holding the 3-D
%                         stacked histogram, subjectIDs, freq_bins,
%                         and SO-axis bins.
%       .tiff_pages     — for SOPHs categories: cell array of per-subject
%                         2-D matrices (one page each, in subject order)
%                         to be written to a multi-page TIFF.
%       .subjectIDs     — cell array of fbase strings whose data made it
%                         into this category's aggregate, in row/page order.
%
%   The dedupe rule: group per-subject file basenames by the first
%   whitespace-separated token of the fbase. Among collisions, keep the
%   shortest fbase (typically the unsuffixed default); tiebreak alphabetical.
%
%   result.skipped is a cell array of {fbase, reason} pairs documenting
%   files that were dropped (dedupe collisions or load errors).

arguments
    channelDir  (1,:) char
    opts.Files  (1,:) cell        = {}
    opts.ProgressFcn               = []     % @(catName,stage,ii,total) -> []
end

if isempty(opts.ProgressFcn)
    progress = @(varargin) [];
else
    progress = opts.ProgressFcn;
end

result.paramPower  = empty_paramfit_struct();
result.paramPhase  = empty_paramfit_struct();
result.sophsPower  = empty_sophs_struct();
result.sophsPhase  = empty_sophs_struct();
result.skipped     = {};
result.warnings    = {};   % user-facing strings; caller mirrors to UI status

if ~isfolder(channelDir)
    return
end

[~, channelName] = fileparts(channelDir);

% When Files is provided, every list_*_files call below pulls from this
% in-memory list instead of hitting the filesystem. The paths are kept as
% absolute (caller passes them already resolved); each list_* helper
% filters by directory + suffix to recover the same shape dir() would
% have returned.
useIndex = ~isempty(opts.Files);

% Each category: directory + filename pattern (analysis tag) + format extensions
cats(1) = struct( ...
    'name',        'paramPower', ...
    'subdir',      'param_basis', ...
    'tag',         'SOpower_paramfit', ...
    'kind',        'table');
cats(2) = struct( ...
    'name',        'paramPhase', ...
    'subdir',      'param_basis', ...
    'tag',         'SOphase_paramfit', ...
    'kind',        'table');
cats(3) = struct( ...
    'name',        'sophsPower', ...
    'subdir',      'SOPHs', ...
    'tag',         'SOPHs', ...
    'kind',        'sophs_power');
cats(4) = struct( ...
    'name',        'sophsPhase', ...
    'subdir',      'SOPHs', ...
    'tag',         'SOPHs', ...
    'kind',        'sophs_phase');

for ci = 1:numel(cats)
    cat = cats(ci);
    catDir = fullfile(channelDir, cat.subdir);
    if ~isfolder(catDir), continue, end

    % Find per-subject files. For paramfit: <fbase>_<tag>_<channel>.{csv,mat}.
    % For SOPHs we always source from the *_SOPHs_<channel>.mat (whole struct)
    % and the *_SOPHs_{power,phase}_<channel>.tiff per-axis files.
    switch cat.kind
        case 'table'
            if useIndex
                csvList = list_paramfit_from_index(opts.Files, catDir, cat.tag, channelName, '.csv');
                matList = list_paramfit_from_index(opts.Files, catDir, cat.tag, channelName, '.mat');
            else
                csvList = list_paramfit_files(catDir, cat.tag, channelName, '.csv');
                matList = list_paramfit_files(catDir, cat.tag, channelName, '.mat');
            end
            [csvKept, csvDropped] = dedupe_by_subject(csvList);
            [matKept, matDropped] = dedupe_by_subject(matList);
            result.skipped = [result.skipped; csvDropped; matDropped];

            catName = cat.name;
            progCsv = @(ii,total) progress(catName, 'csv', ii, total);
            progMat = @(ii,total) progress(catName, 'mat', ii, total);
            [csv_table, csv_ids, w1] = stack_table_files(csvKept, 'csv', progCsv);
            [mat_table, mat_ids, w2] = stack_table_files(matKept, 'mat', progMat);
            result.warnings = [result.warnings, w1, w2];
            result.(cat.name).csv_table  = csv_table;
            result.(cat.name).mat_table  = mat_table;
            result.(cat.name).subjectIDs = unique_preserving([csv_ids; mat_ids]);

        case {'sophs_power', 'sophs_phase'}
            axis = strrep(cat.kind, 'sophs_', '');     % 'power' or 'phase'

            if useIndex
                matList  = list_sophs_struct_from_index(opts.Files, catDir, channelName);
                tiffList = list_sophs_axis_from_index(opts.Files, catDir, channelName, axis);
            else
                matList  = list_sophs_struct_files(catDir, channelName, '.mat');
                tiffList = list_sophs_axis_files(catDir, channelName, axis, '.tiff');
            end

            [matKept,  matDrop]  = dedupe_by_subject(matList);
            [tiffKept, tiffDrop] = dedupe_by_subject(tiffList);
            result.skipped = [result.skipped; matDrop; tiffDrop];

            catName = cat.name;
            progMat  = @(ii,total) progress(catName, 'mat',  ii, total);
            progTiff = @(ii,total) progress(catName, 'tiff', ii, total);
            [mat_struct, mat_ids, w3]              = stack_sophs_mat_files(matKept, axis, progMat);
            [tiff_pages, tiff_ids, w4, fbT, sbT]   = stack_sophs_tiff_files(tiffKept, axis, progTiff);
            result.warnings = [result.warnings, w3, w4];

            % Capture freq + SO-axis bins for the aggregate. Prefer the
            % bins already pulled out of stack_sophs_mat_files; if those
            % weren't populated (TIFF-only run), try (1) the TIFF
            % ImageDescription, (2) any whole-struct .mat in the folder,
            % (3) the run_settings_*.txt file at the results root.
            freqBins = []; soBins = [];
            if ~isempty(fieldnames(mat_struct))
                if isfield(mat_struct,'freq_bins'),  freqBins = mat_struct.freq_bins; end
                if isfield(mat_struct,['SO' axis '_bins']), soBins = mat_struct.(['SO' axis '_bins']); end
            end
            if isempty(freqBins) && ~isempty(fbT), freqBins = fbT; end
            if isempty(soBins)   && ~isempty(sbT), soBins   = sbT; end
            if (isempty(freqBins) || isempty(soBins)) && ~isempty(matList)
                [fb2, sb2] = peek_bins_any(matList, axis);
                if isempty(freqBins), freqBins = fb2; end
                if isempty(soBins),   soBins   = sb2; end
            end
            if isempty(freqBins) || (isempty(soBins) && strcmp(axis,'phase'))
                [fb3, sb3] = peek_bins_from_settings(channelDir, axis);
                if isempty(freqBins) && ~isempty(fb3), freqBins = fb3; end
                if isempty(soBins)   && ~isempty(sb3), soBins   = sb3; end
            end

            result.(cat.name).mat_struct = mat_struct;
            result.(cat.name).tiff_pages = tiff_pages;
            result.(cat.name).subjectIDs = unique_preserving([mat_ids(:); tiff_ids(:)]);
            % Keep the per-source ID lists so the caller can write parallel
            % subjectIDs files matching .mat vs .tiff page order.
            result.(cat.name).mat_ids  = mat_ids;
            result.(cat.name).tiff_ids = tiff_ids;
            result.(cat.name).freq_bins = freqBins;
            result.(cat.name).so_bins   = soBins;
    end
end

end % aggregate_DYNAMO_outputs

% ============================================================================

function s = empty_paramfit_struct()
s = struct('csv_table', table.empty, 'mat_table', table.empty, ...
           'subjectIDs', {{}});
end

function s = empty_sophs_struct()
s = struct('mat_struct', struct(), 'tiff_pages', {{}}, ...
           'subjectIDs', {{}}, 'mat_ids', {{}}, 'tiff_ids', {{}}, ...
           'freq_bins', [], 'so_bins', []);
end

function [freqBins, soBins] = peek_bins_any(lst, axis)
%PEEK_BINS_ANY  Try each .mat in lst until we find one whose SOPHs struct
%carries the bin axes; return [] if none did.
freqBins = []; soBins = [];
binsField = ['SO' axis '_bins'];
for ii = 1:numel(lst)
    try
        S = load(lst(ii).path);
    catch
        continue
    end
    SOPHs = locate_sophs_struct(S);
    if isempty(SOPHs), continue, end
    if isfield(SOPHs,'freq_bins'), freqBins = SOPHs.freq_bins; end
    if isfield(SOPHs, binsField),  soBins   = SOPHs.(binsField); end
    if ~isempty(freqBins) || ~isempty(soBins), return, end
end
end

function lst = list_paramfit_from_index(allFiles, dirPath, tag, channelName, ext)
%LIST_PARAMFIT_FROM_INDEX  Filter the index file list for paramfit-shaped
%   entries under dirPath. Same return shape as list_paramfit_files; no
%   filesystem access.
suffix = ['_' tag '_' channelName ext];
lst = struct('fbase', {}, 'path', {});
for ii = 1:numel(allFiles)
    p = char(allFiles{ii});
    [parent, base, e] = fileparts(p);
    if ~strcmp([base e], '') && ~strcmp(parent, dirPath), continue, end
    fname = [base e];
    if ~endsWith(fname, suffix), continue, end
    fbase = extractBefore(fname, length(fname) - length(suffix) + 1);
    if isempty(fbase), continue, end
    lst(end+1).fbase = fbase; %#ok<AGROW>
    lst(end).path    = p;
end
end

function lst = list_sophs_struct_from_index(allFiles, dirPath, channelName)
%LIST_SOPHS_STRUCT_FROM_INDEX  Filter the index file list for whole-SOPHs
%   .mat entries under dirPath, excluding the per-axis variants.
suffix = ['_SOPHs_' channelName '.mat'];
lst = struct('fbase', {}, 'path', {});
for ii = 1:numel(allFiles)
    p = char(allFiles{ii});
    [parent, base, e] = fileparts(p);
    if ~strcmp(parent, dirPath), continue, end
    fname = [base e];
    if contains(fname, '_SOPHs_power_') || contains(fname, '_SOPHs_phase_')
        continue
    end
    if ~endsWith(fname, suffix), continue, end
    fbase = extractBefore(fname, length(fname) - length(suffix) + 1);
    if isempty(fbase), continue, end
    lst(end+1).fbase = fbase; %#ok<AGROW>
    lst(end).path    = p;
end
end

function lst = list_sophs_axis_from_index(allFiles, dirPath, channelName, axis)
%LIST_SOPHS_AXIS_FROM_INDEX  Filter the index file list for the
%   per-axis SOPHs TIFFs under dirPath.
suffix = ['_SOPHs_' axis '_' channelName '.tiff'];
lst = struct('fbase', {}, 'path', {});
for ii = 1:numel(allFiles)
    p = char(allFiles{ii});
    [parent, base, e] = fileparts(p);
    if ~strcmp(parent, dirPath), continue, end
    fname = [base e];
    if ~endsWith(fname, suffix), continue, end
    fbase = extractBefore(fname, length(fname) - length(suffix) + 1);
    if isempty(fbase), continue, end
    lst(end+1).fbase = fbase; %#ok<AGROW>
    lst(end).path    = p;
end
end

function lst = list_paramfit_files(dirPath, tag, channelName, ext)
%LIST_PARAMFIT_FILES  Find per-subject files matching <fbase>_<tag>_<channel><ext>.
suffix = ['_' tag '_' channelName ext];
files = dir(fullfile(dirPath, ['*' suffix]));
lst = struct('fbase', {}, 'path', {});
for ii = 1:numel(files)
    fname = files(ii).name;
    if ~endsWith(fname, suffix), continue, end
    fbase = extractBefore(fname, length(fname) - length(suffix) + 1);
    if isempty(fbase), continue, end
    lst(end+1).fbase = fbase; %#ok<AGROW>
    lst(end).path    = fullfile(dirPath, fname);
end
end

function lst = list_sophs_struct_files(dirPath, channelName, ext)
%LIST_SOPHS_STRUCT_FILES  Find per-subject *_SOPHs_<channel>.mat (whole struct).
suffix = ['_SOPHs_' channelName ext];
files = dir(fullfile(dirPath, ['*' suffix]));
lst = struct('fbase', {}, 'path', {});
for ii = 1:numel(files)
    fname = files(ii).name;
    % Skip the per-axis variants (*_SOPHs_power_*, *_SOPHs_phase_*) so we
    % only pick up the whole-struct file.
    if contains(fname, '_SOPHs_power_') || contains(fname, '_SOPHs_phase_')
        continue
    end
    if ~endsWith(fname, suffix), continue, end
    fbase = extractBefore(fname, length(fname) - length(suffix) + 1);
    if isempty(fbase), continue, end
    lst(end+1).fbase = fbase; %#ok<AGROW>
    lst(end).path    = fullfile(dirPath, fname);
end
end

function lst = list_sophs_axis_files(dirPath, channelName, axis, ext)
%LIST_SOPHS_AXIS_FILES  Find per-subject *_SOPHs_<axis>_<channel><ext>.
suffix = ['_SOPHs_' axis '_' channelName ext];
files = dir(fullfile(dirPath, ['*' suffix]));
lst = struct('fbase', {}, 'path', {});
for ii = 1:numel(files)
    fname = files(ii).name;
    if ~endsWith(fname, suffix), continue, end
    fbase = extractBefore(fname, length(fname) - length(suffix) + 1);
    if isempty(fbase), continue, end
    lst(end+1).fbase = fbase; %#ok<AGROW>
    lst(end).path    = fullfile(dirPath, fname);
end
end

function [kept, dropped] = dedupe_by_subject(lst)
%DEDUPE_BY_SUBJECT  Group entries by first whitespace token of fbase; keep the
%shortest fbase (tiebreak alphabetical). Returns kept entries plus a
%{fbase, reason} cell array of dropped entries.
kept    = lst([]);
dropped = {};
if isempty(lst)
    return
end

fbases = {lst.fbase};
% First whitespace-separated token of each fbase
tokens = cell(size(fbases));
for ii = 1:numel(fbases)
    tk = strsplit(fbases{ii});
    if isempty(tk), tokens{ii} = ''; else, tokens{ii} = tk{1}; end
end
uniqTokens = unique(tokens);
for ti = 1:numel(uniqTokens)
    grpIdx = find(strcmp(tokens, uniqTokens{ti}));
    if numel(grpIdx) == 1
        kept(end+1) = lst(grpIdx); %#ok<AGROW>
        continue
    end
    grpFbases  = fbases(grpIdx);
    [~, order] = sort(cellfun(@length, grpFbases));
    grpIdx     = grpIdx(order);
    grpFbases  = grpFbases(order);
    % Among entries of the shortest length, alphabetical order
    minLen = length(grpFbases{1});
    keepLocal = grpIdx(1);
    for kk = 2:numel(grpIdx)
        if length(grpFbases{kk}) > minLen
            break
        end
    end
    kept(end+1) = lst(keepLocal); %#ok<AGROW>
    for jj = 1:numel(grpIdx)
        if grpIdx(jj) == keepLocal, continue, end
        dropped(end+1, :) = {lst(grpIdx(jj)).fbase, ...
            sprintf('dedupe collision with kept fbase "%s"', lst(keepLocal).fbase)}; %#ok<AGROW>
    end
end
end

function [T, ids, warnings_out] = stack_table_files(lst, fmt, progFcn)
%STACK_TABLE_FILES  Vertically concatenate per-subject paramfit tables with an
%ID column prepended (= fbase repeated for every mode row).
T            = table.empty;
ids          = {};
warnings_out = {};
if isempty(lst), return, end
if nargin < 3 || isempty(progFcn), progFcn = @(varargin) []; end
parts = cell(1, numel(lst));
total = numel(lst);
for ii = 1:total
    progFcn(ii, total);
    fbase = lst(ii).fbase;
    p     = lst(ii).path;
    try
        switch fmt
            case 'csv'
                % Per-subject paramfit CSVs start with ~16 lines of
                % '#'-prefixed metadata (background coefs, gof, bins,
                % fitobj coef names/values — see writeParamfitCsv.m).
                % CommentStyle='#' is the documented contract; without
                % it, readtable treats those metadata lines as data
                % and the stacked aggregate is garbage.
                Ti = readtable(p, ...
                    'VariableNamingRule', 'preserve', ...
                    'CommentStyle',       '#');
            case 'mat'
                S  = load(p);
                Ti = locate_paramfit_table(S);
        end
    catch ME
        warnings_out{end+1} = sprintf('load failed: %s — %s', p, ME.message); %#ok<AGROW>
        continue
    end
    if isempty(Ti) || height(Ti) == 0
        continue
    end
    idCol = repmat({fbase}, height(Ti), 1);
    Ti = addvars(Ti, idCol, 'Before', 1, 'NewVariableNames', 'ID');
    parts{ii} = Ti;
    ids(end+1, 1) = {fbase}; %#ok<AGROW>
end
parts(cellfun(@isempty, parts)) = [];
if isempty(parts), return, end
T = vertcat(parts{:});
end

function T = locate_paramfit_table(S)
%LOCATE_PARAMFIT_TABLE  Pull the .params table out of a loaded paramfit MAT.
fn = fieldnames(S);
T = table.empty;
for ii = 1:numel(fn)
    v = S.(fn{ii});
    if isstruct(v) && isfield(v, 'params') && istable(v.params)
        T = v.params; return
    end
end
end

function [out, ids, warnings_out] = stack_sophs_mat_files(lst, axis, progFcn)
%STACK_SOPHS_MAT_FILES  Stack 2-D SOpower_mat or SOphase_mat into a 3-D array.
out          = struct();
ids          = {};
warnings_out = {};
if isempty(lst), return, end
if nargin < 3 || isempty(progFcn), progFcn = @(varargin) []; end

field = ['SO' axis '_mat'];
binsField = ['SO' axis '_bins'];

stacks = {};
freq_bins = []; bins = [];
total = numel(lst);
for ii = 1:total
    progFcn(ii, total);
    fbase = lst(ii).fbase;
    p     = lst(ii).path;
    try
        S = load(p);
    catch ME
        warnings_out{end+1} = sprintf('load failed: %s — %s', p, ME.message); %#ok<AGROW>
        continue
    end
    SOPHs = locate_sophs_struct(S);
    if isempty(SOPHs) || ~isfield(SOPHs, field) || isempty(SOPHs.(field))
        warnings_out{end+1} = sprintf('%s has no %s — skipping', p, field); %#ok<AGROW>
        continue
    end
    M = SOPHs.(field);
    if isempty(stacks)
        if isfield(SOPHs, 'freq_bins'), freq_bins = SOPHs.freq_bins; end
        if isfield(SOPHs, binsField),   bins      = SOPHs.(binsField); end
        canon = size(M);
    else
        if ~isequal(size(M), canon)
            warnings_out{end+1} = sprintf('%s has %s size %s; expected %s — skipping', ...
                p, field, mat2str(size(M)), mat2str(canon)); %#ok<AGROW>
            continue
        end
    end
    stacks{end+1} = M; %#ok<AGROW>
    ids(end+1, 1) = {fbase}; %#ok<AGROW>
end

if isempty(stacks), return, end
out.(field)     = cat(3, stacks{:});
out.subjectIDs  = ids;
out.freq_bins   = freq_bins;
out.(binsField) = bins;
end

function S = locate_sophs_struct(loaded)
%LOCATE_SOPHS_STRUCT  Find the SOPHs struct inside a loaded MAT.
fn = fieldnames(loaded);
S  = [];
for ii = 1:numel(fn)
    v = loaded.(fn{ii});
    if isstruct(v) && (isfield(v, 'SOpower_mat') || isfield(v, 'SOphase_mat'))
        S = v; return
    end
end
end

function [pages, ids, warnings_out, freq_bins, so_bins] = stack_sophs_tiff_files(lst, axis_kind, progFcn)
%STACK_SOPHS_TIFF_FILES  Read each per-subject single-page TIFF as a 2-D
%matrix; return as a cell array (one page per subject). If a TIFF carries
%an ImageDescription tag with bin metadata (newer DYNAMO writes), the bins
%are pulled from the first TIFF that has them.
pages        = {};
ids          = {};
warnings_out = {};
freq_bins    = [];
so_bins      = [];
if nargin < 2, axis_kind = ''; end
if nargin < 3 || isempty(progFcn), progFcn = @(varargin) []; end
if isempty(lst), return, end
canon = [];
binsField = '';
if ~isempty(axis_kind), binsField = ['SO' axis_kind '_bins']; end
total = numel(lst);
for ii = 1:total
    progFcn(ii, total);
    fbase = lst(ii).fbase;
    p     = lst(ii).path;
    try
        M = double(imread(p));
    catch ME
        warnings_out{end+1} = sprintf('TIFF read failed: %s — %s', p, ME.message); %#ok<AGROW>
        continue
    end
    if isempty(canon), canon = size(M); end
    if ~isequal(size(M), canon)
        warnings_out{end+1} = sprintf('%s has size %s; expected %s — skipping', ...
            p, mat2str(size(M)), mat2str(canon)); %#ok<AGROW>
        continue
    end
    pages{end+1} = M;            %#ok<AGROW>
    ids(end+1,1) = {fbase};      %#ok<AGROW>

    if isempty(freq_bins) || isempty(so_bins)
        try
            info = imfinfo(p);
            if isfield(info, 'ImageDescription') && ~isempty(info(1).ImageDescription)
                meta = jsondecode(info(1).ImageDescription);
                if isempty(freq_bins) && isfield(meta,'freq_bins')
                    freq_bins = meta.freq_bins(:);
                end
                if isempty(so_bins) && ~isempty(binsField) && isfield(meta, binsField)
                    so_bins = meta.(binsField)(:);
                end
            end
        catch
            % ImageDescription missing/unparseable — leave bins empty.
        end
    end
end
end

function out = unique_preserving(c)
%UNIQUE_PRESERVING  Unique cell array of chars that preserves first-occurrence order.
if isempty(c), out = {}; return, end
[~, ia] = unique(c, 'stable');
out = c(ia);
end

function [freq_bins, so_bins] = peek_bins_from_settings(channelDir, axis_kind)
%PEEK_BINS_FROM_SETTINGS  Reconstruct freq_bins (and SOphase_bins) from a
%`<root>/settings/run_settings_*.txt` file emitted by the FileManager.
%SOpower_bins are adaptive per subject and cannot be recovered this way.
freq_bins = [];
so_bins   = [];
root = fileparts(channelDir);
settingsDir = fullfile(root, 'settings');
if ~isfolder(settingsDir), return, end
files = dir(fullfile(settingsDir, 'run_settings_*.txt'));
if isempty(files), return, end
% Use the most recent settings file.
[~, idx] = max([files.datenum]);
txt = fileread(fullfile(files(idx).folder, files(idx).name));

freq_range = parse_vec(txt, 'SOPH_options.freq_range');
freq_step  = parse_vec(txt, 'SOPH_options.freq_binsizestep');
freq_bins  = bin_centers(freq_range, freq_step);

if strcmp(axis_kind, 'phase')
    ph_range = parse_vec(txt, 'SOPH_options.SOphase_range');
    ph_step  = parse_vec(txt, 'SOPH_options.SOphase_binsizestep');
    so_bins  = bin_centers(ph_range, ph_step);
end
end

function b = bin_centers(rng, step)
%BIN_CENTERS  linspace-based reconstruction; avoids colon's floating-point
%truncation (which would drop the final bin when step doesn't divide range
%exactly).
b = [];
if numel(rng) ~= 2 || numel(step) ~= 2, return, end
n = round((rng(2) - rng(1)) / step(2)) + 1;
b = linspace(rng(1), rng(2), n).';
end

function v = parse_vec(txt, key)
%PARSE_VEC  Pull `key = [a b ...];` out of a settings text dump.
v = [];
pat = ['^\s*' regexptranslate('escape', key) '\s*=\s*\[([^\]]*)\]'];
tok = regexp(txt, pat, 'tokens', 'lineanchors', 'once');
if isempty(tok), return, end
v = sscanf(tok{1}, '%g').';
end
