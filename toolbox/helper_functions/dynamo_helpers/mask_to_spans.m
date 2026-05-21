function spans = mask_to_spans(mask, Fs)
%MASK_TO_SPANS  Convert a per-sample logical mask to [start_s, end_s] time spans.
%
%   Usage:
%       spans = mask_to_spans(mask, Fs)
%
%   Inputs:
%       mask : 1xN or Nx1 logical/numeric - true where the run is active
%       Fs   : double - sampling frequency in Hz
%
%   Output:
%       spans : Kx2 double - one [start_s, end_s] row per consecutive run of
%               true samples. Empty mask (or no runs) returns zeros(0,2).
%
%   Convention (matches the DYNAM-O desktop app's aux writer/reader so spans
%   are cross-tool readable): a run occupying 1-based samples [a, b] becomes
%   [(a-1)/Fs, b/Fs] — the end is one sample past the last true sample, i.e.
%   the half-open [start, end) interval the reader expands with
%   round(t*Fs). See spans_to_mask for the inverse. Round-trip is exact for
%   integer Fs; non-integer Fs can shift a boundary by +/-1 sample.
%
%   See also: spans_to_mask, consecutive_runs
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

spans = zeros(0, 2);
if isempty(mask) || isempty(Fs) || ~(Fs > 0)
    return
end

[~, run_inds] = consecutive_runs(logical(mask(:)'));
K = numel(run_inds);
if K == 0
    return
end

spans = zeros(K, 2);
for k = 1:K
    a = run_inds{k}(1);     % 1-based first sample of the run
    b = run_inds{k}(end);   % 1-based last sample of the run
    spans(k, :) = [(a - 1) / Fs, b / Fs];
end
end
