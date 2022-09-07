function [rate_true, rate_recon, metric_times, metric, SOpow_inds, KS_SOpow, LL_SOpow, RMSE_SOpow, ...
    EMD_SOpow, var_stat] = ...
    SOpow_hist_rate_recon(SOpow, SOpow_times, SOpow_hist, SOpow_bins, SOpow_freqs, ...
    peak_freqs, peak_times, time_window, fwindow_size, plot_on)
%SOPOW_HIST_RATE_RECON Reconstructs TF-peak rate from SO-power histogram and SO-power
%
% [rate_true, rate_recon, rate_times, rate_SOpow] = SOpow_hist_rate_recon(SOpow, SOpow_times, SOpow_hist, SOpow_bins, SOpow_freqs,
%                                                                         peak_times, peak_freqs, time_window, fwindow_size, plot_on)
%
% Inputs:
%     SOpow: 1xT vector - slow oscillation power --required
%     SOpow_times: 1xT vector - slow oscillation power times --required
%     SOpow_hist: SO-power histogram --required
%     SOpow_hist_TIBs: time in bin for each SOpower bin (minutes) --required
%     SOpow_bins: SO-power histogram power bins --required
%     SOpow_freqs: SO-power histogram frequency bins --required
%     peak_times: times of raw TF-peaks --required
%     peak_freqs: frequencies of raw TF-peaks --required
%     time_window: temporal window for rate for reconstruction  --required
%     fwindow_size: frequency window for reconstruction (should match SOPhist freq bin width) --required
%     plot_on: logical - show plot (default: true)
%
% Outputs:
%     rate_true: matrix for observed TF-peak rate over time
%     rate_recon: matrix for reconstructed TF-peak rate over time
%     rate_times: times for rates (frequencies are SOpow_freqs)
%     rate_SOpow: SO-power used in the reconstruction
%
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Authors: Michael Prerau
%
%   Last modified 03/10/2022
%********************************************************************

%% Deal with Inputs
if nargin == 0
    gen_powsummary;
    return;
end

assert(nargin >= 9, '9 inputs required: SOpow, SOpow_times, SOpow_hist, SOpow_bins, SOpow_freqs, peak_times, peak_freqs, time_window, fwindow_size')

if nargin < 10 || isempty(plot_on)
    plot_on = true;
end

%% Get time windows for computing the sliding rate
[tbin_edges, metric_times] = create_bins(SOpow_times([1 end]), time_window(1), time_window(2), 'full_extend');

%% Get time in bin in minutes
bin_time = time_window(1)/60;

%% Freq windows should match the SO-pow hist windows
fbin_edges(1,:) = SOpow_freqs(:) - (fwindow_size/2);
fbin_edges(2,:) = SOpow_freqs(:) + (fwindow_size/2);

%% Get CDFs for each SOPH column
SOPH_colnorm = SOpow_hist ./ repmat(sum(SOpow_hist, 1), length(SOpow_freqs), 1); % normalize each column to sum to 1
SOPH_cdfs = cumsum(SOPH_colnorm, 1, 'omitnan');

%% Prealocate rate matrices
T = length(metric_times);
F = length(SOpow_freqs);
count_true = zeros(F,T);
rate_recon = zeros(F,T);

%% Preallocate KS and Likelihood statistics
KS_SOpow = nan(T,1);
LL_SOpow = nan(T,1);
RMSE_SOpow = nan(T,1);
EMD_SOpow = nan(T,1);
num_KS_dups = 0;
num_LL_dups = 0;

