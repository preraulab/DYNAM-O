function powphase_hist_bystage_plot(mean_powhists, mean_phasehists, SOpow_cbins, SOphase_cbins, freq_cbins, ...
                                    elect_names, freq_range, fsave_path, print_png, print_eps)
% Plots mean power and phase histograms of each sleep stage for each electrode
%
% Inputs:
%       mean_powhists: 4D double - mean power histograms for each stage separately and
%                      for each electrode [electrode, stage, frequency, SOpow] --required
%       mean_phasehists: 4D double - mean phase histograms for each stage
%                        separately and for each electrode [electrode, stage, frequency, 
%                        SOphase] --required
%       SOpow_cbins: 1D double - bin centers for SOpower in mean_powhists --required
%       SOphase_cbins: 1D double - bin centers for SOphase in mean_phasehists --required
%       freq_cbins: 1D double - bin centers for frequency in mean_powhists and 
%                   mean_phasehists --required
%       elect_names: 1D cell array - names for each electrode (char) --required
%       freq_range: 2x1 double - range for frequency axis --required
%       fsave_path: char - path to save png/eps to. Default = '.'
%       print_png: logical - save figure as png. Default = false
%       pring_eps: logical - save figure as eps. Default = false
%
% Outputs:
%       None
%
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - Tom Possidente 1/03/2022
%%%************************************************************************************%%%

%% Deal with Inputs
assert(nargin >= 7, '7 inputs required: mean_powhists, mean_phasehists, SOpow_cbins, SOphase_cbins, freq_cbins, elect_names, freq_range')

if nargin < 8 || isempty(fsave_path)
    fsave_path = '.';
end

if nargin < 9 || isempty(print_png)
    print_png = false;
end

if nargin < 10 || isempty(print_eps)
    print_eps = false;
end

%% Plot 
%% SOphase
fh1 = figure;
ax = figdesign(7,4,'type','usletter','orient','portrait', 'margins',[.04 .1 .1 .1 .02 .02]);
outerlabels(ax, 'Slow Oscillation Phase (radians)', 'Frequency (Hz)', 'fontsize', 13)
ylabels = {'ALL', 'WAKE', 'REM', 'NREM', 'NREM1', 'NREM2', 'NREM3'};

num_stages = size(mean_powhists,2);
num_elects = length(elect_names);

cphase = [0.0066    0.0088]; % set colormap bounds

count = 0;
for ss = 1:num_stages
    for ee = 1:num_elects
        
        count = count + 1;
        axes(ax(count));
        imagesc(SOphase_cbins, freq_cbins, squeeze(mean_phasehists(ee,ss,:,:))); % plot mean phasehist for selected electrode and stage combo
        axis xy;
        ylim(freq_range);
        colormap(ax(count), 'magma');
        caxis(cphase)
        
        if ss == 1
            title(elect_names{ee});
        end
        
        if ss == num_stages
            xticklabels({'-\pi/2', '0', '\pi/2'})
        else
            xticklabels([]);
        end
        
        if mod(count-1,4) == 0
            ylabel(ylabels{ss})
        else
            yticklabels([]);
        end
        
        if ss == 4 && ee == num_elects
            c = colorbar_noresize;
            c.Label.String = {'Proportion'};
            c.Label.Rotation = -90;
            c.Label.VerticalAlignment = "bottom";     
        end
        
    end
end

%% SO power
fh2 = figure;
ax = figdesign(7,4,'type','usletter','orient','portrait', 'margins',[.04 .1 .1 .1 .02 .02]);
outerlabels(ax, '% Slow Oscillation Power', 'Frequency (Hz)', 'fontsize', 13)
ylabels = {'ALL', 'WAKE', 'REM', 'NREM', 'NREM1', 'NREM2', 'NREM3'};
count = 0;
cpow = [1.398, 5.402]; % set colormap bounds

for ss = 1:num_stages
    for ee = 1:num_elects
        
        count = count + 1;
        axes(ax(count));
        imagesc(SOpow_cbins*100, freq_cbins, squeeze(mean_powhists(ee,ss,:,:))); % plot mean powhist for selected electrode and stage combo
        axis xy;
        ylim(freq_range);
        colormap(ax(count), gouldian);
        caxis(cpow);
        
        if ss == 1
            title(elect_names{ee})
        end
        
        if ss == num_stages
            %nothing
        else
            xticklabels([]);
        end
        
        if mod(count-1,4) == 0
            ylabel(ylabels{ss})
        else
            yticklabels([]);
        end
        
        if ss == 4 && ee == num_elects
            c = colorbar_noresize;
            c.Label.String = {'Density', '(peaks/min in bin)'};
            c.Label.Rotation = -90;
            c.Label.VerticalAlignment = "bottom";     
        end
        
    end
end

%% Print if selected

% Resize paper
set(fh1,'units','normalized','paperunits','normalized','papertype','usletter','paperposition',[0 0 1 1.05],'position',[0 0 1 1])
set(fh2,'units','normalized','paperunits','normalized','papertype','usletter','paperposition',[0 0 1 1],'position',[0 0 1 1])

if print_png
    print(fh2,'-dpng', '-r600',fullfile( fsave_path, 'PNG','pow_hists_bystage.png'));
    print(fh1,'-dpng', '-r600',fullfile( fsave_path, 'PNG','phase_hists_bystage.png'));
end

if print_eps
    print(fh2,'-depsc', fullfile(fsave_path, 'EPS', 'pow_hists_bystage.eps'));
    print(fh1,'-depsc', fullfile(fsave_path, 'EPS', 'phase_hists_bystage.eps'));
end

end

