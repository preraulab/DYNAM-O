function openResultsBrowserNode(app, evt)
    % openResultsBrowserNode  Open the double-clicked file leaf in
    % the OS default application via openInOS.
    if ~isfield(evt,'NodeData') || isempty(evt.NodeData), return; end
    p = evt.NodeData;
    if ~ischar(p) && ~(isstring(p) && isscalar(p)), return; end
    app.openInOS(char(p));
end
