function styleSOPHAxes(app, ax, M, freq_bins, bins, axis_kind)
    % Render a single (nSObins × nFreq) SOPH slice into `ax` with
    % displaySummaryPlot styling: imagesc with bins on x and
    % freq_bins on y, locked aspect, kind-appropriate colormap,
    % freq window 2–16 Hz, robust [5, 98]-prctile colour limits,
    % and a colorbar with a kind-appropriate label.
    if isempty(bins),      bins      = (1:size(M, 1)).'; end
    if isempty(freq_bins), freq_bins = (1:size(M, 2)).'; end

    imagesc(ax, bins, freq_bins, M.');
    axis(ax,'xy');
    pbaspect(ax, app.SOPHPlotBoxAspectRatio_);
    switch axis_kind
        case 'power'
            try, colormap(ax, gouldian); catch, colormap(ax, parula); end
            xlabel(ax, 'SO-Power (dB)');
            colMask = any(M ~= 0 & isfinite(M), 2);
            if any(colMask) && numel(bins) == numel(colMask)
                xlim(ax, [bins(find(colMask,1,'first')), ...
                          bins(find(colMask,1,'last' ))]);
            end
        case 'phase'
            try, colormap(ax, magma);   catch, colormap(ax, hot);    end
            xlabel(ax, 'SO-Phase (rad)');
            xlim(ax, [-pi pi]);
            xticks(ax, [-pi -pi/2 0 pi/2 pi]);
            xticklabels(ax, {'-\pi','-\pi/2','0','\pi/2','\pi'});
    end
    ylabel(ax, 'Frequency (Hz)');

    freq_lim = [max(2, min(freq_bins)), min(16, max(freq_bins))];
    if freq_lim(2) > freq_lim(1)
        ylim(ax, freq_lim);
        tmp_idx = freq_bins >= freq_lim(1) & freq_bins <= freq_lim(2);
        tmp = M(:, tmp_idx);
        tmp = tmp(tmp ~= 0 & isfinite(tmp));
        if ~isempty(tmp)
            cp = prctile(tmp, [5, 98]);
            if isfinite(cp(1)) && isfinite(cp(2)) && cp(2) > cp(1)
                clim(ax, cp);
            end
        end
    end
    cb = colorbar(ax);
    switch axis_kind
        case 'power', cb.Label.String = 'Density (peaks/min/bin)';
        case 'phase', cb.Label.String = 'Proportion';
    end
end
