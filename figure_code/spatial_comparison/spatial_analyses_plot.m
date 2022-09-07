function spatial_analyses_plot(SOpow_hists, SOphase_hists, SOpow_cbins, SOphase_cbins, freq_cbins, electrodes, ...
    freq_range, fsave_path, print_png, print_eps)
% Plot electrode hemisphere comparison and electrode spatial 2D histogram
% comparisons with regions of significant difference
%
%   Inputs:
%       SOpow_hists: 4D double - all SO power histograms [SOpow, freq, subj, electrode] --required
%       SOphase_hists: 4D double - all SO phase histograms [SOphase, freq, subj, electrode] --required
%       SOpow_cbins: 1D double - SOpower values of the bincenters used in
%                    powhists --required
%       SOphase_cbins: 1D double - SOphase values of the bincenters used in
%                      phasehists --required
%       freq_cbins: 1D double - frequnecy values of the bincenters for both
%                   SOpow_hists and SOphase_hists --required
%       electrodes: 1D cell array - electrode names (char). Default = ''
%       freq_range: ylims for the histogram plots. Default = [4,35]
%       fsave_path: char - path to save png/eps to
%       print_png: logical - save figure as png
%       pring_eps: logical - save figure as eps
%
%   Outputs:
%       None
%
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - Tom Possidente 1/03/2022
%%%************************************************************************************%%%%

%% Deal with Inputs
assert(nargin >= 5, '5 inputs required - SOpow_hists, SOphase_hists, SOpow_cbins, SOphase_cbins, freq_cbins');

if nargin < 6 || isempty(electrodes)
    elects = {repelem({''},size(SOpow_hists,3))};
end

if nargin < 7 || isempty(freq_range)
    freq_range = [4,35];
end

%% Get mean power and phase hists
mean_powhists = squeeze(mean(SOpow_hists,3,'omitnan'));
mean_phasehists = squeeze(mean(SOphase_hists,3,'omitnan'));

%% Run multicomparisons testing

% Redim
SOpow_resize = permute(SOpow_hists, [4,1,2,3]);
SOphase_resize = permute(SOphase_hists, [4,1,2,3]);

% Set false discovery rate
FDR = 0.1;

disp('Comptuting power differences...');
for ee1 = 1:length(electrodes)
    for ee2 = ee1:length(electrodes)
        if ee1 ~= ee2
            
            disp(['    ' electrodes{ee1} ' vs. '  electrodes{ee2} '...']);
            
            % Get difference between electrode histograms
            diff_pow{ee1,ee2} = mean_powhists(:,:,ee1) - mean_powhists(:,:,ee2);
            diff_pow{ee2,ee1} = mean_powhists(:,:,ee2) - mean_powhists(:,:,ee1);
            
            % Do ttest on all pixels using FDR to correct for multiple comparisons between dependent samples
            fdr_power{ee1,ee2} = fdr_bhtest2(squeeze(SOpow_resize(ee1,:,:,:)), squeeze(SOpow_resize(ee2,:,:,:)), ...
                'FDR', FDR, 'ploton', false);
            fdr_power{ee2,ee1} = fdr_power{ee1,ee2};
        end
    end
end

disp('Comptuting phase differences...');
for ee1 = 1:length(electrodes)
    for ee2 = ee1:length(electrodes)
        if ee1 ~= ee2
            disp(['    ' electrodes{ee1} ' vs. '  electrodes{ee2} '...']);

            % Get difference between electrode histograms
            diff_phase{ee1,ee2} = mean_phasehists(:,:,ee1) - mean_phasehists(:,:,ee2);
            diff_phase{ee2,ee1} = mean_phasehists(:,:,ee2) - mean_phasehists(:,:,ee1);
            
            % Do ttest on all pixels using FDR to correct for multiple comparisons between dependent samples
            fdr_phase{ee1,ee2} = fdr_bhtest2(squeeze(SOphase_resize(ee1,:,:,:)), squeeze(SOphase_resize(ee2,:,:,:)), 'FDR', FDR, 'ploton', false);
            fdr_phase{ee2,ee1} = fdr_phase{ee1,ee2};
        end
    end
end


%% Set plotting params

lhem = [3 1 7 5]; % left hemisphere elect inds
rhem = [4 2 7 6]; % right hemisphere elect inds
hem_use = lhem;
N = length(hem_use);

