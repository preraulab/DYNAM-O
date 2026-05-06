function tickAggregateProgress(app, state, chan, catName, stage, ii, total)
    % tickAggregateProgress  Per-file progress callback used by the
    %   aggregator. Two display modes:
    %     1. Top-level Aggregate run: app.AggregateProgressBars_
    %        is a Map populated by createAggregateProgressGrid.
    %        Each channel gets its own pre-built bar; this
    %        callback updates that bar's N/LabelPrefix on stage
    %        transitions and ticks within a stage.
    %     2. Single-channel right-click: the Map is empty and
    %        we fall back to the legacy single-bar path
    %        (createResultsBrowserPreviewProgress / tick).
    key = sprintf('%s/%s', catName, stage);
    isStageStart = ~strcmp(state('lastKey'), key);
    if isStageStart
        app.appendResultsBrowserLog(sprintf( ...
            '  [%s] %s (%s): %d file(s)', chan, catName, stage, total));
        state('lastKey') = key;
        state('lastPct') = -1;
        prefix = sprintf('[%s] %s · %s', chan, catName, stage);

        if isa(app.AggregateProgressBars_, 'containers.Map') ...
                && isKey(app.AggregateProgressBars_, chan)
            pb = app.AggregateProgressBars_(chan);
            if ~isempty(pb) && isvalid(pb)
                try
                    pb.N           = max(1, total);
                    pb.LabelPrefix = prefix;
                    pb.start();
                catch
                    % bar may have been deleted; ignore
                end
            end
        else
            app.createResultsBrowserPreviewProgress(prefix, total);
        end
    end

    % Throttle to ~every 5% so the HTML re-render cost doesn't
    % dominate wall-clock on big stages. Always fire the final
    % tick (ii == total) so the bar reaches 100% / completes.
    pct = floor(100 * ii / max(1, total));
    if ii >= total || pct - state('lastPct') >= 5
        state('lastPct') = pct;
        if isa(app.AggregateProgressBars_, 'containers.Map') ...
                && isKey(app.AggregateProgressBars_, chan)
            pb = app.AggregateProgressBars_(chan);
            if ~isempty(pb) && isvalid(pb)
                try
                    pb.updateIteration(ii);
                catch
                    % bar may have been completed; ignore
                end
            end
        else
            app.tickResultsBrowserPreviewProgress(ii);
        end
    end
end
