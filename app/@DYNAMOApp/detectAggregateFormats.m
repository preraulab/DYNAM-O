function present = detectAggregateFormats(app, root, channels, filesByChannel)
    % detectAggregateFormats  Scan the discovered file inventory and
    % return which of the four aggregable file formats are present.
    %
    %   present = struct with logical fields:
    %       .paramfit_csv   - any *.csv  under param_basis/
    %       .paramfit_mat   - any *.mat  under param_basis/
    %       .sophs_mat      - any *.mat  under SOPHs/
    %       .sophs_tiff     - any *.tiff under SOPHs/
    %
    %   When `filesByChannel` is non-empty, detection uses that index
    %   (zero filesystem cost). Otherwise we do a one-shot dir() per
    %   channel — the no-index code path in aggregateResultsRoot.

    present = struct('paramfit_csv', false, 'paramfit_mat', false, ...
                     'sophs_mat',    false, 'sophs_tiff',   false);

    if ~isempty(filesByChannel) && filesByChannel.Count > 0
        keys = filesByChannel.keys;
        for ki = 1:numel(keys)
            paths = filesByChannel(keys{ki});
            if ischar(paths), paths = {paths}; end
            for pi = 1:numel(paths)
                present = mark_path(present, paths{pi});
                if all_set(present), return, end
            end
        end
        return
    end

    % dir() fallback. Walk each channel root for the four patterns.
    for ci = 1:numel(channels)
        if iscell(channels), chDir = channels{ci}; else, chDir = channels(ci); end
        if ~isfolder(chDir)
            chDir = fullfile(root, chDir);
            if ~isfolder(chDir), continue, end
        end
        if ~present.paramfit_csv && has_any(fullfile(chDir, 'param_basis'), '*.csv')
            present.paramfit_csv = true;
        end
        if ~present.paramfit_mat && has_any(fullfile(chDir, 'param_basis'), '*.mat')
            present.paramfit_mat = true;
        end
        if ~present.sophs_mat && has_any(fullfile(chDir, 'SOPHs'), '*.mat')
            present.sophs_mat = true;
        end
        if ~present.sophs_tiff && has_any(fullfile(chDir, 'SOPHs'), '*.tiff')
            present.sophs_tiff = true;
        end
        if all_set(present), return, end
    end
end


function present = mark_path(present, p)
    if ~ischar(p) || isempty(p), return, end
    [folder, ~, ext] = fileparts(p);
    extLow = lower(ext);
    sep    = filesep;

    if contains(folder, [sep 'param_basis']) || endsWith(folder, [sep 'param_basis'])
        if strcmp(extLow, '.csv'), present.paramfit_csv = true; end
        if strcmp(extLow, '.mat'), present.paramfit_mat = true; end
    elseif contains(folder, [sep 'SOPHs']) || endsWith(folder, [sep 'SOPHs'])
        if strcmp(extLow, '.mat'),                       present.sophs_mat  = true; end
        if any(strcmp(extLow, {'.tif','.tiff'})),        present.sophs_tiff = true; end
    end
end


function tf = has_any(dirPath, pattern)
    if ~isfolder(dirPath), tf = false; return, end
    listing = dir(fullfile(dirPath, pattern));
    tf = ~isempty(listing);
end


function tf = all_set(present)
    tf = present.paramfit_csv && present.paramfit_mat && ...
         present.sophs_mat    && present.sophs_tiff;
end
