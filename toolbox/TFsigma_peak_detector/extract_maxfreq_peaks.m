function [ freq_TFpeaks, y, cutoffs ] = extract_maxfreq_peaks(max_curve, bin_centers, MinPeakProm, smoothing_samples, plot_on)
%Identify the peaks on max frequency distribution density curve

if nargin < 3
    MinPeakProm = 0.05;
    smoothing_samples = 100;
    plot_on = false;
elseif nargin < 4
    smoothing_samples = 100;
    plot_on = false;
elseif nargin < 5
    plot_on = false;
end

% calculate smooth duration to print in title 
bin_step = bin_centers(2)-bin_centers(1);
smooth_Hz = bin_step*smoothing_samples;

% smooth max frequency density curve
if smoothing_samples > 0
    y = smooth(max_curve, smoothing_samples,'sgolay',3); % polynomial of degree of 3
else
    y = max_curve;
end

if plot_on ~= 0
    if plot_on == 1
        figure
        [Ypk,Xpk,Wpk,Ppk,wxPk] = findpeaks_extents(y,bin_centers,'MinPeakProminence',MinPeakProm,'Annotate','extents');
    else
        axes(plot_on)
        [Ypk,Xpk,Wpk,Ppk,wxPk] = findpeaks_extents(y,bin_centers,'MinPeakProminence',MinPeakProm,'Annotate','extents');
    end
    xlabel('Frequency (Hz)')
    ylabel('Binned sum density (events / min)')
    xlim([min(bin_centers), max(bin_centers)])
    xticks([min(bin_centers):1:max(bin_centers)])
    legend('off')
    title(['Smooth=', num2str(smooth_Hz), ' Hz, MinPeakProm=', num2str(MinPeakProm)])
    set(gca, 'FontSize', 16)
else
    [Ypk,Xpk,Wpk,Ppk,wxPk] = findpeaks_extents(y,bin_centers,'MinPeakProminence',MinPeakProm);
end

% organize the peak parameters into a table 
freq_TFpeaks = table;
freq_TFpeaks.peak_freq = Xpk';
freq_TFpeaks.peak_lower_freq = wxPk(:,1);
freq_TFpeaks.peak_upper_freq = wxPk(:,2);
freq_TFpeaks.peak_prom = Ppk;
freq_TFpeaks.peak_height = Ypk;

% find the boundary points between peaks
[~, idx] = ismember(Xpk, bin_centers);
boundary_freqs = zeros(length(Xpk)-1,1);
for ii = 1:length(boundary_freqs)
    current_seg = bin_centers(idx(ii):idx(ii+1));
    [~,min_idx] = min(y(idx(ii):idx(ii+1)));
    boundary_freqs(ii) = current_seg(min_idx);
end

if plot_on ~= 0
    hold on
    ylimit = ylim;
    for ii = 1:length(boundary_freqs)
        plot([boundary_freqs(ii), boundary_freqs(ii)], ylimit + [0,5], '--', 'Color', [0.75,0.75,0.75], 'LineWidth', 1)
    end
end

% If no peaks found, return empty table
if size(freq_TFpeaks,1) == 0
    freq_TFpeaks.boundary_from_lastpeak = double.empty(0,1);
    cutoffs = [nan, nan];
    return
end

boundary_freqs = [NaN;boundary_freqs];
freq_TFpeaks.boundary_from_lastpeak = boundary_freqs;

%% Construct the fast, slow, alpha cutoff frequencies with an algorithm

%STEP1: find the indices for peaks in each of the frequency divisions 
% ultra_14_idx = find(Xpk>=14);
fast_12_14 = find(Xpk>=12); %(Xpk>=12 & Xpk<14);
slow_10_12 = find(Xpk>=10 & Xpk<12);
alpha_8_10 = find(Xpk>=8 & Xpk<10);

%STEP2: find the most prominent peak in each of the frequency divisions 
% [~,max_idx] = max(Ppk(ultra_14_idx));
% ultra_14_max_idx = ultra_14_idx(max_idx);

