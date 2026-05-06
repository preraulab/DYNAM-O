function destroyAggregateProgressGrid(app)
    % destroyAggregateProgressGrid  Drop the per-channel bar
    %   map so the next single-channel right-click aggregation
    %   uses the single-bar path instead of trying to look up
    %   a non-existent entry.
    app.AggregateProgressBars_ = [];
end
