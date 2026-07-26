function appendResultsBrowserLog(app, msg)
    % appendResultsBrowserLog  Mirror a status message to (1) the Results
    % Browser status text area and (2) the MATLAB command window.
    % Auto-scrolls the text area to the bottom so streaming output
    % stays visible during long-running aggregate/load operations.
    fprintf('%s\n', msg);
    try
        app.ResultsBrowserTextArea.addnl(msg);
        % CSSBase.pushCmd writes to HTMLComponent.Data, and two
        % rapid writes in the same synchronous block race — JS only
        % sees the second one, so the appended text would be lost.
        % drawnow flushes the appendText event before scrollBottom.
        drawnow;
        app.ResultsBrowserTextArea.scrollToBottom();
    catch
        % Fall back silently if the widget hasn't been built yet.
    end
end
