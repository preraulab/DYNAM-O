
ccc; 
%% Load SO power/phase data
load('/data/preraugp/projects/transient_oscillations_paper/results/SOpowphase_results/SOphase_data_smallbins.mat', 'electrodes', 'freq_cbins', 'issz', 'SOphase_cbins', 'SOphase_data',...
                                                                                                         'SOphase_prop_data', 'SOphase_time_data', 'subjects');
load('/data/preraugp/projects/transient_oscillations_paper/results/SOpowphase_results/SOpow_data_smallbins.mat', 'SOpow_cbins', 'SOpow_data', 'SOpow_prop_data', 'SOpow_time_data');

electrodes = electrodes(1:7); % not using last electrode (x1)

%% Reconstruct power and phase data for each stage (N1, N2, N3, NREM, REM, WAKE)
electrode_inds = [1,2,3,4,5,6,7]; 
stage_select = [1,2,3,4,5];
night_select = [2];
issz_select = false;
freq_range = [4,25];
freq_cbins_length = length(freq_cbins((freq_cbins <= freq_range(2)) & (freq_cbins >= freq_range(1))));
num_subjs = sum(~issz);
num_nights = length(night_select);

num_elects = length(electrode_inds);

powhists = zeros(num_elects, num_subjs*num_nights, length(SOpow_cbins), freq_cbins_length);
phasehists = zeros(num_elects, num_subjs*num_nights, length(SOphase_cbins), freq_cbins_length);

TIBpow = zeros(num_elects, num_subjs*num_nights,length(SOpow_cbins));
TIBphase = zeros(num_elects, num_subjs*num_nights,length(SOphase_cbins));

count_flag = true;

for ee = 1:num_elects
        
        e_use = electrode_inds(ee);

        [SOpow,freqcbins_new,TIBpow_allstages,issz_out,~,night_out] = reconstruct_SOpowphase(SOpow_data{e_use}, SOpow_time_data{e_use},...
                                                                       SOpow_prop_data{e_use}, freq_cbins, 'pow', night_select,...
                                                                       issz_select, stage_select, 0, freq_range, [], count_flag);

        [SOphase,~,TIBphase_allstages,~,~] = reconstruct_SOpowphase(SOphase_data{e_use}, SOphase_time_data{e_use}, SOphase_prop_data{e_use},...
                                               freq_cbins, 'phase', night_select, issz_select, stage_select, 0, freq_range, [], count_flag);
        
        powhists(ee,:,:,:) = SOpow;
        phasehists(ee,:,:,:) = SOphase;
        
        TIBpow(ee,:,:) = sum(TIBpow_allstages,3);
        TIBphase(ee,:,:) = sum(TIBphase_allstages,3);
        
end


%% Resize Data
freq_binsizestep = [1, 0.2]; % [0.5, 0.1] [2,0.5] [3,1] [4,2]
SOpow_binsizestep = [0.2, 0.01]; % [0.05, 0.01] [0.2, 0.05]
SOphase_binsizestep = [(2*pi)/(5), (2*pi)/100]; %[(2*pi)/(400/67), (2*pi)/(400/3)] [(2*pi)/10, (2*pi)/20]

powhists_re = permute(powhists, [1,4,3,2]);
phasehists_re = permute(phasehists, [1,4,3,2]);

[SOpow_resizeC3, freqcbins_resize, SOpowcbins_resize] = rebin_histogram(squeeze(powhists_re(1,:,:,:)), squeeze(TIBpow(1,:,:)), freqcbins_new,...
                                                                        SOpow_cbins, freq_binsizestep, SOpow_binsizestep, 'pow', 0, true,...
                                                                        false, 1);
                                                                  
[SOphase_resizeC3, ~, SOphasecbins_resize] = rebin_histogram(squeeze(phasehists_re(1,:,:,:)), squeeze(TIBphase(1,:,:)), freqcbins_new, ...
                                                             SOphase_cbins, freq_binsizestep, SOphase_binsizestep, 'phase', 'circular',...
                                                             true, true, 0);
      
SOpow_resize = zeros(num_elects, num_subjs*num_nights, length(freqcbins_resize), length(SOpowcbins_resize));
SOpow_resize(1,:,:,:) = SOpow_resizeC3;

SOphase_resize = zeros(num_elects, num_subjs*num_nights, length(freqcbins_resize), length(SOphasecbins_resize));
SOphase_resize(1,:,:,:) = SOphase_resizeC3;

