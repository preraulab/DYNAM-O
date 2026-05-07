function r = getSOPHPowerBinRange(app)
    % getSOPHPowerBinRange  Read SOpower_bins from one of the
    %   loaded power SOPH .mat aggregates, return [min, max].
    %   Returns [] when no .mat power aggregate is reachable.
    r = [];
    if isempty(app.SOHist_ChannelInfo_), return, end
    for ii = 1:numel(app.SOHist_ChannelInfo_)
        info = app.SOHist_ChannelInfo_(ii);
        if ~info.hasPower, continue, end
        if ~endsWith(lower(info.powerPath), '.mat'), continue, end
        try
            S = load(info.powerPath);
            if     isfield(S, 'aggregate'), agg = S.aggregate;
            elseif isfield(S, 'SOPHs'),     agg = S.SOPHs;
            else,                            agg = S;
            end
            if isfield(agg, 'SOpower_bins') && ~isempty(agg.SOpower_bins)
                b = double(agg.SOpower_bins(:));
                b = b(isfinite(b));
                if ~isempty(b)
                    r = [min(b), max(b)];
                    return
                end
            end
        catch
            continue
        end
    end
end
