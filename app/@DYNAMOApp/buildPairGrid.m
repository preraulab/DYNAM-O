function pairs = buildPairGrid(~, panel, channelNames)
    % buildPairGrid  Replace `panel` children with one
    %   (axPower, axPhase) pair per channel, laid out in a
    %   roughly-landscape R×C grid of cells. Each cell hosts a
    %   centered title (channel name) above two side-by-side
    %   uiaxes: power on the left, phase on the right.
    %
    %   Implemented with nested uigridlayouts so the cells
    %   actually fill the panel as it resizes — uiaxes with
    %   normalized 'Position' inside a uipanel under a tab/
    %   grid stack reliably mis-renders to a tiny corner on
    %   the first paint.
    %
    %   Returns a 1×N cell array; pairs{ii} is a 1×2 axes
    %   array [axPower, axPhase] for channelNames{ii}.
    delete(panel.Children);
    pairs = {};
    n = numel(channelNames);
    if n == 0, return, end

    % Choose grid dims so a single plot fills the panel,
    % small counts go landscape (single row), and larger
    % counts pack into a roughly-square grid.
    if n <= 3
        cols = n;
        rows = 1;
    else
        cols = ceil(sqrt(n));
        rows = ceil(n / cols);
    end

    outer             = uigridlayout(panel, [rows, cols]);
    outer.RowHeight   = repmat({'1x'}, 1, rows);
    outer.ColumnWidth = repmat({'1x'}, 1, cols);
    outer.Padding     = [8 8 8 8];
    outer.RowSpacing  = 12;
    outer.ColumnSpacing = 12;

    pairs = cell(1, n);
    for ii = 1:n
        r = ceil(ii / cols);
        c = mod(ii - 1, cols) + 1;

        % Per-cell: title row on top, two axes side-by-side.
        cellGrid               = uigridlayout(outer, [2, 2]);
        cellGrid.Layout.Row    = r;
        cellGrid.Layout.Column = c;
        cellGrid.RowHeight     = {22, '1x'};
        cellGrid.ColumnWidth   = {'1x', '1x'};
        cellGrid.Padding       = [0 0 0 0];
        cellGrid.RowSpacing    = 2;
        cellGrid.ColumnSpacing = 6;
        cellGrid.BackgroundColor = [1 1 1];

        titleLbl = uilabel(cellGrid, ...
            'Text', channelNames{ii}, ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 13, 'FontWeight', 'bold', ...
            'Interpreter', 'none');
        titleLbl.Layout.Row    = 1;
        titleLbl.Layout.Column = [1 2];

        axP                = uiaxes(cellGrid, 'BackgroundColor','white');
        axP.Layout.Row     = 2;
        axP.Layout.Column  = 1;

        axPh               = uiaxes(cellGrid, 'BackgroundColor','white');
        axPh.Layout.Row    = 2;
        axPh.Layout.Column = 2;

        pairs{ii} = [axP, axPh];
    end
end
