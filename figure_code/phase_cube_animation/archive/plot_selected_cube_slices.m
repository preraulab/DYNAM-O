% Plot slices of the pahse histogram at 3 SOpower points for 4 electrodes

% Load data
cube_append = '20181211_ctrl';
load(['/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/figure_ResultsAndData/phase_cube_animation_data/phase_cube_data_vis_' cube_append '.mat']);


% Set up figure
fig = figure;
ax = figdesign(4,4, 'type', 'usletter', 'orient', 'portrait', 'margins', [.08 .05 .08 .11 .03 .08]);

num_elects = size(mean_control_hists,2);

pow_slices = [7, 55, length(power)];

freq_range = [4,25];

%text_colors = {'b', 'r', 'g'};

clims = [0.00323847, 0.00427758];

% Loop through each electrode and plot all 3 slices
count = 0;
for pp = 1:length(pow_slices)
    outerlabels( ax([1:4]+(4*(pp-1))), [num2str(round(power(pow_slices(pp))*100)), '% Slow Oscillation Power (dB)'], '',...
                 'XAxisLocation', 'top', 'FontSize', 14);
             
    if pp == 3
        outerlabels(ax([1:4]+(4*(pp-1))), 'Slow Oscillation Phase (rad)', '', 'FontSize', 11)
    end
    
    for ee = 1:num_elects
        count = count + 1;
        
        % split axes for phase hist and phase guide
        curr_ax = split_axis(ax(count), [0.15, 0.85], 1);
        
        % Plot phase hist
        axes(curr_ax(2));
        imagesc(phase,freqs,squeeze(mean_control_hists{2,ee}(:,:,pow_slices(pp))));
        axis xy;
        ylim(freq_range);
        colormap(magma(2^12));
        caxis(clims);
        xticks([-pi -pi/2 0 pi/2 pi]);
        xticklabels({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'});
        title(labels_array{2,ee});
        
        if ee==1
            ylabel('Frequency (Hz)');
            if pp == 1
                letter_label(gcf, gca, 'A', 'left');
            end
        else
            yticklabels('');
        end
        
        if ee==4 && pp==2
            c = colorbar_noresize;
            c.Label.String = 'Proportion';
            c.Label.Rotation = -90;
            c.Label.VerticalAlignment = "bottom";        
        end
        
        % Plot phase guide
        axes(curr_ax(1));
        hold on
        t = linspace(-pi, pi, 500);
        plot(t,cos(t),'k','linewidth',3);

        set(curr_ax(1),'ylim',[-1 1.25], 'ytick',0,'xlim',[-pi, pi],'xtick', [-pi -pi/2 0 pi/2 pi],'xticklabel',...
            {'-\pi' '-\pi/2' '0' '\pi/2' '\pi' });
        hline(0,'linestyle','--','linewidth',1,'color','k');
        
        if pp == 1
            % Plot proportion time in bin
            axes(ax(count + 12))
            hold on;
            ylim([0,100]);
            plot(power*100, mean_stage_prop_ctrl{2,ee}*100,'linewidth',2);
            vline(power(pow_slices(1))*100,'linestyle','--','linewidth',2, 'Color', 'k');
            vline(power(pow_slices(2))*100,'linestyle','--','linewidth',2, 'Color', 'k');
            vline(power(pow_slices(3))*100,'linestyle','--','linewidth',2, 'Color', 'k'); 
            if ee == 1
                ylabel('% Time in Stage');
            end
            if ee == num_elects
                L=legend('N3', 'N2', 'N1', 'REM', 'WAKE');
            end
        end
        
    end
end

outerlabels(ax(13:16), '% Slow Oscillation Power', '', 'FontSize', 11);
letter_label(gcf, ax(13), 'B', 'left');

% Move legend
set(L, 'Position', [0.8158    0.0873    0.0996    0.1057]);

% Resize paper
set(gcf,'units','normalized','paperunits','normalized','papertype','usletter','paperposition',[0 0 1 1],'position',[0 0 1 1])


% Save if selected
if print_png
    print(fig,'-dpng', '-r600',fullfile( fsave_path, 'PNG','phase_cube_slices.png'));
end

if print_eps
    print(fig,'-depsc', fullfile(fsave_path, 'EPS', 'phase_cube_slices.eps'));
end
