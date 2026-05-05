function app = openFileInOS(app, varargin)
    % openFileInOS  Open a staging file.
    %
    %   Triggered by double-clicking an item in FileListBox.

    if isempty(app.StagingList) || isempty(app.StagingListBox.Value)
        return
    end

    curr_file = app.StagingListBox.Value{:};
    if ~exist(curr_file, 'file')
        uialert(app.UIFigure, sprintf('File does not exist: %s', curr_file), 'Error', 'Icon', 'error');
        return
    end

    % Suppress the launched app's stdout/stderr so Linux desktop
    % editors (pluma, gedit, ...) don't dump Gtk-CRITICAL warnings
    % into MATLAB. & on Linux disowns the child so MATLAB doesn't
    % block on a long-lived editor.
    if ispc        % Windows
        % winopen is a MATLAB function, it handles spaces automatically
        winopen(curr_file);
    elseif ismac   % macOS
        [~, ~] = system(['open -a TextEdit "' curr_file '"']);
    elseif isunix  % Linux
        [~, ~] = system(['xdg-open "' curr_file '" >/dev/null 2>&1 &']);
    end

end
