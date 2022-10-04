function phase_dynamics_summary(data, Fs, stage_struct, phasehist, peak_data, SOphase_cbins, freq_cbins,...
                                freq_range, fsave_path, print_png, print_eps)
% Plots summary of many SO power histogram features as well as spectrogram
%
% NOTE: must run matlab with vglrun to plot properly: use command: vglrun
% -d "$DISPLAY" matlab unless using MATLAB 2021b or newer version
%
% Inputs:
%       data: 1D double - EEG data time series --required
%       Fs: double - sampling frequency of EEG --required
%       stages_struct: structure - 2 fields: time (1D timestamps) and stage (1D stage labels) --required
%       phasehist: 2D double - SO phase histogram [freq, SOphase] --required
%       peak_data: Px5 double - specifies the following for each peak
%                  detected for the subj, night, and electrode being used:
%                  col1=nans, col2=peak time, col3=logical peak selection, col4=peak freq,
%                  col5=peak height
%                   --required
%       SOphase_cbins: 1D double - SO phase bin centers for phasehist --required
%       freq_cbins: 1D double - Frequency bin centers for phasehist --required
%       freq_range: 1x2 double - [min max] used for setting ylims of histogram --required
%       fsave_path: char - path to save png/eps to. Default = '.'
%       print_png: logical - save figure as png. Default = false
%       pring_eps: logical - save figure as eps. Default = false
%
% Outputs:
%       None
%
%
%   Copyright 2022 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%%%************************************************************************************%%%

%% Deal with Inputs
if nargin ==0
    gen_phase_dynamics_summary;
    return;
end

assert(nargin >= 8, '8 inputs required: data, Fs, stages_struct, phasehist, peak_data, SOphase_cbins, freq_cbins, freq_range');

if nargin < 7 || isempty(fsave_path)
    fsave_path = '.';
end

if nargin < 8 || isempty(print_png)
    print_png = false;
end

if nargin < 9 || isempty(print_eps)
    print_eps = false;
end

%% 

%Compute the spectrogram
[spect,stimes,sfreqs]=multitaper_spectrogram(data,Fs,freq_range,[15 29],[30 15],[],'linear',[],false,true,true);

%Get the SO-phase
[eeg_swf, eeg_swf_times] = compute_SOPhase(-data, Fs);%(-data, Fs, 'hilbert');

%Unwrap and interpolate
eeg_swf_uw = eeg_swf';
dtS = eeg_swf_times(2)-eeg_swf_times(1);

[peak_times_sorted, ~] = sort(peak_data(:,2));
peak_swf_interp_uw = interp1(eeg_swf_times,eeg_swf_uw,peak_times_sorted);

%Compute the modulo to get back to the proper units
eeg_swf = mod((eeg_swf_uw),2*pi)-pi;
peak_swf_interp = mod((peak_swf_interp_uw),2*pi)-pi;

%Get the data to plot in the scatter plot
good_inds=peak_data(:,3)>0;

psize=(peak_data(good_inds,5));
psize(isinf(psize))=1e-100;
psize(psize<=0)=1e-100;

%% Generate axes
close all
figure
ax = figdesign(5,2,'type','usletter','orient','portrait','merge',{1:2, 3:4, [5 7 9 ],[6 8 10]},'margins', [.035 .06 .1 .1 .045 .05]);
set(gcf,'units','normalized');


lab_fsize = 40;
lab_gaps = [0 0.5];
ax_fsize = 20;

%Split the axes that need to be split
spect_axes = split_axis(ax(1),[.8 .2],1);
linkaxes([spect_axes ax(2)],'x');
ax(end).Visible = 'off';

ax(3).Position(4) = ax(3).Position(4)*.9;
ax(4).Position(4) = ax(4).Position(4)*.9;

SOphase_axes = split_axis(ax(3),[.15 .85],1);

%% Plotting

cphase = [0.0058    0.0094];

%Plot the hypnogram
axes(spect_axes(2));
hypnoplot(stage_struct.time', stage_struct.stage');
axis tight
set(gca,'xtick',[],'ytick',[]);
letter_label(gcf,spect_axes(2),'A','l',lab_fsize,lab_gaps);
th(1) = title('Full Night Spectrogram');


ax_stage = axes('Position',spect_axes(2).Position);
ax_stage.Position(2) = ax_stage.Position(2) + ax_stage.Position(4);
linkaxes([spect_axes(2) ax_stage],'x');

%Plot stages on top of the hypnogram
fsize_stage = 15;
R_time = find(stage_struct.stage==4,1,'first');
N1_time = find(stage_struct.stage==3,1,'first');
N2_time = find(stage_struct.stage==2,1,'first');
N3_time = find(stage_struct.stage==1,1,'first');

tW = text(ax_stage,1830,0,'W','VerticalAlignment','bottom','HorizontalAlignment','right','FontSize',fsize_stage);
tR = text(ax_stage,stage_struct.time(R_time),0,'R','VerticalAlignment','bottom','HorizontalAlignment','left','FontSize',fsize_stage);
tN1 = text(ax_stage,stage_struct.time(N1_time),0,'1','VerticalAlignment','bottom','HorizontalAlignment','left','FontSize',fsize_stage);
tN2 = text(ax_stage,stage_struct.time(N2_time)+300,0,'2','VerticalAlignment','bottom','HorizontalAlignment','left','FontSize',fsize_stage);
tN3 = text(ax_stage,stage_struct.time(N3_time)+200,0,'3','VerticalAlignment','bottom','HorizontalAlignment','left','FontSize',fsize_stage);
axis off;

