function graphical_abstract(data, Fs, stages, stage_times, pow_hist, phase_hist, peak_data, SOphase_cbins, ...
                            SOpow_cbins, freq_cbins, freq_range, fsave_path, print_png, print_eps)
%
%
%

%% Get time range
time_range(1) = max( min(stage_times(stages~=5))-5*60, 0); % x min before first non-wake stage
time_range(2) = min( max(stage_times(stages~=5))+5*60, max(stage_times)); % x min after last non-wake stage

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

%% Get SOpower time trace
artifacts = detect_artifacts(data, Fs);

nanEEG = data;
nanEEG(artifacts) = nan; 

[SOpower, SOpow_times] = compute_mtspect_power(nanEEG, Fs);

low_val =  1;
high_val =  99;
ptile = prctile(SOpower(SOpow_times>=time_range(1) & SOpow_times<=time_range(2)), [low_val, high_val]);
SOpower_norm = SOpower-ptile(1);
SOpower_norm = SOpower_norm/(ptile(2) - ptile(1));


%% Generate axes
close all
figure
ax = figdesign(9,4,'merge',{1:12, 13:20, [21,22,25,26,29,30], [23,24,27,28,31,32,35,36]},...
               'margins', [.06 .05 .07 .09 .12 .06]);
set(gcf,'units','normalized');
set([ax(4); ax(5)], 'Visible', 'off');

lab_fsize = 24;
lab_gaps = [0 0.5];
fs_title = 14;
fs_label = 12;

% Split SOphase scatter and hypnoplot
hypno_scatter_axes = split_axis(ax(1), [0.8,0.2],1);

% Split SOphase hist axis
SOphase_axes = split_axis(ax(6),[0.3 0.7],1);
linkaxes([hypno_scatter_axes, ax(2)],'x');



%% Plotting
cphase = [0.0058    0.0094];
cpow = [1.2687     5.7733];

%% Plot the hypnogram
axes(hypno_scatter_axes(2));
stage_times_hypno = stage_times(stage_times >= time_range(1) & stage_times <= time_range(2));
stages_hypno = stages(stage_times >= time_range(1) & stage_times <= time_range(2));
hypnoplot(stage_times_hypno, stages_hypno,'HypnogramLabels',...
          {'Undef','N3','N2','N1','REM','Wake','Art'}, 'LabelPos','Left');
axis tight
set(gca,'xtick',[]);
A = letter_label(gcf,hypno_scatter_axes(2),'A','l',lab_fsize,lab_gaps);
set(A, 'Position', [-0.0200    0.9334    0.0500    0.0500]);
title('TF-Peaks with Phase', 'FontSize',fs_title);
xlim(time_range);

%% Plot the scatter plot
axes(hypno_scatter_axes(1));
pmax = prctile(psize,95);
psize(psize>pmax) = pmax; 
scatter(peak_data(:,2),peak_data(:,4), psize/20, peak_swf_interp, 'filled')
caxis([-pi,pi])
ylabel('Frequency (Hz)', 'FontSize',fs_label);
ylim(freq_range);
colormap(hypno_scatter_axes(1),circshift(hsv(2^12),-400))
cbar = colorbar_noresize(hypno_scatter_axes(1));
cbar.Label.String = 'Phase (rad)';
cbar.Label.Rotation = -90;
cbar.Label.VerticalAlignment = "bottom";
xlim(time_range);
xticks('');
xticklabels('');
[~, sh] = scaleline(hypno_scatter_axes(1), 3600,'1 Hour' );
sh.FontSize = 10;

set(cbar,'xtick',([-pi -pi/2 0 pi/2 pi]),'xticklabel',({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'}));

%% Plot SOpower time trace
axes(ax(2));
pow_isnan = isnan(SOpower_norm);
SOpower_norm_interp = interp1(SOpow_times(~pow_isnan), SOpower_norm(~pow_isnan), SOpow_times, 'linear');
plot(SOpow_times, SOpower_norm_interp*100, 'linewidth', 2);
xlim(time_range);
title('SO-Power Time Trace','FontSize',fs_title);
ylabel('% SO-Power','FontSize',fs_label);
xticks('');
xticklabels('');
ylim([0,100]);
B = letter_label(gcf,ax(3),'B','l',lab_fsize,lab_gaps);
set(B, 'Position', [-0.0200   0.6033    0.0500    0.0500]);

%% Plot Power histogram
axes(ax(3));
imagesc(SOpow_cbins, freq_cbins, pow_hist);
axis xy;
caxis(cpow);
axis tight;
ylim(freq_range);
ylabel('Frequency (Hz)','FontSize',fs_label);
title('SO-Power Histogram','FontSize',fs_title);
cbar1 = colorbar_noresize;
cbar1.Label.String = {'Density', 'peaks/min in bin'};
cbar1.Label.Rotation = -90;
cbar1.Label.VerticalAlignment = "bottom";
cbar1.Label.Position = [1.8725    3.4686         0];
C = letter_label(gcf,ax(4),'C','l',lab_fsize,lab_gaps);
set(C, 'Position', [-0.0200    0.3982    0.0500    0.0500]);
xlabel('% SO-Power', 'FontSize', fs_label);

%% Plot Phase histogram
axes(SOphase_axes(2))
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
cbar2.Label.Position = [ 2.1    0.0076         0];


%% Plot the phase guide
axes(SOphase_axes(1))
hold on
t = linspace(-pi, pi, 500);
plot(t,cos(t),'k','linewidth',3);

set(SOphase_axes(1),'ylim',[-1 1.25], 'ytick',0,'xlim',[-pi, pi],'xtick', [-pi -pi/2 0 pi/2 pi],'xticklabel',...
    {'-\pi' '-\pi/2' '0' '\pi/2' '\pi' });
hline(0,'linestyle','--','linewidth',2);
xlabel('SO-Phase (rad)','FontSize',fs_label)

D = letter_label(gcf,SOphase_axes(1),'D','l',lab_fsize,[0 -.1]);
set(D, 'Position', [0.4742    0.4012    0.0500    0.0500]);

set(gcf,'units','normalized','paperunits','normalized','papertype','usletter','paperposition',[0 0 1.5 1.25],'position',[0 0 1.5 1.25]);

%Print if selected
if print_png
    print(gcf,'-dpng', '-r600',fullfile( fsave_path, 'PNG','graphical_abstract.png'));
end

if print_eps
    print(gcf,'-depsc', fullfile(fsave_path, 'EPS', 'graphical_abstract.eps'));
end

end