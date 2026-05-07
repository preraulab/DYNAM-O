function redrawSOHistograms(app)
    % redrawSOHistograms  Replace the Mean SOPH plot-panel
    %   children with one (power, phase) axes pair per
    %   selected channel, laid out by buildPairGrid. Each
    %   pair carries an outer title (channel name) above the
    %   two halves.
    sel = app.SOHistogramsChannelListBox.Value;
    if ischar(sel) || isstring(sel), sel = cellstr(sel); end
    sel = sel(~startsWith(sel, '(no data) '));
    n = numel(sel);
    if n == 0
        delete(app.SOHistogramsPlotPanel.Children);
        app.SOHistogramsPlaceholderAxes = uiaxes( ...
            app.SOHistogramsPlotPanel, ...
            'Units','normalized', 'Position',[0 0 1 1], ...
            'BackgroundColor','white');
        axis(app.SOHistogramsPlaceholderAxes,'off');
        text(app.SOHistogramsPlaceholderAxes, 0.5, 0.5, ...
            'Select one or more channels on the left', ...
            'HorizontalAlignment','center','VerticalAlignment','middle', ...
            'Color',[0.5 0.5 0.5]);
        return
    end

    pairs = app.buildPairGrid(app.SOHistogramsPlotPanel, sel);

    for ii = 1:n
        ch  = sel{ii};
        idx = find(strcmp({app.SOHist_ChannelInfo_.name}, ch), 1);
        axP  = pairs{ii}(1);
        axPh = pairs{ii}(2);

        if isempty(idx)
            axis(axP,'off');  axis(axPh,'off');
            continue
        end
        info = app.SOHist_ChannelInfo_(idx);

        if info.hasPower
            app.plotAggregateSOHist(axP, info.powerPath, 'power');
            app.attachPopOutToolbar(axP, ...
                @(a) app.plotAggregateSOHist(a, info.powerPath, 'power'), ...
                sprintf('Mean SO-Power Histogram — %s', ch));
        else
            axis(axP,'off');
            text(axP, 0.5, 0.5, '(no power aggregate)', ...
                 'HorizontalAlignment','center');
        end

        if info.hasPhase
            app.plotAggregateSOHist(axPh, info.phasePath, 'phase');
            app.attachPopOutToolbar(axPh, ...
                @(a) app.plotAggregateSOHist(a, info.phasePath, 'phase'), ...
                sprintf('Mean SO-Phase Histogram — %s', ch));
        else
            axis(axPh,'off');
            text(axPh, 0.5, 0.5, '(no phase aggregate)', ...
                 'HorizontalAlignment','center');
        end
    end
end
