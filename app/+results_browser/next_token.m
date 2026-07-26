function [tok, rest] = next_token(s)
if startsWith(s, '{')
    cb = strfind(s, '}');
    tok = s(1:cb(1));
    rest = s(cb(1)+1:end);
elseif startsWith(s, '.')
    nextDot   = strfind(s(2:end), '.');
    nextBrace = strfind(s(2:end), '{');
    candidates = [nextDot, nextBrace];
    if isempty(candidates)
        tok = s; rest = '';
    else
        cut = min(candidates);
        tok  = s(1:cut);
        rest = s(cut+1:end);
    end
else
    % Bare leading identifier (the top-level var name).
    nextDot   = strfind(s, '.');
    nextBrace = strfind(s, '{');
    candidates = [nextDot, nextBrace];
    if isempty(candidates)
        tok = s; rest = '';
    else
        cut = min(candidates) - 1;
        tok  = s(1:cut);
        rest = s(cut+1:end);
    end
end
end
