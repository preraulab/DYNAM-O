function v = parse_settings_vec(txt, key)
v = [];
pat = ['^\s*' regexptranslate('escape', key) '\s*=\s*\[([^\]]*)\]'];
tok = regexp(txt, pat, 'tokens', 'lineanchors', 'once');
if isempty(tok), return, end
v = sscanf(tok{1}, '%g').';
end

