function [phase_params, use_inds, use_issz, pvalues_issz, pvalues_night] = meanSZcontrol_phase_ROIs_plot(...
    SOphase_hists, SOphase_counts, SOphase_cbins, freq_cbins, issz, nights, ROI_phase, ROI_freq, ROI_flip_flag,...
    fsave_path, print_png, print_eps)
% Compute and plot HC and SZ means and difference histograms, and boxplots of ROI differences
%
%   Inputs:
%       phasemean_cntrl: 2D double - mean phase histogram for single electrode [freq x SOphase] --required
%       phasemean_sz: 2D double - mean phase histogram for single electrode [freq x SOphase] --required
%       SOphasemean_cbins: 1D double - SOphase values of the bincenters used in phasemean hists --required
%       freqmean_cbins: 1D double - Frequency values of the bincenters used in phasemean hists --required
%       phasehist_counts: 3D double - TFpeak count histograms for each subject [freq x SOphase x N] --required
%       TIBphase:
%       SOphase_cbins: 1D double - SOphase values of the bincenters used in phasehist_counts --required
%       freq_cbins: 1D double - Frequency values of the bincenters used in phasehist_counts --required
%       issz: 1D logical - SZ status for each hist --required
%       nights: 1D double - integer night label --required
%       ROI_phase:
%       ROI_freq:
%       ROI_flip_flag: 
%       fsave_path: char - path to save png/eps to
%       print_png: logical - save figure as png
%       pring_eps: logical - save figure as eps
%
%
%   Outputs:
%       phase_params: RxN double - [number of regions x number of histograms]
%                   mean peak rate for each region for each histogram (peaks/min)
%       use_inds: 1D logical - indicates which hists were used in analysis (hists are excluded if they are all 0s)
%       use_issz: 1D logical - indicates SZ status of use_inds
%       pvalues_issz: 1D double - pvalue for group effect on each ROI
%       pvalues_night: 1D double - pvalue for night effect on each ROI
%
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Authors: Thomas Possidente, Michael Prerau
%
%   Last modified:
%       - Created - Tom Possidente 1/03/2022
%%%************************************************************************************%%%

%% Deal with Inputs
assert(nargin >= 5, '5 input arguments required. See function documentation');

if nargin < 6 || isempty(ROI_phase)
    ROI_phase = [-pi/4 pi/2; (-1.5*pi)/2 (3*pi)/4]; % region of interest phase boundaries;
end

if nargin < 7 || isempty(ROI_freq)
    ROI_freq = [12 17; 6 11];
end

if nargin < 8 || isempty(ROI_flip_flag)
    ROI_flip_flag = [false, true];
end

if nargin < 9 || isempty(fsave_path)
    fsave_path = '.';
end

if nargin < 10 || isempty(print_png)
    print_png = false;
end

if nargin < 11 || isempty(print_eps)
    print_eps = false;
end

%% Set phase regions of interest

num_phase_ROIs = size(ROI_phase,1);

phase_regions = cell(num_phase_ROIs,2);
for rr = 1:num_phase_ROIs
    phase_regions{rr,1} = SOphase_cbins > ROI_phase(rr,1) & SOphase_cbins <= ROI_phase(rr,2);
    phase_regions{rr,2} = freq_cbins > ROI_freq(rr,1) & freq_cbins <= ROI_freq(rr,2);

    if ROI_flip_flag(rr)
        phase_regions{rr,1} = ~phase_regions{rr,1};
    end
        
    ROI_rect(rr,:) = [ROI_phase(rr,1) ROI_freq(rr,1) diff(ROI_phase(rr,:)) diff(ROI_freq(rr,:))];

end

ROI_names = {'\sigma_{crest}', '\alpha_{trough}'};

%% Calculate ROI activity means with raw TFpeak counts

% Get usable (non zero) histograms only
use_inds = squeeze(~(nansum(SOphase_hists,[1,2])==0));
use_issz = issz(use_inds);
use_nights = nights(use_inds);

SOphase_hists = SOphase_hists(:,:,use_inds);
SOphase_counts = SOphase_counts(:,:,use_inds);

% Get region in each histogram, then get mean rate in region
phase_params = nan(sum(use_inds), num_phase_ROIs);

% loop through each region and get average rate for each hist 
for ii = 1:num_phase_ROIs
    % method 1: mean
    %phase_params(:,ii) = mean(SOphase_hists(phase_regions{ii,2}, phase_regions{ii,1},:), [1,2] ,'omitnan');
    
    % method 2: proportion in band
%     full_band_sum = squeeze(sum(SOphase_counts(phase_regions{ii,2},:,:), [1,2], 'omitnan'));
%     region_sum = squeeze(sum(SOphase_counts(phase_regions{ii,2}, phase_regions{ii,1}, :), [1,2], 'omitnan'));
%     phase_params(:,ii) = region_sum ./ full_band_sum;

    % method 3: row sums averaged
    row_sums = squeeze(sum(SOphase_hists(phase_regions{ii,2}, phase_regions{ii,1}, :), 2, 'omitnan'));
    phase_params(:,ii) = mean(row_sums,1,'omitnan');
end


