function plotAggregateSOHist(app, ax, filePath, axis_kind)
    % plotAggregateSOHist  Read aggregate, mean across subjects,
    % render with displaySummaryPlot styling.
    import results_browser.*
    field     = ['SO' axis_kind '_mat'];
    binsField = ['SO' axis_kind '_bins'];

    freq_bins = []; bins = []; M = [];
    try
        [~, ~, ext] = fileparts(filePath);
        switch lower(ext)
            case '.mat'
                S = load(filePath);
                if     isfield(S, 'aggregate'), agg = S.aggregate;
                elseif isfield(S, 'SOPHs'),     agg = S.SOPHs;
                else,                           agg = S;
                end
                if isfield(agg, field) && ~isempty(agg.(field))
                    M = mean(agg.(field), 3, 'omitnan');
                end
                if isfield(agg, 'freq_bins'), freq_bins = agg.freq_bins(:); end
                if isfield(agg, binsField),   bins      = agg.(binsField)(:); end
            case '.tiff'
                info = imfinfo(filePath);
                accum = double(imread(filePath, 1));
                for pp = 2:numel(info)
                    accum = accum + double(imread(filePath, pp));
                end
                M = accum / numel(info);
                % First try the TIFF's own ImageDescription tag;
                % aggregates and per-subject TIFFs written by
                % current DYNAMO carry bins there as JSON.
                if isfield(info,'ImageDescription') && ~isempty(info(1).ImageDescription)
                    try
                        meta = jsondecode(info(1).ImageDescription);
                        if isfield(meta,'freq_bins'), freq_bins = meta.freq_bins(:); end
                        bf = ['SO' axis_kind '_bins'];
                        if isfield(meta, bf), bins = meta.(bf)(:); end
                    catch
                        % Tag present but unparseable — fall through.
                    end
                end
                % Sidecar *_bins.csv covers older aggregates.
                if isempty(freq_bins) || isempty(bins)
                    [d, n, ~] = fileparts(filePath);
                    binsCsv = fullfile(d, [n '_bins.csv']);
                    if isfile(binsCsv)
                        try
                            B = readtable(binsCsv);
                            if isempty(freq_bins) && any(strcmp(B.Properties.VariableNames,'freq'))
                                fb = B.freq(~isnan(B.freq)); freq_bins = fb(:);
                            end
                            axisCol = ['SO' axis_kind];
                            if isempty(bins) && any(strcmp(B.Properties.VariableNames, axisCol))
                                sb = B.(axisCol)(~isnan(B.(axisCol))); bins = sb(:);
                            end
                        catch
                            % Bins CSV unreadable; fall back to pixel indices.
                        end
                    end
                end
                % Per-subject TIFFs (and aggregates without
                % bins.csv) fall back to a run_settings dump
                % found by walking up to ancestor folders. Only
                % freq_bins and SOphase_bins are recoverable
                % this way (SOpower bins are adaptive).
                if isempty(freq_bins) || (isempty(bins) && strcmp(axis_kind,'phase'))
                    [fb2, sb2] = recover_soph_bins_from_run_settings(filePath, axis_kind);
                    if isempty(freq_bins) && ~isempty(fb2), freq_bins = fb2; end
                    if isempty(bins)      && ~isempty(sb2), bins      = sb2; end
                end
        end
    catch ME
        axis(ax,'off');
        text(ax, 0.5, 0.5, sprintf('load failed: %s', ME.message), ...
             'HorizontalAlignment','center','Color','red');
        return
    end

    if isempty(M)
        axis(ax,'off');
        text(ax, 0.5, 0.5, '(empty aggregate)', 'HorizontalAlignment','center');
        return
    end

    app.styleSOPHAxes(ax, M, freq_bins, bins, axis_kind);
end