for ee = 2:num_elects
    [SOpow_resize(ee,:,:,:), ~, ~] = rebin_histogram(squeeze(powhists_re(ee,:,:,:)), squeeze(TIBpow(ee,:,:)), freqcbins_new, SOpow_cbins,...
                                                     freq_binsizestep, SOpow_binsizestep, 'pow', 0, true, false, 1);

    [SOphase_resize(ee,:,:,:), ~, ~] = rebin_histogram(squeeze(phasehists_re(ee,:,:,:)), squeeze(TIBphase(ee,:,:)), freqcbins_new,...
                                                       SOphase_cbins, freq_binsizestep, SOphase_binsizestep, 'phase', 'circular', true,...
                                                       true, 0);
end

%% Get mean poer and phase hists
mean_powhists = squeeze(nanmean(SOpow_resize,2));
mean_phasehists = squeeze(nanmean(SOphase_resize,2));

%% Run multicomparisons testing
 
SOpow_resize = permute(SOpow_resize, [1,3,4,2]);
SOphase_resize = permute(SOphase_resize, [1,3,4,2]);

test_type = 'FDR';

switch test_type
 case 'FDR'
     iterations = false;
     FDR = 0.1;
 case 'gperm'
     iterations = 500;
     alpha_level = 0.05;
 case 'perm'
     iterations = 500;
    alpha_level = 0.05;
end


disp('Comptuting power differences...');

for ee1 = 1:length(electrodes)
    for ee2 = ee1:length(electrodes)
        if ee1 ~= ee2

            disp(['    ' electrodes{ee1} ' vs. '  electrodes{ee2} '...']);

            diff_pow{ee1,ee2} = squeeze(mean_powhists(ee1,:,:)) - squeeze(mean_powhists(ee2,:,:));
            diff_pow{ee2,ee1} = squeeze(mean_powhists(ee2,:,:)) - squeeze(mean_powhists(ee1,:,:));

            tic
            gb_power{ee1,ee2} = fdr_bhtest2(squeeze(SOpow_resize(ee1,:,:,:)), squeeze(SOpow_resize(ee2,:,:,:)), 'FDR', FDR, 'ploton', false);
            %gb_power{ee1,ee2} = permtest2(squeeze(powhists(ee1,:,:,:)), squeeze(powhists(ee2,:,:,:)), alpha_level, iterations, false);
            %gb_power{ee1,ee2} = gpermtest2(squeeze(powhists(ee1,:,:,:)), squeeze(powhists(ee2,:,:,:)), alpha_level, [], iterations, false);
            toc
            gb_power{ee2,ee1} = gb_power{ee1,ee2};
        end
end
end

disp('Comptuting phase differences...');
for ee1 = 1:length(electrodes)
    for ee2 = ee1:length(electrodes)
        if ee1 ~= ee2
            disp(['    ' electrodes{ee1} ' vs. '  electrodes{ee2} '...']);

            diff_phase{ee1,ee2} = squeeze(mean_phasehists(ee1,:,:)) - squeeze(mean_phasehists(ee2,:,:));
            diff_phase{ee2,ee1} = squeeze(mean_phasehists(ee2,:,:)) - squeeze(mean_phasehists(ee1,:,:));

            tic
            gb_phase{ee1,ee2} = fdr_bhtest2(squeeze(SOphase_resize(ee1,:,:,:)), squeeze(SOphase_resize(ee2,:,:,:)), 'FDR', FDR, 'ploton', false);
            %gb_phase{ee1,ee2} = permtest2(squeeze(phasehists(ee1,:,:,:)), squeeze(phasehists(ee2,:,:,:)), alpha_level, iterations, false);
            %gb_phase{ee1,ee2} = gpermtest2(squeeze(phasehists(ee1,:,:,:)),squeeze(phasehists(ee2,:,:,:)), alpha_level, [], iterations, false);
            toc
            gb_phase{ee2,ee1} = gb_phase{ee1,ee2};
        end
    end
end


%% Set plotting params

lhem = [3 1 7 5];
rhem = [4 2 7 6];
hem = lhem;
N = length(hem);

powlims = [0,1];
phaselims = [-pi, pi];

