function report = convert_aux_to_compact(root, varargin)
%CONVERT_AUX_TO_COMPACT  Rewrite legacy DYNAM-O aux files in the compact schema.
%
%   Walks ROOT recursively for auxiliary_data .h5 / .mat files and rewrites
%   any in the OLD layout (per-sample /artifacts, EEG-rate /SOpower_norm,
%   f64 /stage_vals, /SOpower_retain_Fs) into the compact layout matching the
%   DYNAM-O desktop app:
%       - /artifacts (per-sample) -> /artifact_spans  [start_s, end_s]
%       - /SOpower_norm EEG-rate  -> native grid + /SOpower_t_start
%       - /stage_vals f64         -> uint8
%       - /SOpower_freqrange      added (default [0.3 1.5]; metadata only)
%       - /SOpower_retain_Fs      dropped
%   Files already in the compact layout are skipped (idempotent).
%
%   Usage:
%       report = convert_aux_to_compact(root)
%       report = convert_aux_to_compact(root, 'DryRun', true)
%       report = convert_aux_to_compact(root, 'SO_freqrange', [0.3 1.5])
%       report = convert_aux_to_compact(root, 'Backup', false)
%
%   Name-Value:
%       'DryRun'       logical - classify + print intended action, write
%                                nothing (default: false)
%       'Verbose'      logical - one line per file (default: true)
%       'SO_freqrange' 1x2     - band to stamp into legacy files that lack it
%                                (default: [0.3 1.5])
%       'Backup'       logical - keep a .bak copy of each original (default: true)
%
%   SOpower native reconstruction (EEG-rate legacy files): the stored series
%   is a *linear* upsample of the native grid, so evaluating it at the native
%   times t_start + i*step (interp1 'linear') recovers the native values
%   exactly at interior nodes — no anti-alias filtering. Endpoint pads and
%   artifact-NaN runs are the only minor loss; such files are tallied under
%   report.approximate. Native legacy files (retain_Fs=false) convert losslessly.
%
%   Output:
%       report - struct: .scanned, .converted, .skipped {path,reason},
%                .failed {path,reason}, .approximate (subset of converted).
%
%   Safety: temp-then-rename; with 'Backup' (default) the original is moved
%   to '<file>.bak' before the compact file takes its place.
%
%   See also: writeAuxH5, mask_to_spans, normalizeAuxStruct, loadAuxData.
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

ip = inputParser;
addRequired(ip, 'root', @(x) (ischar(x) || isstring(x)) && ~isempty(x));
addParameter(ip, 'DryRun',       false,      @(x) islogical(x) || isnumeric(x));
addParameter(ip, 'Verbose',      true,       @(x) islogical(x) || isnumeric(x));
addParameter(ip, 'SO_freqrange', [0.3 1.5],  @(x) isnumeric(x) && numel(x) == 2);
addParameter(ip, 'Backup',       true,       @(x) islogical(x) || isnumeric(x));
parse(ip, root, varargin{:});
root      = char(ip.Results.root);
dryRun    = logical(ip.Results.DryRun);
verbose   = logical(ip.Results.Verbose);
soFreq    = double(ip.Results.SO_freqrange(:));
doBackup  = logical(ip.Results.Backup);

assert(isfolder(root), 'convert_aux_to_compact:badRoot', 'Root not a folder: %s', root);

% Discover aux files under auxiliary_data/ subdirs (.h5 + .mat), dedup by path.
chunks = {};
for ext = {'*.h5', '*.mat'}
    f = dir(fullfile(root, '**', 'auxiliary_data', '**', ext{1}));
    if ~isempty(f), chunks{end+1} = f(:); end %#ok<AGROW>
end
if isempty(chunks)
    listing = dir(fullfile(root, '__no_match__'));
else
    listing = vertcat(chunks{:});
    paths   = arrayfun(@(s) fullfile(s.folder, s.name), listing, 'UniformOutput', false);
    [~, keep] = unique(paths, 'stable');
    listing = listing(keep);
end
n = numel(listing);

report = struct('scanned', n, 'converted', {{}}, 'skipped', {{}}, ...
                'failed', {{}}, 'approximate', {{}});

if verbose
    fprintf('convert_aux_to_compact: scanning %s\n  found %d aux file(s)\n', root, n);
    if dryRun, fprintf('  DRY RUN — no files will be written\n'); end
end

for ii = 1:n
    p = fullfile(listing(ii).folder, listing(ii).name);
    try
        [raw, isMat] = read_aux_any_(p);
    catch ME
        report.failed{end+1, 1} = {p, ME.message}; %#ok<AGROW>
        if verbose, fprintf('  [%d/%d] FAIL read %s — %s\n', ii, n, p, ME.message); end
        continue
    end

    if is_compact_struct_(raw)
        report.skipped{end+1, 1} = {p, 'already compact'}; %#ok<AGROW>
        if verbose, fprintf('  [%d/%d] skip (compact): %s\n', ii, n, p); end
        continue
    end
    if ~is_legacy_struct_(raw)
        report.skipped{end+1, 1} = {p, 'unrecognized aux layout'}; %#ok<AGROW>
        if verbose, fprintf('  [%d/%d] skip (unrecognized): %s\n', ii, n, p); end
        continue
    end
    if ~isfield(raw, 'Fs') || isempty(raw.Fs) || ~(double(raw.Fs) > 0)
        report.failed{end+1, 1} = {p, 'missing/invalid Fs'}; %#ok<AGROW>
        if verbose, fprintf('  [%d/%d] FAIL (no Fs): %s\n', ii, n, p); end
        continue
    end

    [compact, approx] = to_compact_(raw, soFreq);

    if dryRun
        report.converted{end+1, 1} = p; %#ok<AGROW>
        if approx, report.approximate{end+1, 1} = p; end %#ok<AGROW>
        if verbose
            fprintf('  [%d/%d] WOULD CONVERT%s: %s\n', ii, n, tern_(approx, ' (approx)', ''), p);
        end
        continue
    end

    try
        write_compact_(p, compact, isMat, doBackup);
        report.converted{end+1, 1} = p; %#ok<AGROW>
        if approx, report.approximate{end+1, 1} = p; end %#ok<AGROW>
        if verbose
            fprintf('  [%d/%d] converted%s: %s\n', ii, n, tern_(approx, ' (approx)', ''), p);
        end
    catch ME
        report.failed{end+1, 1} = {p, ME.message}; %#ok<AGROW>
        if verbose, fprintf('  [%d/%d] FAIL write %s — %s\n', ii, n, p, ME.message); end
    end
