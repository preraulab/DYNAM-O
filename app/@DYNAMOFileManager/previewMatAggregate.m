function previewMatAggregate(app, p)
    % previewMatAggregate  Render an aggregate .mat — handles
    % both shapes the aggregator emits: a stacked paramfit
    % `params` table (uitable) and a 3-D SOPHs volume keyed by
    % subject (page slider over an imagesc per subject).
    import results_browser.*
    S = load(p);
    agg = S.aggregate;

    % --- Paramfit aggregate: aggregate.params is a stacked table.
    if isfield(agg, 'params') && istable(agg.params)
        ut = uitable(app.ResultsBrowserPreviewBody);
        ut.Units = 'normalized'; ut.Position = [0 0 1 1];
        ut.Data = agg.params; ut.ColumnSortable = true;
        return
    end

    % --- SOPHs aggregate: 3-D power or phase volume + page slider.
    if isfield(agg, 'SOpower_mat'), axis_kind = 'power';
    elseif isfield(agg, 'SOphase_mat'), axis_kind = 'phase';
    else
        app.renderResultsBrowserPreviewMessage( ...
            'Unknown aggregate shape (no params / SO*_mat).');
        return
    end
    field = ['SO' axis_kind '_mat'];
    V = agg.(field);            % Nfreq × Nbin × Nsubj
    nSubj = size(V, 3);
    ids = {};
    if isfield(agg, 'subjectIDs'), ids = cellstr(string(agg.subjectIDs(:))); end

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
        'Min', 1, 'Max', max(1, nSubj), ...
        'Value', 1, ...
        'Format', '%d', ...
        'HorizontalAlignment', 'center');
    ed.Layout.Column = 1;
    sl = uislider(sliderRow, 'Limits',[1 max(1,nSubj)], 'Value', 1, ...
        'MajorTicks', sparseSliderTicks(nSubj), ...
        'MinorTicks', []);
    sl.Layout.Column = 2;
    uilabel(sliderRow, 'Text', sprintf('of %d', nSubj), ...
        'HorizontalAlignment','right');

    renderPage(1);
    sl.ValueChangedFcn = @(s,~) jumpTo(round(s.Value));
    ed.ValueChangedFcn = @(s,~) jumpTo(round(s.Value));

    function jumpTo(k)
        k = max(1, min(nSubj, round(k)));
        if sl.Value ~= k, sl.Value = k; end
        if ed.Value ~= k, ed.Value = k; end
        renderPage(k);
    end

    function renderPage(k)
        k = max(1, min(nSubj, k));
        M = V(:,:,k);
        cla(ax);
        bins = []; freq_bins = [];
        if isfield(agg, ['SO' axis_kind '_bins']), bins = agg.(['SO' axis_kind '_bins'])(:); end
        if isfield(agg, 'freq_bins'), freq_bins = agg.freq_bins(:); end
        app.styleSOPHAxes(ax, M, freq_bins, bins, axis_kind);
        if k <= numel(ids)
            title(ax, sprintf('Subject %d/%d — %s', k, nSubj, ids{k}), ...
                'Interpreter','none');
        else
            title(ax, sprintf('Subject %d/%d', k, nSubj));
        end
    end
end
