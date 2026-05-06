function [xLim, yLim] = computeScatterLims(app, channelNames, axisKind)
    % computeScatterLims  Return shared X/Y axis limits for all
    %   Mode Scatter axes of a given kind. Limits are dictated
    %   by the SOPH display whenever the dropdown column maps
    %   onto an SO axis or onto frequency:
    %     - X = SOpowerMean → range of SOpower_bins (across loaded SOPH .mats)
    %     - X = SOphaseMean → [-pi, pi]
    %     - Y = FreqMean / FreqStd → SOPH freq window (default [2 16])
    %   For all other columns we fall back to the data union
    %   across the selected channels (5% pad), so every axis
    %   shares the same scale even when no SOPH lock applies.
    xLim = [];
    yLim = [];
    [xDD, yDD] = app.modeScatterDropdowns(axisKind);
    xCol = char(xDD.Value);
    yCol = char(yDD.Value);

    % SOPH-locked X
    if strcmp(axisKind, 'phase') && strcmp(xCol, 'SOphaseMean')
        xLim = [-pi pi];
    elseif strcmp(axisKind, 'power') && strcmp(xCol, 'SOpowerMean')
        pr = app.getSOPHPowerBinRange();
        if ~isempty(pr), xLim = pr; end
    end

    % SOPH-locked Y for frequency-like columns
    if any(strcmp(yCol, {'FreqMean','FreqStd'}))
        fr = app.getSOPHFreqRange();
        if isempty(fr), fr = [2 16]; end
        yLim = fr;
    end

    % Data-driven fallback (union across channels)
    if isempty(xLim) || isempty(yLim)
        xs = []; ys = [];
        for ii = 1:numel(channelNames)
            T = app.loadParamfitAggregateForChannel(channelNames{ii}, axisKind);
            if isempty(T) || ~istable(T), continue, end
            vn = T.Properties.VariableNames;
            if isempty(xLim) && ismember(xCol, vn) && isnumeric(T.(xCol))
                xs = [xs; double(T.(xCol)(:))]; %#ok<AGROW>
            end
            if isempty(yLim) && ismember(yCol, vn) && isnumeric(T.(yCol))
                ys = [ys; double(T.(yCol)(:))]; %#ok<AGROW>
            end
        end
        xs = xs(isfinite(xs));
        ys = ys(isfinite(ys));
        if isempty(xLim) && ~isempty(xs) && min(xs) ~= max(xs)
            pad = 0.05 * (max(xs) - min(xs));
            xLim = [min(xs) - pad, max(xs) + pad];
        end
        if isempty(yLim) && ~isempty(ys) && min(ys) ~= max(ys)
            pad = 0.05 * (max(ys) - min(ys));
            yLim = [min(ys) - pad, max(ys) + pad];
        end
    end
end
