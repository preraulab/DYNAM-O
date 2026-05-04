function renderResultsBrowserPreviewText(app, p)
    % renderResultsBrowserPreviewText  Render a text file in a
    % read-only uitextarea. Truncates to 5000 lines so very
    % large logs/CSVs don't lock up the UI.
    delete(app.ResultsBrowserPreviewBody.Children);
    ta = app.makeFillTextArea(app.ResultsBrowserPreviewBody);
    try
        txt = fileread(p);
        lines = strsplit(txt, newline);
        if numel(lines) > 5000
            lines = [lines(1:5000), {sprintf('… (truncated, %d more lines)', ...
                                             numel(lines)-5000)}];
        end
        ta.Value = lines;
    catch ME
        ta.Value = {sprintf('Read failed: %s', ME.message)};
    end
end