%Plot the MT spectrogram
axes(spect_axes(1));
imagesc(stimes,sfreqs,pow2db(spect'));
axis xy;
caxis([-12.5994    8.8176]);
colormap(spect_axes(1),rainbow4);
ylabel('Frequency (Hz)');
set(gca,'xtick',[]);
[~, sh] = scaleline(spect_axes(1), 3600,'1 Hour' );
sh.FontSize = 12;

cbar = colorbar_noresize(spect_axes(1));
cbar.Label.String = 'Power (dB)';
cbar.Label.Rotation = -90;
cbar.Label.VerticalAlignment = "bottom";
cbar.Position(3) = cbar.Position(3) - 0.015;


%Plot the scatter plot
axes(ax(2))
pmax = prctile(psize,95);
psize(psize>pmax) = pmax; 
scatter(peak_data(:,2),peak_data(:,4), psize/12, peak_swf_interp, 'filled')
caxis([-pi,pi])

ylabel('Frequency (Hz)');

ylim(freq_range);
xlim([1830  30858]);
colormap(ax(2),circshift(hsv(2^12),-400))
cbar = colorbar_noresize(ax(2));
cbar.Label.String = 'Phase (rad)';
cbar.Label.Rotation = -90;
cbar.Label.VerticalAlignment = "bottom";
cbar.Position(3) = cbar.Position(3) - 0.015;

set(cbar,'xtick',([-pi -pi/2 0 pi/2 pi]),'xticklabel',({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'}));

[~, sh] = scaleline(ax(2), 3600,'1 Hour' );
sh.FontSize = 12;

th(2) = title('TF-Peaks with Phase');

letter_label(gcf,ax(2),'B','l',lab_fsize,lab_gaps);

% Plot Phase histogram
axes(SOphase_axes(2))
imagesc(SOphase_cbins,freq_cbins,phasehist); axis xy; climscale;

axis xy;
axis tight
ylim(freq_range)
th(3) = title('SO-Phase Histogram');

ylabel('Frequency (Hz)');
set(gca,'xtick',([-pi -pi/2 0 pi/2 pi]),'xticklabel',({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'}));
caxis(cphase)
colormap(gca,magma(2^12));
set(gca,'xtick',[],'ytick',5:5:25);
ylim(freq_range);
cbar = colorbar_noresize;
cbar.Label.String = 'Proportion';
cbar.Label.Rotation = -90;
cbar.Label.VerticalAlignment = "bottom";

cbar.Position(3) = cbar.Position(3)*.7;
cbar.Position(4) = cbar.Position(4)*.3;
cbar.Position(2) = SOphase_axes(2).Position(2) + (SOphase_axes(2).Position(4) - cbar.Position(4));

ax2 = axes('position',SOphase_axes(1).Position);
ax2.Color = 'none';
ax2.YTick = [-.5 .5];
ax2.YTickLabel = {'+','-'};
ax2.YLim = [-1 1.25];
ax2.FontName = 'courier';
ax2.FontSize = 32;
ax2.XTick = [];

uistack(ax2,'bottom');


%Plot the phase guide
axes(SOphase_axes(1))
hold on
t = linspace(-pi, pi, 500);
plot(t,cos(t),'k','linewidth',3);

set(SOphase_axes(1),'ylim',[-1 1.25], 'ytick',0,'xlim',[-pi, pi],'xtick', [-pi -pi/2 0 pi/2 pi],'xticklabel',...
    {'-\pi' '-\pi/2' '0' '\pi/2' '\pi' });
hline(0,'linestyle','--','linewidth',2);
xlabel('SO-Phase (rad)')
letter_label(gcf,SOphase_axes(2),'C','l',lab_fsize,lab_gaps);

letter_label(gcf,ax(4),'D','l',lab_fsize,[0 -.1]);


% Plot polar histogram of peaks
t_lightsout = min(stage_struct.time(stage_struct.stage~=5))-5*60;
t_lightson = max(stage_struct.time(stage_struct.stage~=5))+5*60;
pick_lightsout = peak_data(:,2)>=t_lightsout & peak_data(:,2)<=t_lightson;
pick_sleep = find_stage_indices(peak_data(:,2),stage_struct, 1:4);

num_bins = 40;

inds1 = pick_lightsout & pick_sleep & peak_data(:,4)>=15 & peak_data(:,4)<=16;

inds2 = pick_lightsout & pick_sleep & peak_data(:,4)>=9 & peak_data(:,4)<=10;


[~, ~, ~, h_pax1, ~] = phasehistogram(peak_swf_interp(inds1),1,'NumBins',num_bins);
title('15-16 Hz')
[~, ~, ~, h_pax2, ~] =phasehistogram(peak_swf_interp(inds2),1,'NumBins',num_bins);
title('9-10 Hz')

h_pax1.Position = [0.68  0.34  0.268   0.207];
h_pax2.Position = h_pax1.Position;
h_pax2.Position(2) = h_pax2.Position(2)-.3;
h_pax1.FontSize = ax_fsize;
h_pax2.FontSize = ax_fsize;
h_pax1.LineWidth =2;
h_pax2.LineWidth =2;

set(spect_axes,'fontsize',ax_fsize);
set(SOphase_axes,'fontsize',ax_fsize);
set(ax(2),'fontsize',ax_fsize);
set(th,'fontsize',26);

%Rescale page to big size to get everything to fit well
set(gcf,'units','normalized','paperunits','normalized','papertype','usletter','paperposition',[0 0 1.75 1.5],'position',[0 0 1.75 1.5]);

%Print if selected
if print_png
    print(gcf,'-dpng', '-r600',fullfile( fsave_path, 'PNG','phase_dynamics_summary.png'));
end

if print_eps
    print(gcf,'-depsc', fullfile(fsave_path, 'EPS', 'phase_dynamics_summary.eps'));
end

end

