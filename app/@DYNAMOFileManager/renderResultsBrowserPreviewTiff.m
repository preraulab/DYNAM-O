function renderResultsBrowserPreviewTiff(app, p)
    % SOPH TIFFs (per-subject and aggregate) get the same look
    % as the Analysis → SO-Histograms tab: transposed imagesc
    % with the right colormap, freq clip to 2–16 Hz, x-axis
    % matched to bin metadata, mean across pages for multi-page
    % aggregates. Generic multi-page TIFFs fall back to a page
    % slider with parula.
    import results_browser.*
    [~, base, ~] = fileparts(p);
    baseLower = lower(base);
    if contains(baseLower, 'sophs_power')
        axis_kind = 'power';
    elseif contains(baseLower, 'sophs_phase')
        axis_kind = 'phase';
    else
        axis_kind = '';
    end

    % Splinefit TIFFs (page 1 = coefs, page 2 = rendered fit)
    % get a dedicated 2-tab preview that mirrors the .mat
    % splinefit preview: rendered image + knots/coefs dump.
    isSplineTiff = contains(baseLower, 'splinefit');
    if isSplineTiff
        if contains(baseLower, 'sopower'),       splineAxisKind = 'power';
        elseif contains(baseLower, 'sophase'),   splineAxisKind = 'phase';
        else,                                    splineAxisKind = 'power';
        end
        delete(app.ResultsBrowserPreviewBody.Children);
        app.renderSplinefitTiffPreview(p, splineAxisKind);
        return
    end

    delete(app.ResultsBrowserPreviewBody.Children);

    if ~isempty(axis_kind)
        info  = imfinfo(p);
        nPage = numel(info);
        % Recover bins from the TIFF metadata or sidecar/settings.
        [freq_bins, bins] = app.peekSOPHTiffBins(p, info, axis_kind);

        if nPage <= 1
            % Wrap in a padded grid so the SOPH image breathes.
            gOne = uigridlayout(app.ResultsBrowserPreviewBody);
            gOne.ColumnWidth = {'1x'}; gOne.RowHeight = {'1x'};
            gOne.Padding = [12 12 12 12];
            ax = uiaxes(gOne, 'BackgroundColor','white');
            ax.Layout.Row = 1; ax.Layout.Column = 1;
            M = double(imread(p, 1));
            app.styleSOPHAxes(ax, M, freq_bins, bins, axis_kind);
            title(ax, sprintf('SO-%s Histogram', upper(axis_kind(1))), ...
                'Interpreter','none');
            app.attachPopOutToolbar(ax, ...
                @(a) app.replotSOPHTiffPage(a, p, axis_kind, 1), ...
                sprintf('SO-%s Histogram', upper(axis_kind(1))));
            return
        end

        % Multi-page aggregate TIFF: page slider + numeric edit
        % so a 1000-subject aggregate is still navigable.
        g = uigridlayout(app.ResultsBrowserPreviewBody);
        g.ColumnWidth = {'1x'}; g.RowHeight = {'1x', 36};
        g.RowSpacing = 6; g.Padding = [12 12 12 12];

        ax = uiaxes(g, 'BackgroundColor','white');
        ax.Layout.Row = 1; ax.Layout.Column = 1;

        sliderRow             = uigridlayout(g);
        sliderRow.ColumnWidth = {70, '1x', 60};
        sliderRow.RowHeight   = {'1x'};
        sliderRow.ColumnSpacing = 8;
        sliderRow.Padding     = [0 0 0 0];
        sliderRow.Layout.Row  = 2; sliderRow.Layout.Column = 1;

        ed = CSSuiNumericField(sliderRow, ...
            'Style', app.AppStyle, ...
            'Min', 1, 'Max', nPage, ...
            'Value', 1, ...
            'Format', '%d', ...
            'HorizontalAlignment', 'center');
        ed.Layout.Column = 1;
        sl = uislider(sliderRow, 'Limits',[1 nPage], 'Value', 1, ...
            'MajorTicks', sparseSliderTicks(nPage), ...
            'MinorTicks', []);
        sl.Layout.Column = 2;
        uilabel(sliderRow, 'Text', sprintf('of %d', nPage), ...
            'HorizontalAlignment','right');

        ctx = struct('ax', ax, 'sliderRow', sliderRow, ...
            'slider', sl, 'edit', ed, ...
            'path', p, 'axis_kind', axis_kind, 'nPage', nPage, ...
            'freq_bins', freq_bins, 'bins', bins);
        app.renderSOPHTiffSliderPage(ctx, 1);
        sl.ValueChangedFcn = @(s,~) app.jumpSOPHTiff(ctx, round(s.Value));
        ed.ValueChangedFcn = @(s,~) app.jumpSOPHTiff(ctx, round(s.Value));
        app.attachPopOutToolbar(ax, ...
            @(a) app.replotSOPHTiffPage(a, p, axis_kind, 1), ...
            sprintf('SO-%s Histogram', upper(axis_kind(1))));
        return
    end

    % --- Generic TIFF fallback (rare): page-by-page browser ---
    info  = imfinfo(p);
    nPage = numel(info);
    if nPage <= 1
        ax = uiaxes(app.ResultsBrowserPreviewBody, ...
            'Units','normalized','Position',[0 0 1 1], ...
            'BackgroundColor','white');
        M = double(imread(p, 1));
        imagesc(ax, M); colormap(ax, parula); axis(ax,'image','xy');
        colorbar(ax);
        app.attachPopOutToolbar(ax, ...
            @(a) drawImagescFigure(a, M), p);
        return
    end

    g = uigridlayout(app.ResultsBrowserPreviewBody);
    g.ColumnWidth = {'1x'}; g.RowHeight = {'1x', 32};
    g.RowSpacing = 2; g.Padding = [4 4 4 4];

    ax = uiaxes(g);
    ax.Layout.Row = 1; ax.Layout.Column = 1;
    ax.BackgroundColor = 'white';

    sliderRow             = uigridlayout(g);
    sliderRow.ColumnWidth = {80, '1x', 60};
    sliderRow.RowHeight   = {'1x'};
    sliderRow.Padding     = [0 0 0 0];
    sliderRow.Layout.Row  = 2; sliderRow.Layout.Column = 1;

    uilabel(sliderRow, 'Text', sprintf('Page 1/%d', nPage), ...
        'Tag','tiffPageLabel', ...
        'HorizontalAlignment','left');
    sl = uislider(sliderRow, 'Limits',[1 nPage], 'Value', 1, ...
        'MajorTicks',[], 'MinorTicks',[]);
    sl.Layout.Column = 2;
    uilabel(sliderRow, 'Text', sprintf('of %d', nPage), ...
        'HorizontalAlignment','right');

    renderPage(1);
    sl.ValueChangedFcn = @(s,e) renderPage(round(s.Value));

    function renderPage(k)
        k = max(1, min(nPage, k));
        M = double(imread(p, k));
        cla(ax);
        imagesc(ax, M); colormap(ax, parula); axis(ax,'image','xy');
        colorbar(ax);
        lbl = findobj(sliderRow,'Tag','tiffPageLabel');
        if ~isempty(lbl), lbl.Text = sprintf('Page %d/%d', k, nPage); end
    end
end
