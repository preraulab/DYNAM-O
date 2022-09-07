
ccc; 
%% Load SO power/phase data
load('/data/preraugp/projects/transient_oscillations_paper/results/SOpowphase_results/SOphase_data_orig.mat', 'electrodes', 'freq_cbins', 'issz', 'SOphase_cbins', 'SOphase_data',...
                                                                                                         'SOphase_prop_data', 'SOphase_time_data', 'subjects');
load('/data/preraugp/projects/transient_oscillations_paper/results/SOpowphase_results/SOpow_data_orig.mat', 'SOpow_cbins', 'SOpow_data', 'SOpow_prop_data', 'SOpow_time_data');


%% Reconstruct power and phase data for each stage (N1, N2, N3, NREM, REM, WAKE)
electrode_inds = [1,2,3,4,5,6,7]; 
stage_select = [1,2,3,4,5];
night_select = [2];
issz_select = false;
freq_range = [4,35];
freq_cbins_length = length(freq_cbins((freq_cbins <= freq_range(2)) & (freq_cbins >= freq_range(1))));
num_subjs = sum(~issz);
num_nights = length(night_select);

num_elects = length(electrode_inds);

powhists = zeros(num_elects, num_subjs*num_nights, length(SOpow_cbins), freq_cbins_length);
phasehists = zeros(num_elects, num_subjs*num_nights, length(SOphase_cbins), freq_cbins_length);

for ee = 1:num_elects
        
        e_use = electrode_inds(ee);

        [SOpow,~,~,~,night_out] = reconstruct_SOpowphase(SOpow_data{e_use}, SOpow_time_data{e_use}, SOpow_prop_data{e_use}, freq_cbins, 'pow', night_select, issz_select, ...
                                                 stage_select, [], freq_range);
        [SOphase,~,~,~,~] = reconstruct_SOpowphase(SOphase_data{e_use}, SOphase_time_data{e_use}, SOphase_prop_data{e_use}, freq_cbins, 'phase', night_select, issz_select, ...
                                                 stage_select, [], freq_range);
        
        powhists(ee,:,:,:) = SOpow;
        phasehists(ee,:,:,:) = SOphase;
        
end

mean_powhists = squeeze(nanmean(powhists,2));
mean_phasehists = squeeze(nanmean(phasehists,2));
 
%% Load permutation test results
load('/data/preraugp/projects/transient_oscillations_paper/figure_ResultsAndData/spatial_comparison/spatial_1_night2_pairedFDR_01.mat', 'gb_power', 'gb_phase', ...
     'diff_pow', 'diff_phase')

lhem = [3 1 7 5];
rhem = [4 2 7 6];
hem = lhem;
N = length(hem);

clims_pow = [0, 2.4];
clims_phase = [0.006, 0.01];
clims_diffpow = [-1.5, 1.5];
clims_diffphase = [-.002 .002];

freq_range = [4,35];
new_freq_cbins = freq_cbins((freq_cbins <= freq_range(2)) & (freq_cbins >= freq_range(1))); 


%% HEMISPHERE ANALYSIS

