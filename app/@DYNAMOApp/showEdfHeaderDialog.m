function app = showEdfHeaderDialog(app, varargin)
    % showEdfHeaderDialog  Open (or update) a floating window showing the EDF file header.
    %
    %   Triggered by double-clicking an item in DataListBox. If the header
    %   viewer figure already exists, its tables are refreshed in place;
    %   otherwise a new figure is created via header_gui.

    if isempty(app.DataList) || isempty(app.DataListBox.Value)
        return
    end

    curr_file = app.DataListBox.Value{:};
    if ~exist(curr_file, 'file')
        uialert(app.UIFigure, sprintf('File does not exist: %s', curr_file), 'Error', 'Icon', 'error');
        return
    end

    [header, signalHeader] = read_EDF(curr_file);

    if isempty(app.header_fig) || (~isempty(app.header_fig) && ~ishandle(app.header_fig))
        % First call or figure was closed: create a new header viewer
        [~, ~, app.header_fig, app.uitable_header, app.uitable_signal] = ...
            header_gui(header, signalHeader);
    else
        % Viewer exists: refresh table data without reopening
        [header_tbl, signal_tbl] = header_gui(header, signalHeader, 'CreateGUI', false);
        app.uitable_header.Data  = header_tbl;
        app.uitable_signal.Data  = signal_tbl;
    end
end
