function toggleRunLogConsole(app, ~, ~)
    % toggleRunLogConsole  Show or hide the floating Run Log Console.
    %   Mirrors the consolelog (diary) file in real time via a timer.

    if ~isempty(app.LogConsoleFig) && isvalid(app.LogConsoleFig)
        % Already open — close it (toggle off)
        app.stopLogConsoleTimer();
        delete(app.LogConsoleFig);
        app.LogConsoleFig      = [];
        app.LogConsoleTextArea = [];
        app.ShowRunLogConsoleMenu.Text = 'Show Run Log Console';
        return
    end

    % Create the console window
    ss = get(0, 'ScreenSize');
    cW = 720; cH = 520;
    fig = uifigure('Name', 'Run Log Console', ...
        'Position', [(ss(3)-cW)/2, (ss(4)-cH)/2, cW, cH], ...
        'WindowStyle', 'normal', ...
        'Resize', 'on', ...
        'CloseRequestFcn', @(~,~) onConsoleClose());

    g = uigridlayout(fig, ...
        'RowHeight', {'1x'}, 'ColumnWidth', {'1x'}, ...
        'Padding', [6 6 6 6]);

    ta = CSSuiTextArea(g, ...
        'Editable',         false, ...
        'Scroll',           true, ...
        'WordWrap',         false, ...
        'Style', app.AppStyle, ...
        'BackgroundColor',  '#ffffff', ...
        'FontSize',         '12px', ...
        'Color',            '#414c57', ...
        'FontWeight',       '500');
    ta.Layout.Row    = 1;
    ta.Layout.Column = 1;

    app.LogConsoleFig      = fig;
    app.LogConsoleTextArea = ta;
    app.ShowRunLogConsoleMenu.Text = 'Hide Run Log Console';

    % If a run is already in progress, load existing content and
    % start the polling timer.
    diaryRunning = ~isempty(app.consolelog_fpath) && ...
                   ~isempty(app.consolelog_fname);
    if diaryRunning
        app.refreshLogConsole();
        app.startLogConsoleTimer();
    end

    function onConsoleClose()
        app.stopLogConsoleTimer();
        delete(fig);
        app.LogConsoleFig      = [];
        app.LogConsoleTextArea = [];
        app.ShowRunLogConsoleMenu.Text = 'Show Run Log Console';
    end
end
