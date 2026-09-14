function tests = test_aggregate_soph_tiff
%TEST_AGGREGATE_SOPH_TIFF  loadSOPHsTiff on multi-page aggregate TIFFs
tests = functiontests(localfunctions);
end

function setupOnce(~)
this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
if isempty(which('loadSOPHsTiff'))
    addpath(repo_root);
    init_DYNAMO();
end
end

function setup(testCase)
d = tempname();
mkdir(d);
testCase.TestData.dir = d;
end

function teardown(testCase)
if isfolder(testCase.TestData.dir)
    rmdir(testCase.TestData.dir, 's');
end
end

function test_aggregate_roundtrip(testCase)
rng(11);
so_bins = linspace(0, 10, 9);
freq_bins = linspace(4, 18, 15);
ids = ["S1", "S2", "S3"];
pages = cell(1, 3);
for k = 1:3
    pages{k} = rand(9, 15) * k;
end
pages{2}(4, 5) = NaN;               % masked bin must survive per page
p = fullfile(testCase.TestData.dir, 'SOPHs_power_C3.tiff');
write_aggregate_fixture_(p, pages, so_bins, freq_bins, ids);

[H, so_out, freq_out, meta] = loadSOPHsTiff(p);
testCase.verifySize(H, [9, 15, 3]);
for k = 1:3
    testCase.verifyTrue(isequaln(single(H(:, :, k)), single(pages{k})), ...
        sprintf('page %d pixels', k));
end
testCase.verifyEqual(meta.subject_ids, ids);
testCase.verifyEqual(meta.n_subjects, 3);
testCase.verifyEqual(meta.n_subjects_stamped, 3);
testCase.verifyEqual(meta.label, 'sopower');
testCase.verifyEqual(so_out, so_bins, 'AbsTol', 1e-12);
testCase.verifyEqual(freq_out, freq_bins, 'AbsTol', 1e-12);
testCase.verifyEqual(meta.source_formats, 2);
testCase.verifyEqual(meta.source_writer_versions, "1.0.0+abcdef123456");
testCase.verifyEqual(meta.source_semantics, ["4", "unstamped"]);
testCase.verifyEqual(numel(meta.page_raw), 3);
testCase.verifyEqual(char(string(meta.page_raw{3}.subject_id)), 'S3');
end

function test_single_page_contract_unchanged(testCase)
% A per-subject (single-page) file returns a plain 2-D matrix and the
% original meta fields - the aggregate support must not disturb it.
H1 = rand(6, 8);
so_bins = 1:6;
freq_bins = 1:8;
p = fullfile(testCase.TestData.dir, 'S1_SOPHs_power_C3.tiff');
writeSOPHsTiff(p, H1, so_bins, freq_bins, 'sopower', fixture_stamp_(), ...
    'subjectID', 'S1');
[H, so_out, freq_out, meta] = loadSOPHsTiff(p);
testCase.verifySize(H, [6, 8]);
testCase.verifyTrue(ismatrix(H));
testCase.verifyEqual(so_out, double(so_bins), 'AbsTol', 1e-12);
testCase.verifyEqual(freq_out, double(freq_bins), 'AbsTol', 1e-12);
testCase.verifyEqual(meta.subjectID, 'S1');
testCase.verifyEqual(meta.subject_ids, "S1");
testCase.verifyEqual(meta.n_subjects, 1);
testCase.verifyTrue(isnan(meta.n_subjects_stamped));
end

function test_page_size_mismatch_errors(testCase)
p = fullfile(testCase.TestData.dir, 'bad.tiff');
write_raw_pages_(p, {ones(4, 6), ones(3, 6)});
testCase.verifyError(@() loadSOPHsTiff(p), ...
    'loadSOPHsTiff:pageSizeMismatch');
end

