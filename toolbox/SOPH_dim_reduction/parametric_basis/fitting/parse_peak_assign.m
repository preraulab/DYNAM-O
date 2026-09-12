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
%   The density rules take an optional sigma FOOTPRINT ('argmax 2 s',
%   'background 1.75 sigma'); bare forms mean a 1.5-sigma footprint.
%
%   Output struct:
%       a.kind     : 'p' | 'sigma' | 'background' | 'argmax'
%       a.value    : the numeric parameter (NaN for the density rules)
%       a.thr      : Q threshold of a numeric contour: -log(1-p) for 'p',
%                    n^2/2 for 'sigma' (NaN for the density rules). A peak
%                    is inside the contour iff Q <= thr (GET_MODE_PEAKS).
%       a.footprint: density-rule footprint radius in sigma (NaN for the
%                    numeric contours)
%       a.q_cap    : the footprint as a Q cap, footprint^2/2 (NaN for the
%                    numeric contours) - see ASSIGN_MODE_PEAKS
%       a.label    : canonical char form ('0.3 p', '1.3 sigma',
%                    'background 1.5 sigma', 'argmax 1.5 sigma') - what
%                    the CSV preamble records (density rules always spell
%                    their footprint).
%
%   Errors on anything else (unknown unit, p outside (0,1), sigma <= 0,
%   footprint <= 0).
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
parts = strsplit(t);
if any(strcmp(parts{1}, {'argmax', 'background'}))
    if numel(parts) == 1
        fp = 1.5;   % default footprint (Rust DEFAULT_DENSITY_FOOTPRINT_SIGMA)
    else
        assert(numel(parts) == 3 && any(strcmp(parts{3}, {'s', 'sigma'})), ...
            'peak_assign: `%s` - density-rule footprint must be `<n> s|sigma`.', char(v));
        fp = str2double(parts{2});
        assert(isfinite(fp) && fp > 0, ...
            'peak_assign: footprint must be > 0, got `%s`.', parts{2});
    end
    a = struct('kind', parts{1}, 'value', NaN, 'thr', NaN, ...
        'footprint', fp, 'q_cap', 0.5 * fp^2, ...
        'label', sprintf('%s %g sigma', parts{1}, fp));
    return
end
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
            'footprint', NaN, 'q_cap', NaN, 'label', sprintf('%g p', x));
    case 'sigma'
        assert(isfinite(x) && x > 0, ...
            'peak_assign: sigma radius must be > 0, got %g.', x);
        a = struct('kind', 'sigma', 'value', x, 'thr', 0.5 * x^2, ...
            'footprint', NaN, 'q_cap', NaN, 'label', sprintf('%g sigma', x));
end
end
