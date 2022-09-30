function graphical_abstract(data, Fs, stages, stage_times, pow_hist, phase_hist, peak_data, SOphase_cbins, ...
                            SOpow_cbins, freq_cbins, freq_range, fsave_path, print_png, print_eps)
% Plot components of graphical abstract for SLEEP submission
%
%   Inputs:
%       data: 1D double - EEG data time series 
%       Fs: double - sampling frequency of EEG
%       stages: 1D double - sleep stage at each time in stage_times
%               (0=unidentified, 1=N3, 2=N2, 3=N1, 4=REM, 5=wake) 
%       stage_times: 1D double - time stamp for each stage in staegs
%       pow_hist: 2D double - SO power histogram [freq, SOpower]
%       phase_hist: 2D double - SO phase histogram [freq, SOphase]
%       peak_data: Px5 double - specifies the following for each peak
%                 detected for the subj, night, and electrode being used:
%                 col1=nans, col2=peak time, col3=logical peak selection, col4=peak freq,
%                 col5=peak height
%       SOphase_cbins: 1D double - SO phase bin centers for phasehist 
%       SOpow_cbins: 1D double - SO power bin centers for powhist 
%       freq_cbins: 1D double - Frequency bin centers for phasehist and
%                    powhist
%       freq_range: 1x2 double - [min max] used for setting ylims of histogram 
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
%       - Created - Tom Possidente 08/25/2022
%%%************************************************************************************%%%%

%% Deal with Inputs
assert(nargin >= 11, '11 or more inputs required, see function docstring');

if nargin < 9 || isempty(fsave_path)
    fsave_path = '';
end

if nargin < 10 || isempty(print_png)
    print_png = false;
end

if nargin < 11 || isempty(print_eps)
    print_eps = false;
end

%% Get time range
time_range(1) = max( min(stage_times(stages~=5))-5*60, 0); % x min before first non-wake stage
time_range(2) = min( max(stage_times(stages~=5))+5*60, max(stage_times)); % x min after last non-wake stage

%% Calculate Spectrogram
[spect,stimes,sfreqs]=multitaper_spectrogram_mex(data,Fs,freq_range,[15 29],[30 15],[],'linear',[],false,true,true);

%% Get the SO-phase
[eeg_swf, eeg_swf_times] = compute_SOPhase(-data, Fs);

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

%% Get SOpower time trace and normalize
artifacts = detect_artifacts(data, Fs);

nanEEG = data;
nanEEG(artifacts) = nan; 

[SOpower, SOpow_times] = compute_mtspect_power(nanEEG, Fs);

low_val =  1;
high_val =  99;
ptile = prctile(SOpower(SOpow_times>=time_range(1) & SOpow_times<=time_range(2)), [low_val, high_val]);
SOpower_norm = SOpower-ptile(1);
SOpower_norm = SOpower_norm/(ptile(2) - ptile(1));


%% Figure 1 - Spectrogram, SOphase scatter plot, hypnogram, SOpow time trace
close all
fh1 = figure;
ax = figdesign(3,1, 'margins', [.06 .05 .07 .09 .12 .06]);
set(gcf,'units','normalized');

lab_fsize = 24;
lab_gaps = [0 0.5];
fs_title = 14;
fs_label = 12;

% Split last axis
hypno_SOpow_axes = split_axis(ax(3), [0.5 0.5], 1);

% Link all x axes
linkaxes([ax(1), ax(2), hypno_SOpow_axes(1), hypno_SOpow_axes(2)],'x');


%% Plot Spectrogram
axes(ax(1));

