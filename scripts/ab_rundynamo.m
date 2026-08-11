function report = ab_rundynamo(rootA, rootB, varargin)
%AB_RUNDYNAMO  Compare two DYNAM-O results trees by loaded content
%
%   Usage:
%       report = ab_rundynamo(rootA, rootB)
%       report = ab_rundynamo(rootA, rootB, 'Tolerance', 1e-12)
%
%   Inputs:
%       rootA : char - results root of the reference run (e.g. produced
%               by a master checkout) -- required
%       rootB : char - results root of the run under review -- required
%
%   Name-Value Pairs:
%       'Tolerance' : double - maximum absolute numeric difference
%                     allowed per array; 0 requires isequaln equality
%                     (default: 0)
%       'Verbose'   : logical - one line per compared artifact
%                     (default: true)
%
%   Outputs:
%       report : struct - .compared (paths checked), .missing (relative
%                paths present in A but absent in B), .mismatched
%                ({relpath, detail} rows), .ok (logical summary)
%
%   Notes:
%       Companion driver to tests/test_rundynamo_invariance.m for the
%       two-checkout workflow: run the same batch_script on both
%       checkouts into different output roots, then compare the trees by
%       loaded content rather than bytes. Stats and paramfit CSVs load
%       through loadStatsTable/loadParamfitCsv, SOPH TIFFs through
%       loadSOPHsTiff, and aux files through loadAuxData, so provenance
%       preambles and metadata stamps never affect the comparison (a
%       stamp-only difference between checkouts compares clean, exactly
%       as intended for metadata-only changes).
%
%   Example:
%       % checkout A: batch_script(..., '/tmp/outA'); checkout B: /tmp/outB
%       report = ab_rundynamo('/tmp/outA', '/tmp/outB');
%
%   See also: capture_invariance_baseline, loadStatsTable, loadParamfitCsv,
%             loadSOPHsTiff, loadAuxData
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('loadStatsTable'))
    addpath(repo_root);
    init_DYNAMO();
end

p = inputParser;
addRequired(p, 'rootA', @(x) validateattributes(x, {'char', 'string'}, {'scalartext', 'nonempty'}));
addRequired(p, 'rootB', @(x) validateattributes(x, {'char', 'string'}, {'scalartext', 'nonempty'}));
addParameter(p, 'Tolerance', 0, @(x) validateattributes(x, {'numeric'}, {'scalar', 'nonnegative'}));
addParameter(p, 'Verbose', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'scalar'}));
parse(p, rootA, rootB, varargin{:});
rootA = char(p.Results.rootA);
rootB = char(p.Results.rootB);
tol = double(p.Results.Tolerance);
verbose = logical(p.Results.Verbose);

assert(isfolder(rootA), 'ab_rundynamo:badRoot', 'rootA is not a folder: %s', rootA);
assert(isfolder(rootB), 'ab_rundynamo:badRoot', 'rootB is not a folder: %s', rootB);

report = struct('compared', {{}}, 'missing', {{}}, 'mismatched', {{}}, 'ok', false);

% Artifact classes: glob pattern under rootA + content loader. The
% loaders return (content, ~) so provenance metadata is excluded from
% the equality check by construction.
classes = {
    fullfile('**', 'TFpeaks', '*_stats_table_*.csv'),  @(f) loadStatsTable(f)
    fullfile('**', 'SOPHs', '*_SOPHs_*_*.tiff'),       @(f) loadSOPHsTiff(f)
    fullfile('**', 'param_basis', '*_paramfit_*.csv'), @(f) loadParamfitCsv(f)
    fullfile('**', 'auxiliary_data', '*.h5'),          @(f) loadAuxData(f)
    fullfile('**', 'spline_basis', '*_splinefit_*.tiff'), @(f) load_spline_pages_(f)
    };

for ci = 1:size(classes, 1)
    listing = dir(fullfile(rootA, classes{ci, 1}));
    loader = classes{ci, 2};
    for ii = 1:numel(listing)
        pA = fullfile(listing(ii).folder, listing(ii).name);
        rel = erase(pA, [rootA filesep]);
        pB = fullfile(rootB, rel);
        if ~isfile(pB)
            report.missing{end+1, 1} = rel; %#ok<AGROW>
            if verbose, fprintf('  MISSING in B: %s\n', rel); end
            continue
        end
        report.compared{end+1, 1} = rel; %#ok<AGROW>
        try
            vA = loader(pA);
            vB = loader(pB);
            detail = compare_content_(vA, vB, tol);
        catch ME
            detail = sprintf('load/compare error: %s', ME.message);
        end
        if isempty(detail)
            if verbose, fprintf('  ok: %s\n', rel); end
        else
            report.mismatched{end+1, 1} = {rel, detail}; %#ok<AGROW>
            if verbose, fprintf('  MISMATCH %s — %s\n', rel, detail); end
        end
    end
