function plotSlice_new(ax, SOpow_cbins, SOphase_cbins, freq_cbins, SOphase_slice_data, cx, pslider, line_h, shade_h, ...
                       power_bin_width, labels_array, th, pp)

%Get the index
if nargin<13
    pp=round(get(pslider,'value'));
end

%Get the window high an low bounds
win_lo= SOpow_cbins(pp)-power_bin_width/2;
win_hi= SOpow_cbins(pp)+power_bin_width/2;

%Update the plots in each axis
for p = (1:length(SOphase_slice_data))
    ax_num = p + length(SOphase_slice_data);
    
    %Update the phase image
    axes(ax(ax_num));
    imagesc(SOphase_cbins, freq_cbins, squeeze(SOphase_slice_data{p}(:,:,pp))');
    colormap(magma(2^12));
    xticks([-pi -pi/2 0 pi/2 pi]);
    xticklabels({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'})
    
    title(labels_array{p});
    axis xy;
    axis tight;
    if p==1
        ylabel('Frequency (Hz)');
    end
    xlabel('Phase (rad)');
    
    
    caxis(cx);
    
    %Update the line position
    line_h(p).XData=[SOpow_cbins(pp) SOpow_cbins(pp)];
    
    %Update the shaded bounds
    sv=shade_h(p).Vertices;
    sv(:,1)=[win_lo win_lo win_hi win_hi]';
    shade_h(p).Vertices=sv;
    
    th.String=['Slow Oscillation Power: ' num2str(round(SOpow_cbins(pp))) '%'];
    ylim([4  25]);
    grid on;
end