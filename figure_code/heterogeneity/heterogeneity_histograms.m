function  heterogeneity_histograms(SOpow_hists, SOphase_hists, SOpow_cbins, SOphase_cbins, freq_cbins, fsave_path, print_png, print_eps)
% Plots nicely formatted SO power/phase histograms for 2 nights in 4 subjs
%
%   Inputs:
%       SOpow_hists: 4D double - [freq, SOpow, subjs, nights] SOpower histogram data --required
%       SOphase_hists: 4D double - [freq, SOphase, subjs, nights] SOphase histogram data --required
%       SOpow_cbins: 1D double - centers of SOpower bins. Should be same length as 2nd dim of SOpow_hists --required
%       SOphase_cbins: 1D double - centers of SOphase bins. Should be same length as 2nd dim of SOphase_hists --required
%       freq_cbins: 1D double - centers of freq bins. Should be same length as 1st dim of SOphase_hists and SOpow_hists. --required
%       fsave_path: char - path to save png/eps to. Default = '.'
%       print_png: logical - save figure as png. Default = false
%       pring_eps: logical - save figure as eps. Default = false
%
%   Outputs:
%       None
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - Tom Possidente 1/03/2022
%%%************************************************************************************%%%%

%% Deal with inputs
assert(all(size(SOpow_hists, [1,3,4]) == size(SOphase_hists, [1,3,4])), ...
       'Dims 1,3, and 4 of SOpow_hists and SOphase_hists be the same length (freqs, num subjs, nights)');
assert(nargin >= 5, '5 inputs required: SOpow_hists, SOphase_hists, SOpow_cbins, SOphase_cbins, freq_cbins')

if nargin < 6 || isempty(fsave_path)
    fsave_path = '.';
end

if nargin < 7 || isempty(print_png)
    print_png = false;
end

if nargin < 8 || isempty(print_eps)
    print_eps = false;
end

%%

N = size(SOpow_hists,3); % get number of subjects to plot

% set colormap bounds for pow and phase
cpow = [1.398, 6];
cphase = [0.0065211  0.00955];

