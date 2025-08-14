function z = normalized_vmGauss(X, Y, unit_row, xxx, yyy, zzz, varargin)
%NORMALIZED_VMGAUSS - Fit multiple von Mises Gaussians to data normalized across unique values of Y

assert(mod(length(varargin), 6) == 0, 'Number of varargin cannot be divided by 6. Cannot convert to vmGauss peaks.')
N_peaks = length(varargin) / 6;

z = xxx*sin(X + yyy) + zzz;

for ii = 1:N_peaks
    amp =       varargin{(ii-1) * 6 + 1};
    fmean =     varargin{(ii-1) * 6 + 2};
    fstd =      varargin{(ii-1) * 6 + 3};
    phasepref = varargin{(ii-1) * 6 + 4};
    recikappa = varargin{(ii-1) * 6 + 5};
    theta =     varargin{(ii-1) * 6 + 6};

    % vmGauss(X,Y, amp, ymean, ystd, xmean, xstd, theta)
    z = z + vmGauss(X, Y, amp, fmean, fstd, phasepref, recikappa, theta);
end

% Normalize across unique values of Y
if unit_row
    uniqueY = unique(Y);
    for jj = 1:length(uniqueY)
        sel_idx = Y == uniqueY(jj);
        z(sel_idx) = z(sel_idx) / sum(z(sel_idx));
    end
end