imagesc(stimes, sfreqs, nanpow2db(spect)');
axis xy;
climscale;
colormap(ax(1),rainbow4);
ylabel('Frequency (Hz)', 'FontSize',fs_label);
title('Spectrogam', 'FontSize', fs_title);
xlim(time_range);
A = letter_label(gcf,ax(1),'A','l',lab_fsize,lab_gaps);

[~, sh] = scaleline(ax(1), 3600,'1 Hour' );
sh.FontSize = 10;

cbar = colorbar_noresize(ax(1));
cbar.Label.String = 'Power (dB)';
cbar.Label.Rotation = -90;
cbar.Label.VerticalAlignment = "bottom";

%% Plot SOphase scatter plot
axes(ax(2));
pmax = prctile(psize,95);
psize(psize>pmax) = pmax; 
scatter(peak_data(:,2),peak_data(:,4), psize/20, peak_swf_interp, 'filled')
caxis([-pi,pi])
ylabel('Frequency (Hz)', 'FontSize',fs_label);
ylim(freq_range);
colormap(ax(2),circshift(hsv(2^12),-400))
cbar = colorbar_noresize(ax(2));
cbar.Label.String = 'Phase (rad)';
cbar.Label.Rotation = -90;
cbar.Label.VerticalAlignment = "bottom";
xlim(time_range);
title('TF-peaks with Phase', 'FontSize', fs_title);
xticks('');
xticklabels('');
B = letter_label(gcf,ax(2),'B','l',lab_fsize,lab_gaps);

set(cbar,'xtick',([-pi -pi/2 0 pi/2 pi]),'xticklabel',({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'}));

%% Plot hypnogram
axes(hypno_SOpow_axes(2));
stage_times_hypno = stage_times(stage_times >= time_range(1) & stage_times <= time_range(2));
stages_hypno = stages(stage_times >= time_range(1) & stage_times <= time_range(2));
hypnoplot(stage_times_hypno, stages_hypno,'HypnogramLabels',...
          {'Undef','N3','N2','N1','REM','Wake','Art'}, 'LabelPos','Left');
axis tight
set(gca,'xtick',[]);
C = letter_label(gcf,hypno_SOpow_axes(2),'C','l',lab_fsize,lab_gaps);
%set(C, 'Position', [-0.0200    0.9334    0.0500    0.0500]);
title('SO-Power Time Trace', 'FontSize', fs_title);
xlim(time_range);

%% Plot SOpower time trace
axes(hypno_SOpow_axes(1));
pow_isnan = isnan(SOpower_norm);
SOpower_norm_interp = interp1(SOpow_times(~pow_isnan), SOpower_norm(~pow_isnan), SOpow_times, 'linear');
plot(SOpow_times, SOpower_norm_interp*100, 'linewidth', 1.5);
xlim(time_range);
ylabel('% SO-Power','FontSize',fs_label);
xticks('');
xticklabels('');
ylim([0,107]);
yticks([0,20,40,60,80,100]);

set(gcf,'units','normalized','paperunits','normalized','papertype','usletter','paperposition',[0 0 1.3 1.1],'position',[0 0 1.3 1.1]);


%% Figure 2 - SOpower and SOphase Histograms
fh2 = figure;
ax = figdesign(7,2, 'orient', 'landscape', 'merge', {[1,3,5,7,9,11], [2,4,6,8,10,12,14]}, 'margins', [.08 .08 .08 .11 .15 .08]);
set(ax(2), 'Visible', 'Off');

% Split SOphase axis
SOphase_hist_axes = split_axis(ax(3), [0.14, 0.86], 1);

cphase = [0.0058    0.0094];
cpow = [1.2687     5.7733];

%% Plot Power histogram
axes(ax(1));
imagesc(SOpow_cbins, freq_cbins, pow_hist);
axis xy;
caxis(cpow);
colormap(ax(1), gouldian);
axis tight;
ylim(freq_range);
ylabel('Frequency (Hz)','FontSize',fs_label);
title('SO-Power Histogram','FontSize',fs_title);
cbar1 = colorbar_noresize;
cbar1.Label.String = {'Density', 'peaks/min in bin'};
cbar1.Label.Rotation = -90;
cbar1.Label.VerticalAlignment = "bottom";
cbar1.Label.Position = [2.5392    3.6371         0];
C = letter_label(gcf,ax(1),'C','l',lab_fsize,lab_gaps);
yticks([5,10,15,20,25]);
%set(C, 'Position', [-0.0200    0.3982    0.0500    0.0500]);
xlabel('% SO-Power', 'FontSize', fs_label);

%% Plot Phase histogram
axes(SOphase_hist_axes(2))
imagesc(SOphase_cbins,freq_cbins,phase_hist); 
axis xy; 
axis tight;
ylim(freq_range);
title('SO-Phase Histogram','FontSize',fs_title);
xlabel('% SO-Power','FontSize',fs_label);

set(gca,'xtick',([-pi -pi/2 0 pi/2 pi]),'xticklabel',({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'}));
caxis(cphase)
colormap(gca,magma(2^12));
set(gca,'xtick',[],'ytick',5:5:25);
ylim(freq_range);
cbar2 = colorbar_noresize;
cbar2.Label.String = 'Proportion';
cbar2.Label.Rotation = -90;
cbar2.Label.VerticalAlignment = "bottom";
cbar2.Label.Position = [2.7667    0.0076         0];
yticks([5,10,15,20,25]);

D = letter_label(gcf,SOphase_hist_axes(2),'D','l',lab_fsize,[0 -.1]);
D.Position = [0.4885    0.920    0.0500    0.0500];

%% Plot the phase guide
axes(SOphase_hist_axes(1))
hold on
t = linspace(-pi, pi, 500);
plot(t,cos(t),'k','linewidth',3);

set(SOphase_hist_axes(1),'ylim',[-1 1.25], 'ytick',0,'xlim',[-pi, pi],'xtick', [-pi -pi/2 0 pi/2 pi],'xticklabel',...
    {'-\pi' '-\pi/2' '0' '\pi/2' '\pi' });
hline(0,'linestyle','--','linewidth',2);
xlabel('SO-Phase (rad)','FontSize',fs_label)

set(fh2, 'Position', [0.0625    0.1586    0.7188    0.6854])
%set(gcf,'units','normalized','paperunits','normalized','papertype','usletter','paperposition',[0 0 1.2 1],'position',[0 0 1.2 1]);


%% Print if selected
if print_png
    print(fh1,'-dpng', '-r600',fullfile( fsave_path, 'PNG','graphical_abstract_1.png'));
end

if print_eps
    print(fh1,'-depsc', fullfile(fsave_path, 'EPS', 'graphical_abstract_1.eps'));
end

if print_png
    print(fh2,'-dpng', '-r600',fullfile( fsave_path, 'PNG','graphical_abstract_2.png'));
end

if print_eps
    print(fh2,'-depsc', fullfile(fsave_path, 'EPS', 'graphical_abstract_2.eps'));
end

end