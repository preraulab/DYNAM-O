function renderMatVolumePage(~, ax, sliderRow, val, label, k)
    % renderMatVolumePage  Draw the k-th page of a 3-D numeric
    % array into the given axes, clamping k to [1, nP] and
    % updating the page-counter label in `sliderRow`.
    nP = size(val, 3);
    k  = max(1, min(nP, k));
    cla(ax);
    imagesc(ax, double(val(:,:,k)));
    axis(ax,'xy'); colormap(ax,parula); colorbar(ax);
    title(ax, sprintf('%s page %d/%d', label, k, nP), ...
        'Interpreter','none');
    lblObj = findobj(sliderRow,'Tag','genPgLabel');
    if ~isempty(lblObj), lblObj.Text = sprintf('Page %d', k); end
end