% Set limits for power and phase values
powlims = [0,1];
phaselims = [-pi, pi];

% Hardcode colormap limits for each type of plot
clims_pow = [1.398, 5.402]; %[1.5 10.5]; %[0 2.5] [0 9] [2, 16]
clims_phase = [0.0065    0.0089];%[0.04, 0.065];
clims_diffpow = [-1.5, 1.5];
clims_diffphase = [-.005 .006];

%% HEMISPHERE ANALYSIS

% Start power hemisphere analysis figure
f1 = figure;
ax = figdesign(3, N, 'type','usletter','orient','portrait','margins',[.05 .1 .1 .1 .04]);

for ee1 = 1:length(lhem)
    enum1 = lhem(ee1);
    ename1 = char(electrodes(enum1));
    enum2 = rhem(ee1);
    ename2 = char(electrodes(enum2));
    
    axes(ax(ee1))
    
    imagesc(SOpow_cbins, freq_cbins, mean_powhists(:,:,enum1)); % plot mean hist for electrode
    
    caxis(clims_pow);
    axis xy;
    ylim(freq_range);
    xlim(powlims)
    if ee1==1
        letter_label(gcf,gca,'A','left',30,[.01 .05]);
    end
    
    grid on
    title(ename1)
    if ee1==4 % create colorbar for row
        c = colorbar_noresize(ax(ee1));
        c.Label.String = {'Density', '(peaks/min in bin)'};
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
    end
    
    
    axes(ax(ee1 + N))
    imagesc(SOpow_cbins, freq_cbins, mean_powhists(:,:,enum2)); % plot mean hist for comparison electrode
    grid on
    climscale(false);
    caxis(clims_pow);
    axis xy;
    ylim(freq_range);
    xlim(powlims);
    
    if ee1==4
        c = colorbar_noresize(ax(ee1 + N));
        c.Label.String = {'Density', '(peaks/min in bin)'};
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
    end
    
    title(ename2)
    
    axes(ax(ee1 + N*2))
    if ee1 ~=3
        imagesc(SOpow_cbins, freq_cbins, diff_pow{enum1,enum2}); % plot electrode comparison difference
        hold on
        contour(SOpow_cbins, freq_cbins, abs(fdr_power{enum1,enum2}),[.95 .95],'color','k'); % highlight areas of significant difference
        
        axis xy;
        axis tight
        grid on
        caxis(clims_diffpow);
        colormap(gca,flipud(redbluemap(1024)))
        ylim(freq_range)
        xlim(powlims);
    end
    
    if ee1==4
        c = colorbar_noresize(ax(ee1 + N*2));
        c.Label.String = {'Density', '(peaks/min in bin)'};
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
    end
    
    
    
    title([ename1 ' - ' ename2]);
end
outerlabels(ax, '% Slow Oscillation Power', 'Frequency (Hz)')

% Start phase hemisphere analysis figure
phase_ticks = [-pi -pi/2 0 pi/2 pi];
phase_labels = {'-\pi','-\pi/2','0','\pi/2','\pi'};
f2 = figure;
ax = figdesign(3, N, 'type','usletter','orient','portrait','margins',[.05 .1 .1 .1 .04]);
for ee1 = 1:length(lhem)
    enum1 = lhem(ee1);
    ename1 = char(electrodes(enum1));
    enum2 = rhem(ee1);
    ename2 = char(electrodes(enum2));
    
    axes(ax(ee1))
    
    imagesc(SOphase_cbins, freq_cbins, mean_phasehists(:,:,enum1));
    
    climscale(false);
    colormap(ax(ee1),magma(2^12))
    caxis(clims_phase);
    axis xy;
    ylim(freq_range);
    xlim(phaselims);
    
    if ee1==1
        letter_label(gcf,gca,'B','left',30,[.01 .05]);
    end
    
    grid on
    title(ename1)
    if ee1==4
        c = colorbar_noresize(ax(ee1));
        c.Label.String = "Proportion";
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
    end
    
    
    axes(ax(ee1 + N))
    
    imagesc(SOphase_cbins, freq_cbins, mean_phasehists(:,:,enum2));
    grid on
    colormap(ax(ee1 + N),magma(2^12))
    caxis(clims_phase);
    axis xy;
    ylim(freq_range)
    xlim(phaselims);
    if ee1==4
        c = colorbar_noresize(ax(ee1 + N));
        c.Label.String = "Proportion";
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
    end
    
    
    title(ename2)
    
    axes(ax(ee1 + N*2))
    if ee1 ~=3
        imagesc(SOphase_cbins, freq_cbins, diff_phase{enum1,enum2});
        hold on
        contour(SOphase_cbins, freq_cbins, abs(fdr_phase{enum1,enum2}),[.95 .95],'color','k');
        
        axis xy;
        axis tight
        grid on
        
        caxis(clims_diffphase);
        colormap(ax(ee1 + N*2),flipud(redbluemap(1024)))
        ylim(freq_range)
        xlim(phaselims);
        
    end
    
    if ee1==4
        
        c = colorbar_noresize(ax(ee1 + N*2));
        c.Label.String = "Proportion";
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
    end
    
    
    title([ename1 ' - ' ename2]);
