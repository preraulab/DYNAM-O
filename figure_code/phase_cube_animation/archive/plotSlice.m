function plotSlice(ax,power,phase,freqs,control_hists,cx,pslider, line_h,shade_h,power_bin_width,labels_array,th, pp)

%Get the index
if nargin<13
    pp=round(get(pslider,'value'));
end

%Get the window high an low bounds
win_lo= power(pp)-power_bin_width/2;
win_hi= power(pp)+power_bin_width/2;

%Update the plots in each axis
for jj = 1:size(control_hists,1)
    for kk = 1:size(control_hists,2)
        ax_num = jj*size(control_hists,2)+kk;
        
        %Update the phase image
        axes(ax(ax_num));
        title(labels_array{jj,kk});
        imagesc(phase,freqs,squeeze(control_hists{jj,kk}(:,:,pp)));
        colormap(magma(2^12));
        xticks([-pi -pi/2 0 pi/2 pi]);
        xticklabels({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'})
        
        if pp==1
            axis xy;
            axis tight;
            ylabel('Frequency (Hz)');
            xlabel('Phase (rad)');
        end
        
        caxis(cx);
        
        %Update the line position
        line_h(jj,kk).XData=[power(pp) power(pp)];
        
        %Update the shaded bounds
        sv=shade_h(jj,kk).Vertices;
        sv(:,1)=[win_lo win_lo win_hi win_hi]';
        shade_h(jj,kk).Vertices=sv;
        
        th.String=['Slow Oscillation Power: ' num2str(round(power(pp))) '%'];
        ylim([4  25]);
        grid on;
    end
end