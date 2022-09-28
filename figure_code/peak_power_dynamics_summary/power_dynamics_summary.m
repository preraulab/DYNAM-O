function power_dynamics_summary(data, stages, stage_props, Fs, freq_range, SOpow, SOpow_times, SOpow_hist, SOpow_bins, SOpow_freqs, ...
                                    peak_freqs, peak_times, peak_proms, SOpow_bystage, time_window, fwindow_size, fsave_path, print_png, print_eps)
% Plot power dynamics summary (hypnogram, spectrogram, SOpow histogram, peak scatter plot, and SOpow over time reconstruction)
%
%   Inputs:
%       data: 1D double - EEG data time series
%       stages: structure - 2 fields: time (1D timestamps) and stage (1D stage labels)
%       stage_props: 2D double - [num_stages, num_SOpow_bins] - proportion
%                   of time spent in each SOpow bin for each stage (stage order is WAKE,
%                   REM, N3, N2, N1)
%       Fs: double - sampling frequency of EEG
%       freq_range: 2x1 double - [min max] frequency range bounds
%       SOpow_hist: 2D double - [freq, SOpow] - SOpower rate histogram
%       SOpow_bins: 2D double - centers of SOpower bins for SOpow_hist. Should be same 
%                   length as dim 2 in SOpow_hist
%       peak_freqs: 1D double - frequencies for each TFpeak found in data (Hz)
%       peak_times: 1D doubule - timestamp for each TFpeak found in data (seconds)
%       peak_proms: 1D double - log prominance value for each TFpeak found in data
%       fsave_path: char - path to save png/eps to. Default = '.'
%       print_png: logical - save figure as png. Default = false
%       pring_eps: logical - save figure as eps. Default = false
%
%   Outputs:
%       None
%
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - Michael Prerau 1/03/2022
%%%************************************************************************************%%%

%% Deal win Inputs
if nargin==0
    gen_powsummary;
    return;
end

assert(nargin >= 15, '11 inputs required')

if nargin < 16 || isempty(fsave_path)
    fsave_path = '.';
end

if nargin < 17 || isempty(print_png)
    print_png = false;
end

if nargin < 18 || isempty(print_eps)
    print_eps = false;
end

%% Compute the full-night spectrogram
[spect,~,sfreqs]=multitaper_spectrogram_mex(data,Fs,freq_range,[15 29],[30 15],[],'linear',[],false,true,true);

%% Set lightson/off times
lightsout = stages.time(find(stages.stage ~= 5,1,'first'))-5*60;
lightson = 33353 + 2.5*60; % BAD ENDING DATA stages.time(find(stages.stage ~= 5,1,'last'))+5*60;

%% Compute the rate reconstruction
[~, ~, rate_times, rate_SOP] = SOpow_hist_rate_recon(SOpow, SOpow_times, SOpow_hist, SOpow_bins, SOpow_freqs,...
    peak_freqs, peak_times, time_window, fwindow_size, false);

%% CREATE FIGURE

lab_fsize = 35;
lab_gaps = [0 0.5];
ax_fsize = 15;

% Generate axes
fh = figure;
ax = figdesign(7,4,'type','usletter','orient','portrait','merge',{1:4, 5:8, [9 10 13 14 17 18],[11 12 15 16 19 20], [21,25], [22,26], [23,27], [24,28]},...
               'margins', [.035 .045 .1 .08 .045 .05]);
set(gcf,'units','normalized');

%Adjust all the axes to proper spacing
ax(1).Position(4) = ax(1).Position(4)*1.6;
ax(2).Position(4) = ax(2).Position(4)*1.6;

ax(3).Position(4) = ax(3).Position(4)*.9;
ax(4).Position(4) = ax(4).Position(4)*.9;

ax(5).Position(4) = ax(5).Position(4)*.75;
ax(6).Position(4) = ax(6).Position(4)*.75;
ax(7).Position(4) = ax(7).Position(4)*.75;
ax(8).Position(4) = ax(8).Position(4)*.75;

