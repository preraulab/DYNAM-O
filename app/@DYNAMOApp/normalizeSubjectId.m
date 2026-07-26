function id = normalizeSubjectId(~, raw)
    % normalizeSubjectId  Canonicalise a subject identifier so the
    %   metadata-CSV first column matches the aggregate's ID column.
    %   Lenient: strips whitespace and a trailing .edf / .EDF if present
    %   so users who paste filenames-with-extension still match against
    %   the fbase used by DYNAM-O internally.
    %
    %   Method form takes an unused first arg (the app) so the helper
    %   can be invoked as app.normalizeSubjectId(x). Vectorised over
    %   string / cell / categorical inputs; scalar in / scalar out for
    %   any other type, char out either way.
    if iscell(raw)
        id = cellfun(@scalar_normalize, raw, 'UniformOutput', false);
        return
    end
    if isstring(raw) && ~isscalar(raw)
        id = arrayfun(@(x) string(scalar_normalize(x)), raw);
        return
    end
    if iscategorical(raw)
        id = arrayfun(@(x) string(scalar_normalize(x)), raw);
        return
    end
    id = scalar_normalize(raw);
end


function out = scalar_normalize(x)
    if ismissing(x), out = ''; return, end
    s = strtrim(string(x));
    if strlength(s) == 0, out = char(s); return, end
    s = regexprep(s, '\.edf$', '', 'ignorecase');
    out = char(s);
end
