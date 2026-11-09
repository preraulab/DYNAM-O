function [peak_labels, mode_members] = label_peaks_by_mode(stats_table, modes, varargin)
%LABEL_PEAKS_BY_MODE  Label every TF-peak with the fitted mode it belongs to
%
%   Usage:
%       peak_labels = label_peaks_by_mode(stats_csv, paramfit_csv)
%       [peak_labels, mode_members] = label_peaks_by_mode(stats_csv, paramfit_csv)
%       peak_labels = label_peaks_by_mode(dynamo_obj.stats_table, dynamo_obj.SOPHs.SOpower_paramfit)
%       peak_labels = label_peaks_by_mode(stats_table, params, 'Background', [PowSlope FreqSlope Offset])
%
%   Inputs:
%       stats_table : table or char - one subject's TF-peak stats table, as a
%                     table or as the path to its stats CSV (the
%                     *_stats_table_*.csv a CLI run writes under TFpeaks/)
%                     -- required
%       modes       : char, struct or table - that subject's fitted modes, as
%                     any of:
%                       the path to its paramfit CSV (*_SOpower_paramfit_*.csv
%                       or *_SOphase_paramfit_*.csv under param_basis/)
%                       a paramfit struct (SOPHs.SOpower_paramfit or
%                       SOPHs.SOphase_paramfit of a DYNAMO object)
%                       the subject's rows of an aggregate paramfit CSV
%                       a bare params table, which needs 'Background' for
%                       power modes -- required
%
%   Name-Value Pairs:
%       'Background' : 1x3 double - power-mode background [PowSlope FreqSlope
%                      Offset], overriding the one found in modes
%                      (default: [], read from modes)
%       'Stages'     : double - sleep stages whose peaks can belong to a
%                      mode, matching the SOPH stages of the run
%                      (default: 1:3, NREM)
%       'Assign'     : char or double - rule deciding which peaks belong to
%                      a mode: 'argmax', 'background', a probability contour
%                      such as '0.95 p', or a sigma contour such as
%                      '1.3 sigma'. See ASSIGNMENT RULES below
%                      (default: the rule the run recorded, or 'argmax')
%
%   Outputs:
%       peak_labels : Nx1 double - one label per row of the stats table:
%                       m   = the peak belongs to mode m (row m of the params)
%                       0   = the peak is in the SOPH stages but in no mode
%                       NaN = the peak is outside the SOPH stages, so it
%                             was never in the histogram the modes were fit to
%       mode_members : NxM logical - mode_members(k, m) is true when peak k
%                      belongs to mode m. Unlike peak_labels, a peak inside
%                      several overlapping modes is true in each of them,
%                      which is how the Pk* columns count it
%
%   Notes:
%       The mode type is read from the params: a fourth column named
%       SOpowerMean means power modes, SOphaseMean means phase modes.
%
%       Power modes: the default argmax rule gives a peak to the mode with
%       the highest fitted density at that peak, and only if that density
%       beats the fitted background plane there. Out in a mode's tails the
%       histogram is mostly background, so the background decides where
%       each mode ends. A power-mode call therefore always needs the
%       background, and stops with an error if it cannot find one. It is
%       found in the paramfit CSV header, the fit object of a paramfit
%       struct, or the Bg* columns of aggregate rows.
%
%       Phase modes: the background is not used. Phase densities are
%       row-normalized, so they are not in the same units as the stored
%       background. A peak belongs to a phase mode when it lies inside the
%       mode's '0.95 p' contour (see assign_mode_peaks).
%
%       Overlapping modes: argmax gives each peak to at most one mode, but
%       under a contour rule ('0.95 p', '1.3 sigma') the contours of
%       neighboring modes can overlap. This is common on the phase axis,
%       where the two modes are wide. A peak inside several contours gets
%       the label of the mode it sits most deeply inside, and is true in
%       mode_members for every one of them.
%
%       Matching the Pk* columns: the Pk* columns count a peak in every mode
%       that contains it, so use mode_members to reproduce them. PkCount for
%       mode m is sum(mode_members(:, m)), and each other Pk* column
%       summarizes its stats_table property over the rows where
%       mode_members(:, m) is true (see MODE_PEAK_STATS). peak_labels gives
%       the same peaks only when no modes overlap, as under argmax. The
%       stages are not recorded in the CSVs, so pass 'Stages' if the run
%       used SOPH stages other than NREM.
%
%       When both inputs are CSVs that name their subject, the two subjects
%       must match.
%
%   -----------------------------------------------------------------------
%   ASSIGNMENT RULES
%   -----------------------------------------------------------------------
%   Each rule decides, for every peak, which modes it belongs to. Q is the
%   peak's distance from a mode's center in that mode's own sigma units
%   (Q = 0 at the center, Q = 1/2 at one sigma along an axis), and a mode's
%   density at the peak is Density*exp(-Q).
%
%   Density rules (compare each mode against the fitted background):
%
%     'argmax'      Each peak goes to the single mode with the highest
%                   density at that peak, and only if that density beats
%                   the background there. Otherwise it belongs to no mode.
%                   Exclusive: a peak is in at most one mode. The default,
%                   and the rule DYNAM-O uses for the Pk* columns.
%     'background'  A peak belongs to every mode whose density at the
%                   peak is at least the background there. Not exclusive:
%                   where two modes both rise above the background, the
%                   peak is in both.
%
%     Both take an optional footprint, e.g. 'argmax 2 sigma': a mode can
%     only claim peaks within that many sigma of its center (default 1.5).
%     Without it, any mode would claim peaks arbitrarily far away wherever
%     the background plane comes close to zero.
%
%   Contour rules (a fixed region around each mode, no background):
%
%     '0.95 p'      A peak belongs to a mode when it lies inside the
%                   contour enclosing probability 0.95 of that mode's
%                   Gaussian. Any 0 < p < 1 works, and a bare number
%                   such as 0.95 means the same. On the phase axis this
%                   is a relative-height contour, Density*exp(-Q) >=
%                   (1-p)*Density, whose enclosed mass depends on the
%                   mode's phase concentration.
%     '1.3 sigma'   A peak belongs to a mode when it lies within 1.3 sigma
%                   of the center, i.e. Q <= 1.3^2/2. Any n > 0 works,
%                   and '1.3 s' means the same.
%
%     Contours of neighboring modes can overlap, so a peak can be in
%     several modes (see mode_members).
%
%   Phase modes: the density rules need the background, which is not
%   comparable on the phase axis, so 'argmax' and 'background' are always
%   replaced by '0.95 p' there.
%
%   Example:
%       subject_dir = 'DYNAM-O_results/C3';
%       stats_csv = fullfile(subject_dir, 'TFpeaks', 'TS00304_stats_table_C3.csv');
%       paramfit_csv = fullfile(subject_dir, 'param_basis', 'TS00304_SOpower_paramfit_C3.csv');
%       peak_labels = label_peaks_by_mode(stats_csv, paramfit_csv);
%       stats_table = loadStatsTable(stats_csv);
%       mode1_peaks = stats_table(peak_labels == 1, :);
%
%   See also: assign_mode_peaks, get_mode_peaks, parse_peak_assign,
%             get_fit_background, loadStatsTable, loadParamfitCsv,
%             annotateModesWithPeakStats, mode_peak_stats
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

