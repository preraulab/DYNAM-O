function aux = normalizeAuxStruct(aux)
%NORMALIZEAUXSTRUCT  Normalize an auxiliary_data struct to the compact schema.
%
%   Usage:
%       aux = normalizeAuxStruct(aux)
%
%   Accepts a struct read from either the new compact aux schema or a legacy
%   aux file (per-sample /artifacts, EEG-rate /SOpower_norm without t_start,
%   f64 /stage_vals, /SOpower_retain_Fs) and fills in the fields consumers
%   expect, without recomputing any data:
%       - stage_vals      -> double (legacy may already be double; new is uint8)
%       - SOpower_step     : native window step, or 1/Fs for legacy EEG-rate
%       - SOpower_t_start  : kept if present; legacy default 0 (EEG-rate) or
%                            window_size/2 (native)
%       - SOpower_freqrange: default [0.3; 1.5] if absent (metadata only)
%       - artifact_spans   : kept if present; else synthesized from a legacy
%                            per-sample /artifacts mask, else zeros(0,2)
%   A legacy per-sample `artifacts` field, when present, is left in place so
%   consumers that still expect a mask keep working.
%
%   See also: loadAuxData, mask_to_spans, spans_to_mask, regenAuxData.
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

if isempty(aux) || ~isstruct(aux)
    return
end

% Detect compact-schema provenance BEFORE adding synthesized fields. A
% compact file carries native-grid markers and/or uint8 stages; for these,
% an absent artifact_spans means "zero artifacts" (authoritative), whereas a
% legacy file lacking artifact info means "unknown" (caller should detect).
is_compact = isfield(aux, 'SOpower_t_start') || isfield(aux, 'artifact_spans') || ...
    isfield(aux, 'SOpower_freqrange') || ...
    (isfield(aux, 'stage_vals') && isinteger(aux.stage_vals));

Fs = NaN;
if isfield(aux, 'Fs') && ~isempty(aux.Fs)
    Fs = double(aux.Fs);
end

wp = [5; 0.5];
if isfield(aux, 'SOpower_window_params') && numel(aux.SOpower_window_params) >= 2
    wp = double(aux.SOpower_window_params(:));
end
window_size = wp(1);
step_native = wp(2);

% stage_vals -> double for hypnoplot/interp1 consumers
if isfield(aux, 'stage_vals') && ~isempty(aux.stage_vals)
    aux.stage_vals = double(aux.stage_vals);
end

% Decide whether a legacy series is EEG-rate (upsampled) or native. New
% files always carry SOpower_t_start and are native.
is_eeg_rate = false;
if ~isfield(aux, 'SOpower_t_start') || isempty(aux.SOpower_t_start)
    if isfield(aux, 'SOpower_retain_Fs') && ~logical(aux.SOpower_retain_Fs)
        is_eeg_rate = false;   % legacy native
    else
        is_eeg_rate = true;    % legacy EEG-rate (retain_Fs true or unknown)
    end
end

% SOpower_step: native step, or EEG sample period for legacy upsampled series
if ~isfield(aux, 'SOpower_step') || isempty(aux.SOpower_step)
    if is_eeg_rate && isfinite(Fs) && Fs > 0
        aux.SOpower_step = 1 / Fs;
    else
        aux.SOpower_step = step_native;
    end
end

% SOpower_t_start
if ~isfield(aux, 'SOpower_t_start') || isempty(aux.SOpower_t_start)
    if is_eeg_rate
        aux.SOpower_t_start = 0;
    else
        aux.SOpower_t_start = window_size / 2;
    end
end

% SOpower_freqrange default (metadata only; does not change values)
if ~isfield(aux, 'SOpower_freqrange') || isempty(aux.SOpower_freqrange)
    aux.SOpower_freqrange = [0.3; 1.5];
end

% artifact_spans: synthesize from a legacy per-sample mask if absent
if ~isfield(aux, 'artifact_spans') || isempty(aux.artifact_spans)
    if isfield(aux, 'artifacts') && ~isempty(aux.artifacts) && isfinite(Fs) && Fs > 0
        aux.artifact_spans = mask_to_spans(logical(aux.artifacts), Fs);
    else
        aux.artifact_spans = zeros(0, 2);
    end
end

% True when artifact_spans (even empty) is authoritative — i.e. a compact
% file where absent spans genuinely means "no artifacts".
aux.is_compact = is_compact;
end
