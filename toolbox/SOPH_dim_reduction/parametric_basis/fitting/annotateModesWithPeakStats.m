function T = annotateModesWithPeakStats(T, axis_kind, stats_table, prob)
%ANNOTATEMODESWITHPEAKSTATS  Append per-mode TF-peak summary columns.
%
%   T = annotateModesWithPeakStats(T, axis_kind, stats_table, prob)
%
%   For each mode (row of the paramfit params table T) finds the TF-peaks
%   inside the mode's confidence region (GET_MODE_PEAKS) and appends ten
%   summary columns built from MODE_PEAK_STATS:
%
%     PkCount, PkFreq, PkDuration, PkBandwidth, PkHeight, PkVolume,
%     PkArea, PkPeakiness, PkSOpower, PkSOphase
%
%   (PkHeight = peak power = amplitude; PkSOphase is a circular mean.)
%   These mirror, name-for-name, the per-mode columns the Rust pipeline
%   writes (dynamo_pipeline::mode_peaks), so the MATLAB and Rust paramfit
%   CSVs share one schema.
%
%   The columns are ALWAYS added (stable schema). When STATS_TABLE is empty
%   / missing the expected columns, PkCount = 0 and the means are NaN.
%
%   STATS_TABLE should already be restricted to the peak population that fed
%   the SOPH (e.g. the SOPH sleep stages); GET_MODE_PEAKS handles the
%   freq/SO-feature locality via the mode ellipse.
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
% =========================================================================
if nargin < 4 || isempty(prob); prob = 0.95; end

nM = height(T);
PkCount     = zeros(nM,1);
PkFreq      = nan(nM,1);
PkDuration  = nan(nM,1);
PkBandwidth = nan(nM,1);
PkHeight    = nan(nM,1);
PkVolume    = nan(nM,1);
PkArea      = nan(nM,1);
PkPeakiness = nan(nM,1);
PkSOpower   = nan(nM,1);
PkSOphase   = nan(nM,1);

have_stats = nargin >= 3 && istable(stats_table) && ~isempty(stats_table) ...
    && ismember('PeakFrequency', stats_table.Properties.VariableNames);

if nM > 0 && have_stats
    props = {'PeakFrequency','Duration','Bandwidth','Height','Volume', ...
             'Area','Peakiness','SOpower','SOphase'};
    for m = 1:nM
        mode_params = T{m, 1:6};   % [Density,FreqMean,FreqStd,SO*Mean,SO*Std,Theta]
        idx = get_mode_peaks(mode_params, axis_kind, stats_table, prob);
        s   = mode_peak_stats(stats_table, idx, props);
        PkCount(m)     = s.count;
        PkFreq(m)      = s.PeakFrequency;
        PkDuration(m)  = s.Duration;
        PkBandwidth(m) = s.Bandwidth;
        PkHeight(m)    = s.Height;
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
T.PkVolume    = PkVolume;
T.PkArea      = PkArea;
T.PkPeakiness = PkPeakiness;
T.PkSOpower   = PkSOpower;
T.PkSOphase   = PkSOphase;
end
