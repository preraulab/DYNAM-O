function writeParamfitCsv(path, paramfit, fit_type, so_bins, freq_bins, stamp, varargin)
%WRITEPARAMFITCSV  Write a SOPH parametric fit as a canonical format-3 CSV
%
%   Usage:
%       writeParamfitCsv(path, paramfit, 'power', SOpower_bins, freq_bins, stamp)
%       writeParamfitCsv(path, paramfit, 'phase', SOphase_bins, freq_bins, stamp, ...
%           'subjectID', 'S001', 'CrossHist', SOpower_mat, 'CrossBins', SOpower_bins)
%
%   Inputs:
%       path      : char - output .csv path (parent dirs created) -- required
%       paramfit  : struct - SOPH_paramfit from createSOPHparamfitStruct
%                   (annotated by fitParamBasis): .params table, .fitobj,
%                   .gof. The params table supplies every data column;
%                   this function is serialization only -- required
%       fit_type  : char - 'power' or 'phase' -- required
%       so_bins   : vector - SO-feature bin centers of the fitted axis
%                   (SOpower_bins for power, SOphase_bins for phase) -- required
%       freq_bins : vector - frequency bin centers (Hz) -- required
%       stamp     : struct - provenance stamp from dynamo_stamp -- required
%
%   Name-Value Pairs:
%       'subjectID' : char - emitted as '# subjectID:' when non-empty
%                     (default: '')
%       'CrossHist' : matrix - phase writes only: the SO-power histogram
%                     [n_SOpower x n_freq] used to fill the cross-axis
%                     SOpowerMean column (mean of the finite column values
%                     at each mode's nearest freq bin). Omit for NaN
%                     (default: [])
%       'CrossBins' : vector - bin centers of CrossHist rows; recorded
%                     for validation only (default: [])
%
%   Outputs:
%       none (side effects only)
%
%   Notes:
%       Emits the DYNAM-O paramfit-CSV format 3 (DesktopApp
%       OUTPUT_FORMAT.md sections 2.4 and 8): a '#' preamble with the
%       provenance stamp, fit metadata (fit_type, n_modes), background
%       coefficients under axis-specific keys, gof scalars, JSON bin
%       centers, and the fitobj coefficient names/values, followed by one
%       row per mode. Column sets mirror the Rust write_paramfit_csv:
%           power: Density,FreqMean,FreqStd,SOpowerMean,SOpowerStd,Theta,
%                  Volume,PrefPhase,Coupling,Pk*
%           phase: Density,FreqMean,FreqStd,SOphaseMean,SOphaseStd,Theta,
%                  Volume,SOpowerMean,Pk*
%       where Pk* is the ten per-mode TF-peak summary columns from
%       annotateModesWithPeakStats.
%
%       Background keys map the fit's internal xxx/yyy/zzz coefficients
%       to their meaning per axis: power xxx*x + yyy*y + zzz is a tilted
%       plane (PowSlope, FreqSlope, Offset); phase xxx*sin(X + yyy) + zzz
%       is a sinusoid (SinAmp, SinPhase, Offset). unit_row is the phase
%       fit's problem parameter (NaN for power). All preamble numerics
%       and data cells use %.17g.
%
%   Example:
%       stamp = dynamo_stamp();
%       writeParamfitCsv('S001_SOpower_paramfit_C3.csv', SOPHs.SOpower_paramfit, ...
%           'power', SOPHs.SOpower_bins, SOPHs.freq_bins, stamp, 'subjectID', 'S001');
%
%   See also: loadParamfitCsv, dynamo_stamp, createSOPHparamfitStruct,
%             fitParamBasis, annotateModesWithPeakStats
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

p = inputParser;
addRequired(p, 'path', @(x) validateattributes(x, {'char','string'}, {'scalartext','nonempty'}));
addRequired(p, 'paramfit', @(x) validateattributes(x, {'struct'}, {'scalar'}));
addRequired(p, 'fit_type', @(x) any(validatestring(lower(char(x)), {'power','phase'})));
addRequired(p, 'so_bins', @(x) validateattributes(x, {'numeric'}, {'vector'}));
addRequired(p, 'freq_bins', @(x) validateattributes(x, {'numeric'}, {'vector'}));
addRequired(p, 'stamp', @(x) validateattributes(x, {'struct'}, {'scalar'}));
addParameter(p, 'subjectID', '', @(x) validateattributes(x, {'char','string'}, {'scalartext'}));
addParameter(p, 'CrossHist', [], @(x) isempty(x) || (isnumeric(x) && ismatrix(x)));
addParameter(p, 'CrossBins', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));
parse(p, path, paramfit, fit_type, so_bins, freq_bins, stamp, varargin{:});
path       = char(p.Results.path);
paramfit   = p.Results.paramfit;
fit_type   = lower(char(p.Results.fit_type));
so_bins    = double(p.Results.so_bins(:)');
freq_bins  = double(p.Results.freq_bins(:)');
stamp      = p.Results.stamp;
subjectID  = char(p.Results.subjectID);
cross_hist = double(p.Results.CrossHist);
cross_bins = double(p.Results.CrossBins(:)');

assert(all(isfield(stamp, {'writer','writer_version','kernel_version'})), ...
    'stamp must carry writer, writer_version, and kernel_version (see dynamo_stamp).');
assert(isfield(paramfit, 'params') && istable(paramfit.params), ...
    'paramfit must carry a .params table (see createSOPHparamfitStruct).');

T = paramfit.params;
n_modes = height(T);

% Axis-dependent naming.
switch fit_type
    case 'power'
        so_field = 'SOpower_bins';
        bg_keys  = {'PowSlope', 'FreqSlope', 'Offset'};
        data_cols = [{'Density','FreqMean','FreqStd','SOpowerMean','SOpowerStd', ...
                      'Theta','Volume','PrefPhase','Coupling'}, pk_cols_()];
    case 'phase'
        so_field = 'SOphase_bins';
        bg_keys  = {'SinAmp', 'SinPhase', 'Offset'};
        data_cols = [{'Density','FreqMean','FreqStd','SOphaseMean','SOphaseStd', ...
                      'Theta','Volume','SOpowerMean'}, pk_cols_()];
end

% Background coefficients + unit_row from the fit object. The cfit/sfit
% keeps the historical internal names xxx/yyy/zzz; they are retired at
% the CSV boundary in favor of the axis-specific keys above.
[bg, unit_row, coefnames_json, coefvalues_json] = fitobj_provenance_(paramfit, fit_type);

% gof scalars (NaN when the fit object predates gof capture).
gof = struct('sse', NaN, 'rsquare', NaN, 'dfe', NaN, 'adjrsquare', NaN, 'rmse', NaN);
if isfield(paramfit, 'gof') && isstruct(paramfit.gof)
    gfn = fieldnames(gof);
    for ii = 1:numel(gfn)
        if isfield(paramfit.gof, gfn{ii}) && ~isempty(paramfit.gof.(gfn{ii}))
            gof.(gfn{ii}) = double(paramfit.gof.(gfn{ii}));
        end
    end
end

% Assemble the numeric output matrix column by column. Columns absent
% from the params table (older fit structs) fill with NaN, except
% PkCount which fills with 0 to keep the stable-schema convention.
M = nan(n_modes, numel(data_cols));
vn = T.Properties.VariableNames;
for cc = 1:numel(data_cols)
    name = data_cols{cc};
    if ismember(name, vn)
        M(:, cc) = double(T.(name));
    elseif strcmp(name, 'SOpowerMean') && strcmp(fit_type, 'phase')
        % Cross-axis column: mean of the finite SO-power histogram
        % column at each mode's nearest freq bin (mirrors the Rust
        % column_mean_at_freq). NaN without CrossHist.
        M(:, cc) = cross_sopower_mean_(cross_hist, freq_bins, double(T.FreqMean));
    elseif strcmp(name, 'PkCount')
        M(:, cc) = 0;
    end
end

outdir = fileparts(path);
if ~isempty(outdir) && ~isfolder(outdir)
    mkdir(outdir);
end

fid = fopen(path, 'w');
if fid < 0
    error('writeParamfitCsv:openFailed', 'Could not open %s for writing.', path);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

% Preamble. Key order matches the Rust write_paramfit_csv.
fprintf(fid, '# DYNAM-O parametric fit\n');
fprintf(fid, '# format: 3\n');
fprintf(fid, '# writer: %s\n', char(stamp.writer));
fprintf(fid, '# writer_version: %s\n', char(stamp.writer_version));
fprintf(fid, '# kernel_version: %s\n', char(stamp.kernel_version));
if ~isempty(subjectID)
    fprintf(fid, '# subjectID: %s\n', subjectID);
end
fprintf(fid, '# fit_type: %s\n', fit_type);
fprintf(fid, '# n_modes: %d\n', n_modes);
for ii = 1:3
    fprintf(fid, '# background.%s: %.17g\n', bg_keys{ii}, bg(ii));
end
fprintf(fid, '# unit_row: %.17g\n', unit_row);
fprintf(fid, '# gof.sse: %.17g\n', gof.sse);
fprintf(fid, '# gof.rsquare: %.17g\n', gof.rsquare);
fprintf(fid, '# gof.dfe: %.17g\n', gof.dfe);
fprintf(fid, '# gof.adjrsquare: %.17g\n', gof.adjrsquare);
fprintf(fid, '# gof.rmse: %.17g\n', gof.rmse);
fprintf(fid, '# freq_bins: %s\n', jsonencode(freq_bins));
fprintf(fid, '# %s: %s\n', so_field, jsonencode(so_bins));
fprintf(fid, '# fitobj_coefnames: %s\n', coefnames_json);
fprintf(fid, '# fitobj_coefvalues: %s\n', coefvalues_json);

% Header + data rows. %.17g keeps full double precision; NaN prints as
% the literal NaN.
fprintf(fid, '%s\n', strjoin(data_cols, ','));
for rr = 1:n_modes
    cells = cell(1, numel(data_cols));
    for cc = 1:numel(data_cols)
        cells{cc} = sprintf('%.17g', M(rr, cc));
    end
    fprintf(fid, '%s\n', strjoin(cells, ','));
end
end


function c = pk_cols_()
%PK_COLS_  Per-mode TF-peak summary column names (schema-stable)
%
%   Inputs:
%       none
%
%   Outputs:
%       c : cell - the ten Pk* column names, matching
%           annotateModesWithPeakStats and the Rust mode_peaks columns
c = {'PkCount','PkFreq','PkDuration','PkBandwidth','PkHeight', ...
     'PkVolume','PkArea','PkPeakiness','PkSOpower','PkSOphase'};
end


function [bg, unit_row, coefnames_json, coefvalues_json] = fitobj_provenance_(paramfit, fit_type)
%FITOBJ_PROVENANCE_  Extract background/unit_row/coefficient lists from the fit
%
%   Inputs:
%       paramfit : struct - SOPH_paramfit (uses .fitobj) -- required
%       fit_type : char - 'power' or 'phase' -- required
%
%   Outputs:
%       bg              : 1x3 double - [xxx yyy zzz] values, NaN when absent
%       unit_row        : double - phase problem parameter, NaN otherwise
%       coefnames_json  : char - JSON array of coefficient names ('[]' fallback)
%       coefvalues_json : char - JSON array of coefficient values ('[]' fallback)
bg = nan(1, 3);
unit_row = NaN;
coefnames_json = '[]';
coefvalues_json = '[]';

if ~isfield(paramfit, 'fitobj') || isempty(paramfit.fitobj)
    return
end
fitobj = paramfit.fitobj;

try
    names = coeffnames(fitobj);
    vals  = coeffvalues(fitobj);
    coefnames_json  = jsonencode(names(:)');
    coefvalues_json = jsonencode(double(vals(:)'));
    bg_names = {'xxx', 'yyy', 'zzz'};
    for ii = 1:3
        hit = strcmpi(names, bg_names{ii});
        if any(hit)
            bg(ii) = double(vals(find(hit, 1)));
        end
    end
catch
    % Fit object without the cfit interface: leave the fallbacks.
end

if strcmp(fit_type, 'phase')
    % The phase fit carries unit_row as a fittype problem parameter.
    try
        pv = probvalues(fitobj);
        if ~isempty(pv)
            unit_row = double(pv(1));
        end
    catch
    end
end
end


function m = cross_sopower_mean_(cross_hist, freq_bins, fmean)
%CROSS_SOPOWER_MEAN_  Mean finite SO-power histogram column at each mode freq
%
%   Inputs:
%       cross_hist : matrix - SO-power histogram [n_SOpower x n_freq],
%                    or [] -- required
%       freq_bins  : 1xN double - frequency bin centers -- required
%       fmean      : Mx1 double - per-mode FreqMean values -- required
%
%   Outputs:
%       m : Mx1 double - arithmetic mean over the finite values of the
%           histogram column nearest each FreqMean; NaN when the
%           histogram is absent, mismatched, or the column is all-NaN
m = nan(numel(fmean), 1);
if isempty(cross_hist) || size(cross_hist, 2) ~= numel(freq_bins)
    return
end
for ii = 1:numel(fmean)
    if ~isfinite(fmean(ii))
        continue
    end
    [~, fi] = min(abs(freq_bins - fmean(ii)));
    col = cross_hist(:, fi);
    col = col(isfinite(col));
    if ~isempty(col)
        m(ii) = mean(col);
    end
end
end
