function mask = spans_to_mask(spans, N, Fs)
%SPANS_TO_MASK  Expand [start_s, end_s] time spans to a per-sample logical mask.
%
%   Usage:
%       mask = spans_to_mask(spans, N, Fs)
%
%   Inputs:
%       spans : Kx2 double - [start_s, end_s] rows (seconds)
%       N     : double - number of samples in the output mask
%       Fs    : double - sampling frequency in Hz
%
%   Output:
%       mask : 1xN logical - true inside any span
%
%   Convention (matches the DYNAM-O desktop app's aux reader): each span sets
%   the half-open sample range [round(start*Fs), round(end*Fs)) in 0-based
%   terms, i.e. 1-based samples (round(start*Fs)+1) : round(end*Fs), clamped
%   to [1, N]. Inverse of mask_to_spans; round-trip is exact for integer Fs.
%
%   See also: mask_to_spans, consecutive_runs
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

mask = false(1, max(0, N));
if isempty(spans) || N <= 0 || isempty(Fs) || ~(Fs > 0)
    return
end

for k = 1:size(spans, 1)
    i0 = round(spans(k, 1) * Fs) + 1;   % 1-based first sample
    i1 = round(spans(k, 2) * Fs);       % 1-based last sample (half-open end)
    i0 = max(i0, 1);
    i1 = min(i1, N);
    if i1 >= i0
        mask(i0:i1) = true;
    end
end
end
