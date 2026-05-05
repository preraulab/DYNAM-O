function openPathInOS(~, p)
    % Shared helper used by both right-click 'Open' and the
    % NodeDoubleClickedFcn double-click handler.
    %
    % Suppresses the OS app's stdout/stderr so Linux desktop
    % editors (pluma, gedit, ...) don't dump Gtk-CRITICAL noise
    % into MATLAB's command window mid-run. Also discards the
    % `Opening: <path>` chatter — it pollutes the run log and
    % the user already triggered the action.
    if ~isfile(p) && ~isfolder(p)
        warning('DYNAMOFileManager:openPathInOS', ...
            'Path does not resolve: %s', p);
        return
    end
    quoted = ['"' strrep(p, '"', '\"') '"'];
    if ispc
        winopen(p);
    elseif ismac
        % `open` returns immediately and is quiet by default;
        % swallow status anyway so a missing app produces a
        % MATLAB warning instead of a stdout dump.
        [~, ~] = system(['open ' quoted]);
    else
        % Background `xdg-open` and redirect stdout+stderr so
        % the launched editor's Gtk warnings don't surface in
        % MATLAB. The trailing & disowns the child so MATLAB
        % doesn't block on a long-lived GUI app.
        [~, ~] = system(['xdg-open ' quoted ' >/dev/null 2>&1 &']);
    end
end