%************************************************************
%                       INPUT HANDLING
%************************************************************
is_path = @(x) ischar(x) || (isstring(x) && isscalar(x));

p = inputParser;
addRequired(p, 'stats_table', @(x) istable(x) || is_path(x));
addRequired(p, 'modes', @(x) isstruct(x) || istable(x) || is_path(x));
addParameter(p, 'Background', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 3));
addParameter(p, 'Stages', 1:3, @isnumeric);
addParameter(p, 'Assign', []);
parse(p, stats_table, modes, varargin{:});

soph_stages = p.Results.Stages;

% A CLI run leaves only CSVs on disk, so either input may be a file path
stats_subject = '';
if is_path(stats_table)
    [stats_table, stats_meta] = loadStatsTable(char(stats_table));
    stats_subject = stats_meta.subjectID;
end

[params, found_background, recorded_rule, modes_subject] = read_modes(modes);

if ~isempty(stats_subject) && ~isempty(modes_subject)
    assert(strcmp(stats_subject, modes_subject), ...
        'The stats table is for subject %s but the modes are for subject %s.', ...
        stats_subject, modes_subject);
end

% The fourth params column is the mode center on the SO axis. Look there
% rather than anywhere in the table: phase params also carry a SOpowerMean
% column (the SO power of each phase mode), further along.
so_center_column = params.Properties.VariableNames{4};
switch so_center_column
    case 'SOpowerMean'
        axis_kind = 'power';
    case 'SOphaseMean'
        axis_kind = 'phase';
    otherwise
        error('label_peaks_by_mode:UnknownParams', ...
            'The fourth params column is %s, not SOpowerMean or SOphaseMean.', so_center_column);
