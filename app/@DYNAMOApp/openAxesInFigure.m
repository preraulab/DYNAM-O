function openAxesInFigure(~, popFcn, ttl)
    % openAxesInFigure  Open a separate MATLAB figure and call
    % popFcn(ax) into it — used by axes pop-out toolbar buttons
    % so users can detach a plot for save/zoom/copy.
    if nargin < 3, ttl = ''; end
    f  = figure('Color','w', 'NumberTitle','off');
    if ~isempty(ttl), f.Name = ttl; end
    ax = axes(f);
    popFcn(ax);
    if ~isempty(ttl), title(ax, ttl, 'Interpreter','none'); end
end
