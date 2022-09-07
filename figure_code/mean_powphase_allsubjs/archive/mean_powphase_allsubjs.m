%%% Plot mean SO power and phase histograms for C3, F3, Pz, O1 for controls night2

ccc;

%% Load SO power/phase data
load('/data/preraugp/projects/transient_oscillations_paper/results/SOpowphase_results/SOphase_data.mat', 'electrodes', 'freq_cbins', 'issz', 'SOphase_cbins', 'SOphase_data',...
                                                                                                         'SOphase_prop_data', 'SOphase_time_data', 'subjects');
load('/data/preraugp/projects/transient_oscillations_paper/results/SOpowphase_results/SOpow_data.mat', 'SOpow_cbins', 'SOpow_data', 'SOpow_prop_data', 'SOpow_time_data');

%% Reconstruct power and phase data for each stage (N1, N2, N3, NREM, REM, WAKE)
electrode_inds = [3,1,7,5]; %'F3', 'C3', 'Pz', 'O1'
stage_select = [1,2,3,4,5];
night_select = [1,2];
issz_select = [];
freq_range = [4,35];
freq_cbins_length = length(freq_cbins((freq_cbins <= freq_range(2)) & (freq_cbins >= freq_range(1))));

num_elects = length(electrode_inds);

mean_powhists = zeros(num_elects, length(SOpow_cbins), freq_cbins_length);
mean_phasehists = zeros(num_elects, length(SOphase_cbins), freq_cbins_length);
all_PIBs = zeros(num_elects, length(SOpow_cbins), length(stage_select));

for ee = 1:num_elects
        
        e_use = electrode_inds(ee);

        [SOpow,TIB,~,~,~] = reconstruct_SOpowphase(SOpow_data{e_use}, SOpow_time_data{e_use}, SOpow_prop_data{e_use}, freq_cbins, 'pow', night_select, issz_select, ...
                                                 stage_select);
        [SOphase,~,~,~,~] = reconstruct_SOpowphase(SOphase_data{e_use}, SOphase_time_data{e_use}, SOphase_prop_data{e_use}, freq_cbins, 'phase', night_select, issz_select, ...
                                                 stage_select);
        
        mean_powhists(ee,:,:) = nanmean(SOpow, 1);
        mean_phasehists(ee,:,:) = nanmean(SOphase, 1);
        TIB_sums = squeeze(nansum(TIB,1));
        all_PIBs(ee,:,:) = TIB_sums ./ nansum(TIB_sums,2);
        
end

%% Plot SOpow
figure;
ax = figdesign(3,4,'type','usletter','orient','landscape', 'merge', {[5,9],[6,10],[7,11],[8,12]}, 'margins',[.08 .12 .05 .1 .02 .001]);
titles = {'F3', 'C3', 'Pz', 'O1'};

outerlabels(ax(5:8), 'Slow Oscillation Power (% normalized)', '', 'fontsize', 13)

new_freq_cbins = freq_cbins((freq_cbins <= freq_range(2)) & (freq_cbins >= freq_range(1)));

for ee = 1:num_elects
    
    elect_data = squeeze(all_PIBs(ee,:,:))*100;
    
    axes(ax(ee));
    plot(elect_data, 'linewidth',2);
    
    xticklabels([]);
    
    if ee ==1 
        ylabel('% Time');
    else
        yticklabels([]);
    end
    
    title(titles{ee})
        
end
legend('NREM3', 'NREM2', 'NREM1', 'REM', 'WAKE')

for ee = 5:8
    
    elect_data = squeeze(mean_powhists(ee-4,:,:));
    
    axes(ax(ee))
    
    imagesc(SOpow_cbins*100, new_freq_cbins, elect_data');
    axis xy;
    colormap parula
    caxis([0,2.4])
    
    if ee == 5
        ylabel('Frequency (Hz)');
    else
        yticklabels([]);
    end
    
    if ee == 8
        c = colorbar_noresize(ax(ee)); 
        outerlabels(ax(ee), '', 'Density (peaks/min in bin)', 'YAxisLocation', 'right')
    end
    
end

%% Plot SO phase

figure;
ax = figdesign(5,4,'type','usletter','orient','landscape', 'merge', {[1,5,9,13],[2,6,10,14],[3,7,11,15],[4,8,12,16]}, 'margins',[.08 .12 .05 .1 .02 .001]);
titles = {'F3', 'C3', 'Pz', 'O1'};

outerlabels(ax(5:8), 'Slow Oscillation Phase (radians)', '', 'fontsize', 13)

new_freq_cbins = freq_cbins((freq_cbins <= freq_range(2)) & (freq_cbins >= freq_range(1)));

for ee = 1:num_elects
    
    elect_data = squeeze(mean_phasehists(ee,:,:));
    
    axes(ax(ee));

    imagesc(SOphase_cbins, new_freq_cbins, elect_data');
    axis xy;
    colormap plasma;
    caxis([0.006, 0.01])
    xticklabels([]);
    title(titles{ee})

    
    if ee ==1 
        ylabel('Frequency (Hz)');
    else
        yticklabels([]);
    end
   
    if ee == 4
        c = colorbar_noresize(ax(ee)); 
        outerlabels(ax(ee), '', 'Proportion', 'YAxisLocation', 'right')
    end
        
end


x = -pi/2:0.1:pi/2;
y = cos(2.*x);
for ee = 5:8
    
    axes(ax(ee))
    
    plot(x,y)
    
    if ee ~= 5
        yticklabels([]);
    else
        yticklabels({'','+', '0', '-',''})
    end
    
    xticklabels({'-\pi/2', '0', '\pi/2'})
    
    hold on;
    hline(0, 'color', [0.5,0.5,0.5], 'linestyle', '--');


end





