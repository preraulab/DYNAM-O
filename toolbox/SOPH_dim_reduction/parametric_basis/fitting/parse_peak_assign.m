function a = parse_peak_assign(v)
%PARSE_PEAK_ASSIGN  Parse the flexible peak_assign option value.
%
%   a = parse_peak_assign(v)
%
%   Accepts (trimmed, case-insensitive; mirrors the Rust settings parser):
%       0.3, '0.3', '0.3 p'   - probability-mass contour, 0 < p < 1
%       '1.3 s', '1.3 sigma'  - sigma-radius contour, n > 0
%       'background'          - mode density >= fitted background density
%       'argmax'              - exclusive: densest component wins
%
%   Output struct:
%       a.kind : 'p' | 'sigma' | 'background' | 'argmax'
%       a.value: the numeric parameter (NaN for the density rules)
%       a.thr  : Q threshold of a numeric contour: -log(1-p) for 'p',
%                n^2/2 for 'sigma' (NaN for the density rules). A peak is
%                inside the contour iff Q <= thr (see GET_MODE_PEAKS).
%       a.label: canonical char form ('0.3 p', '1.3 sigma', 'background',
%                'argmax') - what the CSV preamble records.
%
%   Errors on anything else (unknown unit, p outside (0,1), sigma <= 0).
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
% =========================================================================
if isnumeric(v)
    assert(isscalar(v), 'peak_assign: numeric value must be scalar.');
    a = num_form_('p', v);
    return
end
assert(ischar(v) || (isstring(v) && isscalar(v)), ...
    'peak_assign must be a numeric scalar or char/string.');
t = lower(strtrim(char(v)));
switch t
    case 'argmax'
        a = struct('kind', 'argmax', 'value', NaN, 'thr', NaN, 'label', 'argmax');
        return
    case 'background'
        a = struct('kind', 'background', 'value', NaN, 'thr', NaN, 'label', 'background');
        return
end
parts = strsplit(t);
num = str2double(parts{1});
assert(~isnan(num), 'peak_assign: `%s` is not a number, background, or argmax.', char(v));
if numel(parts) == 1
    unit = 'p';
else
    assert(numel(parts) == 2, 'peak_assign: `%s` has too many parts.', char(v));
    unit = parts{2};
end
switch unit
    case 'p'
        a = num_form_('p', num);
    case {'s', 'sigma'}
        a = num_form_('sigma', num);
    otherwise
        error('peak_assign: unknown unit `%s` in `%s` (use p, s, or sigma).', unit, char(v));
end
end

function a = num_form_(kind, x)
switch kind
    case 'p'
        assert(isfinite(x) && x > 0 && x < 1, ...
            'peak_assign: probability must be in (0, 1), got %g.', x);
        a = struct('kind', 'p', 'value', x, 'thr', -log(1 - x), ...
            'label', sprintf('%g p', x));
    case 'sigma'
        assert(isfinite(x) && x > 0, ...
            'peak_assign: sigma radius must be > 0, got %g.', x);
        a = struct('kind', 'sigma', 'value', x, 'thr', 0.5 * x^2, ...
            'label', sprintf('%g sigma', x));
end
end
