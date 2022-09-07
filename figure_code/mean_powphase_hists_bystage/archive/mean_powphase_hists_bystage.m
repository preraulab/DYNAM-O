%%% Plot mean SO power and phase histograms for C3, F3, Pz, O1 for controls night2

ccc;

%% Load SO power/phase data
load('/data/preraugp/projects/transient_oscillations_paper/results/SOpowphase_results/SOphase_data.mat', 'electrodes', 'freq_cbins', 'issz', 'SOphase_cbins', 'SOphase_data',...
                                                                                                         'SOphase_prop_data', 'SOphase_time_data', 'subjects');
load('/data/preraugp/projects/transient_oscillations_paper/results/SOpowphase_results/SOpow_data.mat', 'SOpow_cbins', 'SOpow_data', 'SOpow_prop_data', 'SOpow_time_data');

%% Reconstruct power and phase data for each stage (N1, N2, N3, NREM, REM, WAKE)
electrode_inds = [3,1,7,5]; % 'F3', 'C3', 'Pz', 'O1'
stage_select = {[1,2,3,4,5], 5, 4, [1,2,3], 3, 2, 1};
night_select = 2;
issz_select = false;
freq_range = [4,35];
freq_cbins_length = length(freq_cbins((freq_cbins <= freq_range(2)) & (freq_cbins >= freq_range(1))));

num_elects = length(electrode_inds);
num_stages = length(stage_select);

mean_powhists = zeros(num_elects, num_stages, length(SOpow_cbins), freq_cbins_length);
mean_phasehists = zeros(num_elects, num_stages, length(SOphase_cbins), freq_cbins_length);

for ee = 1:num_elects
    for ss = 1:num_stages
        
        e_use = electrode_inds(ee);
        
        [SOpow,~,~,~,~] = reconstruct_SOpowphase(SOpow_data{e_use}, SOpow_time_data{e_use}, SOpow_prop_data{e_use}, freq_cbins, 'pow', night_select, issz_select, ...
                                                 stage_select{ss});
        [SOphase,~,~,~,~] = reconstruct_SOpowphase(SOphase_data{e_use}, SOphase_time_data{e_use}, SOphase_prop_data{e_use}, freq_cbins, 'phase', night_select, issz_select, ...
                                                   stage_select{ss});
        
        mean_powhists(ee,ss,:,:) = nanmean(SOpow, 1);
        mean_phasehists(ee,ss,:,:) = nanmean(SOphase, 1);
    end
end

%% Plot 

% SOphase
figure;
ax = figdesign(7,4,'type','usletter','orient','portrait', 'margins',[.04 .1 .1 .02 .02 .02]);
outerlabels(ax, 'Slow Oscillation Phase (radians)', 'Frequency (Hz)', 'fontsize', 13)
ylabels = {'ALL', 'WAKE', 'REM', 'NREM', 'NREM1', 'NREM2', 'NREM3'};
titles = {'F3', 'C3', 'Pz', 'O1'};
new_freq_cbins = freq_cbins((freq_cbins <= freq_range(2)) & (freq_cbins >= freq_range(1)));
count = 0;
for ss = 1:num_stages
    for ee = 1:num_elects
        
        count = count + 1;
        axes(ax(count));
        imagesc(SOphase_cbins, new_freq_cbins, squeeze(mean_phasehists(ee,ss,:,:))');
        axis xy;
        colormap(ax(count), 'plasma');
        %climscale
        caxis([0.006, 0.01])
        
        if ss == 1
            title(titles{ee});
        end
        
        if ss == num_stages
            xticklabels({'-\pi/2', '0', '\pi/2'})
        else
            xticklabels([]);
        end
        
        if mod(count-1,4) == 0
            ylabel(ylabels{ss})
        else
            yticklabels([]);
        end
        
    end
end

% SO power
figure;
ax = figdesign(7,4,'type','usletter','orient','portrait', 'margins',[.04 .1 .1 .02 .02 .02]);
outerlabels(ax, 'Slow Oscillation Power (normalized)', 'Frequency (Hz)', 'fontsize', 13)
ylabels = {'ALL', 'WAKE', 'REM', 'NREM', 'NREM1', 'NREM2', 'NREM3'};
count = 0;
for ss = 1:num_stages
    for ee = 1:num_elects
        
        count = count + 1;
        axes(ax(count));
        imagesc(SOpow_cbins*100, new_freq_cbins, squeeze(mean_powhists(ee,ss,:,:))');
        axis xy;
        colormap(ax(count), 'parula');
        %climscale;
        caxis([0,2.4]);
        
        if ss == 1
            title(titles{ee})
        end
        
        if ss == num_stages
            %nothing
        else
            xticklabels([]);
        end
        
        if mod(count-1,4) == 0
            ylabel(ylabels{ss})
        else
            yticklabels([]);
        end
        
    end
end






