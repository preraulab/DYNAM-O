function build_var_node(parent, label, val, dottedPath)
% Recursive uitree node builder. dottedPath is the indexing string used
% by resolve_path() to retrieve `val` from the cached top-level struct.
    import results_browser.*
nd = uitreenode(parent, 'Text', node_label(label, val), 'NodeData', dottedPath);
if isstruct(val) && isscalar(val)
    fn = fieldnames(val);
    for ii = 1:numel(fn)
        build_var_node(nd, fn{ii}, val.(fn{ii}), [dottedPath '.' fn{ii}]);
    end
elseif iscell(val) && numel(val) <= 50
    for ii = 1:numel(val)
        build_var_node(nd, sprintf('{%d}', ii), val{ii}, ...
            sprintf('%s{%d}', dottedPath, ii));
    end
end
end

