%SMARTRESAMPLE  Resample a signal between arbitrary sampling rates using rational approximation
%
%   Usage:
%       out = smartresample(x, Fs, Frs)
%       out = smartresample(x, Fs, Frs, order)
%
%   Inputs:
%       x     : vector OR N x C matrix
%       Fs    : scalar (uniform across columns) OR length-C vector
%               (one Fs per column — used when channels in `x` were
%               loaded at different native rates).
%       Frs   : scalar - target sampling frequency in Hz.
%       order : integer - FIR filter order passed to resample (default: 500)
%
%   Outputs:
%       out   : resampled signal, same orientation as `x`. Heterogeneous-
%               rate columns are trimmed to the shortest output length so
%               the result remains a rectangular matrix.
%
%   Notes:
%       - Mirrors the canonical Prerau-lab `smartresample` ([d,n]=rat(Fs/Frs);
%         resample(x,n,d,order)) for the scalar case so output is bit-equal
%         to other lab tools using that helper.
%       - The matrix + per-column-Fs path is a DYNAM-O extension used by
%         load_data.m to handle EDFs where selected channels have
%         different native rates.
%       - Columns already at Frs are passed through unchanged (no resample
%         filter ringing where none is needed).
%
%   See also: resample, rat
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

function out = smartresample(x, Fs, Frs, order)
if nargin < 4
    order = 500;
end

if isvector(x)
    f = Fs(1);
    if abs(f - Frs) <= 1e-9
        out = x;
        return
    end
    [d, n] = rat(f / Frs);
    out = resample(x, n, d, order);
    return
end

% Matrix path. Uniform Fs (scalar or all-equal vector) → one-shot resample.
if isscalar(Fs) || all(abs(Fs - Fs(1)) < 1e-9)
    if abs(Fs(1) - Frs) <= 1e-9
        out = x;
        return
    end
    [d, n] = rat(Fs(1) / Frs);
    out = resample(x, n, d, order);
    return
end

% Heterogeneous-rate matrix: resample each column on its own ratio.
% Trim to the shortest output column so we keep a rectangular matrix.
nC = size(x, 2);
cols = cell(1, nC);
for ii = 1:nC
    f = Fs(ii);
    if abs(f - Frs) <= 1e-9
        cols{ii} = x(:, ii);
    else
        [d, n] = rat(f / Frs);
        cols{ii} = resample(x(:, ii), n, d, order);
    end
end
Lmin = min(cellfun(@numel, cols));
out = zeros(Lmin, nC, 'like', x);
for ii = 1:nC
    out(:, ii) = cols{ii}(1:Lmin);
end
end