end
set(ax, 'xtick',phase_ticks,'xticklabel',phase_labels);
outerlabels(ax, 'Slow Oscillation Phase (rad)', 'Frequency (Hz)')

f_hem = mergefigures(f1,f2,.5,'LR',1); % merge power and phase hemisphere analysis figures into one figure
set(f_hem,'color','w','units','inches','position',[0 0 16 8.5], 'papertype','usletter','paperorientation','landscape');
orient landscape;
delete([f1 f2]); % delete unmerged figures

% Save out as eps and/or png if desired
if print_eps
    print(f_hem,'-depsc',fullfile(fsave_path,'EPS','spatial_comparison_hemisphere.eps'));
end

if print_png
    print(f_hem,'-dpng','-r300', fullfile(fsave_path,'PNG','spatial_comparison_hemisphere.png'));
end


%% SPATIAL COMPARISON
% Set up the electrodes
enums = hem_use;
N = length(enums);

% Plot power histogrram spatial comparisons
f3 = figure;
ax = figdesign(N+1, N+1, 'type','usletter','orient','portrait','margins',[.05 .05 .05 .08 .05]);
set(ax,'visible','off');

for ee1 = 1:length(enums)
    enum = enums(ee1);
    if ee1>1
        axes(ax(ee1))
        set(gca,'visible','on')
        imagesc(SOpow_cbins, freq_cbins, mean_powhists(:,:,enum));
        title(electrodes{enum})
        caxis(clims_pow);
        axis xy;
        ylim(freq_range);
        xlim(powlims);
        
           
    if ee1==2
        letter_label(gcf,gca,'A','left',30,[.01 .05]);
    end
        
        if ee1 ==4
            c = colorbar_noresize(ax(ee1));
            c.Label.String = {'Density', '(peaks/min in bin)'};
            c.Label.Rotation = -90;
            c.Label.VerticalAlignment = "bottom";
        end
        
    end
    
    if ee1<N
        axes(ax(ee1+1 + N*ee1 + N))
        set(gca,'visible','on')
        imagesc(SOpow_cbins, freq_cbins, mean_powhists(:,:,enum));
        title(electrodes{enum})
        caxis(clims_pow);
        axis xy;
        ylim(freq_range);
        xlim(powlims);
        set(ax(ee1+1 + N*ee1 + N),'YAxisLocation','right');
    end
end

%Plot difference hists for elects being compared
for ee2 = 1:length(enums)
    for ee1 = ee2+1:length(enums)
        
        enum1 = enums(ee1);
        ename1 = char(electrodes(enum1));
        enum2 = enums(ee2);
        ename2 = char(electrodes(enum2));
        if enum1 ~= enum2
            axes(ax(sub2ind([N+1,N+1],ee1,ee2+1)))
            set(gca,'visible','on')
            imagesc(SOpow_cbins, freq_cbins, diff_pow{enum1,enum2});
            hold on
            contour(SOpow_cbins, freq_cbins, abs(fdr_power{enum1,enum2}),[.95 .95],'color','k');
            
            axis xy;
            axis tight
            grid on
            
            caxis(clims_diffpow);
            colormap(gca,flipud(redbluemap(1024)))
            ylim(freq_range);
            xlim(powlims);
            if ee2==3
                c = colorbar_noresize(ax(sub2ind([N+1,N+1],ee1,ee2+1)),'westoutside');
                c.Label.String = {'Density', '(peaks/min in bin)'};
                c.Label.VerticalAlignment = "bottom";
            end
            title([ename1 ' - ' ename2]);
            
        end
    end
