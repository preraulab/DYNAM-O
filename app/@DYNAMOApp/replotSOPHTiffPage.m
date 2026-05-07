function replotSOPHTiffPage(app, ax, filePath, axis_kind, pageIdx)
    % Pop-out closure target: render a single SOPH TIFF page to ax
    % with full styling (used so the popped figure carries the same
    % colormap / clipping / aspect as the inline preview).
    try
        info = imfinfo(filePath);
        pageIdx = max(1, min(numel(info), pageIdx));
        [freq_bins, bins] = app.peekSOPHTiffBins(filePath, info, axis_kind);
        M = double(imread(filePath, pageIdx));
        app.styleSOPHAxes(ax, M, freq_bins, bins, axis_kind);
    catch ME
        axis(ax,'off');
        text(ax, 0.5, 0.5, sprintf('load failed: %s', ME.message), ...
            'HorizontalAlignment','center','Color','red');
    end
end
