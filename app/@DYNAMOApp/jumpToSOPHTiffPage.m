function jumpToSOPHTiffPage(app, ctx, k)
    % jumpToSOPHTiffPage  Move the multi-page SOPH TIFF preview to
    % page k. Clamps to [1, nPage], keeps both the slider and
    % the numeric edit field in sync (suppressing feedback
    % loops), and redraws the page.
    k = max(1, min(ctx.nPage, round(k)));
    if isfield(ctx,'slider') && isvalid(ctx.slider) && ctx.slider.Value ~= k
        ctx.slider.Value = k;
    end
    if isfield(ctx,'edit') && isvalid(ctx.edit) && ctx.edit.Value ~= k
        ctx.edit.Value = k;
    end
    app.renderSOPHTiffSliderPage(ctx, k);
end
