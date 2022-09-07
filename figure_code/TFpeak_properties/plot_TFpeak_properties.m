function plot_TFpeak_properties(n1_peaktable, n2_peaktable, fsave_path, print_png, print_eps)
% Plots 6 TFpeak properties for nights 1 and 2
%
%   Inputs:
%       n1_peaktable: cell array - each cell is a table of the night 1
%                     TFpeak properties for a single subject --required
%       n2_peaktable: cell array - each cell is a table of the night 2
%                     TFpeak properties for a single subject --required
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

%% Deal with Inputs
assert(nargin >= 2, '2 inputs required: n1_peaktable, n2_peaktable')
assert(length(n1_peaktable) == length(n2_peaktable), 'n1_peaktable and n2_peaktable must be same length');

if nargin < 3 || isempty(fsave_path)
    fsave_path = '.';
end

if nargin < 4 || isempty(print_png)
    print_png = false;
end

if nargin < 5 || isempty(print_eps)
    print_eps = false;
end

%% 
num_subjs = length(n1_peaktable);

n1_props = cell(num_subjs, 6);
n2_props = cell(num_subjs, 6);

for nn = 1:num_subjs
    n1_data = n1_peaktable{nn};
    n2_data = n2_peaktable{nn};
    
    % Get areas
    n1_props{nn,1} = cellfun(@(x) length(x), n1_data.PixelIdxList);
    n2_props{nn,1} = cellfun(@(x) length(x), n2_data.PixelIdxList);
    
    % Get Volumes
    n1_props{nn,2} = cellfun(@(x) sum(x), n1_data.PixelValues);
    n2_props{nn,2} = cellfun(@(x) sum(x), n2_data.PixelValues);
    
    % Get bandwidths
    n1_props{nn,3} = cellfun(@(x) max(x(:,1))-min(x(:,1)), n1_data.bndry);
    n2_props{nn,3} = cellfun(@(x) max(x(:,1))-min(x(:,1)), n2_data.bndry);
    
    % Get durations
    n1_props{nn,4} = cellfun(@(x) max(x(:,2))-min(x(:,2)), n1_data.bndry);
    n2_props{nn,4} = cellfun(@(x) max(x(:,2))-min(x(:,2)), n2_data.bndry);
    
    % Get freqs
    n1_props{nn,5} = n1_data.xy_wcentrd(:,2);
    n2_props{nn,5} = n2_data.xy_wcentrd(:,2);
    
    % Get heights
    n1_props{nn,6} = n1_data.height;
    n2_props{nn,6} = n2_data.height;
    
end

%% Plot

titles = {'Area', 'Volume', 'Bandwidth', 'Duration', 'Frequency', 'Height'};
xlims = {[2 10], [5 18], [2, 20], [0.5, 5.5], [4, 25], [0 15]};
nbins = [50, 50, 50, 50, 150, 50];

for p = 1:num_subjs
    
    figs(p) = figure;
    ax = figdesign(2,3,'margins',[.1 .1 .1 .1 .085]);
    
    for h = 1:6
        axes(ax(h));
        
        if ismember(h, [1, 2,6])
            n1_props{p,h} = log(n1_props{p,h});
            n2_props{p,h} = log(n2_props{p,h});
        end
        
        
        [N,edges] = histcounts(n1_props{p,h}, nbins(h), 'Normalization','pdf');
        edges = edges(2:end) - (edges(2)-edges(1))/2;
        plot(edges, N, 'Color', [0.7 0.7 0.7], 'LineWidth', 2);
        
        hold on;
        
        [N,edges] = histcounts(n2_props{p,h}, nbins(h), 'Normalization','pdf');
        edges = edges(2:end) - (edges(2)-edges(1))/2;
        plot(edges, N, 'Color', 'b', 'LineWidth', 2);
        
        xlim(xlims{h});
        title(titles{h}, 'fontsize', 16);
        
        if h==1
            letter_label(figs(p),ax(h), char(64+p),'l',40,[.05 .05]);
        end
        
    end
   
    set(ax,'fontsize',13,'xtick',[],'ytick',[]);
    set(gcf,'position',[0.0404    2.3434   19.3333    6.1818]);
end
f1 = mergefigures(figure(figs(1)), figure(figs(2)),.5,'LR');
f2 = mergefigures(figure(figs(3)), figure(figs(4)),.5,'LR');
fnew = mergefigures(f2,f1,.5,'UD');
set(fnew,'position', [0.0024         0    0.6341    0.8710]);
close(figs);
close(f1);
close(f2);


%Print if selected
if print_png
    print(fnew,'-dpng', '-r300',fullfile( fsave_path, 'PNG','other_feature_distributions.png'));
end

if print_eps
    print(fnew,'-depsc', fullfile(fsave_path, 'EPS', 'other_feature_distributions.eps'));
end




