function figh= peak_dynamics_summary(EEG, stage_struct, Fs, peak_data, SWP_hists, SWP_bins, SWP_freqs, stage_prop, freq_range)
%
% NOTE: must run matlab with vglrun to plot properly: use command: vglrun -d "$DISPLAY" matlab
% Modified:
% 20181212 - Changed to take SWP_bin_times, SWP_freqs, and stage_prop from power histogram file.

%% Compute multitaper 
[spect,stimes,sfreqs]=multitaper_spectrogram_mex(EEG,Fs,freq_range,[15 29],[30 15],[],'linear',[],false,true,true);

%% Compute SO power
% Mark artifacts
artifacts = detect_artifacts(EEG, Fs);

% replace artifact timepoints with NaNs
nanEEG = EEG;
nanEEG(artifacts) = nan; 

% Compute SO power
SO_freqrange = [0.3,1.5];
[SOpower, SOpower_times] = compute_mtspect_power(nanEEG, Fs, 'freq_range', SO_freqrange);

% Normalize SO power 
t_lightsout = min(stage_struct.time(stage_struct.stage~=5))-5*60;
t_lightson = max(stage_struct.time(stage_struct.stage~=5))+5*60;

low_val =  1;
high_val =  99;
ptiles = prctile(SOpower(SOpower_times>=t_lightsout & SOpower_times<=t_lightson), [low_val, high_val]);
SOpower_norm = SOpower-ptiles(1);
SOpower_norm = SOpower_norm/(ptiles(2) - ptiles(1));

%% Get SOpower at peak times
[time_sort, ~]=sort(peak_data(:,2));
SWAi=interp1(SOpower_times,SOpower_norm,sort(time_sort));

freqs=sfreqs(1:8:end);
F=length(freqs);

window_size=10*60;
window_step_size=.5*60;

%Window start indices
start_times=1:window_step_size:stimes(end)-window_size;
end_times=min(start_times+window_size,stimes(end));
hist_times=(start_times+end_times)./2;

%Number of windows
N=length(start_times);

hists_full=zeros(N,F);

for n=1:N-1
    inds=peak_data(:,2)>start_times(n) & peak_data(:,2)<=end_times(n);
    hists_full(n,:)=smooth(hist(peak_data(inds,4),SWP_freqs));
end

