function paths = make_test_edfs(outDir, varargin)
%MAKE_TEST_EDFS  Synthesize a folder of small EDF files for pre-flight testing.
%
%   paths = make_test_edfs(outDir)
%   paths = make_test_edfs(outDir, Name, Value, ...)
%
%   Generates `NumFiles` short EDFs in `outDir` with synthetic EEG-like
%   data (pink-noise + 1/f character) and a configurable channel-label
%   mix, so the GUI's pre-flight resolution scan can be exercised end-to-
%   end without real subject data. By default also writes matching
%   staging CSVs (one Wake epoch per file) so the full Run flow works.
%
%   Name-value options:
%     'NumFiles'        (50)         number of EDFs to generate
%     'DurationSec'     (5)          seconds of data per channel
%     'Fs'              (256)        sample rate (Hz)
%     'LabelMix'        ('mixed')    'plain' | 'bracketed' | 'mixed' | 'partial'
%                                      'plain'     — every file uses plain labels
%                                                    {C3-A2, C4-A1, O1-A2, O2-A2,
%                                                     R-EOG, L-EOG, EMG, EKG}.
%                                      'bracketed' — every file uses the bracketed
%                                                    EDF-export style
%                                                    {[C3-A2 - B], [C4-A1 - A],
%                                                     [O1-A2 - B], [O2-A2 - A], ...}.
%                                      'mixed'     — random per file: roughly half
%                                                    plain, half bracketed.
%                                      'partial'   — like 'mixed', but each file
%                                                    randomly drops a couple of
%                                                    EEG channels so some
%                                                    (file, outname) pairs fail
%                                                    to resolve. Use this to
%                                                    exercise the pre-flight
%                                                    summary dialog and
%                                                    short-circuit logic.
%     'Channels'        (default)    cell array of plain channel labels to
%                                    cycle through. Default is the EEG montage
%                                    above. The bracketed variants are derived
%                                    automatically (each plain label gets paired
%                                    with one of {' - A',' - B',' - C',' - D'}).
%     'WriteStaging'    (true)       also write a sibling .csv per EDF with
%                                    a single Wake epoch (column 1: time,
%                                    column 2: stage label '0').
%     'Seed'            ([])         RNG seed for reproducibility. Defaults
%                                    to leaving the global RNG state alone.
%     'Verbose'         (false)      echo per-file progress.
%
%   Output:
%       paths : cellstr of generated EDF paths.
%
%   Example:
%       % Build a 30-file test set with mixed plain / bracketed labels and
%       % a sprinkling of partial-resolve files. Point the GUI at this
%       % folder, set up a variant-fallback channel composer, and run.
%       outDir = fullfile(tempdir, 'dynamo_preflight_test');
%       make_test_edfs(outDir, 'NumFiles', 30, 'LabelMix', 'partial', ...
%                              'DurationSec', 2, 'Verbose', true);
%
%   See also: write_EDF, refreshEdfLabelCache, simulateChannelResolution.
%
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
% =========================================================================