ax(1).Position(2) = ax(1).Position(2)-0.05;
ax(2).Position(2) = ax(2).Position(2)-0.08;

ax(3).Position(2) = ax(3).Position(2)-0.05;
ax(4).Position(2) = ax(4).Position(2)-0.05;

%ax(5).Position(2) = ax(5).Position(2) - .04;

%Split the axes that need to be split
spect_axes = split_axis(ax(1),[.8 .2],1);
peak_axes = split_axis(ax(2),[.2 .8],1);
SOPH_axes = [split_axis(ax(3),[.2 .8],1) split_axis(ax(4),[.2 .8],1)];

bystage_axes = ax(5:8)';

%link the x axes of those applicable 
linkaxes([spect_axes peak_axes],'x');

%% Hypnogram/Spectrogram

%Hypnogram
axes(spect_axes(2))
stimes = stages.time;
svals = stages.stage;
good_inds = svals>0;
stimes = stimes(good_inds);
svals = svals(good_inds);

hypnoplot(stimes,svals);
set(gca,'xtick',[],'ytick',[]);
letter_label(gcf,spect_axes(2),'A','l',lab_fsize,lab_gaps);
th(1) = title('Full Night Spectrogram');

ax_stage = axes('Position',spect_axes(2).Position);
ax_stage.Position(2) = ax_stage.Position(2) + ax_stage.Position(4);
linkaxes([spect_axes(2) ax_stage],'x');

%Plot stages on top of the hypnogram
fsize_stage = 15;
R_time = find(stages.stage==4,1,'first');
N1_time = find(stages.stage==3,1,'first');
N2_time = find(stages.stage==2,1,'first');
N3_time = find(stages.stage==1,1,'first');

times = {R_time, N1_time, N2_time, N3_time};
timelabels = {'R', '1', '2', '3'};

text(ax_stage,lightsout,0,'W','VerticalAlignment','bottom','HorizontalAlignment','right','FontSize',fsize_stage);

for tt = 1:length(times)
    if ~isempty(times{tt})
        text(ax_stage,stages.time(times{tt}),0,timelabels{tt},'VerticalAlignment','bottom','HorizontalAlignment','left','FontSize',fsize_stage);
    end
end
axis off;

