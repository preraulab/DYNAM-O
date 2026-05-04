function createConsoleLogPanel(app)
    % createConsoleLogPanel  Redirect MATLAB diary output to a timestamped console log.
    %
    %   Creates <OutputDir>/logs/console_log_<timestamp>.txt and activates
    %   MATLAB's diary function to capture all subsequent console output.

    app.consolelog_fname = strcat('console_log_', app.curr_datetime, '.txt');
    app.consolelog_fpath = strcat(app.OutputDirEditField.Value, '/logs/');
    fullpath = fullfile(app.consolelog_fpath, app.consolelog_fname);

    % Write the header via a scoped fopen + fclose. We must NOT hold
    % the fid open, because `diary` takes ownership of the file right
    % after this; two open handles to the same path makes diary's
    % appends unreliable on macOS (silent failure with empty log).
    fid = fopen(fullpath, 'w');
    if fid < 0
        warning('createConsoleLog:fopen', ...
            'Could not open console log at %s; diary not started.', fullpath);
        app.consolelog_fid = [];
        return
    end
    fprintf(fid, 'Date and time of run start: %s\n\n', app.curr_datetime);
    fclose(fid);
    app.consolelog_fid = [];  % no persistent fid; diary owns the file

    % Start diary. Wrapped so that if MATLAB errors on diary(path)
    % we don't kill the whole batch (the console log is nice-to-have).
    try
        diary off
        diary(fullpath)
    catch diaryErr
        warning('createConsoleLog:diary', ...
            'diary(%s) failed: %s', fullpath, diaryErr.message);
    end

    % If the Run Log Console is already open, start live polling now.
    if ~isempty(app.LogConsoleFig) && isvalid(app.LogConsoleFig)
        app.startLogConsoleTimer();
    end
end
