function renderResultsBrowserPreviewPlaceholder(app, mode)
    % Optional mode: 'empty' | 'loading' | 'idle'. If omitted,
    % inferred from cache state.
    if nargin < 2 || isempty(mode)
        if isempty(app.ResultsBrowserCache_)
            mode = 'empty';
        else
            mode = 'idle';
        end
    end
    app.ResultsBrowserPreviewTitle.Text = 'PREVIEW';
    delete(app.ResultsBrowserPreviewBody.Children);

    if strcmp(mode, 'loading')
        % Render the same SVG animation that the RUN button uses
        % when a batch is in flight (setRunningState). uihtml only
        % positions cleanly via a grid layout (it has no Units
        % property), so we wrap it in a 1x1 grid that fills the
        % preview body's uipanel.
        g = uigridlayout(app.ResultsBrowserPreviewBody, [1 1]);
        g.Padding     = [0 0 0 0];
        g.RowHeight   = {'1x'};
        g.ColumnWidth = {'1x'};
        h = uihtml(g);
        h.Layout.Row    = 1;
        h.Layout.Column = 1;
        h.HTMLSource    = app.buildLoadingAnimationHtml('Loading directory tree…');
        return
    end

    switch mode
        case 'empty'
            msg = sprintf(['Select a DYNAM-O results directory above to begin.\n\n' ...
                           'Use the Browse button or paste a path into the field.']);
        otherwise
            msg = 'Click a file in the tree to preview it.';
    end
    ax = uiaxes(app.ResultsBrowserPreviewBody, ...
        'Units','normalized','Position',[0 0 1 1], ...
        'BackgroundColor','white');
    axis(ax,'off');
    text(ax, 0.5, 0.5, msg, ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'Color',[0.55 0.6 0.65], 'FontSize', 13);
end
