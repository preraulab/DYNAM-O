
load('/data/preraugp/projects/transient_oscillations/code/Lunesta histograms over time/electrode_hists_SW_phase_perSubj_compNights_20190116_nights1and2_sleep.mat')
load('/data/preraugp/projects/transient_oscillations/code/Lunesta histograms over time/jetwraparoundmap.mat')

addpath('/data/preraugp/projects/transient_oscillations/code/Lunesta histograms over time');

results_folder = ['/data/preraugp/projects/transient_oscillations/results/lunesta/figures/SWPhase_color_peak_plot/'];

%Select the subject and electrode
subject='Lun11';
night=2;
channel='C3';

subject_idx=find(strcmp(subjects, subject));
electrode_idx=find(strcmp(electrodes,channel));

%Grab the corresponding phase histpgram
phase_hist=electrode_hists{electrode_idx}(:,:,(night-1)*length(subjects)+subject_idx);

%Get the EEG and peak data
[eegdata, stage_struct, Fs, peak_data, peak_times] = lunesta_load_from_meta(subject, night, channel);

%Compute the spectrogram
[spect,stimes,sfreqs]=multitaper_spectrogram(eegdata,Fs,[.5 35],[15 29],[30 15],[],'linear',[],false,true,true);


%%
%Get the SO-phase
[eeg_swf, eeg_swf_times] = compute_SWPhase(-eegdata, Fs, 'hilbert');

%Unwrap and interpolate
eeg_swf_uw = eeg_swf';
dtS = eeg_swf_times(2)-eeg_swf_times(1);

[peak_times_sorted, sort_ind] = sort(peak_times);
peak_swf_interp_uw = interp1(eeg_swf_times,eeg_swf_uw,peak_times_sorted);

%Compute the modulo to get back to the proper units
eeg_swf = mod((eeg_swf_uw),2*pi)-pi;
peak_swf_interp = mod((peak_swf_interp_uw),2*pi)-pi;

%Get the data to plot in the scatter plot
good_inds=peak_data(:,3)>0;

psize=(peak_data(good_inds,5));
psize(isinf(psize))=1e-100;
psize(psize<=0)=1e-100;

%%
 close all
figh=fullfig;
ax=figdesign(11,3,'margin',[.05 .05 .05 .05 .04],'margin',[.05 .05 .05 .05 .05],'merge',{[1 2],[ 4 5 7 8 10 11],[13 14 16 17 19 20],[22 23 25 26 28 29],[31 32],[3 6 9 12 15 18 21],[24 27],[ 30 33]});

linkaxes(ax([1 2 3 6 7]),'x');
linkaxes(ax([4 5 8]),'x');
linkaxes(ax([2 3 6]),'y');


%Plot the hypnogram
axes(ax(1));
hypnoplot(stage_struct);
axis tight
title('Hypnogram');

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

scatter(peak_data(:,2),peak_data(:,4), min(min((psize)/200,10)*15,25)/10, peak_swf_interp)
caxis([-pi,pi])

ylabel('Frequency (Hz)');

ylim([.5 35]);
xlim([1830  30858]);
[~,cb]=topcolorbar;
set(cb,'xtick',([-pi -pi/2 0 pi/2 pi]),'xticklabel',({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'}));
scaleline(gca,3600,'1 hour');
cm = colormap(ax(3),cm);
 title('Time-Frequency Peaks with Phase');

%Plot the rate histogram across the night
axes(ax(4))
imagesc(SWF_bins,freqs,phase_hist'); axis xy; climscale;

axis xy;
axis tight
ylim([4 35])
title('Phase Histogram');

ylabel('Frequency (Hz)');
xlabel('Phase (rad)');
set(gca,'xtick',([-pi -pi/2 0 pi/2 pi]),'xticklabel',({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'}));
climscale
colormap(gca,plasma(2^12));
% set(gca,'xtick',[]);
ylim([4 33]);

delete(ax(5:8));


%% save as eps
%set(gcf,'renderer','painters');
% print(gcf,['phasesummary_' subject,'-Night',num2str(night),'_plasma.eps'],'-depsc');

%% Plot polar histogram of peaks
t_lightsout = min(stage_struct.time(stage_struct.stage~=5))-5*60;
t_lightson = max(stage_struct.time(stage_struct.stage~=5))+5*60;
pick_lightsout = peak_times>=t_lightsout & peak_times<=t_lightson;
pick_sleep = find_stage_indices(peak_times,stage_struct, 1:4);
max_radius = 0.25;
num_bins = 40;

% close all;

plotBandSOPhasePolarHist(peak_swf_interp,peak_data(:,4),[15 16],num_bins,pick_lightsout & pick_sleep,max_radius);
set(gcf,'renderer','painters');
 print(gcf,['phasesummary_' subject,'-Night',num2str(night),'_15-16Hz_updated.eps'],'-depsc');
plotBandSOPhasePolarHist(peak_swf_interp,peak_data(:,4),[9 10],num_bins,pick_lightsout,max_radius);
set(gcf,'renderer','painters');
 print(gcf,['phasesummary_' subject, '-Night',num2str(night),'_9-10Hz_updated.eps'],'-depsc');
% plotBandSOPhasePolarHist(peak_swf_interp,peak_data(:,4),[4 8],num_bins,pick_lightsout,max_radius);
