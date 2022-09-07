function other_normalizations(SOpow_hists, SOpow_cbins, freq_cbins, xlims, electrodes, freq_range, xlabs, fsave_path, print_png, print_eps)
% Plot mean power histograms for each electrode for each normalization method
%
%   Inputs:
%       SOpow_hists: 3D double - mean SOpower histograms for each
%                    normalization method [norm_method, freq, SOpow] --required
%       SOpow_cbins: 1D double - SOpower values of the bincenters used in
%                    powhists --required
%       freq_cbins: 1D double - frequnecy values of the bincenters for both
%                   SOpow_hists and SOphase_hists --required
%       xlims: cell array - each element is a 1x2 double of min and max
%              x-values for the corresponding SOpow_hist --required
%       electrodes: 1D cell array - electrode names (char). Default = '' 
%       freq_range: ylims for the histogram plots. Default = [4,35]
%       xlabs: Plot labels for each normalization method. Default = ''
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
%%%************************************************************************************%%%%

%% Deal with Inputs
assert(nargin >= 4, '4 inputs required - SOpow_hists, SOpow_cbins, freq_cbins, xlims');

if nargin < 5 || isempty(electrodes)
    electrodes = {repelem({''},size(SOpow_hists,3))};
end

if nargin < 6 || isempty(freq_range)
    freq_range = [4,25];
end

if nargin < 5 || isempty(xlabs)
    xlabs = {repelem({''},size(SOpow_hists,3))};
end

if nargin < 8 || isempty(fsave_path)
    fsave_path = '.';
end

if nargin < 9 || isempty(print_png)
    print_png = false;
end

if nargin < 10 || isempty(print_eps)
    print_eps = false;
end

%%
num_elects = length(electrodes);
num_norms = size(SOpow_hists,1);

%% Plot
clims  = [1.398, 5.402];
f1 = figure;
ax = figdesign(4,4 , 'type','usletter','orient','portrait','margins',[.05 .05 .1 .1 .03 .09]);
count = 0;
for nn = 1:num_norms
    for ee = 1:num_elects
        count = count + 1;
      
        axes(ax(count))
        imagesc(SOpow_cbins(:,nn), freq_cbins, mean(SOpow_hists{nn,ee},3,'omitnan')');
        axis xy;
        caxis(clims);
        ylim(freq_range);
        xlim(xlims{nn})
        
        if ee == 1
            letter_label(f1,ax(count),char(64+nn),'l',25,[0 .1]);
            ylabel('Frequency (Hz)');
        end
        
        title(electrodes{ee}, 'fontsize', 12)

        if ~ismember(count, [1,5,9,13])
            yticklabels('');
        end
        
        if  ee == 4
            c = colorbar_noresize;
            c.Label.String = {'Density', '(peaks/min in bin)'};
            c.Label.Rotation = -90;
            c.Label.VerticalAlignment = "bottom";
        end
        
        
    end
    [xl] =  outerlabels(ax([count-3:count]), xlabs{nn}, '', 'fontsize', 12);
    xl.Position(2) = xl.Position(2) + .05;
end


set(gcf,'units','normalized','paperunits','normalized','papertype','usletter','paperposition',[0 0 1.2 1],'position',[0 0 1.2 1]);

%Print if selected
if print_png
    print(f1,'-dpng', '-r300',fullfile( fsave_path, 'PNG','other_normalizations.png'));
end

if print_eps
    print(f1,'-depsc', fullfile(fsave_path, 'EPS', 'other_normalizations.eps'));
end
end

