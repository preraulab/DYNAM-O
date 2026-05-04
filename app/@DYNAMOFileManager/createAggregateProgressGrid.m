function createAggregateProgressGrid(app, channelNames)
    % createAggregateProgressGrid  Replace the preview body with
    %   one SmoothProgressBar per channel, stacked vertically,
    %   each titled with the channel name. Each bar is reused
    %   across that channel's stages; aggProgressTick swaps
    %   the bar's `N` and `LabelPrefix` whenever a new (cat,
    %   stage) starts. Bars are stored in
    %   app.AggregateProgressBars_ (containers.Map) so the
    %   per-file callback can find them by channel name.
    delete(app.ResultsBrowserPreviewBody.Children);
    app.PreviewProgressBar_     = [];
    app.AggregateProgressBars_  = [];
    if nargin < 2 || isempty(channelNames), return, end
    channelNames = cellstr(channelNames);
    n = numel(channelNames);

    % Each row = a label (channel + current stage) above a
    % progress bar. Fixed pixel heights; the outer grid is
    % marked Scrollable so big channel sets don't overflow.
    ROW_PX  = 56;     % label (18) + bar (~30) + gap
    outer = uigridlayout(app.ResultsBrowserPreviewBody, [n 1]);
    outer.RowHeight   = repmat({ROW_PX}, 1, n);
    outer.ColumnWidth = {'1x'};
    outer.RowSpacing  = 6;
    outer.Padding     = [16 16 16 16];
    outer.Scrollable  = 'on';

    bars = containers.Map('KeyType','char','ValueType','any');
    for ii = 1:n
        ch = channelNames{ii};
        row = uigridlayout(outer);
        row.Layout.Row    = ii;
        row.Layout.Column = 1;
        row.RowHeight     = {18, '1x'};
        row.ColumnWidth   = {'1x'};
        row.RowSpacing    = 2;
        row.Padding       = [0 0 0 0];

        pb = SmoothProgressBar(row, 1, ...
            'BarHeight',       0.5, ...
            'BarBorderRadius', '999px', ...
            'BorderRadius',    '999px', ...
            'TextPosition',    'above');
        pb.Layout.Row    = 2;
        pb.Layout.Column = 1;
        pb.LabelPrefix       = ch;
        pb.ShowPercentage    = true;
        pb.ShowTimeRemaining = false;
        pb.start();
        bars(ch) = pb;
    end
    app.AggregateProgressBars_ = bars;
end