end

if verbose
    fprintf('done: %d converted (%d approx), %d skipped, %d failed (of %d)\n', ...
        numel(report.converted), numel(report.approximate), ...
        numel(report.skipped), numel(report.failed), report.scanned);
end
end


function [s, isMat] = read_aux_any_(p)
[~, ~, ext] = fileparts(p);
isMat = strcmpi(ext, '.mat');
if isMat
    L = load(p, 'auxiliary_data');
    if ~isfield(L, 'auxiliary_data')
        error('no auxiliary_data variable in %s', p);
    end
    s = L.auxiliary_data;
else
    s = struct();
    info = h5info(p);
    for ii = 1:numel(info.Datasets)
        name = info.Datasets(ii).Name;
        v = h5read(p, ['/' name]);
        if isstring(v)
            if isscalar(v), v = char(v); else, v = cellstr(v); end
        end
        if any(strcmp(name, {'artifacts', 'SOpower_retain_Fs'}))
            v = logical(v);
        end
        if strcmp(name, 'subject_id'), name = 'subjectID'; end
        s.(name) = v;
    end
end
end


function tf = is_compact_struct_(s)
tf = isfield(s, 'SOpower_t_start') || isfield(s, 'artifact_spans') || ...
     isfield(s, 'SOpower_freqrange') || ...
     (isfield(s, 'stage_vals') && isinteger(s.stage_vals));
end


function tf = is_legacy_struct_(s)
tf = isfield(s, 'artifacts') || isfield(s, 'SOpower_retain_Fs');
end


function [c, approx] = to_compact_(raw, soFreq_default)
approx = false;
Fs = double(raw.Fs);

wp = [5; 0.5];
if isfield(raw, 'SOpower_window_params') && numel(raw.SOpower_window_params) >= 2
    wp = double(raw.SOpower_window_params(:));
end
window_size = wp(1);
step = wp(2);

c = struct();
c.Fs = Fs;

% SOpower_norm -> native grid + t_start
if isfield(raw, 'SOpower_norm') && ~isempty(raw.SOpower_norm)
    sp = double(raw.SOpower_norm(:));
    is_native_legacy = isfield(raw, 'SOpower_retain_Fs') && ~logical(raw.SOpower_retain_Fs);
    if is_native_legacy
        c.SOpower_norm = sp;                 % already native
    else
        N   = numel(sp);
        dur = (N - 1) / Fs;
        Nn  = floor((dur - window_size) / step) + 1;
        if Nn >= 1
            t_eeg    = (0:N-1) / Fs;
            t_native = window_size/2 + (0:Nn-1) * step;
            c.SOpower_norm = interp1(t_eeg, sp, t_native, 'linear').';
            approx = true;                   % endpoints / NaN-runs may differ slightly
        else
            c.SOpower_norm = sp;             % too short to re-grid; keep as-is
        end
    end
    c.SOpower_t_start = window_size / 2;
end

if isfield(raw, 'SOpower_norm_method') && ~isempty(raw.SOpower_norm_method)
    c.SOpower_norm_method = char(string(raw.SOpower_norm_method));
end
c.SOpower_window_params = wp;                 % (2,1)

if isfield(raw, 'SOpower_freqrange') && ~isempty(raw.SOpower_freqrange)
    c.SOpower_freqrange = double(raw.SOpower_freqrange(:));
else
    c.SOpower_freqrange = soFreq_default(:);
end

% artifacts (per-sample) -> spans. Empty -> zeros(0,2) (writer omits it).
if isfield(raw, 'artifacts') && ~isempty(raw.artifacts)
    c.artifact_spans = mask_to_spans(logical(raw.artifacts), Fs);
end

if isfield(raw, 'stage_times') && ~isempty(raw.stage_times)
    c.stage_times = double(raw.stage_times(:)');
end
if isfield(raw, 'stage_vals') && ~isempty(raw.stage_vals)
    c.stage_vals = uint8(round(double(raw.stage_vals(:)')));
end

if isfield(raw, 'subjectID') && ~isempty(raw.subjectID)
    c.subjectID = char(string(raw.subjectID));
end
end


function write_compact_(p, compact, isMat, doBackup)
[pd, pn, pe] = fileparts(p);
tmp = fullfile(pd, [pn '.tmpconv' pe]);   % preserve .h5/.mat so writers accept it
if isfile(tmp), delete(tmp); end
if isMat
    auxiliary_data = compact; %#ok<NASGU>
    save(tmp, 'auxiliary_data', '-v7.3');
else
    writeAuxH5(tmp, compact);
end
if doBackup
    bak = [p '.bak'];
    if ~isfile(bak)
        [ok, msg] = copyfile(p, bak, 'f');
        if ~ok, delete(tmp); error('backup failed: %s', msg); end
    end
end
[ok, msg] = movefile(tmp, p, 'f');
if ~ok, error('movefile failed: %s', msg); end
end


function s = tern_(c, a, b)
if c, s = a; else, s = b; end
end