p = inputParser;
p.CaseSensitive = false;
addRequired(p,  'outDir',         @(x) ischar(x) || isstring(x));
addParameter(p, 'NumFiles',     50, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'DurationSec',   5, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'Fs',          256, @(x) isnumeric(x) && isscalar(x) && x >= 50);
addParameter(p, 'LabelMix',  'mixed', @(s) ischar(s) || isstring(s));
addParameter(p, 'Channels',     {}, @iscell);
addParameter(p, 'WriteStaging', true, @islogical);
addParameter(p, 'Seed',         [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'Verbose',     false, @islogical);
parse(p, outDir, varargin{:});

outDir       = char(p.Results.outDir);
nFiles       = round(p.Results.NumFiles);
durationSec  = p.Results.DurationSec;
fs           = p.Results.Fs;
labelMix     = char(lower(string(p.Results.LabelMix)));
plainChans   = p.Results.Channels;
writeStaging = p.Results.WriteStaging;
seed         = p.Results.Seed;
verbose      = p.Results.Verbose;

if isempty(plainChans)
    plainChans = {'C3-A2', 'C4-A1', 'O1-A2', 'O2-A2', ...
                  'R-EOG', 'L-EOG', 'EMG',   'EKG'};
end

if ~isfolder(outDir), mkdir(outDir); end
if ~isempty(seed), rng(seed); end

% Build the bracketed variants by appending one of {-A,-B,-C,-D} per
% channel. Mirrors the EDF-export style the user has been testing.
suffixes = {'A', 'B', 'C', 'D'};
brktChans = cell(1, numel(plainChans));
for k = 1:numel(plainChans)
    brktChans{k} = sprintf('[%s - %s]', plainChans{k}, suffixes{mod(k-1, numel(suffixes)) + 1});
end

paths = cell(1, nFiles);

samplesPerRecord = fs;                       % data_record_duration = 1.0 s
nRecords         = max(1, round(durationSec));
totalSamples     = samplesPerRecord * nRecords;

t_start = tic;
for ii = 1:nFiles
    % --- Pick this file's label set --------------------------------------
    switch labelMix
        case 'plain'
            labelsThisFile = plainChans;
        case 'bracketed'
            labelsThisFile = brktChans;
        case 'mixed'
            useBrkt = rand() < 0.5;
            if useBrkt, labelsThisFile = brktChans;
            else,       labelsThisFile = plainChans;
            end
        case 'partial'
            useBrkt = rand() < 0.5;
            if useBrkt, labelsThisFile = brktChans;
            else,       labelsThisFile = plainChans;
            end
            % Randomly drop 1-2 channels for "partial" coverage.
            nDrop = randi([1, 2]);
            keep  = sort(randperm(numel(labelsThisFile), max(1, numel(labelsThisFile) - nDrop)));
            labelsThisFile = labelsThisFile(keep);
        otherwise
            error('make_test_edfs:badLabelMix', ...
                'Unknown LabelMix "%s". Use plain | bracketed | mixed | partial.', labelMix);
    end

    nSig = numel(labelsThisFile);

    % --- Synthetic signal data (pink-noise EEG-like) --------------------
    sc = cell(1, nSig);
    for s = 1:nSig
        x = randn(totalSamples, 1);
        % cheap 1/f-ish shaping: low-pass cumulative + high-pass detrend
        x = filter(1, [1 -0.99], x);
        x = x - mean(x);
        x = x / max(1e-6, max(abs(x))) * 80;   % roughly +/- 80 microvolts
        sc{s} = x;
    end

    % --- Header ---------------------------------------------------------
    fileBase = sprintf('test_%03d', ii);
    fpath    = fullfile(outDir, [fileBase, '.edf']);

    header = struct();
    header.edf_ver              = '0';
    header.patient_id           = sprintf('TestSubj%03d M Test', ii);
    header.local_rec_id         = sprintf('Startdate %s X %s X', ...
                                         datestr(now, 'dd-mmm-yyyy'), fileBase); %#ok<DATST>
    header.recording_startdate  = datestr(now, 'dd.mm.yy');                       %#ok<DATST>
    header.recording_starttime  = '22.00.00';
    header.data_record_duration = 1.0;
    header.num_data_records     = nRecords;
    header.num_signals          = nSig;
    header.num_header_bytes     = 256 + 256 * nSig;

    % --- Per-signal header ---------------------------------------------
    sh = repmat(struct( ...
        'signal_labels',      '', ...
        'transducer_type',    'AgAgCl electrodes', ...
        'physical_dimension', 'uV', ...
        'physical_min',       -100, ...
        'physical_max',        100, ...
        'digital_min',        -32768, ...
        'digital_max',         32767, ...
        'prefiltering',       'HP:0.1Hz LP:100Hz', ...
        'samples_in_record',  samplesPerRecord, ...
        'sampling_frequency', fs), 1, nSig);
    for s = 1:nSig
        sh(s).signal_labels = labelsThisFile{s};
    end

    % --- Write EDF -----------------------------------------------------
    write_EDF(fpath, header, sh, sc, [], 'AutoScale', 'recompute');

    % --- Staging CSV (one Wake epoch covering the whole recording) -----
    if writeStaging
        csvPath = fullfile(outDir, [fileBase, '.csv']);
        fid = fopen(csvPath, 'w');
        if fid > 0
            cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fprintf(fid, 'time,stage\n');
            fprintf(fid, '0,0\n');   % '0' = Wake under the GUI's default mapping
            clear cleaner
        end
    end

    paths{ii} = fpath;
    if verbose
        fprintf('  [%d/%d] %s  (%d ch, %.0fs @ %g Hz)\n', ...
            ii, nFiles, fileBase, nSig, nRecords * 1.0, fs);
    end
end

if verbose
    fprintf('make_test_edfs: %d file(s) written to %s in %.1fs.\n', ...
        nFiles, outDir, toc(t_start));
end
end
