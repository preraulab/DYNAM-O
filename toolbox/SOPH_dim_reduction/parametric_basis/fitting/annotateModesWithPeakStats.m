function T = annotateModesWithPeakStats(T, axis_kind, stats_table_SOPH, assign, background, baseline, varargin)
%ANNOTATEMODESWITHPEAKSTATS  Append per-mode TF-peak summary (Pk*) columns to a params table
%
%   Usage:
%       T = annotateModesWithPeakStats(T, axis_kind, stats_table_SOPH)
%       T = annotateModesWithPeakStats(T, axis_kind, stats_table_SOPH, assign, background, baseline)
%       T = annotateModesWithPeakStats(T, axis_kind, stats_table_SOPH, assign, background, baseline, 'Summary', 'mean')
%
%   Inputs:
%       T                : table - paramfit params table, one row per mode,
%                          first six columns [Density FreqMean FreqStd
%                          SO*Mean SO*Std Theta] -- required
%       axis_kind        : char - 'power' or 'phase' -- required
%       stats_table_SOPH : table - TF-peak stats table already restricted
%                          to the peaks that built the SOPH (see
%                          SOPH_PEAK_MASK) -- required
%       assign           : char or double - peak_assign rule, anything
%                          PARSE_PEAK_ASSIGN accepts (default: 'argmax')
%       background       : 1x3 double - the fit's [xxx yyy zzz] from
%                          GET_FIT_BACKGROUND, used by the density rules
%                          on the power axis (default: nan(1, 3))
%       baseline         : struct - extraction floor as struct('values', v,
%                          'freqs', f), v linear power on the frequency
%                          axis f, needed for PkPower (default: [])
%
%   Name-Value Pairs:
%       'Summary' : char - statistic over each mode's member peaks,
%                   'median' or 'mean', passed to MODE_PEAK_STATS
%                   (default: 'median')
%
%   Outputs:
%       T : table - the input with eleven columns appended, in this order:
%           PkCount, PkFreq, PkDuration, PkBandwidth, PkHeight, PkPower,
%           PkVolume, PkArea, PkPeakiness, PkSOpower, PkSOphase
%
%   Notes:
%       Each mode's member peaks are chosen by ASSIGN_MODE_PEAKS under the
%       assign rule. PkCount counts them, and every other Pk* column is
%       the summary of one stats-table property over them (PkSOphase is
%       always a circular mean). The pipeline uses the default median, and
%       the columns match name for name the ones the Rust pipeline writes
%       (dynamo_pipeline::mode_peaks), so MATLAB and Rust paramfit CSVs
%       share one schema.
%
%       PkPower is the summary over member peaks of pow2db(Height *
%       baseline(PeakFrequency)). Stats-table Height is a linear prominence
%       over the recording's own floor, so it is only comparable within a
%       recording. Multiplying the floor back in re-anchors it to absolute
%       power, the spectrogram-domain counterpart of per-spindle envelope
%       amplitude. Without a baseline PkPower is NaN.
%
%       On the phase axis the density rules fall back to the '0.95 p'
%       contour, since phase Density is row-normalized and the stored
%       background is not.
%
%       The columns are always added, so the schema is stable. With no
%       stats table, or no modes, PkCount is 0 and the rest are NaN.
%
%   See also: assign_mode_peaks, mode_peak_stats, label_peaks_by_mode,
%             soph_peak_mask, parse_peak_assign, get_fit_background
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

if nargin < 4 || isempty(assign); assign = 'argmax'; end
if nargin < 5 || isempty(background); background = nan(1, 3); end
if nargin < 6; baseline = []; end

p = inputParser;
addParameter(p, 'Summary', 'median', @(x) any(validatestring(x, {'median', 'mean'})));
parse(p, varargin{:});
summary = p.Results.Summary;

assign = parse_peak_assign(assign);

% Each Pk* column and the stats-table property it summarizes, in the
% shared cross-implementation column order (PkCount comes first). PowerDb
% is not a stats-table column. It is computed per peak below.
pk_columns = {
    'PkFreq',      'PeakFrequency'
    'PkDuration',  'Duration'
    'PkBandwidth', 'Bandwidth'
    'PkHeight',    'Height'
    'PkPower',     'PowerDb'
    'PkVolume',    'Volume'
    'PkArea',      'Area'
    'PkPeakiness', 'Peakiness'
    'PkSOpower',   'SOpower'
    'PkSOphase',   'SOphase'
    };
num_modes = height(T);

pk_count = zeros(num_modes, 1);
pk_values = nan(num_modes, size(pk_columns, 1));

have_stats = istable(stats_table_SOPH) && ~isempty(stats_table_SOPH) ...
    && ismember('PeakFrequency', stats_table_SOPH.Properties.VariableNames);

if num_modes > 0 && have_stats
    stats_table_SOPH.PowerDb = peak_power_db_(stats_table_SOPH, baseline);
    mode_shapes = T{:, 1:6};
    members = assign_mode_peaks(mode_shapes, axis_kind, stats_table_SOPH, assign, background);

    for mode_num = 1:num_modes
        s = mode_peak_stats(stats_table_SOPH, members(:, mode_num), pk_columns(:, 2)', ...
            'Summary', summary);
        pk_count(mode_num) = s.count;
        for jj = 1:size(pk_columns, 1)
            pk_values(mode_num, jj) = s.(pk_columns{jj, 2});
        end
    end
end

T.PkCount = pk_count;
for jj = 1:size(pk_columns, 1)
    T.(pk_columns{jj, 1}) = pk_values(:, jj);
end
end

%************************************************************
%            PER-PEAK ABSOLUTE PROMINENCE POWER
%************************************************************
function v = peak_power_db_(stats_table, baseline)
%PEAK_POWER_DB_  pow2db(Height * baseline(PeakFrequency)) per peak
%
%   Inputs:
%       stats_table : table - carries PeakFrequency + Height -- required
%       baseline    : struct with values (linear power) + freqs (Hz), or
%                     [] when unavailable -- required
%
%   Outputs:
%       v : [n x 1] double - absolute prominence power, dB; all-NaN when
%           the baseline is absent or malformed, NaN where Height <= 0.
%           Clamped linear interpolation matches Rust peak_power_db.
v = nan(height(stats_table), 1);
ok_base = isstruct(baseline) && isfield(baseline, 'values') && isfield(baseline, 'freqs') ...
    && numel(baseline.values) == numel(baseline.freqs) && numel(baseline.values) >= 2;
if ~ok_base || ~ismember('Height', stats_table.Properties.VariableNames)
    return
end
f  = double(baseline.freqs(:));
bv = double(baseline.values(:));
q  = min(max(double(stats_table.PeakFrequency), f(1)), f(end));   % clamp to the axis
b  = interp1(f, bv, q, 'linear');
h  = double(stats_table.Height);
good = isfinite(h) & h > 0 & isfinite(b) & b > 0;
v(good) = pow2db(h(good) .* b(good));
end