end

% Use the rule the run itself recorded, so the labels match its Pk* columns
if ~isempty(p.Results.Assign)
    assign_rule = p.Results.Assign;
elseif ~isempty(recorded_rule)
    assign_rule = recorded_rule;
else
    assign_rule = 'argmax';
end

%************************************************************
%                 CHOOSE THE POWER BACKGROUND
%************************************************************
if strcmp(axis_kind, 'phase')
    % Never consulted on the phase axis (see Notes)
    background = nan(1, 3);
elseif ~isempty(p.Results.Background)
    background = p.Results.Background(:).';
elseif all(isfinite(found_background))
    background = found_background;
else
    error('label_peaks_by_mode:NoBackground', ...
        ['Power modes need the fit background, and none was found in modes. ' ...
         'Pass the paramfit CSV, the paramfit struct or the subject''s aggregate ' ...
         'rows, or give ''Background'' directly.']);
end

num_peaks = height(stats_table);
num_modes = height(params);

%************************************************************
%            KEEP ONLY THE PEAKS THAT BUILT THE SOPH
%************************************************************
% The modes were fit to a histogram of the peaks in the SOPH stages only,
% so peaks from other stages cannot belong to a mode. They are labeled NaN
% to keep them distinct from SOPH peaks that simply fall in no mode (0).
in_soph_stages = ismember(stats_table.PeakStage, soph_stages);

peak_labels = nan(num_peaks, 1);
peak_labels(in_soph_stages) = 0;
mode_members = false(num_peaks, num_modes);

if num_modes == 0 || ~any(in_soph_stages)
    return
end

soph_peaks = stats_table(in_soph_stages, :);

%************************************************************
%              ASSIGN EACH PEAK TO ITS MODE
%************************************************************
% First six params columns are the mode shape, in the order the
% assignment functions expect: [Density, FreqMean, FreqStd, SO*Mean, SO*Std, Theta]
mode_shapes = params{:, 1:6};

% is_member(k, m) is true when the k-th SOPH peak belongs to mode m
is_member = assign_mode_peaks(mode_shapes, axis_kind, soph_peaks, assign_rule, background);

% Distance of every peak from every mode center, in the mode's own
% sigma units (Q = 0 at the center, larger further out). Used only to
% break ties when a peak belongs to more than one mode.
mode_distance = nan(height(soph_peaks), num_modes);
for mode_num = 1:num_modes
    [~, mode_distance(:, mode_num)] = get_mode_peaks(mode_shapes(mode_num, :), axis_kind, soph_peaks, 0.95);
end

% Hide the modes a peak does not belong to, then take the closest of the
% rest. A peak that belongs to no mode has an all-Inf row and keeps label 0.
mode_distance(~is_member) = inf;
[closest_distance, closest_mode] = min(mode_distance, [], 2);

