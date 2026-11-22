function T = annotateModesWithPeakStats(T, axis_kind, stats_table_SOPH, assign, background, baseline)
%ANNOTATEMODESWITHPEAKSTATS  Append per-mode TF-peak summary columns.
%
%   T = annotateModesWithPeakStats(T, axis_kind, stats_table_SOPH, assign, background, baseline)
%
%   For each mode (row of the paramfit params table T) selects its member
%   TF-peaks under the peak_assign rule (ASSIGN_MODE_PEAKS) and appends
%   eleven summary columns built from MODE_PEAK_STATS:
%
%     PkCount, PkFreq, PkDuration, PkBandwidth, PkHeight, PkPower,
%     PkVolume, PkArea, PkPeakiness, PkSOpower, PkSOphase
%
%   Every Pk* aggregate is a MEDIAN over the mode's member peaks
%   (PkSOphase is a circular mean, PkCount a count) - see
%   MODE_PEAK_STATS for why. These mirror, name-for-name, the per-mode
%   columns the Rust pipeline writes (dynamo_pipeline::mode_peaks), so
%   the MATLAB and Rust paramfit CSVs share one schema.
%
%   BASELINE (optional) is the extraction's per-frequency 2nd-percentile
%   floor as struct('values', v, 'freqs', f): v LINEAR power on the
%   frequency axis f (computeTFPeaks' baseline over sfreqs). It feeds
%   PkPower, the median per-peak pow2db(Height * baseline(PeakFrequency)).
%   Stats-table Height is a LINEAR prominence over the recording's own
%   floor and is only comparable within a recording (the floor carries
%   the stable subject-amplitude trait); multiplying the floor back in
%   re-anchors it to absolute power - the spectrogram-domain counterpart
%   of per-spindle bandpass-envelope amplitude. Omitted or empty ->
%   PkPower = NaN (the column is still added).
%
%   ASSIGN accepts anything PARSE_PEAK_ASSIGN does: a probability (0.3 or
%   '0.3 p' - a numeric value keeps this function backward compatible with
%   the old `prob` argument), a sigma radius ('1.3 sigma'), 'background',
%   or 'argmax' (the toolbox default). BACKGROUND is the fit's [xxx yyy
%   zzz] (GET_FIT_BACKGROUND); only the density rules consult it, and on
%   the phase axis those fall back to the '0.95 p' contour (phase Density
%   is row-normalized; the stored phase background is not).
%
%   The columns are ALWAYS added (stable schema). When STATS_TABLE_SOPH is
%   empty/missing the expected columns, PkCount = 0 and the means are NaN.
%
%   STATS_TABLE_SOPH should already be restricted to the peak population that
%   fed the SOPH (e.g. the SOPH sleep stages); the assignment rule handles
%   the freq/SO-feature locality.
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
% =========================================================================
nM = height(T);
PkCount     = zeros(nM,1);
PkFreq      = nan(nM,1);
PkDuration  = nan(nM,1);
PkBandwidth = nan(nM,1);
PkHeight    = nan(nM,1);
PkPower     = nan(nM,1);
PkVolume    = nan(nM,1);
PkArea      = nan(nM,1);
PkPeakiness = nan(nM,1);
PkSOpower   = nan(nM,1);
PkSOphase   = nan(nM,1);

if nargin < 4 || isempty(assign); assign = 'argmax'; end
if nargin < 5 || isempty(background); background = nan(1, 3); end
if nargin < 6; baseline = []; end
assign = parse_peak_assign(assign);

have_stats = nargin >= 3 && istable(stats_table_SOPH) && ~isempty(stats_table_SOPH) ...
    && ismember('PeakFrequency', stats_table_SOPH.Properties.VariableNames);

if nM > 0 && have_stats
    % Per-peak absolute prominence power (dB); all-NaN without a baseline.
    stats_table_SOPH.PowerDb = peak_power_db_(stats_table_SOPH, baseline);
    props = {'PeakFrequency','Duration','Bandwidth','Height','PowerDb', ...
             'Volume','Area','Peakiness','SOpower','SOphase'};
    params6 = T{:, 1:6};   % [Density,FreqMean,FreqStd,SO*Mean,SO*Std,Theta]
    members = assign_mode_peaks(params6, axis_kind, stats_table_SOPH, assign, background);
    for m = 1:nM
        s = mode_peak_stats(stats_table_SOPH, members(:, m), props);
        PkCount(m)     = s.count;
        PkFreq(m)      = s.PeakFrequency;
        PkDuration(m)  = s.Duration;
        PkBandwidth(m) = s.Bandwidth;
        PkHeight(m)    = s.Height;
        PkPower(m)     = s.PowerDb;
        PkVolume(m)    = s.Volume;
        PkArea(m)      = s.Area;
        PkPeakiness(m) = s.Peakiness;
        PkSOpower(m)   = s.SOpower;
        PkSOphase(m)   = s.SOphase;
    end
end

T.PkCount     = PkCount;
T.PkFreq      = PkFreq;
T.PkDuration  = PkDuration;
T.PkBandwidth = PkBandwidth;
T.PkHeight    = PkHeight;
T.PkPower     = PkPower;
T.PkVolume    = PkVolume;
T.PkArea      = PkArea;
T.PkPeakiness = PkPeakiness;
T.PkSOpower   = PkSOpower;
T.PkSOphase   = PkSOphase;
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