clims_pow = [0.8, 4.7]; %[1.5 10.5]; %[0 2.5] [0 9] [2, 16]
clims_phase = [0.0088, 0.0116];%[0.04, 0.065];
clims_diffpow = [-1.5, 1.5];
clims_diffphase = [-.005 .006];

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
    
    imagesc(SOpowcbins_resize, freqcbins_resize, squeeze(mean_powhists(enum1,:,:)));
    
    caxis(clims_pow);
    axis xy;
    ylim(freq_range);
    xlim(powlims)
    
    grid on
    title(ename1)
    if ee1==4
        c = colorbar_noresize(ax(ee1));
        c.Label.String = 'Density (peaks/min/bin)';
    end
    
    
    axes(ax(ee1 + N))
    imagesc(SOpowcbins_resize, freqcbins_resize, squeeze(mean_powhists(enum2,:,:)));
    grid on
    climscale;
    caxis(clims_pow);
    axis xy;
    ylim(freq_range);
    xlim(powlims);
        
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
        imagesc(SOpowcbins_resize, freqcbins_resize, diff_pow{enum1,enum2});
        hold on
        contour(SOpowcbins_resize, freqcbins_resize, abs(gb_power{enum1,enum2}),[.95 .95],'color','k');

        axis xy;
        axis tight
        grid on
        %diff_val=prctile(abs(diff_pow{enum1,enum2}(:)),95);
        %caxis([-diff_val diff_val]);
        caxis(clims_diffpow);
        colormap(gca,flipud(redbluemap(1024)))
        ylim(freq_range)
        xlim(powlims);
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
    
    imagesc(SOphasecbins_resize, freqcbins_resize, squeeze(mean_phasehists(enum1,:,:)));
    
    climscale;
    colormap(ax(ee1),plasma(2^12))
    caxis(clims_phase);
    axis xy;
    ylim(freq_range);
    xlim(phaselims);
    
    grid on
    title(ename1)
    if ee1==4
        c = colorbar_noresize(ax(ee1));
        c.Label.String = "Proportion";
    end
    
    
    axes(ax(ee1 + N))
    
    imagesc(SOphasecbins_resize, freqcbins_resize, squeeze(mean_phasehists(enum2,:,:)));
    grid on
    colormap(ax(ee1 + N),plasma(2^12))
    caxis(clims_phase);
    axis xy;
    ylim(freq_range)
    xlim(phaselims);
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
    imagesc(SOphasecbins_resize, freqcbins_resize, diff_phase{enum1,enum2});
    hold on
    contour(SOphasecbins_resize, freqcbins_resize, abs(gb_phase{enum1,enum2}),[.95 .95],'color','k');
    
    axis xy;
    axis tight
    grid on
    %diff_val=prctile(abs(diff_phase{enum1,enum2}(:)),95);
    %caxis([-diff_val diff_val]);
    caxis(clims_diffphase);
    colormap(ax(ee1 + N*2),flipud(redbluemap(1024)))
    ylim(freq_range)
    xlim(phaselims);
    
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
        imagesc(SOpowcbins_resize, freqcbins_resize, squeeze(mean_powhists(enum,:,:)));
        title(electrodes{enum})
        caxis(clims_pow);
        axis xy;
        ylim(freq_range);
        xlim(powlims);
        
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
        imagesc(SOpowcbins_resize, freqcbins_resize, squeeze(mean_powhists(enum,:,:)));
        title(electrodes{enum})
        caxis(clims_pow);
        axis xy;
        ylim(freq_range);
        xlim(powlims);
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
            imagesc(SOpowcbins_resize, freqcbins_resize, diff_pow{enum1,enum2});
            hold on
            contour(SOpowcbins_resize, freqcbins_resize, abs(gb_power{enum1,enum2}),[.95 .95],'color','k');

            axis xy;
            axis tight
            grid on

            %diff_val=prctile(abs(diff_pow{enum1,enum2}(:)),95);
            %caxis([-diff_val diff_val]);
            caxis(clims_diffpow);
            colormap(gca,flipud(redbluemap(1024)))
            ylim(freq_range);
            xlim(powlims);
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
        imagesc(SOphasecbins_resize, freqcbins_resize, squeeze(mean_phasehists(enum,:,:)));
        title(electrodes{enum})
        caxis(clims_phase);
        axis xy;
        ylim(freq_range);
        xlim(phaselims);
        
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
        imagesc(SOphasecbins_resize, freqcbins_resize,  squeeze(mean_phasehists(enum,:,:)));
        title(electrodes{enum})
        caxis(clims_phase);
        axis xy;
        ylim(freq_range);
        xlim(phaselims);
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
        imagesc(SOphasecbins_resize, freqcbins_resize, diff_phase{enum1,enum2});
        hold on
        contour(SOphasecbins_resize, freqcbins_resize, abs(gb_phase{enum1,enum2}),[.95 .95],'color','k');
        set(gca, 'xtick',phase_ticks,'xticklabel',phase_labels);
        axis xy;
        axis tight
        grid on
        
        %diff_val=prctile(abs(diff_phase{enum1,enum2}(:)),95);
        %caxis([-diff_val diff_val]);
        caxis(clims_diffphase);
        colormap(gca,flipud(redbluemap(1024)))
        ylim(freq_range);
        xlim(phaselims);
        
        
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
