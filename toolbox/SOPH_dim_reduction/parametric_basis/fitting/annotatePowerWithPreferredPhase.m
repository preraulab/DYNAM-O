function T = annotatePowerWithPreferredPhase(T, SOphase_mat, freq_bins, phase_bins, model_SOPH_phase, phase_freq_limits)
%ANNOTATEPOWERWITHPREFERREDPHASE  Add per-mode preferred-phase columns.
%
%   T = annotatePowerWithPreferredPhase(T, SOphase_mat, freq_bins, ...
%                                       phase_bins, model_SOPH_phase, ...
%                                       phase_freq_limits)
%
%   Appends a single (phase, magnitude) pair to a power-fit params
%   table T, the model-based SO phase-coupling estimate:
%
%     PrefPhase  / Coupling  — argmax of the fitted phase
%                                         parametric model evaluated at
%                                         the mode's frequency. NaN-filled
%                                         when MODEL_SOPH_PHASE is empty
%                                         (phase fit failed).
%
%   PHASE_FREQ_LIMITS (optional) is the [low high] frequency window the
%   phase fit was run over (its 'freq_limits' option). The phase model is
%   only fitted inside that window, so a mode whose frequency bin lies
%   outside it has no phase model to read: its PrefPhase and Coupling are
%   NaN. When PHASE_FREQ_LIMITS is omitted or empty, every mode is read
%   from MODEL_SOPH_PHASE.
%
%   SOPHASE_MAT is accepted for backward-compatible call sites but is no
%   longer used: the model-based estimate reads the fitted phase surface
%   (MODEL_SOPH_PHASE), not the raw SO-phase histogram.
%
%   T is expected to have at least a FreqMean column. Returns T with the
%   two new columns appended.

if nargin < 6
    phase_freq_limits = [];
end

if isempty(T)
    return
end
f = T.FreqMean;

if ~isempty(model_SOPH_phase)
    [pm, mm] = get_mode_phase_argmax(f, model_SOPH_phase, freq_bins, phase_bins);
else
    pm = nan(size(f));
    mm = nan(size(f));
end

% No phase model outside the phase fit's frequency window. The test uses
% the frequency bin each mode is read from, the one nearest its FreqMean.
if ~isempty(model_SOPH_phase) && ~isempty(phase_freq_limits)
    mode_bin = knnsearch(freq_bins(:), f(:));
    mode_bin_freq = freq_bins(mode_bin);
    mode_bin_freq = mode_bin_freq(:);
    outside_window = mode_bin_freq < phase_freq_limits(1) | mode_bin_freq > phase_freq_limits(2);
    pm(outside_window) = NaN;
    mm(outside_window) = NaN;
end

T.PrefPhase  = pm;
T.Coupling   = mm;
end