% eegtimes = (1:length(eeg_data))/Fs;
% % In next line, [1:4] is used (instead of select_stages) to only use artifact-free sleep
% % of eeg data for the power percentiles. It does NOT subselect peaks.
% pick_eegrawstages = find_stage_indices(eegtimes',stage_struct,[1:4]); % select_stages
% pick_eegrawlightsout = eegtimes'>=t_lightsout & eegtimes'<=t_lightson;
% pick_eegrawstages = pick_eegrawstages & pick_eegrawlightsout;
% 
% %Compute percent bounds with no artifacts on lights out time
% low_val =  .1;
% high_val =  99.9;
% num_std = 5;
% [processed_ptiles, ~] = SW_percentiles_artifact_rejected(eeg_data(pick_eegrawstages), Fs, [low_val high_val], num_std, 'db');
% p_low = processed_ptiles(1);
% p_high = processed_ptiles(2);

%Compute the power histogram
% [SWP_hists, SWP_bin_times, SWP_freqs, ~, stage_prop] = swFeatHistogram(eeg_data,Fs,peak_data(:,4),peak_data(:,2),[],stage_struct, 'power', 'db', 'percentlightsoutnoartifact',[],1:5,true, false);
% load(ipath_hist_power);

%%

figh=fullfig;
ax=figdesign(11,3,'margin',[.05 .05 .06 .05 .08, 0.08],'margin',[.05 .05 .05 .05 .05],'merge',{[1 2],[ 4 5 7 8 10 11],[13 14 16 17 19 20],[22 23 25 26 28 29],[31 32],[3 6 9 12 15 18 21],[24 27],[ 30 33]});

linkaxes(ax([1 2 3 6 7]),'x');
linkaxes(ax([4 5 8]),'x');
linkaxes(ax([2 3 6]),'y');

cpow = [1, 7];
ylims = [4,25];

%Plot the hypnogram
axes(ax(1));
hypnoplot(stage_struct);
axis tight

%Plot the MT spectrogram
axes(ax(2));
imagesc(stimes,sfreqs,pow2db(spect'));
axis xy;
caxis([-9.82755, 10.2031]);
colormap(jet);

title('Spectrogram');
ylabel('Frequency (Hz)');
% topcolorbar;
set(gca,'xtick',[]);

%Plot the scatter plot
axes(ax(3))
good_inds=peak_data(:,3)>0;

psize=(peak_data(good_inds,5));
psize(isinf(psize))=1e-100;
psize(psize<=0)=1e-100;

scatter(peak_data(:,2),peak_data(:,4), (psize)/300, 'k')

ylim(ylims)
title('TF Peaks');
ylabel('Frequency (Hz)');
set(gca,'xtick',[]);

%Plot the rate histogram across the night
axes(ax(6))
imagesc(hist_times,freqs,hists_full'/30); axis xy;

axis xy;
axis tight
ylim(ylims)
title('Slow Oscillation Power Over Time');

ylabel('Frequency (Hz)');
climscale;
colormap(gca,parula);
set(gca,'xtick',[]);
ylim(ylims);

%Plot the SWP
axes(ax(7))
plot(SOpower_times,SOpower);

ylabel('Power (dB)');
scaleline(3600,'1 Hour');
title('Slow Oscillation Power');
axis tight
hline(p_low,'linewidth',2,'color', 'k','linestyle', '--');
hline(p_high,'linewidth',2,'color', 'k','linestyle', '--');
xlim([t_lightsout t_lightson]);

%Plot the SWP histogram
axes(ax(4));
imagesc((SWP_bins),SWP_freqs,(SWP_hists))
caxis(cpow);
xlabel('% SO Power');
ylabel('Frequency (Hz)');
axis xy;
% xlim([23 42]);
title('Slow Oscillation Power Histogram');
hold on
xlabel('% SO Power');
c = colorbar_noresize;
c.Label.String = {'Density', '(peaks/min in bin)'};
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";

color=get(gca,'colororder');

freq_bands=[10 12; 12 14];%[.5 2; 2.5 5; 10.5 12.3; 12.6 14];


for ii=1:size(freq_bands,1)
    hline(freq_bands(ii,1),'linewidth', 3,'color', color(ii,:));
    hline(freq_bands(ii,2),'linewidth', 3,'color', color(ii,:));
    
    legend_txt{ii}=[num2str((freq_bands(ii,1))) '-' num2str((freq_bands(ii,2))) ' Hz'];
end
ylim(ylims)

colormap(gca,'parula');

%Plot the rates of the selected bands
axes(ax(5))
hold all;
for ii=1:size(freq_bands,1)
    finds=SWP_freqs>freq_bands(ii,1) & SWP_freqs<freq_bands(ii,2);
    plot(SWP_bins,sum(SWP_hists(finds,:),1)','linewidth',2);
end
legend(legend_txt,'location','northwest');
ylabel('Density (peaks/min)');
xlabel('% SO Power');
title('Integrated Rate Within Band');

%Plot the rates of the selected bands
axes(ax(8))
plot(SWP_bins, stage_prop,'linewidth',2);
axis tight
ylim([0 1])
legend('N3','N2','N1','REM','Wake');
title('Percent Time in Scored Stage');
ylabel('% Time in Stage');
xlabel('% SO Power');

%% RECONSTRUCTION

%SOP=(SOpower-p_low)./(p_high-p_low);
N=length(SOpower_norm);
F=length(SWP_freqs);

r=zeros(N,F);

for ii=1:N
    [~,idx]=min(abs(SOpower_norm(ii)-SWP_bins));
    if SOpower_norm(ii)<=1 && SOpower_norm(ii)>0
        r(ii,:)=SWP_hists(:,idx);
    end
end

%Plot Reconstruction
figure;
ax=figdesign(2,1);
axes(ax(1))
imagesc(hist_times,freqs,hists_full'/30); axis xy;
climscale
colormap(gca,parula);
set(gca,'xtick',[]);
ylim(ylims);
% cx=caxis;

linkaxes(ax,'x');
smoother=ones((600/15),2);
axes(ax(2))
imagesc(SOpower_times,SWP_freqs,imfilter(r,smoother/numel(smoother))'); axis xy;
climscale
colormap(gca,parula);
set(gca,'xtick',[]);
ylim(ylims);
%caxis(cx)

%%
% stages = {'N3','N2','N1','REM','Wake'};
% % close all
% times = stimes(:);
% t_lightsout = min(stage_struct.time(stage_struct.stage~=5))-5*60;
% t_lightson = max(stage_struct.time(stage_struct.stage~=5))+5*60;
% pick_lightsout = times>=t_lightsout & times<=t_lightson;

swps = fliplr([80,60,50]/100);
% [~, stagemax_inds] = max(stage_prop);


figure;

dp = SWP_bins(2) - SWP_bins(1);
pwidth = .2;
ind_width = round(pwidth/dp/2);
ax = figdesign(1,3);
%  hold all;
%  yyaxis right
% for ss = 3:-1:1
%
%
%
%
%     hold all;
%     pick_stage = find_stage_indices(times,stage_struct,ss);
%     pick_plot_times = pick_lightsout & pick_stage;
%
%     plot(sfreqs,(mean(spect(pick_plot_times,:)',2)),'linewidth',2);
%     axis tight;
%        xlim([5 35])
% end
%
%
%
%     yyaxis left;

linkaxes(ax,'xy');
    [~, inds] = findclosest(SWP_bins,swps);
for ss = 1:3
    axes(ax(ss))
    ind= inds(ss);
    

    plot(mean(SWP_hists(:,max(ind-ind_width,1):min(ind+ind_width,length(SWP_bins))),2),SWP_freqs,'linewidth',2);
    
    ylim(ylims)
    title([num2str(swps(ss)*100) '%'])
    if(ss == 1)
        ylabel('Frequency (Hz)');
    end
    if ss == 2
        xlabel('Density (peaks/min in bin)');
    end
end


figure
imagesc((SWP_bins)*100,SWP_freqs,(SWP_hists))
climscale;
xlabel('% SO Power');
ylabel('Frequency (Hz)');
axis xy;
ylim(ylims);
% xlim([23 42]);
title('Slow Oscillation Power Histogram');
hold on




%% Plot median spectrum for each stage
%plotStageMedSpectra(spect',stimes,sfreqs,stage_struct);

%plotStageSOPowerSlices(SWP_hists,time_in_bins,SWP_freqs',1,stage_prop);
