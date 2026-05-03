function out = cache_to_tree_node(node)
%CACHE_TO_TREE_NODE  Convert the recursive walk_to_cache struct into the
%nested struct/cell format CSSuiTree.Data expects. Returns a 1-element
%cell containing the root node so CSSuiTree can render it as a single
%top-level entry. Each node also gets a 'menu' field describing the
%right-click actions available on it (see node_menu_items). The root
%node's menu is overridden here so it carries 'Aggregate All'.
    import results_browser.*
s = build_tree_node(node, 'root');
s.menu = node_menu_items('root', node.path);
out = {s};
end

