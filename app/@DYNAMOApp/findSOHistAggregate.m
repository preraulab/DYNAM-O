function [path, found] = findSOHistAggregate(~, root, channelName, axis_kind)
    % findSOHistAggregate  Locate the aggregate file we should plot
    % for one (channel, axis_kind) pair. Prefers .mat (carries bins)
    % over .tiff (faster but pixel-indexed).
    base = fullfile(root, 'aggregates', channelName, ['SOPHs_' axis_kind], ...
                    [channelName '_aggregate_SOPHs_' axis_kind]);
    if isfile([base '.mat'])
        path = [base '.mat']; found = true; return
    end
    if isfile([base '.tiff'])
        path = [base '.tiff']; found = true; return
    end
    path = ''; found = false;
end
