function mean_powphase_plot(SOpow_hists, SOphase_hists, SOpow_cbins, SOphase_cbins, ...
    freq_cbins, elect_names, fsave_path, print_png, print_eps)
% Plot mean power and phase histograms for each electrode with PIB curves
%
%   Inputs:
%       SOpow_hists: 1D cell array - each cell is one electrode of data - a 3D double
%                 [freq x SOpow x N] --required
%       SOphase_hists: 1D cell array -  each cell is one electrode of data - a 3D double
%                   [freq x SOphase x N] --required
%       SOpow_cbins: 1D double - SOpower values of the bincenters used in SOpow_hists --required
%       SOphase_cbins: 1D double - SOphase values of the bincenters used in SOphase_hists --required
%       freq_cbins: 1D double - frequnecy values of the bincenters for both SOpow_hists
%                   and SOphase_hists --required
%       elect_names: 1D cell array - electrode names (char) --required
%       fsave_path: char - path to save png/eps to. Default = '.'
%       print_png: logical - save figure as png. Default = false
%       pring_eps: logical - save figure as eps. Default = false
%
%   Outputs:
%       None
%
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - Tom Possidente 1/03/2022
%%%************************************************************************************%%%

%% Deal with Inputs
assert(nargin >= 6, '7 inputs required: SOpow_hists, SOphase_hists, SOpow_cbins, SOphase_cbins, freq_cbins, elect_names')

if nargin < 7 || isempty(fsave_path)
    fsave_path = '.';
end

if nargin < 8 || isempty(print_png)
    print_png = false;
end

if nargin < 9 || isempty(print_eps)
    print_eps = false;
end

%% Get mean SO pow/phase hists
num_elects = length(elect_names);

mean_powhists = cellfun(@(x) mean(x,3,'omitnan'), SOpow_hists, 'UniformOutput', false);
mean_phasehists = cellfun(@(x) mean(x,3,'omitnan'), SOphase_hists, 'UniformOutput', false);

%% Initialize figure and axes
fh =figure;
ax = figdesign(2,num_elects,'type','usletter','orient','landscape', 'margins',[.08, .08 .1 .1 .02 .125]);

% split each axis into 2 for hist and PIB plots
ax_pow = [];
for ii = 1:4
    ax_split = split_axis(ax(ii),[.8 .2],1);
    ax_split(2).XTick = [];
    ax_pow = [ax_pow ax_split];
end
linkaxes(ax_pow,'x');
ot = outertitle(ax_pow,'Cross-Subject Mean SO-Power Histograms');
ot.Position(2) = ot.Position(2)+.03;

for ii = 1:length(ax_pow)
    ax_pow(ii).Position(2) = ax_pow(ii).Position(2) + .06;
end

ax_phase = [];
for ii = 5:8
    ax_split = split_axis(ax(ii),[.2 .8],1);
    ax_split(1).XTick = [];
    ax_phase = [ax_phase ax_split];
end
linkaxes(ax_phase,'x');
ot = outertitle(ax_phase,'Cross-Subject Mean SO-Phase Histograms');
ot.Position(2) = ot.Position(2)+.03;

%% Plot SO pow

outerlabels(ax_pow, '% Slow Oscillation Power', '', 'fontsize', 14)

cpow = [1.398, 5.6]; % set colormap limits 


for ee = 1:num_elects
    
    set(ax_pow(ee*2),'visible','off');
    
    
    elect_data = mean_powhists{ee};
    
    axes(ax_pow(ee*2-1))
    
    imagesc(SOpow_cbins*100, freq_cbins, elect_data); % plot mean histogram
    axis xy;
    colormap(gca, gouldian)
    caxis(cpow)
    grid on;
    set(ax_pow(ee*2-1), 'GridLineStyle', '--', 'GridColor', '[1, 1, 1]', 'GridAlpha', 0.8);

    if ee == 1
        ylabel('Frequency (Hz)','fontsize',18);
        set(ax_pow(ee*2-1),'ytick',[5:5:20]);
        letter_label(fh,ax_pow(ee*2-1),'A','left',30,[.04 .05]);
    else
        yticklabels([]);
    end
    
    if ee ==4 % make colorbar
        c = colorbar_noresize(ax_pow(ee*2-1));
        c.Label.String = {'Density', '(peaks/min in bin)'};
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
    end
    
    title(elect_names{ee})
end
set(ax_pow,'fontsize',12);

%% Plot SO phase
cphase = [0.0065    0.0089]; % set colorbar

xlab  = outerlabels(ax_phase, 'Slow Oscillation Phase (rad)', '', 'fontsize', 14);
xlab.Position(2) = xlab.Position(2) - .05;

for ee = 1:num_elects
    
    elect_data = mean_phasehists{ee};
    
    axes(ax_phase(ee*2));
    
    imagesc(SOphase_cbins, freq_cbins, elect_data); % plot histogram
    axis xy;
    colormap(ax_phase(ee*2), magma);
    caxis(cphase)
    xticklabels([]);
    title(elect_names{ee})
    grid on;
    set(ax_phase(ee*2), 'GridLineStyle', '--', 'GridColor', '[1, 1, 1]', 'GridAlpha', 0.8, 'xtick', [-pi, -pi/2, 0, pi/2, pi]);
    
    if ee ==1
        ylabel('Frequency (Hz)','fontsize',18);
        set(ax_phase(ee*2),'ytick',[5:5:20]);
        letter_label(fh,ax_phase(ee*2),'B','left',30,[.04 .05]);
    else
        yticklabels([]);
    end
    
    if ee == 4 % make colobar
        c = colorbar_noresize(ax_phase(ee*2));
        c.Label.String = 'Proportion';
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
    end
    
    %Make hidden axis to show +-
    if ee == 1
        ax3 = axes('position',ax_phase(ee*2-1).Position);
        ax3.Color = 'none';
        ax3.YTick = [-.5 .5];
        ax3.YTickLabel = {'+','-'};
        ax3.YLim = [-1 1.25];
        ax3.FontName = 'courier';
        ax3.FontSize = 32;
        ax3.XTick = [];
        
        uistack(ax3,'bottom');
    end
    
    %Plots the phase guide
    axes(ax_phase(ee*2-1))
    
    t = linspace(-pi, pi, 500);
    plot(t,cos(t),'k','linewidth',2);
    hold on
    set(ax_phase(ee*2-1),'ylim',[-1 1.25], 'ytick',0,'xlim',[-pi, pi],'xtick', [-pi, -pi/2, 0, pi/2, pi],'xticklabel',...
        {'-\pi', '-\pi/2', '0', '\pi/2', '\pi' });
    
    hline(0,'linestyle','--');
end
set(ax_phase,'fontsize',12);

%Print if selected
if print_png
    print(fh,'-dpng', '-r300',fullfile( fsave_path, 'PNG','mean_pow_phase_hists.png'));
end

if print_eps
    print(fh,'-depsc', fullfile(fsave_path, 'EPS', 'mean_pow_phase_hists.eps'));
end