%% Loop through each subject and plot
for fig_num = 1:N

    f(fig_num)  = figure;

    %Create axes
    ax = figdesign(8,2,'type','usletter','orient','portrait','merge', {[1 3 5],[2 4 6],[9 11 13 15], [10 12 14 16]},...
        'margins', [.13 .135 .14 .225 .06 .03]);

    delete(ax(3:4));
    ax = ax(setdiff(1:length(ax),[3 4]));
    set(ax(3:4),'xticklabel',[]);
    ax2 = split_axis(ax(3),[.25,.75],1);
    ax3 = split_axis(ax(4),[.25,.75],1);
    
    ax = [ax(1:2); ax2(2); ax3(2); ax2(1); ax3(1)];
    
    %Night 1 Power
    axes(ax(1))
    imagesc(SOpow_cbins*100, freq_cbins, SOpow_hists(:,:,fig_num,1));
    axis xy;
    caxis(cpow)
    colormap(gca, gouldian);
    title('Night 1')
    ylabel('Frequency (Hz)')
    ax(1).Position(2) = ax(1).Position(2) + .04;
    letter_label(f(fig_num),ax(1),char(64+fig_num),'left',35,[.05 .1]);
    

    %Night 2 Power
    axes(ax(2))
    imagesc(SOpow_cbins*100, freq_cbins, SOpow_hists(:,:,fig_num,2));
    caxis(cpow);
    colormap(gca, gouldian);
    axis xy;
    title('Night 2')

    %Set colorbar with proper label
    c = colorbar_noresize;
    c.Label.String = {'Density', '(peaks/min in bin)'};
    c.Label.Rotation = -90;
    c.Label.VerticalAlignment = "bottom";
    ax(2).Position(2) = ax(2).Position(2) + .04;
    ax(2).YTick = [];



    %Night 1 Phase
    axes(ax(3))
    imagesc(SOphase_cbins, freq_cbins, SOphase_hists(:,:,fig_num,1));
    axis xy;
    caxis(cphase);
    title('Night 1')
    ylabel('Frequency (Hz)')
    colormap(ax(3),magma(1024));
    ax(3).XTick = [];

    %Night 1 Phase
    axes(ax(4))
    imagesc(SOphase_cbins, freq_cbins, SOphase_hists(:,:,fig_num,2));
    axis xy;
    caxis(cphase);
    title('Night 2')

    %Create colorbar with proper label
    c = colorbar_noresize;
    c.Label.String = 'Proportion';
    c.Label.Rotation = -90;
    c.Label.VerticalAlignment = "bottom";

    colormap(ax(4),magma(1024));
    ax(4).YTick = [];
    ax(4).XTick = [];


    for ax_num = 5:6
        %Make hidden axis to show +-
        if ax_num == 5
            ax2 = axes('position',ax(ax_num).Position);
            ax2.Color = 'none';
            ax2.YTick = [-.5 .5];
            ax2.YTickLabel = {'+','-'};
            ax2.YLim = [-1 1.25];
            ax2.FontName = 'courier';
            ax2.FontSize = 32;
            ax2.XTick = [];

            uistack(ax2,'bottom');
        end

        %Plots the phase guide
        axes(ax(ax_num))
        hold on
        t = linspace(-pi, pi, 500);
        plot(t,cos(t),'k','linewidth',2);

        set(ax(ax_num),'ylim',[-1 1.25], 'ytick',0,'xlim',[-pi, pi],'xtick', [-pi -pi/2 0 pi/2 pi],'xticklabel',...
            {'-\pi' '-\pi/2' '0' '\pi/2' '\pi' });
        hline(0,'linestyle','--');
    end

    %Create outer label
    [hx1,~,haxo] = outerlabels(ax(1:2),'% Slow Oscillaton Power','','fontsize',18);
    haxo.FontSize = 18;
    hx1.Position(2) = hx1.Position(2) + 0.001;

    %Set outer labels
    [hx2,~,haxo] = outerlabels(ax(5:6),'Slow Oscillation Phase','','fontsize',18);
    haxo.FontSize = 18;
    hx2.Units = 'inches';
    hx2.Position(2) = -0.5;
    %hx2.Position(2) = hx2.Position(2) - 0.06;
    hx2.Units = 'normalized';

    set(ax(1:6),'FontSize',14);
end

%Join two figures
ftop = mergefigures(f(1), f(2));
fbot = mergefigures(f(3), f(4));

close(f);

%Join into 1 figure
new_fig = mergefigures(fbot, ftop,.5,'ud');

close(ftop);
close(fbot);

% new_fig.Position = [0   0    0.4854    0.8463];
set(new_fig,'papertype','usletter','paperorientation','portrait');
orient('portrait')
set(new_fig, 'PaperUnits', 'inches','units','inches','position',[0 0 8.5 10], 'paperposition',[0 0 8.5 10]);
% set(new_fig, 'PaperSize', [8.5 11]);

% Shifting down all phase labels
SOPh = findall(new_fig, 'type', 'text', 'string', 'Slow Oscillation Phase');
set(SOPh, 'Units', 'inches');
for i = 1:length(SOPh)
    SOPh(i).Position(2) = SOPh(i).Position(2) - 0.03;
end

% Make Title fonts larger
n1h = findall(new_fig, 'type', 'text', 'string', 'Night 1');
n2h = findall(new_fig, 'type', 'text', 'string', 'Night 2');
set([n1h; n2h], 'Fontsize', 13);


%Print if selected
if print_png
    print(new_fig,'-dpng', '-r600',fullfile( fsave_path, 'PNG','SO_histogram_heterogeneity.png'));
end

if print_eps
    print(new_fig,'-depsc', fullfile(fsave_path, 'EPS', 'SO_histogram_heterogeneity.eps'));
end
