function openPathInOS(~, p)
    % Shared helper used by both right-click 'Open' and the
    % NodeDoubleClickedFcn double-click handler.
    if ~isfile(p) && ~isfolder(p)
        warning('DYNAMOFileManager:openPathInOS', ...
            'Path does not resolve: %s', p);
        return
    end
    fprintf('Opening: %s\n', p);
    quoted = ['"' strrep(p, '"', '\"') '"'];
    if ispc
        winopen(p);
    elseif ismac
        system(['open ' quoted]);
    else
        system(['xdg-open ' quoted]);
    end
end
