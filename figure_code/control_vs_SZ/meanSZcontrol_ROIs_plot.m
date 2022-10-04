function [pow_params, use_inds, use_issz, pvalues_issz, pvalues_night] = meanSZcontrol_ROIs_plot(powmean_cntrl, powmean_sz, ...
    SOpowmean_cbins, freqmean_cbins, powhist_counts, TIBpow, SOpow_bins, freq_bins, issz, nights, col_norm, ROI_pow, ROI_freq,...
    fsave_path, print_png, print_eps)
% Compute and plot HC and SZ means and difference histograms, and boxplots of ROI differences
%
%   Inputs:
%       powmean_cntrl: 2D double - mean power histogram for single electrode [freq x SOpower] --required
%       powmean_sz: 2D double - mean phase histogram for single electrode [freq x SOphase] --required
%       SOpowmean_cbins: 1D double - SOpower values of the bincenters used in powmean hists --required
%       freqmean_cbins: 1D double - Frequency values of the bincenters used in powmean hists --required
%       powhist_counts: 3D double - TFpeak count histograms for each subject [freq x SOpower x N] --required
%       TIBpow: 2D double - Time in each SOpower bin (minutes) --required
%       SOpow_cbins: 1D double - SOpower values of the bincenters used in powhist_counts --required
%       freq_cbins: 1D double - Frequency values of the bincenters used in powhist_counts --required
%       issz: 1D logical - SZ status for each hist --required
%       nights: 1D double - integer night label --required
%       col_norm: logical - normalize SOpower so that each column sums to 1. Default = false
%       ROI_pow:
%       ROI_freq:
%       fsave_path: char - path to save png/eps to
%       print_png: logical - save figure as png
%       pring_eps: logical - save figure as eps
%
%
%   Outputs:
%       pow_params: RxN double - [number of regions x number of histograms]
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
assert(nargin >= 10, '10 input arguments required. See function documentation');

if nargin < 11 || isempty(col_norm)
    col_norm = false;
end

if nargin < 12 || isempty(ROI_pow)
    ROI_pow = [.15 1; .65 1; 0.2 0.85; 0 .8; 0 .2]; % region of interest power boundaries;
end

if nargin < 13 || isempty(ROI_freq)
    ROI_freq = [12 15; 10 12; 7 10; 0 6; 8 12];
end

if nargin < 14 || isempty(fsave_path)
    fsave_path = '.';
end

if nargin < 15 || isempty(print_png)
    print_png = false;
end

if nargin < 16 || isempty(print_eps)
    print_eps = false;
end

%% Set pow regions of interest

if all(ROI_pow <= 1)
    pow_mult = 100;
else
    pow_mult = 1;
end

num_pow_ROIs = size(ROI_pow,1) - 1;

pow_regions = cell(num_pow_ROIs,2);
for rr = 1:num_pow_ROIs
    pow_regions{rr,1} = SOpow_bins> ROI_pow(rr,1) & SOpow_bins<= ROI_pow(rr,2);
    pow_regions{rr,2} = freq_bins> ROI_freq(rr,1) & freq_bins<= ROI_freq(rr,2);

    ROI_rect(rr,:) = [ROI_pow(rr,1)*pow_mult ROI_freq(rr,1) diff(ROI_pow(rr,:))*pow_mult diff(ROI_freq(rr,:))];

end

%ROI_names = {'\sigma_{fast}', '\sigma_{slow}', '\alpha_{low}', '\theta', '\alpha_{wake}'};
ROI_names = {'\sigma_{fast}', '\sigma_{slow}', '\alpha_{low}', '\theta'};

num_pow_ROIs = size(pow_regions,1);


%% Calculate ROI activity means with raw TFpeak counts

% Get usable (non zero) histograms only
use_inds = squeeze(~(nansum(powhist_counts,[1,2])==0));
use_issz = issz(use_inds);
use_nights = nights(use_inds);

powhist_counts = powhist_counts(:,:,use_inds);
TIBpow = TIBpow(use_inds,:);

% Get region in each histogram, then get mean rate in region
pow_params = nan(sum(use_inds), num_pow_ROIs);
if col_norm

    TIBpow_mod(1,:,:) = TIBpow'; % add singleton dim for dim agreement
    rates = powhist_counts ./ TIBpow_mod; % convert to rate
    rates_norm = rates ./ sum(rates,1); % normalize so columns add to 1
    for ii = 1:num_pow_ROIs
        region_rates_norm = rates_norm(pow_regions{ii,2}, pow_regions{ii,1},:); % select region of normalized rates
        all_weights = repelem(TIBpow(:,pow_regions{ii,1}), 1,1,size(region_rates_norm,1)); % weights for weighted mean will be time in bin
        all_weights = permute(all_weights, [3,2,1]); % make dims agree
        weighted_sum = squeeze(nansum(region_rates_norm .* all_weights,[1,2])); % multiply normalized rates by weights and add
        sum_of_weights = squeeze(sum(all_weights,[1,2])); % add up all weights
        weighted_avg = weighted_sum ./ sum_of_weights; % divide weighted sum by sum of weights to get weighted avg
        pow_params(:,ii) = weighted_avg;
    end

