function leaf = find_first_leaf(tree)
leaf = [];
if isempty(tree.Children), return, end
n = tree.Children(1);
while ~isempty(n.Children)
    n = n.Children(1);
end
leaf = n;
end

