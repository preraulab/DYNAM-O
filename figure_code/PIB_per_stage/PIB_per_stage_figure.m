function PIB_per_stage_figure(PIBs_per_stage, powbins, electrodes, norm_strs, xlims, fsave_path, print_png, print_eps)
% Plot average % time in SOpower bin for each electrode and stage
%
% Inputs:
%   PIBs_per_stage: NxM cell - N is normalization method, M is electrodes.
%                   Each cell contains a 3D double [SObin, stage, subject] of data
%                   representing the proportion of total time spent in each SOpower bin
%   powbins: PxN double - P is number of SOpower bins, N is electrodes.
%            Data is the SOpower bin centers corresponding to PIBs_per_stage
%   electrodes: 1D cell - Each cell contains a string indicating the
%               electrode (same order as PIBs_per_stage)
%   norm_strs: 1D cell - Each cell contains a string indicating the
%              normalization method (same order as PIBs_per_stage)
%   xlims: 1D cell - Each cell contains a 2 element array giving the xlims
%          for plotting each normalization method (same order as
%          PIBs_per_stage)
%   fsave_path: str - indicates where to save the figure png and eps
%               (default = '')
%   print_png: logical - save out the png of the figure (default = false)
%   print_eps: logical - save out the eps of the figure (default = false)
%
% Outputs:
%   None
%
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - Tom Possidente 8/20/2022
%%%************************************************************************************%%%%


%% Deal with inputs
assert(nargin>=5, '5 or more inputs required');

if nargin < 6 || isempty(fsave_path)
    fsave_path = '';
end

if nargin < 7 || isempty(print_png)
    print_png = false;
end

if nargin < 8 || isempty(print_eps)
    print_eps = false;
end

%% Plot norm x electrode grid of PIB plots
[num_norms, num_elects] = size(PIBs_per_stage);

f1 = figure;
ax = figdesign(4,4 , 'type','usletter','orient','portrait','margins',[.05 .05 .1 .11 .03 .09]);
count = 0;
for nn = 1:num_norms
    for ee = 1:num_elects
        count = count + 1;
      
        axes(ax(count))
        plot(powbins(:,nn), mean(PIBs_per_stage{nn,ee},3,'omitnan'), 'LineWidth', 2);
        xlim(xlims{nn});
        
        if ee == 1
            letter_label(f1,ax(count),char(64+nn),'l',25,[0 .1]);
            ylabel('% Time in Stage');
        end

        if ee == num_elects && nn == 1
            L = legend('N3', 'N2', 'N1', 'REM', 'WAKE');
        end

        
        title(electrodes{ee}, 'fontsize', 12)

        if ~ismember(count, [1,5,9,13])
            yticklabels('');
        end
        
        
    end
    [xl] =  outerlabels(ax([count-3:count]), norm_strs{nn}, '', 'fontsize', 12);
    xl.Position(2) = xl.Position(2) + .05;
end

set(L, 'Position', [0.9176    0.8105    0.0554    0.1057]);
set(gcf,'units','normalized','paperunits','normalized','papertype','usletter','paperposition',[0 0 1.1 1],'position',[0 0 1.1 1]);

%Print if selected
if print_png
    print(f1,'-dpng', '-r300',fullfile( fsave_path, 'PNG','PIB_per_stage.png'));
end

if print_eps
    print(f1,'-depsc', fullfile(fsave_path, 'EPS', 'PIB_per_stage.eps'));
end

end

