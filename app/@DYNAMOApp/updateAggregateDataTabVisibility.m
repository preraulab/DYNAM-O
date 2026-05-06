function updateAggregateDataTabVisibility(app, forceRefresh)
    % updateAggregateDataTabVisibility  Show or hide the outer
    %   "Aggregate Data" tab and its inner "Mode Scatter" tab,
    %   based on what data is available under the current
    %   results root, and refresh the views accordingly.
    %
    %   Visibility rules:
    %     - Outer tab attached IFF <root>/aggregates/ exists.
    %     - Inner Mode Scatter tab attached IFF any channel
    %       under <root>/aggregates/<chan>/param_basis/ has
    %       a paramfit aggregate .mat (power or phase).
    %
    %   forceRefresh (default false): when true, repopulate
    %   the channel listbox, clear the paramfit cache, and
    %   redraw immediately. Aggregate-call sites pass true.
    %   Hidden→visible transitions also force a refresh so
    %   the user lands on a populated UI.
    if nargin < 2, forceRefresh = false; end

    root = strtrim(char(app.ResultsBrowserOutputDirField.Value));
    hasAgg = ~isempty(root) && isfolder(root) ...
          && isfolder(fullfile(root, 'aggregates'));

    attached = ~isempty(app.AnalysisTab.Parent);
    if hasAgg
        justAttached = ~attached;
        if justAttached
            app.AnalysisTab.Parent = app.ProjectTabGroup;
        end

        doRefresh = forceRefresh || justAttached;
        if doRefresh
            % Clear the paramfit table cache so a re-run of
            % the aggregator (which may have changed file
            % contents on disk) is observed on the next
            % redraw.
            if isa(app.ModeScatter_TableCache_, 'containers.Map')
                remove(app.ModeScatter_TableCache_, ...
                       app.ModeScatter_TableCache_.keys);
            else
                app.ModeScatter_TableCache_ = containers.Map( ...
                    'KeyType','char','ValueType','any');
            end
            % Reset the dropdown-init flags so a fresh load
            % re-applies the axis-specific defaults instead
            % of preserving stale '(none)' picks from the
            % previous tree.
            app.ModeScatter_DropdownsInited_ = struct( ...
                'power', false, 'phase', false);
            app.refreshSOHistogramsAvailability();
        end

        % Gate the single Mode Scatter inner tab on the
        % presence of *either* axis aggregate. The tab hosts
        % paired (power, phase) scatters per channel, with two
        % independent dropdown groups; missing axes fall back
        % to per-cell text overlays.
        hasPow = app.hasModeParamData('power');
        hasPha = app.hasModeParamData('phase');
        hasAny = hasPow || hasPha;
        tabH   = app.ModeScatterTab;
        is_attached = ~isempty(tabH.Parent);
        if hasAny && ~is_attached
            tabH.Parent = app.AggregateViewsTabGroup;
        elseif ~hasAny && is_attached
            tabH.Parent = [];
        end
        if hasAny && doRefresh
            app.refreshModeScatterDropdowns('power');
            app.refreshModeScatterDropdowns('phase');
            app.redrawModeScatter();
        end
    else
        if attached
            app.AnalysisTab.Parent = [];
        end
    end
end
