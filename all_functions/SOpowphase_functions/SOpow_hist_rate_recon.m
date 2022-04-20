function [rate_true, rate_recon, rate_times, rate_SOpow] = SOpow_hist_rate_recon(SOpow, SOpow_times, SOpow_hist, SOpow_bins, SOpow_freqs, peak_freqs, peak_times, time_window, fwindow_size, plot_on)
%SOPOW_HIST_RATE_RECON Reconstructs TF-peak rate from SO-power histogram and SO-power
%
% [rate_true, rate_recon, rate_times, rate_SOpow] = SOpow_hist_rate_recon(SOpow, SOpow_times, SOpow_hist, SOpow_bins, SOpow_freqs, 
%                                                                         peak_times, peak_freqs, time_window, fwindow_size, plot_on)
%
% Inputs:
%     SOpow: 1xT vector - slow oscillation power --required
%     SOpow_times: 1xT vector - slow oscillation power times --required
%     SOpow_hist: SO-power histogram --required
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
%   Copyright 2022 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
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
[tbin_edges, rate_times] = create_bins(SOpow_times([1 end]), time_window(1), time_window(2), 'full_extend');

%% Get time in bin in minutes
bin_time = time_window(1)/60;

%% Freq windows should match the SO-pow hist windows
fbin_edges(1,:) = SOpow_freqs(:) - (fwindow_size/2);
fbin_edges(2,:) = SOpow_freqs(:) + (fwindow_size/2);

%% Prealocate rate matrices
T = length(rate_times);
F = length(SOpow_freqs);
rate_true = zeros(F,T);
rate_recon = zeros(F,T);

%% Create the rate over time
for tt = 1:T
    %Grab the peaks within the temporal bin
    t_inds = peak_times>tbin_edges(1,tt) & peak_times<=tbin_edges(2,tt);

    %Get the frequencies of those peaks
    tfpeak_freqs = peak_freqs(t_inds);

    %Loop over the frequency bins
    for ff = 1:F
        %Grab the peaks in the frequency bin
        f_inds = tfpeak_freqs>fbin_edges(1,ff) & tfpeak_freqs<=fbin_edges(2,ff);

        %Compute the rate
        rate_true(ff,tt) = sum(f_inds)/bin_time;
    end
end

SOpow([1 end]) = 0;
SOpowint = interp1(SOpow_times(~isnan(SOpow)), SOpow(~isnan(SOpow)), SOpow_times,'linear');
SOpowint = max(min(SOpowint,1),0);

rate_SOpow = zeros(1,T);

for tt = 1:T
    %Find the average SOpow in the temporal bin
    t_inds = SOpow_times>tbin_edges(1,tt) & SOpow_times<=tbin_edges(2,tt);
    rate_SOpow(tt) = mean(SOpowint(t_inds));

    %Find the closest SOpow bin to the observed SOpow
    [~, idx] = min(abs(rate_SOpow(tt)-SOpow_bins));

    %Add the corresponding SOpow histogram column to the list
    rate_recon(:,tt) = SOpow_hist(:,idx);
end

%% Plotting
if plot_on
    fh = figure;
    ax = figdesign(12,4,'orient','landscape','merge',{[1:28],[29:36],[37:44],[45:48]},...
        'margins',[.09 .1 .05 .05 .07, .07],'numberaxes',true);
    ax(1).Position=[0.2500    0.5184    0.5000    0.4500];
    ax(2).Position=[0.1000    0.2986    0.8000    0.1417];
    ax(3).Position=[0.1000    0.1258    0.8000    0.1417];
    ax(4).Position=[0.1000    0.0348    0.8000    0.0658];

    linkaxes(ax(2:end),'x');
    linkaxes(ax(2:3),'y');

    fh.Position = [0.5139    1.2778   16.8194   12.2361];

    axes(ax(1))
    imagesc(SOpow_bins*100,SOpow_freqs,SOpow_hist);
    xlabel('% SO-power')
    ylabel('Frequency (Hz)')
    axis xy;
    climscale(false);
    cx = caxis;
    title('SO Power Histogram')
    colorbar_noresize

    axes(ax(2))
    imagesc(rate_times, SOpow_freqs, rate_true);
    axis xy;
    climscale
    colorbar_noresize
    caxis(cx);
    title("Observed Data")
    scaleline(3600, '1 hour')
    ylabel('Freq (Hz)')

    axes(ax(3))
    imagesc(rate_times, SOpow_freqs, rate_recon);
    axis xy;
    caxis(cx);
    colorbar_noresize
    title("Reconstruction from SO-power and SO-power Histogram")
    scaleline(3600, '1 hour')
    ylabel('Freq (Hz)')

    axes(ax(4))
    hold on
    plot(rate_times, rate_SOpow*100,'linewidth',2)
    axis tight
    ylabel('%SO-pow')
    scaleline(3600, '1 hour');
    title("Slow Oscillation Power Time Trace")
    xlabel('Time (s)');

    set(ax,'fontsize',14)
end