soph_labels = zeros(height(soph_peaks), 1);
in_a_mode = isfinite(closest_distance);
soph_labels(in_a_mode) = closest_mode(in_a_mode);

peak_labels(in_soph_stages) = soph_labels;
mode_members(in_soph_stages, :) = is_member;
end

%************************************************************
%                 UNPACK THE MODES INPUT
%************************************************************
function [params, background, recorded_rule, subject_id] = read_modes(modes)
%READ_MODES  Params table, background and recorded rule from any modes input
%
%   Inputs:
%       modes : char, struct or table - the modes input of
%               label_peaks_by_mode -- required
%
%   Outputs:
%       params        : table - one row per mode
%       background    : 1x3 double - power background [PowSlope FreqSlope
%                       Offset], NaN where modes does not carry one
%       recorded_rule : char - the peak_assign rule the run recorded, ''
%                       when modes does not carry one
%       subject_id    : char - subject named in the CSV header, '' otherwise
%
%   Notes:
%       The background is the plane PowSlope*SOpower + FreqSlope*Frequency
%       + Offset. The fit object stores it as its xxx, yyy and zzz
%       coefficients. An aggregate CSV repeats a subject's background on
%       every row of that subject, so the rows must all agree. Rows that
%       differ mean several subjects were passed at once.
background = nan(1, 3);
recorded_rule = '';
subject_id = '';

% --- Paramfit CSV ---------------------------------------------------
if ischar(modes) || isstring(modes)
    csv_path = char(modes);
    [params, meta] = loadParamfitCsv(csv_path);
    subject_id = meta.subjectID;
    bg_keys = {'PowSlope', 'FreqSlope', 'Offset'};
    if all(isfield(meta.background, bg_keys))
        background = [meta.background.PowSlope, meta.background.FreqSlope, meta.background.Offset];
    end
    recorded_rule = read_recorded_rule(csv_path);
    return
end

% --- Paramfit struct from a DYNAMO object ---------------------------
if isstruct(modes)
    params = modes.params;
    if isfield(modes, 'fitobj') && ~isempty(modes.fitobj)
        background = get_fit_background(modes.fitobj);
    end
    if isfield(modes, 'peak_assign') && ~isempty(modes.peak_assign)
        recorded_rule = modes.peak_assign;
    end
    return
end

% --- Params table (aggregate rows carry Bg* columns) ----------------
params = modes;
bg_columns = {'BgPowSlope', 'BgFreqSlope', 'BgOffset'};
if all(ismember(bg_columns, params.Properties.VariableNames)) && height(params) > 0
    bg_rows = params{:, bg_columns};
    assert(all(all(abs(bg_rows - bg_rows(1, :)) <= 1e-12 * max(1, abs(bg_rows(1, :))))), ...
        'The params rows have different backgrounds. Pass the rows of one subject only.');
    background = bg_rows(1, :);
end
end

%************************************************************
%              READ THE RECORDED ASSIGNMENT RULE
%************************************************************
function rule = read_recorded_rule(csv_path)
%READ_RECORDED_RULE  The '# peak_assign:' value from a paramfit CSV header
%
%   Inputs:
%       csv_path : char - paramfit CSV path -- required
%
%   Outputs:
%       rule : char - the recorded rule (e.g. 'argmax 1.5 sigma'), '' when
%              the header has no peak_assign line
%
%   Notes:
%       loadParamfitCsv does not return this key, so the header is scanned
%       here. Only the leading '#' lines are header, so the scan stops at
%       the first line that does not start with '#'.
rule = '';
fid = fopen(csv_path, 'r');
assert(fid > 0, 'Could not open %s', csv_path);
closer = onCleanup(@() fclose(fid));

line = fgetl(fid);
while ischar(line) && startsWith(line, '#')
    tok = regexp(line, '^#\s*peak_assign\s*:\s*(.*)$', 'tokens', 'once');
    if ~isempty(tok)
        rule = strtrim(tok{1});
        return
    end
    line = fgetl(fid);
end
end
