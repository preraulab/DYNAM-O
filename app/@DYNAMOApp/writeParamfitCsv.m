function writeParamfitCsv(filename, PF, axis_kind, freq_bins, so_bins, subject_id)
%writeParamfitCsv  Write a parametric-fit CSV with a fixed-format
%   comment header carrying everything needed to reconstruct
%   model_SOPH from the params table alone:
%     - background coefs (power: PowSlope/FreqSlope/Offset;
%       phase: SinAmp/SinPhase/Offset)
%     - unit_row (phase only; NaN for power)
%     - gof scalars (sse, rsquare, dfe, adjrsquare, rmse)
%     - source bins (freq_bins, SOpower_bins or SOphase_bins)
%
%   Header lines start with '# ' so readtable / pandas can skip
%   them via CommentStyle='#' / comment='#'. The header has the
%   same field set / line order for power and phase (NaN where
%   inapplicable) so downstream parsers can rely on it.
%
%   PF        : SOpower_paramfit or SOphase_paramfit struct
%   axis_kind : 'power' | 'phase'
%   freq_bins : SOPHs.freq_bins
%   so_bins   : SOPHs.SOpower_bins or SOPHs.SOphase_bins

fitobj = PF.fitobj;
gof    = PF.gof;
xxx = local_coef(fitobj, 'xxx');
yyy = local_coef(fitobj, 'yyy');
zzz = local_coef(fitobj, 'zzz');
if strcmp(axis_kind,'phase')
    unit_row     = local_coef(fitobj, 'unit_row');
    so_bin_field = 'SOphase_bins';
else
    unit_row     = NaN;
    so_bin_field = 'SOpower_bins';
end

% Pull the raw fitobj coefficient names / values. Phase fits overwrite
% params(:,1) with an empirical "no-sin" amplitude (param_basis_phase
% line 694-697) for human interpretability — that means the params
% table alone is NOT sufficient to reconstruct model_SOPH for phase.
% Saving the raw coefnames/coefvalues gives downstream readers an
% exact-reconstruction path independent of the table transformations.
try
    cn = coeffnames(fitobj);
    cv = coeffvalues(fitobj);
    fit_coef_names_json  = jsonencode(cn(:).');
    fit_coef_values_json = jsonencode(double(cv(:)).');
catch
    fit_coef_names_json  = '[]';
    fit_coef_values_json = '[]';
end
n_modes = height(PF.params);
sse        = local_field(gof, 'sse');
rsquare    = local_field(gof, 'rsquare');
dfe        = local_field(gof, 'dfe');
adjrsquare = local_field(gof, 'adjrsquare');
rmse       = local_field(gof, 'rmse');

fid = fopen(filename, 'w');
if fid < 0
    error('writeParamfitCsv:open','Cannot open %s for writing.', filename);
end
% onCleanup so the fid closes even if fprintf errors
cleaner = onCleanup(@() local_safe_fclose(fid)); %#ok<NASGU>

fprintf(fid, '# DYNAM-O parametric fit\n');
fprintf(fid, '# version: 1\n');
if nargin >= 6 && ~isempty(subject_id)
    fprintf(fid, '# subjectID: %s\n', char(subject_id));
end
fprintf(fid, '# fit_type: %s\n', axis_kind);
fprintf(fid, '# n_modes: %d\n', n_modes);
% Background coefficients — emitted under axis-specific, meaningful keys
% (the internal fitobj coeffs keep the historical xxx/yyy/zzz names so the
% fit's alphabetical-ordering trick is untouched; only the emitted CSV key
% is renamed). Power background is a tilted plane (two slopes + offset);
% phase background is a sinusoid (amplitude + phase + offset). Matches the
% Rust writer's keys.
if strcmp(axis_kind,'phase')
    bg_names = {'SinAmp','SinPhase','Offset'};
else
    bg_names = {'PowSlope','FreqSlope','Offset'};
end
fprintf(fid, '# background.%s: %.17g\n', bg_names{1}, xxx);
fprintf(fid, '# background.%s: %.17g\n', bg_names{2}, yyy);
fprintf(fid, '# background.%s: %.17g\n', bg_names{3}, zzz);
fprintf(fid, '# unit_row: %.17g\n', unit_row);
fprintf(fid, '# gof.sse: %.17g\n', sse);
fprintf(fid, '# gof.rsquare: %.17g\n', rsquare);
fprintf(fid, '# gof.dfe: %.17g\n', dfe);
fprintf(fid, '# gof.adjrsquare: %.17g\n', adjrsquare);
fprintf(fid, '# gof.rmse: %.17g\n', rmse);
fprintf(fid, '# freq_bins: %s\n', jsonencode(freq_bins(:).'));
fprintf(fid, '# %s: %s\n', so_bin_field, jsonencode(so_bins(:).'));
fprintf(fid, '# fitobj_coefnames: %s\n',  fit_coef_names_json);
fprintf(fid, '# fitobj_coefvalues: %s\n', fit_coef_values_json);

% Write the params table inline via fprintf so we don't depend on
% writetable's append-mode auto-detection of the comment header.
% Column names + each numeric row, comma-delimited.
T = PF.params;
vn = T.Properties.VariableNames;
fprintf(fid, '%s\n', strjoin(vn, ','));
if ~isempty(T)
    A = table2array(T);
    fmt = [strjoin(repmat({'%.17g'}, 1, size(A,2)), ','), '\n'];
    fprintf(fid, fmt, A.');
end

end

% --- helpers ---

function v = local_coef(obj, name)
try
    v = obj.(name);
catch
    v = NaN;
end
if islogical(v), v = double(v); end          % unit_row is stored as logical
if iscell(v) && isscalar(v), v = v{1}; end
if islogical(v), v = double(v); end
if ~isnumeric(v) || isempty(v) || numel(v) ~= 1
    v = NaN;
end
v = double(v);
end

function v = local_field(s, name)
try
    v = s.(name);
    if ~isnumeric(v) || isempty(v), v = NaN; end
catch
    v = NaN;
end
end

function local_safe_fclose(f)
try
    if f >= 0
        fclose(f);
    end
catch
end
end
