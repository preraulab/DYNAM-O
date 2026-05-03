function index = dynamo_index_runs(rootDir)
%DYNAMO_INDEX_RUNS  Build a (subject, channel) index from _runs/*.jsonl logs.
%
%   index = dynamo_index_runs(rootDir)
%
%   Walks <rootDir>/_runs/*.jsonl, parses every line, and unions them
%   with "latest ts wins" semantics for duplicates. Each .jsonl file is
%   written by a single batch invocation (one writer per file => no
%   contention even when concurrent batches run on different machines).
%
%   Returns a struct with fields:
%       entries   : 1xN cell of event structs (one per unique (subject,channel))
%       subjects  : 1xK cell of unique subject IDs
%       channels  : 1xC cell of unique channel names
%       byKey     : containers.Map keyed "<subject>::<channel>" → entry struct
%       runFiles  : 1xR cell of jsonl file basenames that contributed
%       nLines    : total lines parsed across all run files
%       nDropped  : lines that failed to parse
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

arguments
    rootDir (1,:) char
end

index = struct( ...
    'entries',  {{}}, ...
    'subjects', {{}}, ...
    'channels', {{}}, ...
    'byKey',    containers.Map('KeyType','char','ValueType','any'), ...
    'runFiles', {{}}, ...
    'nLines',   0, ...
    'nDropped', 0);

runsDir = fullfile(rootDir, '_runs');
if ~isfolder(runsDir), return, end

files = dir(fullfile(runsDir, '*.jsonl'));
if isempty(files), return, end

byKey = containers.Map('KeyType','char','ValueType','any');
nLines   = 0;
nDropped = 0;

for ii = 1:numel(files)
    fp = fullfile(files(ii).folder, files(ii).name);
    try
        txt = fileread(fp);
    catch
        continue
    end
    if isempty(txt), continue, end
    lines = regexp(txt, '\r?\n', 'split');
    for jj = 1:numel(lines)
        ln = strtrim(lines{jj});
        if isempty(ln), continue, end
        nLines = nLines + 1;
        try
            ev = jsondecode(ln);
        catch
            nDropped = nDropped + 1;
            continue
        end
        if ~isstruct(ev) || ~isfield(ev,'subject') || ~isfield(ev,'channel')
            nDropped = nDropped + 1;
            continue
        end
        key   = sprintf('%s::%s', char(ev.subject), char(ev.channel));
        prev  = [];
        if isKey(byKey, key), prev = byKey(key); end
        if isempty(prev) || ts_gt(ev, prev)
            byKey(key) = ev;
        end
    end
end

keys = byKey.keys;
entries = cell(1, numel(keys));
subjects = cell(1, numel(keys));
channels = cell(1, numel(keys));
for ii = 1:numel(keys)
    e = byKey(keys{ii});
    % Backfill `files` for legacy entries (pre-files-field schema). The
    % fallback synthesizes paths from components+subj+chan via the shared
    % naming convention. Newer entries already have `files` from the
    % writer/seeder; they pass through unchanged.
    if ~isfield(e, 'files') || isempty(e.files)
        comps = {};
        if isfield(e, 'components')
            c = e.components;
            if ischar(c)
                comps = {c};
            elseif iscell(c)
                comps = c;
            elseif isstring(c)
                comps = cellstr(c);
            end
        end
        e.files = dynamo_files_for_components( ...
            char(e.subject), char(e.channel), comps);
        byKey(keys{ii}) = e;
    end
    entries{ii}  = e;
    subjects{ii} = char(e.subject);
    channels{ii} = char(e.channel);
end

index.entries  = entries;
index.subjects = unique(subjects);
index.channels = unique(channels);
index.byKey    = byKey;
index.runFiles = {files.name};
index.nLines   = nLines;
index.nDropped = nDropped;
end

function tf = ts_gt(a, b)
%TS_GT  True iff event a's ts is strictly later than event b's ts.
%   ISO 8601 timestamps sort lexically, so a string compare suffices.
ta = ''; tb = '';
if isfield(a,'ts'), ta = char(a.ts); end
if isfield(b,'ts'), tb = char(b.ts); end
if isempty(ta) && isempty(tb), tf = false; return; end
if isempty(tb), tf = ~isempty(ta); return; end
if isempty(ta), tf = false; return; end
if strcmp(ta, tb), tf = false; return; end
sorted = sort({ta, tb});
tf = strcmp(sorted{2}, ta);
end
