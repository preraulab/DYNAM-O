%% Create phase cube animation

ccc; 

% Load percentage time in bin data
load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/watershed_TFpeaks/figure_code/figure_data_init_nowake.mat',...
    'elect_names', 'PIBpow_all', 'subjects_full', 'night_out');
PIBpow_all = PIBpow_all([3,1,7,5],1); % get PIB for elects F3, C3, Pz, O1
cntrl_subjs = strsplit(num2str([1 3 5 6 7 8 9 11 12 13 15 17 18 19 20 21])); % subj nums to extract and average PIBs for 
subj_mask = ismember(repelem(subjects_full,2), cntrl_subjs) & (night_out==2); % mask for correct subj nums and night (2)
PIBpow_all_avg = cellfun(@(x) squeeze(mean(x(subj_mask,:,:),1,'omitnan')), PIBpow_all, 'UniformOutput',false); % select subjs/night and average PIBs for each electrode

% Load phase slice data
load('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOphase_slice_data/SOphase_slice_data.mat')

%% GENERATE ANIMATION FIGURE
figure;

ax = figdesign(3,4,'type','usletter','orient','landscape','margins',[.05 .07 .05 .025 ,.06, .1],'merge',{[5,9], [6,10],[7,11],[8,12]});

SOpow_cbins_p = SOpow_cbins*100;
SOpow_bin_width_p = SOpow_bin_width*100;

cx=prctile(SOphase_slice_data{2}(:),[7 98]);

for p = 1:length(electrodes)
    axes(ax(p));

    plot(SOpow_cbins_p(2:end), PIBpow_all_avg{p}*100,'linewidth',2);
    axis tight;
    ylim([0 100]);
    slide_line(p)=vline(SOpow_cbins_p(1),'linewidth',3);
    hold on;
    shade_h(p)=fill([SOpow_cbins_p(1)-SOpow_bin_width_p/2, SOpow_cbins_p(1)-SOpow_bin_width_p/2, SOpow_cbins_p(1)+SOpow_bin_width_p/2 SOpow_cbins_p(1)+SOpow_bin_width_p/2],[0 max(ylim) max(ylim) 0],[.9 .9 .9]);
    uistack(shade_h(p),'bottom');
    
    title('Sleep Stage Proportion');
    if p ==1 
        ylabel('% Time in Stage');
    end
    xlabel('% Slow Oscillation Power');
    xlim([0 100]);
end

th= suptitle(['Slow Oscillation Power: ' num2str(round(SOpow_cbins_p(1))) '%']);
th.FontSize=25;

pslider=[]; 
plotSlice_new(ax, SOpow_cbins_p, SOphase_cbins, freq_cbins, SOphase_slice_data, cx, pslider, ....
          slide_line, shade_h, SOpow_bin_width_p, electrodes, th, 1);


% Comment back in for interactive
% pslider = uicontrol('style','slider','units','normalized','position',[.05 .025 .9 .025],'min',1,'max',length(power),'value',1,'sliderstep',1/(length(power)-1)*[1 2]);
% pl=addlistener(pslider,'ContinuousValueChange',@(src,evnt)plotSlice(ax,SWP_percent,phase,freqs,control_hists,cx,pslider,l,shade_h,power_bin_width_percent,labels_array));

%%  RUN ANIMATION

write_vid=true;
compressed_vid=true;

if write_vid
    if compressed_vid
        v = VideoWriter(['phase_cube_animation_compressed.avi']);
    else
        v = VideoWriter(['phase_cube_animation_uncompressed.avi'],'Uncompressed AVI');
    end
    
    v.FrameRate=10;
    open(v);
end

for pp=1:length(SOpow_cbins_p)
    plotSlice_new(ax, SOpow_cbins_p, SOphase_cbins, freq_cbins, SOphase_slice_data, cx, pslider, ....
          slide_line, shade_h, SOpow_bin_width_p, electrodes, th, pp);
    drawnow
    
    if write_vid
        frame = getframe(gcf);
        writeVideo(v,frame);
    end
end


if write_vid
    close(v);
end