function test_stamped_count_mismatch_warns(testCase)
% Aggregator stamped 3 subjects but the file holds 2 pages - the
% aggregation was incomplete, and the reader must say so.
pages = {ones(5, 7), 2 * ones(5, 7)};
p = fullfile(testCase.TestData.dir, 'SOPHs_phase_C3.tiff');
write_aggregate_fixture_(p, pages, 1:5, 1:7, ["A", "B"], 'n_subjects', 3);
[H, ~, ~, meta] = testCase.verifyWarning(@() loadSOPHsTiff(p), ...
    'loadSOPHsTiff:pageCountMismatch');
testCase.verifySize(H, [5, 7, 2]);
testCase.verifyEqual(meta.n_subjects, 2);
testCase.verifyEqual(meta.n_subjects_stamped, 3);
end


function write_aggregate_fixture_(path, pages, so_bins, freq_bins, ids, varargin)
%WRITE_AGGREGATE_FIXTURE_  Multi-page aggregate TIFF shaped like the Rust aggregator's
%
%   Inputs:
%       path      : char - output path -- required
%       pages     : cell - one [n_so x n_freq] matrix per subject -- required
%       so_bins   : vector - SO-feature bin centers -- required
%       freq_bins : vector - frequency bin centers -- required
%       ids       : string - one subject id per page -- required
%
%   Name-Value Pairs:
%       'n_subjects' : double - stamped count (default: numel(pages))
%
%   Outputs:
%       none (side effects only)
q = inputParser;
addParameter(q, 'n_subjects', numel(pages));
parse(q, varargin{:});
descs = cell(1, numel(pages));
for k = 1:numel(pages)
    d = struct();
    d.label = 'sopower';
    d.rows = size(pages{k}, 1);
    d.cols = size(pages{k}, 2);
    d.row_centers = so_bins(:)';
    d.col_centers = freq_bins(:)';
    d.SOpower_bins = so_bins(:)';
    d.freq_bins = freq_bins(:)';
    d.subject_id = char(ids(k));
    if k == 1
        % Aggregate-level keys ride page 1, on top of its subject's own.
        d.subject_ids = cellstr(ids(:));
        d.format = 2;
        d.pixel_format = 'f32 row-major';
        d.writer = 'dynamo-cli';
        d.writer_version = '1.0.0+abcdef123456';
        d.kernel_version = '1.0.0+abcdef123456';
        d.semantics = 4;
        d.n_subjects = q.Results.n_subjects;
        d.source_formats = 2;
        d.source_writer_versions = {'1.0.0+abcdef123456'};
        d.source_semantics = {4, 'unstamped'};  % mixed types, as the aggregator writes
    end
    descs{k} = jsonencode(d);
end
write_raw_pages_(path, pages, descs);
end

function write_raw_pages_(path, pages, descs)
%WRITE_RAW_PAGES_  f32 grayscale multi-page TIFF with per-page descriptions
%
%   Inputs:
%       pages : cell - one matrix per page -- required
%       descs : cell - one ImageDescription char per page (optional)
%
%   Outputs:
%       none (side effects only)
if nargin < 3
    descs = repmat({''}, 1, numel(pages));
end
t = Tiff(path, 'w');
cleaner = onCleanup(@() close(t));
for k = 1:numel(pages)
    page = single(pages{k});
    tag = struct();
    tag.ImageLength = size(page, 1);
    tag.ImageWidth = size(page, 2);
    tag.Photometric = Tiff.Photometric.MinIsBlack;
    tag.BitsPerSample = 32;
    tag.SamplesPerPixel = 1;
    tag.SampleFormat = Tiff.SampleFormat.IEEEFP;
    tag.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
    if ~isempty(descs{k})
        tag.ImageDescription = descs{k};
    end
    setTag(t, tag);
    write(t, page);
    if k < numel(pages)
        writeDirectory(t);
    end
end
end

function stamp = fixture_stamp_()
%FIXTURE_STAMP_  Deterministic provenance stamp for fixtures
%
%   Inputs:
%       none
%
%   Outputs:
%       stamp : struct - writer/writer_version/kernel_version
stamp = struct('writer', 'dynamo-matlab', ...
    'writer_version', '1.0.0+abcdef123456', ...
    'kernel_version', 'matlab-native');
end
