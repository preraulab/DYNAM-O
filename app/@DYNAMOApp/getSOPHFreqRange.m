function r = getSOPHFreqRange(app)
    % getSOPHFreqRange  Read freq_bins from one of the loaded
    %   SOPH .mat aggregates and return the SOPH display
    %   window — clamped to [2, 16] Hz the same way
    %   styleSOPHAxes does.
    r = [];
    if isempty(app.SOHist_ChannelInfo_), return, end
    for ii = 1:numel(app.SOHist_ChannelInfo_)
        info = app.SOHist_ChannelInfo_(ii);
        cands = {};
        if info.hasPower && endsWith(lower(info.powerPath), '.mat')
            cands{end+1} = info.powerPath; %#ok<AGROW>
        end
        if info.hasPhase && endsWith(lower(info.phasePath), '.mat')
            cands{end+1} = info.phasePath; %#ok<AGROW>
        end
        for jj = 1:numel(cands)
            try
                S = load(cands{jj});
                if     isfield(S, 'aggregate'), agg = S.aggregate;
                elseif isfield(S, 'SOPHs'),     agg = S.SOPHs;
                else,                            agg = S;
                end
                if isfield(agg, 'freq_bins') && ~isempty(agg.freq_bins)
                    f = double(agg.freq_bins(:));
                    f = f(isfinite(f));
                    if ~isempty(f)
                        r = [max(2, min(f)), min(16, max(f))];
                        if r(2) > r(1), return, end
                        r = [];
                    end
                end
            catch
                continue
            end
        end
    end
end
