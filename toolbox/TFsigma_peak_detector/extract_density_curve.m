function [ max_curve, bin_centers, hist_olN2, hist_olN3 ] = extract_density_curve(sel_freqs, sel_stages, bin_width, bin_step, bin_range, N2_minutes, N3_minutes, ignore_N3_threshold, plot_on)
% Using the heuristic of max(stage2, stage3) to extract the cumulated
% histogram curves for mid-point frequency of TFpeaks

% set up bin starts and ends
hb = bin_width/2;
bin_centers = bin_range(1)+hb:bin_step:bin_range(2)-hb;
bin_starts = bin_centers - hb;
bin_ends = bin_centers + hb;

% stage 2 binned cumulative density
data = sel_freqs(sel_stages=='Stage2');
hist_ol = zeros(1, length(bin_centers));
for jj = 1:length(bin_centers)
    hist_ol(jj) = sum(data>bin_starts(jj) & data<=bin_ends(jj));
end
hist_olN2 = hist_ol / N2_minutes;

% stage 3 binned cumulative density
data = sel_freqs(sel_stages=='Stage3');
hist_ol = zeros(1, length(bin_centers));
if N3_minutes > ignore_N3_threshold % ignore stage 3 if duration of N3 is shorter than [ignore_N3_threshold] minutes
    for jj = 1:length(bin_centers)
        hist_ol(jj) = sum(data>bin_starts(jj) & data<=bin_ends(jj));
    end
end
hist_olN3 = hist_ol / N3_minutes;

if plot_on ~= 0
    if plot_on == 1
        figure
    else
        axes(plot_on)
    end
    hold on
    plot(bin_centers, hist_olN2, 'Linewidth', 2)
    plot(bin_centers, hist_olN3, 'Linewidth', 2)
    legend(['Stage2=', num2str(N2_minutes), 'min'], ['Stage3=', num2str(N3_minutes), 'min'], 'Location', 'best')
    xlabel('Frequency (Hz)')
    ylabel('Binned sum density (events / min)')
    title('Binned sum density')
    set(gca,'FontSize',16)
    xlim([min(bin_centers), max(bin_centers)])
    xticks([min(bin_centers):1:max(bin_centers)])
end

% extract the max out of the two curves
max_curve = max([hist_olN2; hist_olN3]);

end

