function all_subjs_powphase_2nights(powhists, phasehists, SOpow_cbins, SOphase_cbins, freq_cbins, elects, subjs,...
    nights, plot_title, fsave_path, print_png, print_eps)
% Plot SO power and SO phase histograms for given subjects, nights, and electrodes
%
%   Inputs:
%       powhists: 1D cell array - each cell is one electrode of data - a 3D double
%                 [freq x SOpow x N] --required
%       phasehists: 1D cell array -  each cell is one electrode of data - a 3D double
%                   [freq x SOphase x N] --required
%       SOpow_cbins: 1D double - SOpower values of the bincenters used in powhists --required
%       SOphase_cbins: 1D double - SOphase values of the bincenters used in phasehists --required
%       freq_cbins: 1D double - frequnecy values of the bincenters for both powhists
%                   and phaseshists --required
%       elects: 1D cell array - electrode names (char). Default = ''
%       subjs: 1D cell array - subject ID (char) for each pow/phase hist. Default = ''
%       nights: 1D double - night value for each pow/phase hist. Default = 0
%       plot_title: char - prefix for plot title. Default = ''
%       fsave_path: char - path to save png/eps to
%       print_png: logical - save figure as png
%       pring_eps: logical - save figure as eps
%
%   Outputs:
%       None
%
%
%   Copyright 2022 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified: 3/15/2022 - MJP
%%%************************************************************************************%%%

%% Deal with inputs

assert(nargin >= 5, '5 inputs required - powhists, phasehists, SOpow_cbins, SOphase_cbins, freq_cbins');

if nargin < 6 || isempty(elects)
    elects = {repelem({''},size(powhists,3))};
end

if nargin < 7 || isempty(subjs)
    subjs = {repelem({''},size(powhists,3))};
end

if nargin < 8 || isempty(nights)
    nights = zeros(size(powhists,3),1);
end

if nargin < 9 || isempty(plot_title)
    plot_title = '';
end

%% Initialize bin data

x_hist{1} = SOpow_cbins;
x_hist{2} = SOphase_cbins;

%% Initialize number of plots and electrodes
N_plots = size(powhists{1},3);
num_elects = length(elects);

%% Set row and columns of figure based on number of plots required
if N_plots<=40
    M = 5;
    N = 8;
elseif N_plots<=48
    M = 6;
    N = 8;
else
    error('Too many subjects to plot under current figdesign')
end


%% Loop through each electrode, plot type,and histogram and plot
plot_type = {'Slow Oscillation Power','Slow Oscillation Phase'};
for ee = 1:num_elects
    plot_hists{1} = powhists{ee};
    plot_hists{2} = phasehists{ee};

    for pp = 1:length(plot_type)

        clims = prctile(plot_hists{pp}(:),[5 98]); % set colormap limits

        f(pp) = figure; % open figure
        ax = figdesign(M,N,'type','usletter','orient','landscape','margin',[.2 .07 .1 .01 .03 .04]);

        if pp ==1 % set outertitle
            ot = outertitle(ax,'SO-Power Histograms','FontSize',30);
            ot.Position(2) = ot.Position(2) + .05;
        else
            ot = outertitle(ax,'SO-Phase Histograms','FontSize',30);
            ot.Position(2) = ot.Position(2) + .05;
        end

        delete(ax(N_plots+1:end)); % delete unused axes
        ax = ax(1:N_plots); % limit ax to appropriate axes

        for ii = 1:N_plots

            axes(ax(ii));
            if ii == 1
                letter_label(gcf,ax(ii),char(64 + pp),'l',35);
            end

            hist_mat = squeeze(plot_hists{pp}(:,:,ii)); % get relevant histogram for this iteration

            if any(~isnan(hist_mat(:))) % only plot if there is non-nan data in hist
                imagesc(x_hist{pp},freq_cbins,hist_mat); %plot hist
                axis xy;
                caxis(clims); % set colormap limits
                grid on;

                % Move hists from same subj closer together
                if nights(ii) == 1
                    ax(ii).Position(1) = ax(ii).Position(1)+.01;
                else
                    ax(ii).Position(1) = ax(ii).Position(1)-.01;
                end

                % set colormap and xticks
                if pp==1
                    set(ax(ii), 'xtick', 0:.25:1,'xticklabel',{'0' '25' '50' '75' '100'});
                    colormap(ax(ii), gouldian);
                else
                    set(ax(ii), 'xtick', [-pi/2, 0, pi/2], 'xticklabel', {'-\pi/2', '0', '\pi/2'});
                    colormap(ax(ii), magma(2^12));
                end

                % Make colorbar for final plot
                if ii == N_plots
                    c = colorbar_noresize(ax(ii),'EastOutside');
                    if pp==1
                        c.Label.String = {'Density', '(peaks/min in bin)'};
                        c.Label.VerticalAlignment = "bottom";
                        c.Label.Rotation = -90;
                    else
                        c.Label.String = 'Proportion';
                        c.Label.VerticalAlignment = "bottom";
                        c.Label.Rotation = -90;
                    end
                end

                % Set plot title for subj/night
                title([subjs{ii} ' Night ' num2str(nights(ii))],'FontSize',10);

                % Get rid of yticklabels for all columns except 1
                [col, ~] = ind2sub([N,M],ii);
                if col ~= 1
                    set(ax(ii),'yticklabel', []);
                end

            else
                % If all nans, turn axis off
                axis off;
                if nights(ii) == 2 % if night 2 is all nans, turn off plot for night 1 also
                    a = ax(ii-1);
                    c = a.Children;
                    set(a, 'Visible', 'off');
                    set(c, 'Visible', 'off');
                end
            end
        end

        if pp == 1
            outerlabels(ax, '% Slow Oscillation Power', 'Frequency (Hz)', 'FontSize', 32);
        else
            outerlabels(ax, 'Slow Oscillation Phase (rad)', 'Frequency (Hz)', 'FontSize', 32);
        end

    end

    %Merge into a big figure
    new_fig = mergefigures(f(2), f(1), .5, 'UD',1.5);
    close(f(1));
    close(f(2));
    drawnow;
    pause(1);

    % Make figure portrait
    set(new_fig, 'units','inches','position',[0 0 8.5*2 11*2], 'papersize', [8.5*2 11*2], 'PaperPosition', [0 0 8.5*2 11*2], 'paperorientation','portrait');
    orient tall;

    % Make overall figure title
    ax_all = findobj(gcf,'Type','Axes');
    outertitle(ax_all, [plot_title ' Electrode ' elects{ee}], 'FontSize', 25);

    %Print if desired
    if print_png
        print(new_fig,'-dpng', '-r300',fullfile( fsave_path, 'PNG',[strrep(plot_title,' ','_') '_' elects{ee} '-powerphasehists.png']));
    end

    if print_eps
        print(new_fig,'-depsc', fullfile(fsave_path, 'EPS', [strrep(plot_title,' ','_') '_' elects{ee} '-powerphasehists.eps']));
    end
end




