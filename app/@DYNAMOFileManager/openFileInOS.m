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

    if ispc        % Windows
        % winopen is a MATLAB function, it handles spaces automatically
        winopen(curr_file);
    elseif ismac   % macOS
        system(['open -a TextEdit "' curr_file '"']);
    elseif isunix  % Linux
        % system() calls the terminal; quotes are required for spaces
        system(['xdg-open "' curr_file '"']);
    end

end
