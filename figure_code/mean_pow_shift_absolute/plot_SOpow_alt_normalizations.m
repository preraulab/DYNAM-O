function plot_SOpow_alt_normalizations(SOpow_hists, SOpow_cbins, freq_cbins, electrodes, freq_range, xlabs, xlims)
% Plot mean power histograms for each electrode
%
%   Inputs:
%       SOpow_hists: 
%       SOphase_hists: 
%       SOpow_cbins: 1D double - SOpower values of the bincenters used in
%                    powhists --required
%       freq_cbins: 1D double - frequnecy values of the bincenters for both
%                   SOpow_hists and SOphase_hists --required
%       electrodes: 1D cell array - electrode names (char). Default = ''
%       freq_range: ylims for the histogram plots. Default = [4,35]
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
assert(nargin > 4, '5 inputs required - SOpow_hists, SOphase_hists, SOpow_cbins, SOphase_cbins, freq_cbins');

if nargin < 6 || isempty(electrodes)
    elects = {repelem({''},size(SOpow_hists,3))};
end

if nargin < 7 || isempty(freq_range)
    freq_range = [4,25];
end

%%
num_elects = length(electrodes);
num_norms = size(SOpow_hists,1);

%% Plot

f1 = figure;
ax = figdesign(4,4 , 'type','usletter','orient','portrait','margins',[.03 .1 .1 .1 .02 .08]);
count = 0;
for nn = 1:num_norms
    for ee = 1:num_elects
        count = count + 1;

        axes(ax(count))    
        imagesc(SOpow_cbins(nn,:), freq_cbins, SOpow_hists{nn,ee}');
        axis xy;
        climscale(false);
        ylim(freq_range);
        xlim(xlims{nn})
        
        if count < 5
            title(electrodes{ee}, 'fontsize', 12)
        end
        
        if ~ismember(count, [1,5,9,13])
            yticklabels('');
        end

        if ee == 4 && nn == 4
            c = colorbar_noresize;
            c.Label.String = {'Density', '(peaks/min in bin)'};
            c.Label.Rotation = -90;
            c.Label.VerticalAlignment = "bottom";        
        end
        

    end
    outerlabels(ax([count-3:count]), xlabs{nn}, '', 'fontsize', 12)
end

outerlabels(ax, '', 'Frequency (Hz)', 'fontsize', 12)


end