%% Statistical Comparison
if length(unique(nights)) == 2

    for ii = 1:num_phase_ROIs
        % Using repeated-measures ANOVA to utilize both nights of data

        % determine night 1 and 2 features
        n1 = phase_params(use_nights==1,ii);
        n2 = phase_params(use_nights==2,ii);

        % form the tables for anova analysis
        between_tbl = table(use_issz(use_nights==1), n1, n2, 'VariableNames',{'issz','n1','n2'});
        within_tbl = table(categorical([1;2]), 'VariableNames', {'night'});

        % do mixed effect ANOVA analysis
        rm = fitrm(between_tbl, 'n1-n2 ~ issz', 'WithinDesign', within_tbl);
        ranovatbl = ranova(rm, 'WithinModel', 'night');

        % Extract pvalues for issz and night effect on avg ROI activity
        pvalues_issz(ii) = ranovatbl{'issz','pValue'};
        pvalues_night(ii) = ranovatbl{'(Intercept):night', 'pValue'};
    end
else
    pvalues_issz = [];
    pvalues_night = [];
end

%% Get histogram means
phasemean_HC = mean(SOphase_hists(:,:,~use_issz), 3, 'omitnan');
phasemean_SZ = mean(SOphase_hists(:,:,use_issz), 3, 'omitnan');

%% Plot

ylims = [4,25];

fh = figure;
ax = figdesign(2,3,'type','usletter', 'orient', 'landscape', 'merge', {[4:6]}, 'margins', ...
    [.08 .06 .08 .1 .08 .1]);
ax(2).Position(1) = ax(2).Position(1) - 0.05;

% Control phase
axes(ax(1))
imagesc(SOphase_cbins, freq_cbins, phasemean_HC);
axis xy;

styles = {'--','-'};

for rr = 1:num_phase_ROIs
    if ~ROI_flip_flag(rr)
        rectangle('Position',ROI_rect(rr,:),'linestyle',styles{rr}, 'edgecolor', 'w');
    end
end

colormap(ax(1), magma);
clims = [0.0067   0.0090];
caxis(clims);
ylim(ylims);
ylabel('Frequency (Hz)');
xlabel('SO-phase (rad)');
set(gca,'xtick',([-pi -pi/2 0 pi/2 pi]),'xticklabel',({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'}));
title('Healthy Control (HC)');
t_1 = text(-2.348, 15.7647, ROI_names{1},'fontsize',15,'color','w');
t_2 = text(-1.0525, 6.1294, ROI_names{2},'fontsize',15,'color','w');
letter_label(gcf,ax(1),'A','left',30,[.01 .05]);

% SZ phase
axes(ax(2))
imagesc(SOphase_cbins, freq_cbins, phasemean_SZ);
axis xy;

for rr = 1:num_phase_ROIs
    if ~ROI_flip_flag(rr)
        rectangle('Position',ROI_rect(rr,:),'linestyle',styles{rr}, 'edgecolor', 'w');
    end
end

colormap(ax(2), magma);
caxis(clims);
c = colorbar_noresize;
c.Position(3:4) = c.Position(3:4)*.7;
c.Position(2) = c.Position(2) + ax(2).Position(4) - c.Position(4);
c.Label.String = {'Proportion'};
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";

ylim(ylims)
set(gca,'xtick',([-pi -pi/2 0 pi/2 pi]),'xticklabel',({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'}));
title('Schizophrenia (SZ)');
xlabel('SO-phase (rad)');
yticklabels('');


% Control, SZ compare
axes(ax(3))
diff_phase = phasemean_HC - phasemean_SZ;
imagesc(SOphase_cbins, freq_cbins, diff_phase);
axis xy;

for rr = 1:num_phase_ROIs
    if ~ROI_flip_flag(rr)
        rectangle('Position',ROI_rect(rr,:),'linestyle',styles{rr});
    end
end

clims_diff = [-0.001, 0.001];
caxis(clims_diff);
colormap(ax(3), redbluemap)

c = colorbar_noresize;
c.Position(3:4) = c.Position(3:4)*.7;
c.Position(2) = c.Position(2) + ax(3).Position(4) - c.Position(4);
c.Label.String = {'Density Difference', 'Proportion'};
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";

ylim(ylims)
set(gca,'xtick',([-pi -pi/2 0 pi/2 pi]),'xticklabel',({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'}));
title('HC - SZ');
xlabel('SO-phase (rad)');

% ROI boxplots

axes(ax(4));

[h_box,pvalues_issz] = group_boxchart(phase_params, use_issz, ROI_names, {'HC','SZ'}, 1, 0.5, 'o^o^o^o^','brbrbrbrbrb', pvalues_issz(:), 'markerstyle','none');
ylabel('Proportion');
set(ax, 'FontSize', 12);
ylim([0.3,0.55]);

if any(pvalues_night(:) < 0.05)
    warning(['Effect of night is significant for ROI ', ROI_names{pvalues_night(:)<0.05}]);
end

%Make greek symbols larger
ax(4).XAxis.FontSize = 15;
letter_label(gcf,ax(4),'B','left',30,[.01 .05]);

%Print if selected
if print_png
    print(fh,'-dpng', '-r300',fullfile( fsave_path, 'PNG','phase_SZ_HC_ROI.png'));
end

if print_eps
    print(fh,'-depsc', fullfile(fsave_path, 'EPS', 'phase_SZ_HC_ROI.eps'));
end

end