%close all
f1 = figure;
ax = figdesign(3, N, 'type','usletter','orient','portrait','margins',[.05 .05 .05 .1 .04]);
for ee1 = 1:length(lhem)
    enum1 = lhem(ee1);
    ename1 = char(electrodes(enum1));
    enum2 = rhem(ee1);
    ename2 = char(electrodes(enum2));
    
    axes(ax(ee1))
    
    imagesc(SOpow_cbins, new_freq_cbins, squeeze(mean_powhists(enum1,:,:))');
    
    caxis(clims_pow);
    axis xy;
    ylim(freq_range)
    
    grid on
    title(ename1)
    if ee1==4
        c = colorbar_noresize(ax(ee1));
                c.Label.String = 'Density (peaks/min/bin)';
    end
    
    
    axes(ax(ee1 + N))
    imagesc(SOpow_cbins, new_freq_cbins, squeeze(mean_powhists(enum2,:,:))');
    grid on
    climscale;
    caxis(clims_pow);
    axis xy;
    ylim(freq_range)
        
    if ee1==4
        c = colorbar_noresize(ax(ee1 + N));
        c.Label.String = 'Density (peaks/min/bin)';
    end
    
    title(ename2)
    if ee1==1
        ylabel('Frequency (Hz)');
    end
    
    axes(ax(ee1 + N*2))
    if ee1 ~=3
    imagesc(SOpow_cbins, new_freq_cbins, diff_pow{enum1,enum2}');
    hold on
    contour(SOpow_cbins, new_freq_cbins, abs(gb_power{enum1,enum2})',[.95 .95],'color','k');
    
    axis xy;
    axis tight
    grid on
    %diff_val=prctile(abs(diff_pow{enum1,enum2}(:)),95);
    %caxis([-diff_val diff_val]);
    caxis(clims_diffpow);
    colormap(gca,flipud(redbluemap(1024)))
    ylim(freq_range)
    end
    
    if ee1==4
        c = colorbar_noresize(ax(ee1 + N*2));
          c.Label.String = 'Density (peaks/min/bin)';
    end

    title([ename1 ' - ' ename2]);
    xlabel('%SO-Power');
end

phase_ticks = [-pi -pi/2 0 pi/2 pi];
phase_labels = {'-\pi','-\pi/2','0','\pi/2','\pi'};
f2 = figure;
ax = figdesign(3, N, 'type','usletter','orient','portrait','margins',[.05 .05 .05 .1 .04]);
for ee1 = 1:length(lhem)
    enum1 = lhem(ee1);
    ename1 = char(electrodes(enum1));
    enum2 = rhem(ee1);
    ename2 = char(electrodes(enum2));
    
    axes(ax(ee1))
    
    imagesc(SOphase_cbins, new_freq_cbins, squeeze(mean_phasehists(enum1,:,:))');
    
    climscale;
    colormap(ax(ee1),plasma(2^12))
    caxis(clims_phase);
    axis xy;
    ylim(freq_range)
    
    grid on
    title(ename1)
    if ee1==4
        c = colorbar_noresize(ax(ee1));
        c.Label.String = "Proportion";
    end
    
    
    axes(ax(ee1 + N))
    
    imagesc(SOphase_cbins, new_freq_cbins, squeeze(mean_phasehists(enum2,:,:))');
    grid on
    colormap(ax(ee1 + N),plasma(2^12))
    caxis(clims_phase);
    axis xy;
    ylim(freq_range)
    if ee1==4 
        c = colorbar_noresize(ax(ee1 + N));
        c.Label.String = "Proportion";
    end
    
    
    title(ename2)
    if ee1==1
        ylabel('Frequency (Hz)');
    end
    
    axes(ax(ee1 + N*2))
    if ee1 ~=3
    imagesc(SOphase_cbins, new_freq_cbins, diff_phase{enum1,enum2}');
    hold on
    contour(SOphase_cbins, new_freq_cbins, abs(gb_phase{enum1,enum2})',[.95 .95],'color','k');
    
    axis xy;
    axis tight
    grid on
    %diff_val=prctile(abs(diff_phase{enum1,enum2}(:)),95);
    %caxis([-diff_val diff_val]);
    caxis(clims_diffphase);
    colormap(ax(ee1 + N*2),flipud(redbluemap(1024)))
    ylim(freq_range)
    
    end
    
    if ee1==4
        
        c = colorbar_noresize(ax(ee1 + N*2));
        c.Label.String = "Proportion";
    end
    
    
    title([ename1 ' - ' ename2]);
    xlabel('Phase (rad)');
end
set(ax, 'xtick',phase_ticks,'xticklabel',phase_labels);

f_hem = mergefigures(f1,f2);
set(f_hem,'color','w','units','inches','position',[0 0 11 8.5]);

%% SPATIAL COMPARISON
% Set up the electrodes
enums = hem; %[3 1 7 5];% 4 2 7 6];
N = length(enums);

f3 = figure;
ax = figdesign(N+1, N+1, 'type','usletter','orient','portrait','margins',[.05 .05 .05 .08 .05]);
set(ax,'visible','off');

%Get the averages on the rows/cols
for ee1 = 1:length(enums)
    enum = enums(ee1);
    if ee1>1
        axes(ax(ee1))
        set(gca,'visible','on')
        imagesc(SOpow_cbins, new_freq_cbins, squeeze(mean_powhists(enum,:,:))');
        title(electrodes{enum})
        caxis(clims_pow);
        axis xy;
        ylim(freq_range)
        
        if ee1 == 2
            ylabel('Frequency (Hz)');
        end
        
        if ee1 ==4
            c = colorbar_noresize(ax(ee1));
            %c.FontSize = 8;
            %             c = colorbar('location','east');
            %             c.Position(1) = c.Position(1) + .08;
            %             %c.FontSize = 8;
            c.Label.String = 'Density (peaks/min/bin)';
        end
        
    end
    
    if ee1<N
        axes(ax(ee1+1 + N*ee1 + N))
        set(gca,'visible','on')
        imagesc(SOpow_cbins, new_freq_cbins, squeeze(mean_powhists(enum,:,:))');
        title(electrodes{enum})
        caxis(clims_pow);
        axis xy;
        ylim(freq_range)
        set(ax(ee1+1 + N*ee1 + N),'YAxisLocation','right');
        ylabel('Frequency (Hz)');
    end
end

%Plot the differences
for ee2 = 1:length(enums)
    for ee1 = ee2+1:length(enums)
    
        enum1 = enums(ee1);
        ename1 = char(electrodes(enum1));
        enum2 = enums(ee2);
        ename2 = char(electrodes(enum2));
            if enum1 ~= enum2
        axes(ax(sub2ind([N+1,N+1],ee1,ee2+1)))
        set(gca,'visible','on')
        imagesc(SOpow_cbins, new_freq_cbins, diff_pow{enum1,enum2}');
        hold on
        contour(SOpow_cbins, new_freq_cbins, abs(gb_power{enum1,enum2})',[.95 .95],'color','k');
        
        axis xy;
        axis tight
        grid on
        
        %diff_val=prctile(abs(diff_pow{enum1,enum2}(:)),95);
        %caxis([-diff_val diff_val]);
        caxis(clims_diffpow);
        colormap(gca,flipud(redbluemap(1024)))
        ylim(freq_range)
        if ee2==3
            c = colorbar_noresize(ax(sub2ind([N+1,N+1],ee1,ee2+1)),'westoutside');
            c.Label.String = 'Density (peaks/min/bin)';
        end
        title([ename1 ' - ' ename2]);
        
        if ee1 == ee2+1
            xlabel('%SO-Power');
        end
        
        end
    end
end

%%

enums = hem;
N = length(enums);

f4 = figure;
ax = figdesign(N+1, N+1, 'type','usletter','orient','portrait','margins',[.05 .05 .05 .08 .05]);
set(ax,'visible','off');

phase_ticks = [-pi -pi/2 0 pi/2 pi];
phase_labels = {'-\pi','-\pi/2','0','\pi/2','\pi'};

%Get the averages on the rows/cols
for ee1 = 1:length(enums)
    enum = enums(ee1);
    if ee1>1
        axes(ax(ee1))
        set(gca,'visible','on')
        imagesc(SOphase_cbins, new_freq_cbins, squeeze(mean_phasehists(enum,:,:))');
        title(electrodes{enum})
        caxis(clims_phase);
        axis xy;
        ylim(freq_range)
        
        if ee1 == 2
            ylabel('Frequency (Hz)');
        end
        
        if ee1 ==4
            c = colorbar_noresize(ax(ee1));
            c.Label.String = 'Proportion';
        end
        
        
        set(gca, 'xtick',phase_ticks,'xticklabel',phase_labels);
        colormap(gca,plasma(2^12));
    end
    
    if ee1<N
        axes(ax(ee1+1 + N*ee1 + N))
        set(gca,'visible','on')
        imagesc(SOphase_cbins, new_freq_cbins,  squeeze(mean_phasehists(enum,:,:))');
        title(electrodes{enum})
        caxis(clims_phase);
        axis xy;
        ylim(freq_range)
        set(ax(ee1+1 + N*ee1 + N),'YAxisLocation','right');
        ylabel('Frequency (Hz)');
        
        set(gca, 'xtick',phase_ticks,'xticklabel',phase_labels);
        colormap(gca,plasma(2^12));
    end
    
    
end

%Plot the differences
for ee2 = 1:length(enums)
    for ee1 = ee2+1:length(enums)
        enum1 = enums(ee1);
        ename1 = char(electrodes(enum1));
        enum2 = enums(ee2);
        ename2 = char(electrodes(enum2));
        
        axes(ax(sub2ind([N+1,N+1],ee1,ee2+1)))
        set(gca,'visible','on')
        imagesc(SOphase_cbins, new_freq_cbins, diff_phase{enum1,enum2}');
        hold on
        contour(SOphase_cbins, new_freq_cbins, abs(gb_phase{enum1,enum2})',[.95 .95],'color','k');
        set(gca, 'xtick',phase_ticks,'xticklabel',phase_labels);
        axis xy;
        axis tight
        grid on
        
        %diff_val=prctile(abs(diff_phase{enum1,enum2}(:)),95);
        %caxis([-diff_val diff_val]);
        caxis(clims_diffphase);
        colormap(gca,flipud(redbluemap(1024)))
        ylim(freq_range)
        
        
        if ee2==3
            c = colorbar_noresize(ax(sub2ind([N+1,N+1],ee1,ee2+1)), 'westoutside');
             c.Label.String = 'Proportion';
        end
        title([ename1 ' - ' ename2]);
        
        if ee1 == ee2+1
            xlabel('Phase (rad)');
        end
        
        
    end
end


% f_spat= mergefigures(f3,f4);
% set(f_spat,'color','w','units','inches','position',[0 0 11 8.5]);
% 
% 
% 
% f_all= mergefigures(f_hem,f_spat,.5,'ud');
% set(f_all,'color','w','units','inches','position',[0 0 11 8.5]);