%Spectrogram
axes(spect_axes(1))
imagesc(stimes,sfreqs,pow2db(spect'));
axis xy;
climscale;
colormap(spect_axes(1),jet);
[~, sh] = scaleline(spect_axes(1), 3600,'1 Hour' );
sh.FontSize = 12;

ylabel('Frequency (Hz)')

%% Peak Scatter Plot

%Peak scatter plot
axes(peak_axes(2))
good_inds=peak_proms>0;

psize=(peak_proms(good_inds));
psize(isinf(psize))=1e-100;
psize(psize<=0)=1e-100;

scatter(peak_times, peak_freqs, (psize)/100, 'k')
ylim(freq_range);
ylscat = ylabel('Frequency (Hz)');
set(gca,'xtick',[]);

th(2) = title('Time-Frequency Peaks');

letter_label(gcf,peak_axes(2),'B','l',lab_fsize,lab_gaps);

%SO power trace
axes(peak_axes(1))
good_inds = ~isnan(SOpow);
plot(SOpow_times(good_inds),SOpow(good_inds)*100,'linewidth',1.5);
ylim([0 130])
xlim([lightsout lightson]);
peak_axes(1).YTick = [0 50 100];
axhorig = peak_axes(1).Position(4);
axhnew = .04;
peak_axes(1).Position(4) = axhnew;
peak_axes(1).Position(2) = peak_axes(1).Position(2) - (axhnew- axhorig);
[~,sh] = scaleline(peak_axes(1), 3600,'1 Hour' );
sh.FontSize = 12;

ylpow = ylabel('%SOP');

st = -1*stages.stage;
st(st==0) = 5;
st = st - min(st);
st = st/max(st)*95;

hold on
sh = stairs(stages.time,st,'color',[.6 .6 .6],'LineWidth',4);
uistack(sh,'bottom');

%% SO-power Histogram

%Plot the histogram
axes(SOPH_axes(2))
imagesc(SOpow_bins*100, SOpow_freqs, SOpow_hist);
axis xy;
climscale(SOPH_axes(2),[2.5 97.5],false)
cx=caxis;

colormap(SOPH_axes(2),gouldian);
set(gca,'xtick',[]);
ylabel('Frequency (Hz)')
th(3) = title('SO-power Histogram');
cbar = colorbar_noresize;
cbar.Position(3:4) = cbar.Position(3:4)*.4;
cbar.Position(2) = SOPH_axes(2).Position(2) + (SOPH_axes(2).Position(4) - cbar.Position(4));
cbar.Label.String = {'Density', '(peaks/min in bin)'};
cbar.Label.Rotation = -90;
cbar.Label.VerticalAlignment = "bottom";

letter_label(gcf,SOPH_axes(2),'C','l',lab_fsize,lab_gaps);

%Plot the % time in bin
axes(SOPH_axes(1))
ph = plot(SOpow_bins*100,stage_props(1:4,:)'*100,'linewidth',3);
xlabel('% Slow Oscillation Power')
ylabel('% Time')
ylim([0 140]);
set(gca,'ytick',[0 50 100]);
%Integrated frequency
fastslow_ranges = [12.5 15; 10 12.5];
pows = 20:20:100;

%% Add sleep stage label to hypnoplot
tR = text(SOPH_axes(1),3,100,'REM','color',ph(4).Color,'VerticalAlignment','bottom','HorizontalAlignment','left','FontSize',fsize_stage+4);
tN2 = text(SOPH_axes(1),45,100,'N2','color',ph(2).Color,'VerticalAlignment','bottom','HorizontalAlignment','left','FontSize',fsize_stage+4);
tN3 = text(SOPH_axes(1),80,100,'N3','color',ph(1).Color,'VerticalAlignment','bottom','HorizontalAlignment','left','FontSize',fsize_stage+4);
%tW = text(SOPH_axes(1),1,25,'W','color',ph(5).Color,'VerticalAlignment','bottom','HorizontalAlignment','left','FontSize',fsize_stage+4);
tN1 = text(SOPH_axes(1),7.5,25,'N1','color',ph(3).Color,'VerticalAlignment','bottom','HorizontalAlignment','left','FontSize',fsize_stage+4);

%%

axes(SOPH_axes(4))
hold on;
ylim(freq_range);
SOPH_axes(4).Color = 'none';

rbins = create_bins([.1 1],.1,.1,'full_extend');
SOpowint = interp1(rate_times, rate_SOP, peak_times);
hfreqs = linspace(freq_range(1), freq_range(2),200);

%Compute rate in bins from TF-peaks
for ii =1:length(rbins)
    inds = SOpowint>rbins(1,ii) & SOpowint<=rbins(2,ii);
    hc = smooth(histcounts(peak_freqs(inds),hfreqs,'Normalization','count'));
    hc = hc/6;
    hc = hc-min(hc)+(rbins(1,ii)*100);
    plot(hc,hfreqs(1:end-1),'linewidth',3);
end

xlim([0 100])
letter_label(gcf,SOPH_axes(4),'D','l',lab_fsize,[lab_gaps(1) -.02]);
SOPH_axes(4).YTick = 5:5:25;
th(4) = title('TF-Peak Distributions');

ylim(freq_range)
xlim([0,100])
set(gca,'xtick',[]);
SOPH_axes(4).YAxisLocation = "right";
yl=ylabel('Frequency (Hz)');
yl.Rotation = -90;
yl.VerticalAlignment = "bottom";

ax_fill = axes('Position',SOPH_axes(4).Position,'color','none');
axes(ax_fill);
axis off;
ax_fill.Position(1) = ax_fill.Position(1) - .2;
ax_fill.Position(3) = ax_fill.Position(3) + .2;
hold on

%Plot shaded regions
fill([0 100 100 0],[fastslow_ranges(1,1) fastslow_ranges(1,1) fastslow_ranges(1,2) fastslow_ranges(1,2)],[.8 .8 1],'EdgeColor','none')
fill([0 100 100 0],[fastslow_ranges(2,1) fastslow_ranges(2,1) fastslow_ranges(2,2) fastslow_ranges(2,2)],[1 .8 .8],'EdgeColor','none')
ylim(freq_range)
xlim([0,100])
uistack(ax_fill,'bottom');

%Plot TF_peak rate
axes(SOPH_axes(3))
[rbins, rbin_times] = create_bins([0,1],.2,.01,'partial');
SOpowint = interp1(SOpow_times, SOpow, peak_times);

%Compute rate in bins from TF-peaks
for ii =1:size(rbins,2)
    inds = SOpowint>rbins(1,ii) & SOpowint<=rbins(2,ii);

    tinds = SOpow>rbins(1,ii) & SOpow<=rbins(2,ii);
    SOpow_TIB = sum(tinds)/4;
    fidx = peak_freqs(inds)>fastslow_ranges(1,1) & peak_freqs(inds)<fastslow_ranges(1,2);
    sidx = peak_freqs(inds)>fastslow_ranges(2,1) & peak_freqs(inds)<fastslow_ranges(2,2);

    fast_rate(ii) = sum(fidx)/SOpow_TIB;
    slow_rate(ii) = sum(sidx)/SOpow_TIB;
end

hold all
plot(rbin_times*100,fast_rate,'b','linewidth',2)
plot(rbin_times*100,slow_rate,'r','linewidth',2)
text(gca,15,18,'12.5-15Hz','color','b','fontsize',16);
text(gca,81,15,'10-12.5Hz','color','r','fontsize',16);

% legend(sprintf('%2.1f - %2.1f Hz',fastslow_ranges(1,:)),sprintf('%2.1f - %2.1f Hz',fastslow_ranges(2,:)),'location','northwest')
SOPH_axes(3).YAxisLocation = "right";
axis tight;
SOPH_axes(3).YTick = 5:10:25;

yl = ylabel('Density');
yl.Rotation = -90;
yl.VerticalAlignment = "bottom";

ylim([0 30]);
xlabel('% Slow Oscillation Power')


%outerlabels(SOPH_axes, '% Slow Oscillation Power', '');

%% BY STAGE HISTOGRAMS
titles = {'REM', 'N1', 'N2', 'N3'};
%cpow = [1.398, 5.402]; % set colormap bounds

for p = 1:4
    axes(bystage_axes(p))
    
    imagesc(SOpow_bins*100, SOpow_freqs, squeeze(SOpow_bystage(p,:,:)));
    axis xy;
    caxis(cx);
    
    if p == 1
        letter_label(gcf,bystage_axes(1),'E','l',lab_fsize,lab_gaps);
        ylabel('Frequency (Hz)');
    end
    title(titles{p});

    if p == 4
        cbar = colorbar_noresize;
        %cbar.Position(3:4) = cbar.Position(3:4)*.4;
        %cbar.Position(2) = SOPH_axes(2).Position(2) + (SOPH_axes(2).Position(4) - cbar.Position(4));
        cbar.Label.String = {'Density', '(peaks/min in bin)'};
        cbar.Label.Rotation = -90;
        cbar.Label.VerticalAlignment = "bottom";
    end
end

outerlabels(bystage_axes, '% Slow Oscillation Power', '');

%%

set(spect_axes,'fontsize', ax_fsize);
set(peak_axes,'fontsize', ax_fsize);
set(SOPH_axes,'fontsize', ax_fsize);
set(bystage_axes,'fontsize', ax_fsize);

set(th,'fontsize',23);

set(gcf,'units','normalized','paperunits','normalized','papertype','usletter','paperposition',[0 0 1.8 1.5],'position',[0 0 1.75 1.5])


%% Print if selected
if print_png
    print(fh,'-dpng', '-r600',fullfile( fsave_path, 'PNG','power_dynamics_summary.png'));
end

if print_eps
    print(fh,'-depsc', fullfile(fsave_path, 'EPS', 'power_dynamics_summary.eps'));
end
