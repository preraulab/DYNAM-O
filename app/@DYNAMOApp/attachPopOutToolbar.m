function attachPopOutToolbar(app, ax, popFcn, ttl)
    % attachPopOutToolbar  Add a 'Pop out to figure' button to
    % the axes toolbar. popFcn is @(newAx) -> draws into newAx.
    % ttl is used as the figure name and axes title (optional).
    % The toolbar appears on hover at the top-right of the axes;
    % right-click on uiaxes covered by imagesc swallows events,
    % so this is the dependable hook.
    try
        tb  = axtoolbar(ax, 'default');
        btn = axtoolbarbtn(tb, 'push', ...
            'Icon', 'export', ...
            'Tooltip', 'Pop out to figure');
        btn.ButtonPushedFcn = @(~,~) app.openAxesInFigure(popFcn, ttl);
    catch
        % axtoolbar can fail on some legacy graphics contexts;
        % silently skip the button rather than blocking the plot.
    end
end
