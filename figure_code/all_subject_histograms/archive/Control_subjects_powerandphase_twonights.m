% Controls all subjects individual power and phase plots
%ccc

base =  '/data/preraugp/projects/transient_oscillations/code/Lunesta histograms over time/';

% load([base 'electrode_hists_SW_power_dB_percentLightsOutNoArtifact_compChans_20181207_checkMismatchWithNewCount.mat']);
load([base 'electrode_hists_SW_power_dB_percentLightsOutNoArtifact_compNights_20190102_nights1and2.mat']);
hists{1} = electrode_hists;
x_hist{1} = SWF_bins;

% load([base 'electrode_hists_SW_phase_perSubj_compChans_20181107.mat']);
load([base 'electrode_hists_SW_phase_perSubj_compNights_20190117_nights1and2_all.mat']);

hists{2} = electrode_hists;
x_hist{2} = SWF_bins;

num_subs = 17;
num_nights = 2;
N_plots = num_subs*num_nights;
jump = 40;

M = 5;
N = 8;

subject = reshape([1:num_subs; 1:num_subs], 1, 2*num_subs);
night = repmat(1:2, 1, num_subs);

plot_type = {'Slow Oscillation Power','Slow Oscillation Phase'};

for ee = [3 1 7 5]
    for pp = 1:length(plot_type)
        
        plot_hists{1} = hists{pp}{ee}(:,:,1:num_subs);
        plot_hists{2} = hists{pp}{ee}(:,:,jump+(1:num_subs));
        
        all_hists = cat(3, plot_hists{:});
        
        clim = prctile(all_hists(:),[5 98]);
        
        f(pp) = figure;%('units','normalized','position',[0 0 1 1]);
        ax = figdesign(M,N,'type','usletter','orient','landscape','margin',[.05 .05 .05 .01 .03 .04]);
        delete(ax(N_plots+1:end));
        ax = ax(1:N_plots);
        
        for ii = 1:N_plots
            
            axes(ax(ii));
            hist_mat = plot_hists{night(ii)}(:,:,subject(ii))';
            
            if any(~isnan(hist_mat(:)))
                imagesc(x_hist{pp},freqs,hist_mat);
                axis xy;
                caxis(clim);
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
                
                title(['S' num2str(subjects{subject(ii)}(4:end)) ' Night ' num2str(night(ii))],'fontsize',10);
                
                [col, row] = ind2sub([N,M],ii);
                
                
                if col ~= 1
                    set(ax(ii),'yticklabel', []);
                end
                
                if ~(row == M | (row == M-1 & col>2))
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
    suptitle(['Electrode ' electrodes{ee}]);
    
    %Add colorbars
    cax = findall(new_fig,'tag','cbar');
    c = colorbar(cax(1),'location','eastoutside');
    c.Position(1) = c.Position(1)+.05;
    c = colorbar(cax(2),'EastOutside');
    c.Position(1) = c.Position(1)+.05;
    
    %print(new_fig,'-depsc', [electrodes{ee} '-powerphasehists_plasma.eps']);
end