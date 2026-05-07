function renderSOPHTiffSliderPage(app, ctx, k)
    % Slider callback target — render page k of a multi-page SOPH
    % TIFF using cached metadata from ctx.
    k = max(1, min(ctx.nPage, k));
    M = double(imread(ctx.path, k));
    cla(ctx.ax);
    app.styleSOPHAxes(ctx.ax, M, ctx.freq_bins, ctx.bins, ctx.axis_kind);
    title(ctx.ax, sprintf('SO-%s Histogram — Subject %d/%d', ...
        upper(ctx.axis_kind(1)), k, ctx.nPage), 'Interpreter','none');
end