end

report.ok = isempty(report.missing) && isempty(report.mismatched);
fprintf('ab_rundynamo: %d compared, %d missing, %d mismatched -> %s\n', ...
    numel(report.compared), numel(report.missing), numel(report.mismatched), ...
    ternary_(report.ok, 'PASS', 'FAIL'));
end


function pages = load_spline_pages_(f)
%LOAD_SPLINE_PAGES_  Read both pages of a splinefit TIFF as content
%
%   Inputs:
%       f : char - splinefit .tiff path -- required
%
%   Outputs:
%       pages : struct - .coefs (page 1) and .splinefit (page 2) doubles
pages = struct('coefs', double(imread(f, 1)), 'splinefit', double(imread(f, 2)));
end


function detail = compare_content_(a, b, tol)
%COMPARE_CONTENT_  Recursive content equality with optional tolerance
%
%   Inputs:
%       a, b : any - loaded artifact content -- required
%       tol  : double - max absolute difference for numerics; 0 means
%              isequaln -- required
%
%   Outputs:
%       detail : char - '' when equal, else a one-line description of the
%                first difference found
detail = '';
if tol == 0
    if ~isequaln(a, b)
        detail = first_difference_(a, b);
    end
    return
end
% Tolerant path: numerics compare by max-abs difference (NaN patterns
% must still match); everything else falls back to isequaln.
if isnumeric(a) && isnumeric(b)
    if ~isequal(size(a), size(b))
        detail = sprintf('size %s vs %s', mat2str(size(a)), mat2str(size(b)));
    elseif ~isequal(isnan(a), isnan(b))
        detail = 'NaN patterns differ';
    else
        d = max(abs(a(~isnan(a)) - b(~isnan(b))), [], 'all');
        if ~isempty(d) && d > tol
            detail = sprintf('max abs diff %.3g > tol %.3g', d, tol);
        end
    end
elseif istable(a) && istable(b)
    if ~isequal(a.Properties.VariableNames, b.Properties.VariableNames)
        detail = 'table columns differ';
        return
    end
    vn = a.Properties.VariableNames;
    for ii = 1:numel(vn)
        d = compare_content_(a.(vn{ii}), b.(vn{ii}), tol);
        if ~isempty(d)
            detail = sprintf('column %s: %s', vn{ii}, d);
            return
        end
    end
elseif isstruct(a) && isstruct(b)
    fa = sort(fieldnames(a));
    if ~isequal(fa, sort(fieldnames(b)))
        detail = 'struct fields differ';
        return
    end
    for ii = 1:numel(fa)
        d = compare_content_(a.(fa{ii}), b.(fa{ii}), tol);
        if ~isempty(d)
            detail = sprintf('field %s: %s', fa{ii}, d);
            return
        end
    end
else
    if ~isequaln(a, b)
        detail = first_difference_(a, b);
    end
end
end


function detail = first_difference_(a, b)
%FIRST_DIFFERENCE_  Describe where two unequal values first diverge
%
%   Inputs:
%       a, b : any - values already known unequal -- required
%
%   Outputs:
%       detail : char - short human-readable locator
if istable(a) && istable(b) && isequal(a.Properties.VariableNames, b.Properties.VariableNames)
    vn = a.Properties.VariableNames;
    for ii = 1:numel(vn)
        if ~isequaln(a.(vn{ii}), b.(vn{ii}))
            detail = sprintf('column %s differs', vn{ii});
            return
        end
    end
    detail = 'table metadata differs';
elseif isstruct(a) && isstruct(b)
    fa = fieldnames(a);
    fb = fieldnames(b);
    if ~isequal(sort(fa), sort(fb))
        detail = 'struct fields differ';
        return
    end
    for ii = 1:numel(fa)
        if ~isequaln(a.(fa{ii}), b.(fa{ii}))
            detail = sprintf('field %s differs', fa{ii});
            return
        end
    end
    detail = 'struct differs';
elseif isnumeric(a) && isnumeric(b) && isequal(size(a), size(b))
    d = max(abs(a(:) - b(:)));
    detail = sprintf('numeric content differs (max abs diff %.3g)', d);
else
    detail = sprintf('%s vs %s content differs', class(a), class(b));
end
end


function s = ternary_(cond, a, b)
%TERNARY_  Inline conditional for format strings
%
%   Inputs:
%       cond : logical - selector -- required
%       a, b : char - value when true / false -- required
%
%   Outputs:
%       s : char - a when cond, else b
if cond, s = a; else, s = b; end
end
