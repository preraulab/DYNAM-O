function v = resolve_path(S, dottedPath)
% Resolve a path like 'SOPHs.SOpower_mat' or 'C{2}.field' against S.
    import results_browser.*
v = S;
remaining = dottedPath;
while ~isempty(remaining)
    [tok, rest] = next_token(remaining);
    if startsWith(tok, '{')
        idx = sscanf(tok, '{%d}');
        v = v{idx};
    else
        % Strip leading dot if present.
        if startsWith(tok, '.'), tok = tok(2:end); end
        if isempty(tok), remaining = rest; continue, end
        v = v.(tok);
    end
    remaining = rest;
end
end

