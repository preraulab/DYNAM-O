function appendRunLog(app, msg)
    % appendRunLog  Write a structured message to the run log file.
    %   Console output is captured separately via diary() and
    %   mirrored by the LogConsoleTimer polling the consolelog file.
    if ~isempty(app.runlog_fid) && app.runlog_fid > 0
        fprintf(app.runlog_fid, '%s', msg);
    end
end
