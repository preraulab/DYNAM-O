function renderResultsBrowserPreviewMatGeneric(app, p, info)
    % renderResultsBrowserPreviewMatGeneric  Generic .mat browser
    % used when no smart-case applies: a left-side variable tree
    % (one node per top-level variable, expandable into struct
    % fields and cell elements) paired with a right-side
    % type-aware viewer (uitable / imagesc / page slider /
    % uitextarea). Caches the loaded struct on the app so node
    % clicks don't re-load the file.
    import results_browser.*
    try
        S = load(p);
    catch ME
        app.renderResultsBrowserPreviewMessage( ...
            sprintf('load() failed:\n%s', ME.message));
        return
    end
    app.MatPreviewCache_.path = p;
    app.MatPreviewCache_.S    = S;

    g = uigridlayout(app.ResultsBrowserPreviewBody);
    g.ColumnWidth  = {220, '1x'};
    g.RowHeight    = {'1x'};
    g.ColumnSpacing = 4; g.RowSpacing = 0;
    g.Padding = [4 4 4 4];

    tree = uitree(g);
    tree.Layout.Row = 1; tree.Layout.Column = 1;

    rightPanel = uipanel(g, 'BorderType','none', 'BackgroundColor','white');
    rightPanel.Layout.Row = 1; rightPanel.Layout.Column = 2;

    for ii = 1:numel(info)
        nm = info(ii).name;
        build_var_node(tree, nm, S.(nm), nm);
    end
    tree.SelectionChangedFcn = @(t,e) onSelect(e);
    % Auto-render the first leaf so the right pane isn't empty.
    firstLeaf = find_first_leaf(tree);
    if ~isempty(firstLeaf)
        tree.SelectedNodes = firstLeaf;
        renderNode(firstLeaf);
    end

    function onSelect(e)
        if isempty(e.SelectedNodes), return, end
        renderNode(e.SelectedNodes(1));
    end

    function renderNode(node)
        if isempty(node) || isempty(node.NodeData), return, end
        % NodeData carries the dotted path (e.g. 'SOPHs.SOpower_mat')
        val = resolve_path(S, node.NodeData);
        delete(rightPanel.Children);
        app.renderMatNodeValue(rightPanel, val, node.NodeData);
    end
end
