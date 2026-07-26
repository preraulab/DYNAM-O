function items = node_menu_items(kind, ~)
%NODE_MENU_ITEMS  Right-click menu definition for a tree node based on
%its classification. 'open' covers files, folders, and dirs uniformly
%(handler resolves file vs folder at click time).
openFile   = struct('action','open','label','Open file');
openFolder = struct('action','open','label','Open folder');
sep        = struct('sep', true);

switch kind
    case 'file'
        items = {openFile};
    case 'root'
        items = {openFolder, sep, ...
                 struct('action','aggregate-all',         'label','Aggregate All'), ...
                 struct('action','regenerate-run-index',  'label','Regenerate run index')};
    case 'channel'
        items = {openFolder, sep, ...
                 struct('action','aggregate-channel', 'label','Aggregate channel'), ...
                 struct('action','aggregate-paramfit','label','Aggregate paramfits'), ...
                 struct('action','aggregate-sophs',   'label','Aggregate SOPHs')};
    case 'param_basis'
        items = {openFolder, sep, ...
                 struct('action','aggregate-paramfit','label','Aggregate paramfits (this channel)')};
    case 'SOPHs'
        items = {openFolder, sep, ...
                 struct('action','aggregate-sophs',   'label','Aggregate SOPHs (this channel)')};
    otherwise
        items = {openFolder};
end
end

