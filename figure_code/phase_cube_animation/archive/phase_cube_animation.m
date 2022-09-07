%% Create phase cube animation

cube_append = '20181211_ctrl';
load(['/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/figure_ResultsAndData/phase_cube_animation/phase_cube_data_vis_' cube_append '.mat']);

%% GENERATE ANIMATION FIGURE
figure;

for ii=1:8
    if ii<5
        ax_start=5;
    else
        ax_start=13-4;
    end
    
    merge{ii}=[ax_start+(ii-1) ax_start+4+(ii-1)];
end

ax = figdesign(6,4,'type','usletter','orient','landscape','margins',[.05 .05 .05 .025 .06],'merge',merge);
set(ax(5:12),'nextplot','replacechildren');

set(gcf,'units','normalize','position',[ 0.0020    0.0201    0.5941    0.9062]);

SWP_percent=power*100;
power_bin_width_percent=power_bin_width*100;

cx=prctile(pow_average(:),[7 98]);

for jj=1:size(comps,1)
    for kk=1:size(comps,2)
        if jj==1
            axes(ax(kk));
        else
            axes(ax(3*size(comps,2)+kk));
        end
        hold on;
        plot(SWP_percent, mean_stage_prop_ctrl{jj,kk}*100,'linewidth',2);
        axis tight;
        ylim([0 100]);
        l(jj,kk)=vline(SWP_percent(1),'linewidth',3);
        hold on;
        shade_h(jj,kk)=fill([SWP_percent(1)-power_bin_width_percent/2, SWP_percent(1)-power_bin_width_percent/2, SWP_percent(1)+power_bin_width_percent/2 SWP_percent(1)+power_bin_width_percent/2],[0 max(ylim) max(ylim) 0],[.9 .9 .9]);
        uistack(shade_h(jj,kk),'bottom');
        
        title('Sleep Stage Proportion');
        ylabel('% Time in Stage');
        xlabel('% Slow Oscillation Power');
        xlim([0 100]);
    end
end

th= suptitle(['Slow Oscillation Power: ' num2str(round(SWP_percent(1))) '%']);
th.FontSize=25;

pslider=[]; 
plotSlice(ax,SWP_percent,phase,freqs,mean_control_hists,cx,pslider, l,shade_h,power_bin_width_percent,labels_array,th,1);


% Comment back in for interactive
% pslider = uicontrol('style','slider','units','normalized','position',[.05 .025 .9 .025],'min',1,'max',length(power),'value',1,'sliderstep',1/(length(power)-1)*[1 2]);
% pl=addlistener(pslider,'ContinuousValueChange',@(src,evnt)plotSlice(ax,SWP_percent,phase,freqs,control_hists,cx,pslider,l,shade_h,power_bin_width_percent,labels_array));

%%  RUN ANIMATION

write_vid=true;
compressed_vid=true;

if write_vid
    if compressed_vid
        v = VideoWriter(['phase_cube_animation_' cube_append '_compressed.avi']);
    else
        v = VideoWriter(['phase_cube_animation_' cube_append '_uncompressed.avi'],'Uncompressed AVI');
    end
    
    v.FrameRate=10;
    open(v);
end

for pp=1:length(SWP_percent)
    plotSlice(ax,SWP_percent,phase,freqs,mean_control_hists,cx,pslider, l,shade_h,power_bin_width_percent,labels_array,th, pp);
    drawnow
    
    if write_vid
        frame = getframe(gcf);
        writeVideo(v,frame);
    end
end


if write_vid
    close(v);
end
