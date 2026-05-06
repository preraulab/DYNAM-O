function renderResultsBrowserPreviewImage(app, p)
    % renderResultsBrowserPreviewImage  Render a still image
    % (PNG/JPG/BMP) into the preview pane via imshow, with a
    % pop-out toolbar button that opens the same image in a
    % separate figure.
    delete(app.ResultsBrowserPreviewBody.Children);
    img = imread(p);
    ax = uiaxes(app.ResultsBrowserPreviewBody, ...
        'Units','normalized','Position',[0 0 1 1], ...
        'BackgroundColor','white');
    imshow(img, 'Parent', ax);
    app.attachPopOutToolbar(ax, ...
        @(a) imshow(img, 'Parent', a), p);
end
