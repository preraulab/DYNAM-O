function T = annotatePowerWithPreferredPhase(T, SOphase_mat, freq_bins, phase_bins, model_SOPH_phase)
%ANNOTATEPOWERWITHPREFERREDPHASE  Add per-mode preferred-phase columns.
%
%   T = annotatePowerWithPreferredPhase(T, SOphase_mat, freq_bins, ...
%                                       phase_bins, model_SOPH_phase)
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
%   SOPHASE_MAT is accepted for backward-compatible call sites but is no
%   longer used: the model-based estimate reads the fitted phase surface
%   (MODEL_SOPH_PHASE), not the raw SO-phase histogram.
%
%   T is expected to have at least a FreqMean column. Returns T with the
%   two new columns appended.

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

T.PrefPhase  = pm;
T.Coupling   = mm;
end