else
    % loop through each region and get average rate for each hist without column normalization
    for ii = 1:num_pow_ROIs
        region_count = squeeze(sum(powhist_counts(pow_regions{ii,2}, pow_regions{ii,1},:), [1,2], 'omitnan'));
        region_TIB = sum(TIBpow(:,pow_regions{ii,1}), 2);
        pow_params(:,ii) = (region_count./region_TIB);
        pow_params(:,ii) = squeeze(mean(powhist_counts(pow_regions{ii,2}, pow_regions{ii,1},:), [1,2], 'omitnan'));

    end
end

%% Statistical Comparison
if length(unique(nights)) == 2

    for ii = 1:num_pow_ROIs
        % Using repeated-measures ANOVA to utilize both nights of data

        % determine night 1 and 2 features
        n1 = pow_params(use_nights==1,ii);
        n2 = pow_params(use_nights==2,ii);

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


%% Plot

ylims = [4,25];
if col_norm
    clims = [0.0026181, 0.01684];
    clims_diff = [-0.003424, 0.003424];
else
    clims  = [1.398, 5.402];
    clims_diff = [-2.25, 2.25];
end

fh = figure;
ax = figdesign(2,3,'type','usletter', 'orient', 'landscape', 'merge', {[4:6]}, 'margins', [.08 .06 .08 .08 .08 .1]);
ax(2).Position(1) = ax(2).Position(1) - 0.05;

% Control pow
axes(ax(1))
imagesc(SOpowmean_cbins*pow_mult, freqmean_cbins, powmean_cntrl);
axis xy;

styles = {'--','-',':','-.','-.'};

for rr = 1:num_pow_ROIs
    rectangle('Position',ROI_rect(rr,:),'linestyle',styles{rr},'linewidth',2);
end

colormap(ax(1), gouldian);
clims = [.95 4.6];
caxis(clims);
ylim(ylims)
ylabel('Frequency (Hz)');
xlabel('% SO-Power');
title('Healthy Control (HC)');
t_fast = text(49,17.5,'\sigma_{fast}','fontsize',15,'color','w');
t_slow = text(13,11.25,'\sigma_{slow}','fontsize',15,'color','w');
t_alpha = text(1,8.5,'\alpha_{low}','fontsize',15,'color','w');
t_dt = text(83,5,'\theta','fontsize',15,'color','w');
letter_label(gcf,ax(1),'A','left',30,[.01 .05]);

% SZ pow
axes(ax(2))
imagesc(SOpowmean_cbins*pow_mult, freqmean_cbins, powmean_sz);
axis xy;

for rr = 1:num_pow_ROIs
    rectangle('Position',ROI_rect(rr,:),'linestyle',styles{rr}, 'linewidth',2);
end

colormap(ax(2), gouldian);
caxis(clims);
c = colorbar_noresize;
c.Position(3:4) = c.Position(3:4)*.7;
c.Position(2) = c.Position(2) + ax(2).Position(4) - c.Position(4);
c.Label.String = {'Density', '(peaks/min in bin)'};
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";

ylim(ylims)
title('Schizophrenia (SZ)');
xlabel('% SO-Power');
yticklabels('');


% Control, SZ compare
axes(ax(3))
diff_pow = powmean_cntrl - powmean_sz;
imagesc(SOpowmean_cbins*pow_mult, freqmean_cbins, diff_pow);
axis xy;

for rr = 1:num_pow_ROIs
    rectangle('Position',ROI_rect(rr,:),'linestyle',styles{rr},'linewidth',2);
end

caxis(clims_diff);
colormap(ax(3), flipud(redbluelight))

c = colorbar_noresize;
c.Position(3:4) = c.Position(3:4)*.7;
c.Position(2) = c.Position(2) + ax(3).Position(4) - c.Position(4);
c.Label.String = {'Density Difference', '(peaks/min in bin)'};
c.Label.Rotation = -90;
c.Label.VerticalAlignment = "bottom";

ylim(ylims)
title('HC - SZ');
xlabel('% SO-Power');

% ROI boxplots

axes(ax(4));

[h_box,pvalues_issz] = group_boxchart(pow_params, use_issz, ROI_names, {'HC','SZ'}, 1, 0.5, 'o^o^o^o^','brbrbrbrbrb', pvalues_issz(:), 'markerstyle','none');
ylabel('Density (peaks/min)');
set(ax, 'FontSize', 12);

if any(pvalues_night(:) < 0.05)
    warning(['Effect of night is significant for ROI ', ROI_names{pvalues_night(:)<0.05}]);
end

%Make greek symbols larger
ax(4).XAxis.FontSize = 15;
letter_label(gcf,ax(4),'B','left',30,[.01 .05]);

%Print if selected
if print_png
    print(fh,'-dpng', '-r300',fullfile( fsave_path, 'PNG','SZ_HC_ROI.png'));
end

if print_eps
    print(fh,'-depsc', fullfile(fsave_path, 'EPS', 'SZ_HC_ROI.eps'));
end
