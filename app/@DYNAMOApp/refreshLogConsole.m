function refreshLogConsole(app)
    % refreshLogConsole  Read the consolelog file and refresh the text area.
    if isempty(app.LogConsoleFig) || ~isvalid(app.LogConsoleFig)
        return
    end
    fpath = fullfile(app.consolelog_fpath, app.consolelog_fname);
    if ~isfile(fpath), return, end
    try
        app.LogConsoleTextArea.Value = fileread(fpath);
    catch
    end
end
