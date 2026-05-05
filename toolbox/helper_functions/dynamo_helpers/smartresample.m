function out = smartresample(data, src_fs, target_fs)
%SMARTRESAMPLE  Resample to target_fs, handling scalar or per-column source rates.
%
%   out = smartresample(data, src_fs, target_fs)
%
%   data:      vector or N x C matrix
%   src_fs:    scalar (uniform across columns) OR length-C vector
%              (one Fs per column — used when channels in `data` were
%              loaded at different native rates).
%   target_fs: scalar
%
%   When src_fs is a vector with at least two distinct rates, each
%   column is resampled with its own ratio and the result is trimmed
%   to the shortest length so the output stays a rectangular matrix.
%   Columns already at target_fs are passed through unchanged.

    if isvector(data)
        % Single-channel fast path. Accept src_fs as scalar (or 1-elem
        % vector); rat() then chooses the smallest integer ratio that
        % approximates target/src to MATLAB's default tolerance.
        f = src_fs(1);
        if abs(f - target_fs) <= 1e-9
            out = data;
            return
        end
        [p, q] = rat(target_fs / f);
        out = resample(data, p, q);
        return
    end

    % Matrix path. If src_fs is scalar OR uniform, do it in one shot
    % (resample handles columns of a matrix natively).
    if isscalar(src_fs) || all(abs(src_fs - src_fs(1)) < 1e-9)
        if abs(src_fs(1) - target_fs) <= 1e-9
            out = data;
            return
        end
        [p, q] = rat(target_fs / src_fs(1));
        out = resample(data, p, q);
        return
    end

    % Heterogeneous-rate matrix: resample each column independently.
    % Resulting columns may differ by 1 sample due to rat()/resample
    % rounding — trim to the shortest so the output remains a matrix.
    nC = size(data, 2);
    cols = cell(1, nC);
    for ii = 1:nC
        f = src_fs(ii);
        if abs(f - target_fs) <= 1e-9
            cols{ii} = data(:, ii);
        else
            [p, q] = rat(target_fs / f);
            cols{ii} = resample(data(:, ii), p, q);
        end
    end
    Lmin = min(cellfun(@numel, cols));
    out = zeros(Lmin, nC, 'like', data);
    for ii = 1:nC
        out(:, ii) = cols{ii}(1:Lmin);
    end
end