[~,max_idx] = max(Ppk(fast_12_14));
fast_12_14_max_idx = fast_12_14(max_idx);

[~,max_idx] = max(Ppk(slow_10_12));
slow_10_12_max_idx = slow_10_12(max_idx);

[~,max_idx] = max(Ppk(alpha_8_10));
alpha_8_10_max_idx = alpha_8_10(max_idx);

%STEP3: iterate down the categories to define cutoffs 
% ----- ultra-fast vs. fast cutoff -----
% if ~isempty(ultra_14_max_idx)
%     extended_lowbound = wxPk(ultra_14_max_idx,1)-(wxPk(ultra_14_max_idx,2)-wxPk(ultra_14_max_idx,1))/2;
%     trough_lowbound = boundary_freqs(ultra_14_max_idx);
%     ultra_cutoff = max(trough_lowbound, extended_lowbound);
% elseif ~isempty(fast_12_14_max_idx)
%     extended_highbound = wxPk(fast_12_14_max_idx,2)+(wxPk(fast_12_14_max_idx,2)-wxPk(fast_12_14_max_idx,1))/2; 
%     ultra_cutoff = extended_highbound;
% else
%     ultra_cutoff = 14; % default cutoff 
% end

% ----- fast vs. slow cutoff -----
if ~isempty(fast_12_14_max_idx)
    extended_lowbound = wxPk(fast_12_14_max_idx,1)-(wxPk(fast_12_14_max_idx,2)-wxPk(fast_12_14_max_idx,1))/2;
    trough_lowbound = boundary_freqs(fast_12_14_max_idx);
    fast_cutoff = max(trough_lowbound, extended_lowbound);
    % need to check if there exist multiple peaks 
    if ~isnan(boundary_freqs(fast_12_14(1)))
        trough_lowbound_all = boundary_freqs(fast_12_14(1));
        if trough_lowbound_all > 12 && trough_lowbound_all > fast_cutoff
            fast_cutoff = trough_lowbound_all;
        end
    end
elseif ~isempty(slow_10_12_max_idx)
    extended_highbound = wxPk(slow_10_12_max_idx,2)+(wxPk(slow_10_12_max_idx,2)-wxPk(slow_10_12_max_idx,1))/2;
    fast_cutoff = extended_highbound;
else
    fast_cutoff = 12; % default cutoff
end

% ----- slow vs. alpha cutoff -----
if ~isempty(slow_10_12_max_idx)
    extended_lowbound = wxPk(slow_10_12_max_idx,1)-(wxPk(slow_10_12_max_idx,2)-wxPk(slow_10_12_max_idx,1))/2;
    trough_lowbound = boundary_freqs(slow_10_12_max_idx);
    slow_cutoff = max(trough_lowbound, extended_lowbound);
    % need to check if there exist multiple peaks 
    if ~isnan(boundary_freqs(slow_10_12(1)))
        trough_lowbound_all = boundary_freqs(slow_10_12(1));
        if trough_lowbound_all > 10 && trough_lowbound_all > slow_cutoff
            slow_cutoff = trough_lowbound_all;
        end
    end
elseif ~isempty(alpha_8_10_max_idx)
    extended_highbound = wxPk(alpha_8_10_max_idx,2)+(wxPk(alpha_8_10_max_idx,2)-wxPk(alpha_8_10_max_idx,1))/2;
    slow_cutoff = extended_highbound;
else
    slow_cutoff = 10; % default cutoff
end

% Visualize the two cutoff frequencies 
if plot_on ~= 0
    hold on
    ylimit = ylim;
%     plot([ultra_cutoff, ultra_cutoff], ylimit + [0,5], 'm--', 'LineWidth', 1)
    plot([fast_cutoff, fast_cutoff], ylimit + [0,5], 'm--', 'LineWidth', 1)
    plot([slow_cutoff, slow_cutoff], ylimit + [0,5], 'm--', 'LineWidth', 1)
end

cutoffs = [slow_cutoff, fast_cutoff]; % ultra_cutoff

end

