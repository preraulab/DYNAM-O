function figh= peak_dynamics_summary1(eeg_data, stage_struct, Fs, peak_data)

if nargin==0
    subject='Lun03';
    electrode='C3';
    night='2';
end

[spect,stimes,sfreqs]=multitaper_spectrogram_mex(eeg_data,Fs,[.5 35],[15 29],[30 15],[],'linear',[],false,true,true);

[SWA, SWA_times]= compute_SWA( eeg_data, Fs, 'db' );

[time_sort, sort_ind]=sort(peak_data(:,2));
SWAi=interp1(SWA_times,SWA,sort(time_sort));
% SWAi=SWAi(sort_ind);

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

parfor n=1:N-1
    inds=peak_data(:,2)>start_times(n) & peak_data(:,2)<=end_times(n);
    hists_full(n,:)=smooth(hist(peak_data(inds,4),freqs));
end

%Get lights out time
eegtimes = (1:length(eeg_data))/Fs;
% In next line, [1:4] is used (instead of select_stages) to only use artifact-free sleep
% of eeg data for the power percentiles. It does NOT subselect peaks.
pick_eegrawstages = find_stage_indices(eegtimes',stage_struct,[1:4]); % select_stages
t_lightsout = min(stage_struct.time(stage_struct.stage~=5))-5*60;
t_lightson = max(stage_struct.time(stage_struct.stage~=5))+5*60;
pick_eegrawlightsout = eegtimes'>=t_lightsout & eegtimes'<=t_lightson;
pick_eegrawstages = pick_eegrawstages & pick_eegrawlightsout;

%Compute percent bounds with no artifacts on lights out time
low_val =  .1;
high_val =  99.9;
num_std = 5;
[processed_ptiles, ~] = SW_percentiles_artifact_rejected(eeg_data(pick_eegrawstages), Fs, [low_val high_val], num_std, 'db');
p_low = processed_ptiles(1);
p_high = processed_ptiles(2);

%Compute the power histogram
[SWP_hists, SWP_bin_times, SWP_freqs, ~, stage_prop] = swFeatHistogram(eeg_data,Fs,peak_data(:,4),peak_data(:,2),[],stage_struct, 'power', 'db', 'percentlightsoutnoartifact',[],1:5,true, false);
%%   

figh=fullfig;
ax=figdesign(11,3,'margin',[.05 .05 .05 .05 .04],'margin',[.05 .05 .05 .05 .05],'merge',{[1 2],[ 4 5 7 8 10 11],[13 14 16 17 19 20],[22 23 25 26 28 29],[31 32],[3 6 9 12 15 18 21],[24 27],[ 30 33]});

linkaxes(ax([1 2 3 6 7]),'x');
linkaxes(ax([4 5 8]),'x');
linkaxes(ax([2 3 6]),'y');


%Plot the hypnogram
axes(ax(1));
hypnoplot(stage_struct);
axis tight

%Plot the MT spectrogram
axes(ax(2));
imagesc(stimes,sfreqs,pow2db(spect'));
axis xy;
caxis([-12.5994    8.8176]);
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
ylabel('Frequency (Hz)');

scatter(peak_data(:,2),peak_data(:,4), (psize)/300, 'k')

ylim([1 35])
title('Identified Peaks');
set(gca,'xtick',[]);

%Plot the rate histogram across the night
axes(ax(6))
imagesc(hist_times,freqs,hists_full'/30); axis xy;

axis xy;
axis tight
ylim([1 35])
title('Rate Histogram Over Time');

ylabel('Frequency (Hz)');
climscale
colormap(gca,parula);
set(gca,'xtick',[]);
ylim([.5 33]);

%Plot the SWP
axes(ax(7))
plot(SWA_times,SWA);

ylabel('Power (dB)');
scaleline(3600,'1 Hour');
title('Slow Wave Power (SWP)');
axis tight
hline(p_low,2,'k','--');
hline(p_high,2,'k','--');
xlim([t_lightsout t_lightson]);

%Plot the SWP histogram
axes(ax(4));
imagesc((SWP_bin_times),SWP_freqs,(SWP_hists'))
climscale;
xlabel('% SWP');
ylabel('Frequency (Hz)');
axis xy;
% xlim([23 42]);
title('Rate as a Function of Frequency and % SWP');
hold on

color=get(gca,'colororder');

freq_bands=[.5 2; 2.5 5; 10 12; 12.5 14];

for ii=1:size(freq_bands,1)
    hline(freq_bands(ii,1),3,color(ii,:));
    hline(freq_bands(ii,2),3,color(ii,:));
    
    legend_txt{ii}=[num2str((freq_bands(ii,1))) '-' num2str((freq_bands(ii,2))) ' Hz'];
end
ylim([1 35])

colormap(gca,'parula');

%Plot the rates of the selected bands
axes(ax(5))
hold all;
for ii=1:size(freq_bands,1)
    finds=SWP_freqs>freq_bands(ii,1) & SWP_freqs<freq_bands(ii,2);
    plot(SWP_bin_times,sum(SWP_hists(:,finds),2)','linewidth',2);
end
legend(legend_txt,'location','northwest');
ylabel('Event Rate (events/min)');
xlabel('% SWP');
title('Integrated Rate Within Band');

%Plot the rates of the selected bands
axes(ax(8))
plot(SWP_bin_times, stage_prop,'linewidth',2);
axis tight
ylim([0 1])
legend('N3','N2','N1','REM','Wake');
title('Percent Time in Scored Stage');
ylabel('% Time in Stage');
xlabel('% SWP');


