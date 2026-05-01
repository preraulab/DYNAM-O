function T = annotatePowerWithPreferredPhase(T, SOphase_mat, freq_bins, phase_bins, model_SOPH_phase)
%ANNOTATEPOWERWITHPREFERREDPHASE  Add per-mode preferred-phase columns.
%
%   T = annotatePowerWithPreferredPhase(T, SOphase_mat, freq_bins, ...
%                                       phase_bins, model_SOPH_phase)
%
%   Appends six columns to a power-fit params table T, one (phase,
%   magnitude) pair from each of three estimators:
%
%     PrefPhaseArgmax / CouplingArgmax  — argmax of the raw SO-phase
%                                          histogram column at the
%                                          mode's frequency.
%     PrefPhaseCirc   / CouplingCirc    — weighted circular mean of
%                                          the same column. Magnitude
%                                          is the mean resultant length
%                                          (Canolty PAC / PLV / vector
%                                          strength), in [0,1].
%     PrefPhaseModel  / CouplingModel   — argmax of the fitted phase
%                                          parametric model evaluated
%                                          at the mode's frequency.
%                                          NaN-filled when MODEL_SOPH_PHASE
%                                          is empty (phase fit failed).
%
%   T is expected to have at least a FreqMean column. Returns T with
%   six new columns appended in the order listed above.

if isempty(T)
    return
end
f = T.FreqMean;

[pa, ma] = get_mode_phase_argmax(f, SOphase_mat, freq_bins, phase_bins);
[pc, rc] = get_mode_phase_circmean(f, SOphase_mat, freq_bins, phase_bins);
if ~isempty(model_SOPH_phase)
    [pm, mm] = get_mode_phase_argmax(f, model_SOPH_phase, freq_bins, phase_bins);
else
    pm = nan(size(f));
    mm = nan(size(f));
end

T.PrefPhaseArgmax = pa;
T.CouplingArgmax  = ma;
T.PrefPhaseCirc   = pc;
T.CouplingCirc    = rc;
T.PrefPhaseModel  = pm;
T.CouplingModel   = mm;
end
