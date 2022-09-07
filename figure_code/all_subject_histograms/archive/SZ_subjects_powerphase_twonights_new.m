% Controls subjects individual power and phase plots
ccc;

%% Load SO power/phase data
load('/data/preraugp/projects/transient_oscillations_paper/results/SOpowphase_results/SOphase_data.mat', 'electrodes', 'freq_cbins', 'issz', 'SOphase_cbins', 'SOphase_data',...
                                                                                                         'SOphase_prop_data', 'SOphase_time_data', 'subjects');
load('/data/preraugp/projects/transient_oscillations_paper/results/SOpowphase_results/SOpow_data.mat', 'SOpow_cbins', 'SOpow_data', 'SOpow_prop_data', 'SOpow_time_data');


%% Reconstruct power and phase data for each stage (N1, N2, N3, NREM, REM, WAKE)
electrode_inds = [3,1,7,5]; %'F3', 'C3', 'Pz', 'O1'
stage_select = [1,2,3,4,5];
night_select = [1,2];
issz_select = true;
freq_range = [4,35];
freq_cbins_length = length(freq_cbins((freq_cbins <= freq_range(2)) & (freq_cbins >= freq_range(1))));
num_subjs = sum(issz);
subjects = subjects(sum(~issz)+1:end);
num_nights = length(night_select);

num_elects = length(electrode_inds);

powhists = zeros(num_elects, num_subjs*num_nights, length(SOpow_cbins), freq_cbins_length);
phasehists = zeros(num_elects, num_subjs*num_nights, length(SOphase_cbins), freq_cbins_length);

for ee = 1:num_elects
        
        e_use = electrode_inds(ee);

        [SOpow,~,~,~,night_out] = reconstruct_SOpowphase(SOpow_data{e_use}, SOpow_time_data{e_use}, SOpow_prop_data{e_use}, freq_cbins, 'pow', night_select, issz_select, ...
                                                 stage_select);
        [SOphase,~,~,~,~] = reconstruct_SOpowphase(SOphase_data{e_use}, SOphase_time_data{e_use}, SOphase_prop_data{e_use}, freq_cbins, 'phase', night_select, issz_select, ...
                                                 stage_select);
        
        powhists(ee,:,:,:) = SOpow;
        phasehists(ee,:,:,:) = SOphase;
        
end


%%


hists{1} = SOpow;
x_hist{1} = SOpow_cbins;

hists{2} = SOphase;
x_hist{2} = SOphase_cbins;

N_plots = num_subjs*num_nights;

M = 6;
N = 8;

subject = reshape([1:num_subjs; 1:num_subjs], 1, 2*num_subjs);
night = repmat(1:2, 1, num_subjs);

plot_type = {'Slow Oscillation Power','Slow Oscillation Phase'};

for ee = 1:num_elects
    plot_hists{1} = squeeze(powhists(ee,:,:,:));
    plot_hists{2} = squeeze(phasehists(ee,:,:,:));
    
    for pp = 1:length(plot_type)
        
        clims = prctile(plot_hists{pp}(:),[5 98]);
        
        f(pp) = figure;%('units','normalized','position',[0 0 1 1]);
        ax = figdesign(M,N,'type','usletter','orient','landscape','margin',[.05 .05 .05 .01 .03 .04]);
        delete(ax(N_plots+1:end));
        ax = ax(1:N_plots);
        
        for ii = 1:N_plots
            
            axes(ax(ii));
            hist_mat = squeeze(plot_hists{pp}(ii,:,:))';
            
            if any(~isnan(hist_mat(:)))
                imagesc(x_hist{pp},freq_cbins,hist_mat);
                axis xy;
                
                if pp == 1
                    caxis(clims);
                else
                    caxis(clims);
                end
                
                grid on;
                
                if pp==1
                    set(ax(ii), 'xtick', 0:.25:1,'xticklabel',{'0' '25' '50' '75' '100'});
                    colormap(ax(ii), parula(2^12));
                else
                    set(ax(ii), 'xtick', [-pi/2, 0, pi/2], 'xticklabel', {'-\pi/2', '0', '\pi/2'});
                    colormap(ax(ii), plasma(2^12));
                end
                
                if ii == N_plots
                    set(ax(ii),'tag','cbar');
                    c = colorbar(ax(ii),'EastOutside');
                    c.Position(1) = c.Position(1)+.06;
                end
                
                title(['S' num2str(subjects(subject(ii))) ' Night ' num2str(night(ii))],'fontsize',10);
                
                [col, row] = ind2sub([N,M],ii);
                
                
                if col ~= 1
                    set(ax(ii),'yticklabel', []);
                end
                
                if ~(row == M || (row == M-1 && col>2))
                    set(ax(ii),'xticklabel', []);
                end
                
                if row == ceil(M/2) && col ==1
                    ylabel('Frequency (Hz)','fontsize',14);
                end
                
                if col == ceil(N/2) && row == M-1
                    if pp == 1
                        xlabel('Slow Oscillation Power (%)','fontsize',12);
                    else
                        xlabel('Slow Oscillation Phase (rad)','fontsize',12);
                    end
                end
                
            else
                axis off;
            end
        end
    end
    
    %Merge into a big figure
    new_fig = mergefigures(f(2), f(1), .5, 'UD');
    close(f(1));
    close(f(2));
    drawnow;
    pause(1);
    
    %Make the nights closer to each other
    a = findobj(gcf,'Type','Axes');
    for ii = 1:2:length(a);a(ii).Position(1) = a(ii).Position(1)+.01; end
    for ii = 2:2:length(a);a(ii).Position(1) = a(ii).Position(1)-.01; end
    
    %Add super title
    suptitle(['Controls: Electrode ' electrodes{electrode_inds(ee)}]);
    
    %Add colorbars
    cax = findall(new_fig,'tag','cbar');
    c = colorbar(cax(1),'location','eastoutside');
    c.Position(1) = c.Position(1)+.06;
    c = colorbar(cax(2),'EastOutside');
    c.Position(1) = c.Position(1)+.06;
    
    %print(new_fig,'-depsc', [electrodes{electrode_inds(ee)} '-powerphasehists_plasma.eps']);
end