function bg = get_fit_background(fitobj)
%GET_FIT_BACKGROUND  Background coefficients [xxx yyy zzz] from a fitobj.
%
%   bg = get_fit_background(fitobj)
%
%   Pulls the three background coefficients off a paramfit cfit/sfit
%   object by coefficient name (the alphabetical-ordering names xxx/yyy/
%   zzz sort after the per-mode amp_/fmean_/... coefficients):
%       power: bg(F, P) = xxx*P + yyy*F + zzz   (tilted plane)
%       phase: xxx*sin(X + yyy) + zzz           (sinusoid + offset)
%
%   Returns NaN(1,3) when fitobj is empty or lacks the coefficients, so
%   density-based peak assignment fails closed (see ASSIGN_MODE_PEAKS).
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
% =========================================================================
bg = nan(1, 3);
if isempty(fitobj)
    return
end
try
    names = coeffnames(fitobj);
    vals = coeffvalues(fitobj);
    keys = {'xxx', 'yyy', 'zzz'};
    for k = 1:3
        idx = find(strcmp(names, keys{k}), 1);
        if ~isempty(idx)
            bg(k) = vals(idx);
        end
    end
catch
    % Not a fit object (or degenerate) - fail closed with NaNs.
end
end
