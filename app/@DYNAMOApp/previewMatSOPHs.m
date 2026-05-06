function previewMatSOPHs(app, p)
    % Per-subject SOPHs.mat → two tabs (Power / Phase).
    S = load(p);
    if ~isfield(S, 'SOPHs')
        app.renderResultsBrowserPreviewMessage('SOPHs variable missing.');
        return
    end
    tg = uitabgroup(app.ResultsBrowserPreviewBody, ...
        'Units','normalized','Position',[0 0 1 1]);

    tPow  = uitab(tg, 'Title','SO-Power');
    gPow  = uigridlayout(tPow);
    gPow.ColumnWidth = {'1x'}; gPow.RowHeight = {'1x'};
    gPow.Padding = [12 12 12 12];
    axP = uiaxes(gPow, 'BackgroundColor','white');
    axP.Layout.Row = 1; axP.Layout.Column = 1;
    app.plotAggregateSOHist(axP, p, 'power');
    app.attachPopOutToolbar(axP, ...
        @(a) app.plotAggregateSOHist(a, p, 'power'), 'SO-Power Histogram');

    tPh   = uitab(tg, 'Title','SO-Phase');
    gPh   = uigridlayout(tPh);
    gPh.ColumnWidth = {'1x'}; gPh.RowHeight = {'1x'};
    gPh.Padding = [12 12 12 12];
    axPh = uiaxes(gPh, 'BackgroundColor','white');
    axPh.Layout.Row = 1; axPh.Layout.Column = 1;
    app.plotAggregateSOHist(axPh, p, 'phase');
    app.attachPopOutToolbar(axPh, ...
        @(a) app.plotAggregateSOHist(a, p, 'phase'), 'SO-Phase Histogram');
end
