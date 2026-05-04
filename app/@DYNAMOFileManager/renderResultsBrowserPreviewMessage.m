function renderResultsBrowserPreviewMessage(app, msg)
    % renderResultsBrowserPreviewMessage  Render a centered text
    % message in the preview pane — used for "file not found",
    % unsupported types, and similar status messages. Treats
    % `msg` literally (Interpreter='none') so paths and errors
    % render exactly as given.
    delete(app.ResultsBrowserPreviewBody.Children);
    ax = uiaxes(app.ResultsBrowserPreviewBody, ...
        'Units','normalized','Position',[0 0 1 1], ...
        'BackgroundColor','white');
    axis(ax,'off');
    text(ax, 0.5, 0.5, msg, ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'Interpreter','none','Color',[0.45 0.5 0.55], 'FontSize', 13);
end
