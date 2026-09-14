function label = effective_peak_assign_label(assign, axis_kind)
%EFFECTIVE_PEAK_ASSIGN_LABEL  Canonical label of the rule used on one axis.
%
%   label = effective_peak_assign_label(assign, axis_kind)
%
%   The '# peak_assign:' CSV preamble records the rule EFFECTIVELY used:
%   the phase axis always runs a numeric contour, so under the density
%   rules ('background' / 'argmax') it reports the '0.95 p' fallback
%   (see ASSIGN_MODE_PEAKS). ASSIGN accepts anything PARSE_PEAK_ASSIGN
%   does.
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
% =========================================================================
a = parse_peak_assign(assign);
if strcmpi(axis_kind, 'phase') && any(strcmp(a.kind, {'background', 'argmax'}))
    a = parse_peak_assign('0.95 p');
end
label = a.label;
end
