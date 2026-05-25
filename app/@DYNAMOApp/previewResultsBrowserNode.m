function previewResultsBrowserNode(app, evt)
    % previewResultsBrowserNode  Render a preview of the
    % single-clicked tree node in the right-column preview pane.
    % Images and TIFFs go into a uiaxes; CSVs into a uitable;
    % MAT and other types fall back to a "preview not available"
    % placeholder per current scope.
    if ~isfield(evt,'NodeData') || isempty(evt.NodeData)
        app.renderResultsBrowserPreviewPlaceholder();
        return
    end
    p = char(evt.NodeData);
    if isfolder(p)
        app.renderResultsBrowserPreviewPlaceholder();
        return
    end
    if ~isfile(p)
        app.renderResultsBrowserPreviewMessage(...
            sprintf('File not found:\n%s', p));
        return
    end

    [~, name, ext] = fileparts(p);
    app.ResultsBrowserPreviewTitle.Text = upper([name, ext]);

    ext = lower(ext);
    % Show the dancing-bars animation while the renderer prepares
    % the preview. Each renderer below replaces the body's
    % children, which clears the spinner.
    app.renderResultsBrowserPreviewPlaceholder('loading');
    drawnow;
    try
        switch ext
            case {'.png','.jpg','.jpeg','.gif','.bmp'}
                app.renderResultsBrowserPreviewImage(p);
            case {'.tif','.tiff'}
                app.renderResultsBrowserPreviewTiff(p);
            case '.csv'
                app.renderResultsBrowserPreviewCsv(p);
            case {'.txt', '.json', '.log'}
                % JSON is plain text — render via the text viewer instead
                % of falling through to "Preview not available". `.log`
                % covers any other text-style log files we emit.
                app.renderResultsBrowserPreviewText(p);
            case '.mat'
                app.renderResultsBrowserPreviewMat(p);
            case {'.h5','.hdf5'}
                app.renderResultsBrowserPreviewH5(p);
            otherwise
                app.renderResultsBrowserPreviewMessage(...
                    sprintf('Preview not available for %s files.', ext));
        end
    catch ME
        app.renderResultsBrowserPreviewMessage(...
            sprintf('Preview failed:\n%s', ME.message));
    end
end