%% Calculate the true rate over time
for tt = 1:T
    %Grab the peaks within the temporal bin
    t_inds = peak_times>tbin_edges(1,tt) & peak_times<=tbin_edges(2,tt);
    f_inds_bounds = (peak_freqs >=(fbin_edges(1,1))) & (peak_freqs<=fbin_edges(2,end));

    %Get the frequencies of those peaks
    tfpeak_freqs = peak_freqs(t_inds & f_inds_bounds);

    %Loop over the frequency bins
    for ff = 1:F
        %Grab the peaks in the frequency bin
        f_inds = tfpeak_freqs>fbin_edges(1,ff) & tfpeak_freqs<=fbin_edges(2,ff);

        %Compute the rate
        count_true(ff,tt) = sum(f_inds);
    end
    
    % Compute normalized true counts
    count_true_norm = count_true ./ repmat(sum(count_true,1), [length(size(count_true,2)), 1]);

    if isempty(tfpeak_freqs)
        % No tfpeaks in this time window means leave LL and KS as nan
        continue 
    else
        %% Calculate KS statistic and RMSE
        % Get ECDF of true counts in this temporal window across frequencies
        [twindow_ecdf, ecdf_freqs] = ecdf(SOpow_freqs', 'Frequency', count_true(:,tt));
        twindow_ecdf = twindow_ecdf(2:end); % cut out first point because it repeats 1st freq twice
        ecdf_freqs = ecdf_freqs(2:end);
        
        RMSE_all = nan(length(SOpow_bins), 1);
        KS_stats_all = nan(length(SOpow_bins),1);
        EMD_all = nan(length(SOpow_bins),1);
        confmat = nan(F);
        twindow_ecdf_interp = interp1(ecdf_freqs, twindow_ecdf , SOpow_freqs, 'previous');
        for ss = 1:length(SOpow_bins) % for each SO power bin
            KS_stats_all(ss) = max(abs(SOPH_cdfs(:,ss) - twindow_ecdf_interp'));
            RMSE_all(ss) = sum(sqrt((SOPH_colnorm(:,ss) - count_true_norm(:,tt)).^2));
            EMD_all(ss) = sum(abs(cumsum(SOPH_colnorm(:,ss) - count_true_norm(:,tt))));
        end
        [~, RMSE_min_ind] = min(RMSE_all);
        [~, KS_min_ind] = min(KS_stats_all); 
        [~, EMD_min_ind] = min(EMD_all); 
        if sum(KS_stats_all==KS_stats_all(KS_min_ind)) > 1
            warning([num2str(sum(KS_stats_all==KS_stats_all(KS_min_ind))), ...
                ' SOpower bins have the minimum KS statistic. SOpower bins are: ', ...
                num2str(SOpow_bins(KS_stats_all==KS_stats_all(KS_min_ind))), ...
                '. First bin will be used.']);
            num_KS_dups = num_KS_dups + 1;
        end
        KS_SOpow(tt) = SOpow_bins(KS_min_ind);
        RMSE_SOpow(tt) = SOpow_bins(RMSE_min_ind);
        EMD_SOpow(tt) = SOpow_bins(EMD_min_ind);

        %% Calculate Log Likelihood Statistic
        prob_per_peak = nan(length(tfpeak_freqs), length(SOpow_bins));
        for tfp = 1:length(tfpeak_freqs)

            % Find freq bin closest to tfpeak freq
            [~, freq_ind] = min(abs(SOpow_freqs - tfpeak_freqs(tfp)));

            % Get probability of that freq occurring in each SOPH slice
            for ss = 1:length(SOpow_bins)
                prob = SOPH_colnorm(freq_ind, ss);
                if isnan(prob) % if nan, this whole column didn't have any TIB, so ignore it by setting prob to 0
                    prob_per_peak(tfp, ss) = 0;
                else
                    prob_per_peak(tfp, ss) = SOPH_colnorm(freq_ind, ss);
                end
            end
        end

        LL_per_SOpow_bin = sum(log(prob_per_peak), 1, 'omitnan');
        [~, LL_max_bin_ind] = max(LL_per_SOpow_bin);
        if sum(LL_per_SOpow_bin==LL_per_SOpow_bin(LL_max_bin_ind)) > 1
            warning([num2str(sum(LL_per_SOpow_bin==LL_per_SOpow_bin(LL_max_bin_ind))), ...
                ' SOpower bins have the maximum LL. SOpower bins are: ', ...
                num2str(SOpow_bins(LL_per_SOpow_bin==LL_per_SOpow_bin(LL_max_bin_ind))), ...
                '. First bin will be used.'])
            num_LL_dups = num_LL_dups + 1;
        end
        %assert(sum(LL_per_SOpow_bin==LL_per_SOpow_bin(LL_max_bin_ind)) == 1, 'More than one SOpower bin has the maximum log likelihood');
        LL_SOpow(tt) = SOpow_bins(LL_max_bin_ind);
    end
end
disp(['Num LL dups: ', num2str(num_LL_dups)]);
disp(['Num KS dups: ', num2str(num_KS_dups)]);

% Divide counts by bin times to get rates
rate_true = count_true ./ bin_time;

%% Interpolate SOpow timeseries to ensure no NaN gaps
%SOpow([1 end]) = 0;
%SOpowint = interp1(SOpow_times(~isnan(SOpow)), SOpow(~isnan(SOpow)), SOpow_times, 'linear');
%SOpowint = max(min(SOpowint,1),0);

%% Create rate reconstruction
metric = zeros(1,T);
SOpow_inds = nan(1,T);

for tt = 1:T
    %Find the average SOpow in the temporal bin
    t_inds = SOpow_times>tbin_edges(1,tt) & SOpow_times<=tbin_edges(2,tt);
    metric(tt) = mean(SOpow(t_inds), 'omitnan');

    %Find the closest SOpow bin to the observed SOpow
    [~, SOpow_inds(tt)] = min(abs(metric(tt)-SOpow_bins));

    %Add the corresponding SOpow histogram column to the list
    rate_recon(:,tt) = SOpow_hist(:,SOpow_inds(tt));
end

% wherever metric is nan, make recon and inds nan
SOpow_inds(isnan(metric)) = nan;
rate_recon(:,isnan(metric)) = nan;

%% Calculate Variability and KS Statistics Over Sleep Depth Metric
% Set up vars for loop
num_SOpow_bins = length(SOpow_bins);
var_stat = nan(num_SOpow_bins,1);

for mm = 1:num_SOpow_bins % loop over SOPH bin

    % Get all rate slices that fall in this SOPH bin
    concat_rate_slices = rate_true(:,SOpow_inds==mm);

    % Sum the SDs of each row of concatenated rates
    var_stat(mm) = sum(std(concat_rate_slices,0,2));

end



%% Plotting
if plot_on

    % Create figure
    fh = figure('PaperOrientation','landscape','Color',[1 1 1]);

    % Create axes
    ax(4) = axes('Parent',fh,'Position',[0.1 0.0348 0.8 0.0658]);
    ax(3) = axes('Parent',fh,'Position',[0.1 0.1258 0.8 0.1417]);
    ax(2) = axes('Parent',fh,'Position',[0.1 0.2986 0.8 0.1417]);
    ax(1) = axes('Parent',fh,'Position',[0.25 0.5184 0.5 0.45]);

    linkaxes(ax(2:end),'x');
    linkaxes(ax(2:3),'y');

    %fh.Position = [0.5139    1.2778   16.8194   12.2361];

    axes(ax(1))
    imagesc(SOpow_bins*100,SOpow_freqs,SOpow_hist);
    xlabel('% SO-power')
    ylabel('Frequency (Hz)')
    axis xy;
    climscale(false);
    cx = caxis;
    title('SO Power Histogram')
    colorbar_noresize;

    axes(ax(2))
    imagesc(metric_times, SOpow_freqs, rate_true);
    axis xy;
    climscale;
    colorbar_noresize;
    caxis(cx);
    title("Observed Data")
    scaleline(3600, '1 hour')
    ylabel('Freq (Hz)')

    axes(ax(3))
    imagesc(metric_times, SOpow_freqs, rate_recon);
    axis xy;
    caxis(cx);
    colorbar_noresize;
    title("Reconstruction from SO-power and SO-power Histogram")
    scaleline(3600, '1 hour')
    ylabel('Freq (Hz)')

    axes(ax(4))
    hold on
    plot(metric_times, metric*100,'linewidth',2)
    axis tight
    ylabel('%SO-pow')
    scaleline(3600, '1 hour');
    title("Slow Oscillation Power Time Trace")
    xlabel('Time (s)');

    set(ax,'fontsize',14)
end