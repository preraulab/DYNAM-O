function chDir = resolveChannelDir(~, p)
    % resolveChannelDir  Walk up from the clicked node until the
    % parent directory is the results root (i.e., the next level
    % up has no more parametric/SOPH structure). For a node
    % already at channel level (param_basis/SOPHs subdir was the
    % click target), walk one step up.
    chDir = '';
    if isempty(p), return, end
    if isfolder(p), chDir = p; else, chDir = fileparts(p); end
    [~, name] = fileparts(chDir);
    if strcmp(name,'param_basis') || strcmp(name,'SOPHs')
        chDir = fileparts(chDir);
    end
end
