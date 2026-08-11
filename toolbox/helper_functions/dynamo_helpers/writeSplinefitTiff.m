function writeSplinefitTiff(path, splinefit_struct, fit_type, stamp, varargin)
%WRITESPLINEFITTIFF  Write a SOPH spline fit as a stamped two-page f32 TIFF
%
%   Usage:
%       writeSplinefitTiff(path, SOPHs.SOpower_splinefit, 'power', stamp)
%       writeSplinefitTiff(path, SOPHs.SOphase_splinefit, 'phase', stamp, ...
%           'subjectID', 'S001')
%
%   Inputs:
%       path             : char - output .tiff path (parent dirs created) -- required
%       splinefit_struct : struct - SOPH_splinefit from
%                          createSOPHsplinefitStruct: .coefs [m_y x m_x],
%                          .splinefit [n_fit_so x n_fit_freq], .knots_x,
%                          .knots_y, .fit_SOfeature_bins, .fit_freq_bins -- required
%       fit_type         : char - 'power' or 'phase' -- required
%       stamp            : struct - provenance stamp from dynamo_stamp -- required
%
%   Name-Value Pairs:
%       'subjectID' : char - embedded in the metadata JSON (default: '')
%
%   Outputs:
%       none (side effects only)
%
%   Notes:
%       Two-page f32 TIFF via DYNAMO.writeTiff, matching the Rust
%       write_splinefit_tiff (DesktopApp OUTPUT_FORMAT.md sections 2.5
%       and 8.2): page 1 is the coefficient matrix and carries the
%       format-2 ImageDescription JSON; page 2 is the reconstructed
%       splinefit on the fit-domain bins (a bare page).
%
%       The knots_x/knots_y JSON keys carry the AUGMENTED knot sequences
%       actually used by the fit. spline_basis calls augknt(knots, 3),
%       which gives the end knots multiplicity 3 (two extra copies each
%       end); the augmentation is replicated inline here so writing does
%       not require the Curve Fitting Toolbox.
%
%   Example:
%       stamp = dynamo_stamp();
%       writeSplinefitTiff('S001_SOpower_splinefit_C3.tiff', ...
%           SOPHs.SOpower_splinefit, 'power', stamp, 'subjectID', 'S001');
%
%   See also: writeSOPHsTiff, dynamo_stamp, createSOPHsplinefitStruct,
%             spline_basis, DYNAMO
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

p = inputParser;
addRequired(p, 'path', @(x) validateattributes(x, {'char','string'}, {'scalartext','nonempty'}));
addRequired(p, 'splinefit_struct', @(x) validateattributes(x, {'struct'}, {'scalar'}));
addRequired(p, 'fit_type', @(x) any(validatestring(lower(char(x)), {'power','phase'})));
addRequired(p, 'stamp', @(x) validateattributes(x, {'struct'}, {'scalar'}));
addParameter(p, 'subjectID', '', @(x) validateattributes(x, {'char','string'}, {'scalartext'}));
parse(p, path, splinefit_struct, fit_type, stamp, varargin{:});
path      = char(p.Results.path);
S         = p.Results.splinefit_struct;
fit_type  = lower(char(p.Results.fit_type));
stamp     = p.Results.stamp;
subjectID = char(p.Results.subjectID);

assert(all(isfield(stamp, {'writer','writer_version','kernel_version'})), ...
    'stamp must carry writer, writer_version, and kernel_version (see dynamo_stamp).');
need = {'coefs', 'splinefit', 'knots_x', 'knots_y'};
have = isfield(S, need);
if ~all(have)
    error('writeSplinefitTiff:missingField', ...
        'splinefit struct is missing field(s): %s (see createSOPHsplinefitStruct).', ...
        strjoin(need(~have), ', '));
end
if ~isfield(S, 'fit_SOfeature_bins') || isempty(S.fit_SOfeature_bins) || ...
        ~isfield(S, 'fit_freq_bins') || isempty(S.fit_freq_bins)
    error('writeSplinefitTiff:missingFitBins', ...
        ['splinefit struct lacks fit_SOfeature_bins/fit_freq_bins (an older ' ...
         'fit result). Re-run fitSplineBasis to populate the fit-domain bins ' ...
         'the TIFF metadata requires.']);
end

coefs    = double(S.coefs);
fit_mat  = double(S.splinefit);
so_bins  = double(S.fit_SOfeature_bins(:)');
fbins    = double(S.fit_freq_bins(:)');

% spline_basis returns splinefit as [n_fit_so x n_fit_freq]. Accept a
% transposed matrix (defensive, since the two fit-window extents can be
% equal only by coincidence) and refuse anything else.
if ~isequal(size(fit_mat), [numel(so_bins), numel(fbins)])
    if isequal(size(fit_mat), [numel(fbins), numel(so_bins)])
        fit_mat = fit_mat.';
    else
        error('writeSplinefitTiff:shapeMismatch', ...
            'splinefit is %dx%d but the fit-domain bins imply %dx%d.', ...
            size(fit_mat, 1), size(fit_mat, 2), numel(so_bins), numel(fbins));
    end
end

% Augmented knot sequences, replicating augknt(k, 3) from spline_basis
% (end-knot multiplicity 3) without a Curve Fitting Toolbox dependency.
kx = double(S.knots_x(:)');
ky = double(S.knots_y(:)');
kx_aug = [repmat(kx(1), 1, 2), kx, repmat(kx(end), 1, 2)];
ky_aug = [repmat(ky(1), 1, 2), ky, repmat(ky(end), 1, 2)];

% Metadata JSON. Field order mirrors the Rust write_splinefit_tiff.
meta = struct();
meta.label = 'splinefit';
meta.knots_x = kx_aug;
meta.knots_y = ky_aug;
meta.freq_bins = fbins;
if strcmp(fit_type, 'power')
    meta.SOpower_bins = so_bins;
else
    meta.SOphase_bins = so_bins;
end
meta.subjectID = subjectID;
meta.page1 = 'coefs';
meta.page2 = 'splinefit';
meta.format = 2;
meta.pixel_format = 'f32 row-major';
meta.writer = char(stamp.writer);
meta.writer_version = char(stamp.writer_version);
meta.kernel_version = char(stamp.kernel_version);

outdir = fileparts(path);
if ~isempty(outdir) && ~isfolder(outdir)
    mkdir(outdir);
end

% Page 1 carries the metadata (DYNAMO.writeTiff attaches the description
% to page 1 only); page 2 is bare, per the format-2 layout.
DYNAMO.writeTiff(path, {coefs, fit_mat}, meta);
end
