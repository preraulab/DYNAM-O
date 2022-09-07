ccc; 

load('/data/preraugp/projects/transient_oscillations_paper/figure_ResultsAndData/spatial_comparison/archive/spatial_1000_night2.mat');

%% HEMISPHERE ANALYSIS
lhem = [3 1 7 5];
rhem = [4 2 7 6];
N = length(lhem);

close all
f1 = figure;
ax = figdesign(3, N, 'type','usletter','orient','portrait','margins',[.05 .05 .05 .1 .04]);
for ee1 = 1:length(lhem)
    enum1 = lhem(ee1);
    ename1 = char(electrodes(enum1));
    enum2 = rhem(ee1);
    ename2 = char(electrodes(enum2));
    
    axes(ax(ee1))
    
    imagesc(pow_bins, freqs, (nanmean(squeeze(pow_hists{enum1}),3))');
    
    cx = [.1 .55];
    caxis(cx);
    axis xy;
    ylim([4,35])
    
    grid on
    title(ename1)
    if ee1==4
        c = colorbar_noresize(ax(ee1));
                c.Label.String = 'Density (peaks/min/bin)';
    end
    
    
    axes(ax(ee1 + N))
    imagesc(pow_bins, freqs, (nanmean(squeeze(pow_hists{enum2}),3))');
    grid on
    climscale;
    caxis(cx);
    axis xy;
    ylim([4,35])
        
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
    imagesc(pow_bins, freqs, diff_pow{enum1,enum2});
    hold on
    contour(pow_bins, freqs, abs(gb_power{enum1,enum2})',[.95 .95],'color','k');
    
    axis xy;
    axis tight
    grid on
    diff_val=prctile(abs(diff_pow{enum1,enum2}(:)),95);
    caxis([-diff_val diff_val]);
    %caxis([-.15 .15]);
    colormap(gca,flipud(redbluemap(1024)))
    ylim([4,35])
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
    
    imagesc(phase_bins, freqs, (nanmean(squeeze(phase_hists{enum1}),3))');
    
    climscale;
    cx = [0.0092    0.0125];
    colormap(ax(ee1),plasma(2^12))
    caxis(cx);
    axis xy;
    ylim([4,35])
    
    grid on
    title(ename1)
    if ee1==4
        c = colorbar_noresize(ax(ee1));
        c.Label.String = "Proportion";
    end
    
    
    axes(ax(ee1 + N))
    
    imagesc(phase_bins, freqs, (nanmean(squeeze(phase_hists{enum2}),3))');
    grid on
    colormap(ax(ee1 + N),plasma(2^12))
    caxis(cx);
    axis xy;
    ylim([4,35])
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
    imagesc(phase_bins, freqs, diff_pow{enum1,enum2});
    hold on
    contour(phase_bins, freqs, abs(gb_phase{enum1,enum2})',[.95 .95],'color','k');
    
    axis xy;
    axis tight
    grid on
    diff_val=prctile(abs(diff_phase{enum1,enum2}(:)),95);
    caxis([-diff_val diff_val]);
    %caxis([-.15 .15]);
    colormap(ax(ee1 + N*2),flipud(redbluemap(1024)))
    ylim([4,35])
    
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
enums = [3 1 7 5];% 4 2 7 6];
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
        imagesc(pow_bins, freqs, (nanmean(squeeze(pow_hists{enum}),3))');
        title(electrodes{enum})
        cx = [.1 .55];
        caxis(cx);
        axis xy;
        ylim([4,35])
        
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
        imagesc(pow_bins, freqs, (nanmean(squeeze(pow_hists{enum}),3))');
        title(electrodes{enum})
        cx = [.1 .55];
        caxis(cx);
        axis xy;
        ylim([4,35])
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
        imagesc(pow_bins, freqs, diff_pow{enum1,enum2});
        hold on
        contour(pow_bins, freqs, abs(gb_power{enum1,enum2})',[.95 .95],'color','k');
        
        axis xy;
        axis tight
        grid on
        
        diff_val=prctile(abs(diff_pow{enum1,enum2}(:)),95);
        caxis([-diff_val diff_val]);
        %caxis([-.15 .15]);
        colormap(gca,flipud(redbluemap(1024)))
        ylim([4,35])
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

enums = [3 1 7 5];
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
        imagesc(phase_bins, freqs, (nanmean(squeeze(phase_hists{enum}),3))');
        title(electrodes{enum})
        cx = [0.0092    0.0125];
        caxis(cx);
        axis xy;
        ylim([4,35])
        
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
        imagesc(phase_bins, freqs, (nanmean(squeeze(phase_hists{enum}),3))');
        title(electrodes{enum})
        cx = [0.0092    0.0125];
        caxis(cx);
        axis xy;
        ylim([4,35])
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
        imagesc(phase_bins, freqs, diff_phase{enum1,enum2});
        hold on
        contour(phase_bins, freqs, abs(gb_phase{enum1,enum2})',[.95 .95],'color','k');
        set(gca, 'xtick',phase_ticks,'xticklabel',phase_labels);
        axis xy;
        axis tight
        grid on
        
        diff_val=prctile(abs(diff_phase{enum1,enum2}(:)),95);
        caxis([-diff_val diff_val]);
        %caxis([-.15 .15]);
        colormap(gca,flipud(redbluemap(1024)))
        ylim([4,35])
        
        
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


f_spat= mergefigures(f3,f4);
set(f_spat,'color','w','units','inches','position',[0 0 11 8.5]);



f_all= mergefigures(f_hem,f_spat,.5,'ud');
set(f_all,'color','w','units','inches','position',[0 0 11 8.5]);