end
ax_good = ax([ax.Visible]=='on');
[~, h_yl, h_axbig] = outerlabels(ax_good, 'Slow Oscillation Phase (rad)', 'Frequency (Hz)');
h_axbig.YAxisLocation = 'right';
h_yl.Rotation = -90;


% Plot phase histogram spatial comparisons
f4 = figure;
ax = figdesign(N+1, N+1, 'type','usletter','orient','portrait','margins',[.05 .05 .05 .08 .05]);
set(ax,'visible','off');

phase_ticks = [-pi -pi/2 0 pi/2 pi];
phase_labels = {'-\pi','-\pi/2','0','\pi/2','\pi'};

% Plot mean histograms for each electrode
for ee1 = 1:length(enums)
    enum = enums(ee1);
    if ee1>1
        axes(ax(ee1))
        set(gca,'visible','on')
        imagesc(SOphase_cbins, freq_cbins, mean_phasehists(:,:,enum));
        title(electrodes{enum})
        caxis(clims_phase);
        axis xy;
        ylim(freq_range);
        xlim(phaselims);
        
        if ee1 ==4
            c = colorbar_noresize(ax(ee1));
            c.Label.String = 'Proportion';
            c.Label.Rotation = -90;
            c.Label.VerticalAlignment = "bottom";
        end
         if ee1==2
        letter_label(gcf,gca,'B','left',30,[.01 .05]);
    end
        
        set(gca, 'xtick',phase_ticks,'xticklabel',phase_labels);
        colormap(gca,magma(2^12));
    end
    
    if ee1<N
        axes(ax(ee1+1 + N*ee1 + N))
        set(gca,'visible','on')
        imagesc(SOphase_cbins, freq_cbins,  mean_phasehists(:,:,enum));
        title(electrodes{enum})
        caxis(clims_phase);
        axis xy;
        ylim(freq_range);
        xlim(phaselims);
        set(ax(ee1+1 + N*ee1 + N),'YAxisLocation','right');
        
        
        set(gca, 'xtick',phase_ticks,'xticklabel',phase_labels);
        colormap(gca,magma(2^12));
    end
    
    
end

%Plot difference hists for elects being compared
for ee2 = 1:length(enums)
    for ee1 = ee2+1:length(enums)
        enum1 = enums(ee1);
        ename1 = char(electrodes(enum1));
        enum2 = enums(ee2);
        ename2 = char(electrodes(enum2));
        
        axes(ax(sub2ind([N+1,N+1],ee1,ee2+1)))
        set(gca,'visible','on')
        imagesc(SOphase_cbins, freq_cbins, diff_phase{enum1,enum2});
        hold on
        contour(SOphase_cbins, freq_cbins, abs(fdr_phase{enum1,enum2}),[.95 .95],'color','k');
        set(gca, 'xtick',phase_ticks,'xticklabel',phase_labels);
        axis xy;
        axis tight
        grid on
        
        caxis(clims_diffphase);
        colormap(gca,flipud(redbluemap(1024)))
        ylim(freq_range);
        xlim(phaselims);
        
        
        if ee2==3
            c = colorbar_noresize(ax(sub2ind([N+1,N+1],ee1,ee2+1)), 'westoutside');
            c.Label.String = 'Proportion';
            c.Label.VerticalAlignment = "bottom";
        end
        title([ename1 ' - ' ename2]);
        
        
    end
end
ax_good = ax([ax.Visible]=='on');
[~, h_yl, h_axbig] = outerlabels(ax_good, 'Slow Oscillation Phase (rad)', 'Frequency (Hz)');
h_axbig.YAxisLocation = 'right';
h_yl.Rotation = -90;

f_elect = mergefigures(f3,f4,.5,'LR',1);
set(f_elect,'color','w','units','inches','position',[0 0 16 8.5], 'papertype','usletter','paperorientation','landscape');
orient('landscape');
delete([f3 f4]);

% Save eps and/or png out if desired
if print_eps
    print(f_elect,'-depsc',fullfile(fsave_path,'EPS','spatial_comparison.eps'));
end

if print_png
    print(f_elect,'-dpng','-r300', fullfile(fsave_path,'PNG','spatial_comparison.png'));
end
