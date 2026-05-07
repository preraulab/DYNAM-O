function s = build_tree_node(node, kind)
%BUILD_TREE_NODE  Recursive cache-struct → JS-node converter that
%classifies nodes (root | channel | category | dir | aggregates) so
%child nodes inherit the right context for menu generation.
    import results_browser.*
isChannel = is_channel_dir(node);
if isChannel
    myKind = 'channel';
elseif strcmp(kind, 'channel') && (strcmp(node.name,'param_basis') || strcmp(node.name,'SOPHs'))
    myKind = node.name;     % 'param_basis' or 'SOPHs' inside a channel
elseif strcmp(node.name,'aggregates') && strcmp(kind,'root')
    myKind = 'aggregates';
else
    myKind = 'dir';
end

kids = cell(1, numel(node.dirs) + numel(node.files));
k    = 0;
for ii = 1:numel(node.dirs)
    k = k + 1;
    kids{k} = build_tree_node(node.dirs{ii}, myKind);
end
for ii = 1:numel(node.files)
    k = k + 1;
    kids{k} = struct('text', node.files(ii).name, ...
                     'data', node.files(ii).path, ...
                     'isLeaf', true, ...
                     'children', {{}}, ...
                     'menu',  {node_menu_items('file', node.files(ii).path)});
end
s = struct('text', node.name, ...
           'data', node.path, ...
           'isLeaf', isempty(kids), ...
           'children', {kids}, ...
           'menu', {node_menu_items(myKind, node.path)});
end

