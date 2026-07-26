function outPath = dynamo_seed_index_from_cache(rootDir, cache)
%DYNAMO_SEED_INDEX_FROM_CACHE  Emit a synthetic _runs/*.jsonl from an
%   already-walked directory cache (the same shape walk_to_cache builds).
%   Use this to backfill a run index for a results tree that pre-dates
%   the JSONL logger — no second walk needed if the Results Browser has
%   already cached the tree.
%
%   outPath = dynamo_seed_index_from_cache(rootDir, cache)
%
%   The output file lives at:
%       <rootDir>/_runs/backfill_<host>_<yyyymmdd_HHmmss>_pid<pid>.jsonl
%
%   Recognized per-subject filename shapes (channel name == cache.dirs{ic}.name):
%       <subj>_auxiliary_data_<chan>.{h5,mat}            → component "aux"
%       <subj>_SOPHs_<chan>.{h5,mat}                     → component "SOPHs"
%       <subj>_stats_table_<chan>.{h5,mat}               → component "TFpeaks"
%       <subj>_SO{power,phase}_paramfit_<chan>.{h5,mat}  → component "paramfit"
%       <subj>_SO{power,phase}_splinefit_<chan>.{h5,mat} → component "spline"
%
%   Only binary files contribute (.h5 first-class, .mat legacy); sidecar
%   .csv / .tiff are ignored — they accompany a binary that already
%   classifies the (subject, component) pair.
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

arguments
    rootDir (1,:) char
    cache   struct
end

runsDir = fullfile(rootDir, '_runs');
if ~isfolder(runsDir), mkdir(runsDir); end

[hostName, userName, pidNum, startTime] = run_meta();
runID  = sprintf('backfill_%s_%s_pid%d', sanitize(hostName), ...
    char(datetime(startTime,'Format','yyyyMMdd_HHmmss')), pidNum);
outPath = fullfile(runsDir, [runID '.jsonl']);

skipDirs = {'aggregates','logs','settings'};
keyToComps = containers.Map('KeyType','char','ValueType','any');
keyToFiles = containers.Map('KeyType','char','ValueType','any');

for ic = 1:numel(cache.dirs)
    chanNode = cache.dirs{ic};
    chanName = chanNode.name;
    if any(strcmp(chanName, skipDirs)) || (~isempty(chanName) && chanName(1) == '_')
        continue
    end
    % Iterate immediate subdirs (param_basis, SOPHs, etc.)
    for is = 1:numel(chanNode.dirs)
        catNode = chanNode.dirs{is};
        catName = catNode.name;
        for ifn = 1:numel(catNode.files)
            fname = catNode.files(ifn).name;
            [~, base, ext] = fileparts(fname);
            if ~any(strcmp(ext, {'.h5','.mat'})), continue, end
            [subj, comp] = parse_per_subject_file(base, catName);
            if isempty(subj) || isempty(comp), continue, end
            key = sprintf('%s::%s', subj, chanName);
            if isKey(keyToComps, key)
                comps = keyToComps(key);
                fpaths = keyToFiles(key);
            else
                comps = {};
                fpaths = {};
            end
            if ~ismember(comp, comps), comps{end+1} = comp; end %#ok<AGROW>
            % Root-relative path with forward slashes (cross-platform stable).
            relPath = sprintf('%s/%s/%s', chanName, catName, fname);
            if ~ismember(relPath, fpaths), fpaths{end+1} = relPath; end %#ok<AGROW>
            keyToComps(key) = comps;
            keyToFiles(key) = fpaths;
        end
    end
end

fid = fopen(outPath, 'w');
if fid < 0
    error('dynamo_seed_index_from_cache:OpenFailed', ...
        'Could not open output for write: %s', outPath);
end
keys = sort(keyToComps.keys);
ts = sprintf('%s', char(datetime(startTime,'Format','yyyy-MM-dd''T''HH:mm:ss''Z''')));
for ii = 1:numel(keys)
    k = keys{ii};
    comps = keyToComps(k);
    fpaths = sort(keyToFiles(k));
    parts = strsplit(k, '::');
    evt = struct();
    evt.ts            = ts;
    evt.host          = hostName;
    evt.user          = userName;
    evt.pid           = pidNum;
    evt.run_id        = runID;
    evt.code_version  = 'backfill';
    evt.subject       = parts{1};
    evt.channel       = parts{2};
    evt.input_file    = '';
    evt.components    = sort(comps);
    evt.files         = fpaths;
    evt.status        = 'backfill';
    evt.failures      = {};
    evt.duration_sec  = NaN;
    fprintf(fid, '%s\n', jsonencode(evt));
end
fclose(fid);
end


function [subj, comp] = parse_per_subject_file(base, category)
subj = ''; comp = '';
switch category
    case 'auxiliary_data'
        t = regexp(base, '^(.+)_auxiliary_data_', 'tokens', 'once');
        if ~isempty(t), subj = t{1}; comp = 'aux'; end
    case 'SOPHs'
        % Skip preview-style SOPHs_power / SOPHs_phase basenames; the
        % real SOPHs.mat is "<subj>_SOPHs_<chan>".
        t = regexp(base, '^(.+)_SOPHs_(?!power|phase)', 'tokens', 'once');
        if ~isempty(t), subj = t{1}; comp = 'SOPHs'; end
    case 'TFpeaks'
        t = regexp(base, '^(.+)_stats_table_', 'tokens', 'once');
        if ~isempty(t), subj = t{1}; comp = 'TFpeaks'; end
    case 'param_basis'
        t = regexp(base, '^(.+)_SO(?:power|phase)_paramfit_', 'tokens', 'once');
        if ~isempty(t), subj = t{1}; comp = 'paramfit'; end
    case 'spline_basis'
        t = regexp(base, '^(.+)_SO(?:power|phase)_splinefit_', 'tokens', 'once');
        if ~isempty(t), subj = t{1}; comp = 'spline'; end
end
end


function s = sanitize(in)
s = regexprep(in, '[^A-Za-z0-9_-]', '_');
end


function [hostName, userName, pidNum, startTime] = run_meta()
hostName = '';
try
    [st, out] = system('hostname');
    if st == 0, hostName = strtrim(out); end
catch
end
if isempty(hostName), hostName = getenv('HOSTNAME'); end
if isempty(hostName), hostName = getenv('COMPUTERNAME'); end
if isempty(hostName), hostName = 'unknown_host'; end
userName = getenv('USER');
if isempty(userName), userName = getenv('USERNAME'); end
if isempty(userName), userName = 'unknown_user'; end
pidNum = double(feature('getpid'));
startTime = datetime('now', 'TimeZone', 'UTC');
end
