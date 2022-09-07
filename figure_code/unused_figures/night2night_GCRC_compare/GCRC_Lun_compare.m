%%%% plot SO pow and phase hists for 2 common GCRC and Lun subjs

%% Load data
% Grab Lun subj SOpow and phase hist data
subjs = repelem(subjects_full, 2);
subj_inds = ismember(subjs, {'5', 'S1'});
SOpows_lun = powhists{1}(:,:,subj_inds);
SOphases_lun = phasehists{1}(:,:,subj_inds);

% Load GCRC SOpow and phase hist data
load('/data/preraugp/projects/schizophrenia/results/GCRC_HC_SOpowphase/HC_C3_zzn8_SOpow_phase_hists.mat', 'SOpow_hists', 'SOphase_hists', 'freq_cbins');
SOpow_hist_HC8 = SOpow_hists(:,21:126,:);
SOphase_hist_HC8 = SOphase_hists(:,21:126,:);

load('/data/preraugp/projects/schizophrenia/results/GCRC_SZ_SOpowphase/SZ_C3_zzs6_SOpow_phase_hists.mat', 'SOpow_hists', 'SOphase_hists');
SOpow_hist_SZ6 = SOpow_hists(:,21:126,:);
SOphase_hist_SZ6 = SOphase_hists(:,21:126,:);

%% Plot
ylims = [4,25];

figure;
ax = figdesign(2,3, 'margins', [.11 .08 .08 .1 .08 .08]);

% SO pow hists for Lun05/ssn8
axes(ax(1));
imagesc(SOpow_cbins_final, freq_cbins_final, SOpow_hist_HC8');
axis xy;
ylim(ylims);
cpow = climscale;
title('GCRC C3, Age: 36.4yrs');
ylabel('Frequency (Hz)');
xlabel('% SO Power');
grid;
set(ax(1), 'GridLineStyle', '--', 'GridColor', '[1, 1, 1]', 'GridAlpha', 0.8);

axes(ax(2));
imagesc(SOpow_cbins_final, freq_cbins_final, SOpows_lun(:,:,1));
axis xy;
ylim(ylims);
caxis(cpow);
xlabel('% SO Power');
title('Lun Night 1 C3, Age: 37.9yrs');
grid;
set(ax(2), 'GridLineStyle', '--', 'GridColor', '[1, 1, 1]', 'GridAlpha', 0.8);

axes(ax(3));
imagesc(SOpow_cbins_final, freq_cbins_final, SOpows_lun(:,:,2));
axis xy;
ylim(ylims);
caxis(cpow);
xlabel('% SO Power');
title('Lun Night 2 C3, Age: 37.9yrs');
colorbar_noresize;
grid;
set(ax(3), 'GridLineStyle', '--', 'GridColor', '[1, 1, 1]', 'GridAlpha', 0.8);

% SO phase hists for Lun05/ssn8
axes(ax(4));
imagesc(SOphase_cbins_final, freq_cbins_final, SOphase_hist_HC8');
axis xy;
colormap(ax(4), 'magma');
ylim(ylims);
cphase = climscale;
xlabel('SO Phase (radians)');
ylabel('Frequency (Hz)');
grid;
set(ax(4), 'GridLineStyle', '--', 'GridColor', '[1, 1, 1]', 'GridAlpha', 0.8);

axes(ax(5));
imagesc(SOphase_cbins_final, freq_cbins_final, SOphases_lun(:,:,1));
axis xy;
colormap(ax(5), 'magma');
ylim(ylims);
caxis(cphase);
xlabel('SO Phase (radians)');
grid;
set(ax(5), 'GridLineStyle', '--', 'GridColor', '[1, 1, 1]', 'GridAlpha', 0.8);

axes(ax(6));
imagesc(SOphase_cbins_final, freq_cbins_final, SOphases_lun(:,:,2));
axis xy;
colormap(ax(6), 'magma');
ylim(ylims);
caxis(cphase);
xlabel('SO Phase (radians)');
colorbar_noresize;
grid;
set(ax(6), 'GridLineStyle', '--', 'GridColor', '[1, 1, 1]', 'GridAlpha', 0.8);

suptitle('Lun05/zzn06 Comparison')

%%
figure;
ax = figdesign(2,3, 'margins', [.11 .08 .08 .1 .08 .08]);

% SO pow hists for LunSZ01/zzs6
axes(ax(1));
imagesc(SOpow_cbins_final, freq_cbins_final, SOpow_hist_SZ6');
axis xy;
ylim(ylims);
cpow = climscale;
xlabel('% SO Power');
ylabel('Frequency (Hz)');
title('GCRC C3, Age: 40.5yrs');
grid;
set(ax(1), 'GridLineStyle', '--', 'GridColor', '[1, 1, 1]', 'GridAlpha', 0.8);

axes(ax(2));
imagesc(SOpow_cbins_final, freq_cbins_final, SOpows_lun(:,:,3));
axis xy;
ylim(ylims);
caxis(cpow);
xlabel('% SO Power');
title('Lun Night 1 C3, Age: 41.6yrs');
grid;
set(ax(2), 'GridLineStyle', '--', 'GridColor', '[1, 1, 1]', 'GridAlpha', 0.8);

axes(ax(3));
imagesc(SOpow_cbins_final, freq_cbins_final, SOpows_lun(:,:,4));
axis xy;
ylim(ylims);
caxis(cpow);
colorbar_noresize;
xlabel('% SO Power');
title('Lun Night 2 C3, Age: 41.6yrs');
grid;
set(ax(3), 'GridLineStyle', '--', 'GridColor', '[1, 1, 1]', 'GridAlpha', 0.8);

% SO phase hists for LunSZ01/zzs6
axes(ax(4));
imagesc(SOphase_cbins_final, freq_cbins_final, SOphase_hist_SZ6');
axis xy;
colormap(ax(4), 'magma');
ylim(ylims)
cphase = climscale;
xlabel('SO Phase (radians)');
ylabel('Frequency (Hz)');
grid;
set(ax(4), 'GridLineStyle', '--', 'GridColor', '[1, 1, 1]', 'GridAlpha', 0.8);

axes(ax(5));
imagesc(SOphase_cbins_final, freq_cbins_final, SOphases_lun(:,:,3));
axis xy;
colormap(ax(5), 'magma');
ylim(ylims);
caxis(cphase);
xlabel('SO Phase (radians)');
grid;
set(ax(5), 'GridLineStyle', '--', 'GridColor', '[1, 1, 1]', 'GridAlpha', 0.8);

axes(ax(6));
imagesc(SOphase_cbins_final, freq_cbins_final, SOphases_lun(:,:,4));
axis xy;
colormap(ax(6), 'magma');
caxis(cphase);
ylim(ylims);
colorbar_noresize;
xlabel('SO Phase (radians)');
grid;
set(ax(6), 'GridLineStyle', '--', 'GridColor', '[1, 1, 1]', 'GridAlpha', 0.8);

suptitle('LunSZ01/zzs08 Comparison')




