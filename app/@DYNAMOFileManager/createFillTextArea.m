function ta = createFillTextArea(~, parent)
    % uitextarea has no Units property — wrap it in a fill grid
    % so it stretches to the parent (uitab / uipanel / uifigure).
    g = uigridlayout(parent);
    g.RowHeight   = {'1x'};
    g.ColumnWidth = {'1x'};
    g.Padding     = [0 0 0 0];
    ta = uitextarea(g);
    ta.Editable = 'off';
end
