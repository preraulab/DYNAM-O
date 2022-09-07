function plotBandSOPhasePolarHist(peak_sophases,peak_freqs,freq_rng,num_bins,pick_subset,max_radius)

if nargin < 6
    max_radius = []; 
end
if nargin < 5
    pick_subset = [];
end
if isempty(pick_subset)
    pick_subset = ones(size(peak_freqs));
end

if nargin<4
    num_bins = 50;
end

figure;
pick_peaks_plot = pick_subset & (peak_freqs >= freq_rng(1)) & (peak_freqs <= freq_rng(2));
% polarhistogram(peak_sophases(pick_peaks_plot),30); 
polarhistogram(peak_sophases(pick_peaks_plot),num_bins,'Normalization','pdf'); 
set(gca,'ThetaAxisUnits','radians')
if ~isempty(max_radius)
    set(gca,'RLim',[0 max_radius]);
end
set(gca,'thetatick',[0 pi/2 pi 3*pi/2],'thetaticklabel',{'0','\pi/2', '\pm\pi', '-\pi/2'})
title([num2str(freq_rng(1)) '-' num2str(freq_rng(2)) 'Hz']);
% zm = sum(exp(1i*peak_sophases(pick_peaks_plot)));
theta= circ_mean(peak_sophases(pick_peaks_plot));
mag = circ_r(peak_sophases(pick_peaks_plot));
hold on
polarplot([theta theta], [0, mag],'r','linewidth',2)

% hold on;
% compass(real(ang), imag(ang));
% 
% figure
% circ_plot(peak_sophases(pick_peaks_plot),'hist',[],20,true,true,'linewidth',2,'color','r');