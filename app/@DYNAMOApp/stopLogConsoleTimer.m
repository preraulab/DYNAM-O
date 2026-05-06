function stopLogConsoleTimer(app)
    % stopLogConsoleTimer  Stop and delete the polling timer if running.
    if ~isempty(app.LogConsoleTimer) && isvalid(app.LogConsoleTimer)
        stop(app.LogConsoleTimer);
        delete(app.LogConsoleTimer);
    end
    app.LogConsoleTimer = [];
end
