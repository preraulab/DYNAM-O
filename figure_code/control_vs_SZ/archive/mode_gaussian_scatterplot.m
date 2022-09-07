function [] = mode_gaussian_scatterplot(powhists, SOpow_cbins, freq_cbins, issz, nights, elect_num, min_amp, fsave_path, print_png, print_eps)
%
%
%

%% Deal with Inputs
if nargin < 6 || isempty(elect_num)
    elect_num = 1;
end

if nargin < 7 || isempty(min_amp)
    min_amp = 2; %Remove peaks with amps below this value
end


%Slightly adjusted ROIs, decide on one for both figures
ROI_pow = [.15 1; .7 1; 0.2 0.8; 0 .7; 0 .2];
ROI_freq = [12 16; 10 12; 7 10; 0 6; 8 12];

num_pow_ROIs = size(ROI_pow,1);
pow_ROI_names = {'\sigma_{fast}', '\sigma_{slow}', '\alpha_{low}', '\theta'};

pow_regions = cell(num_pow_ROIs,2);
for rr = 1:num_pow_ROIs
    pow_regions{rr,1} = SOpow_cbins> ROI_pow(rr,1) & SOpow_cbins<= ROI_pow(rr,2);
    pow_regions{rr,2} = freq_cbins> ROI_freq(rr,1) & freq_cbins<= ROI_freq(rr,2);
  
    ROI_rect(rr,:) = [ROI_pow(rr,1)*100 ROI_freq(rr,1) diff(ROI_pow(rr,:))*100 diff(ROI_freq(rr,:))];
    
end

%Set nights to both nights
night_inds = nights > 0;

%Select which peaks to show
peak_inds = 1:(num_pow_ROIs -1); %Don't show the wake peak

%Get HC and SZ indices
HC_inds = ~issz & night_inds;
SZ_inds = issz & night_inds;

%Create reduced range for analysis
sub_inds = night_inds;
freq_range = freq_cbins>4 & freq_cbins< 18;
params = nan(num_pow_ROIs, 8, length(sub_inds));

% progressbar
phists = powhists{elect_num};

%Fit on all subjects
for ii = 1:length(nights)
    if sub_inds(ii)
        pow_hist = squeeze(phists(:,:,ii));
        pow_hist = pow_hist(freq_range,:);
        
        
        if ~all(isnan(pow_hist(:)))
            mparams = fit_SOPpower_skew_Gaussian_model(pow_hist, SOpow_cbins, freq_cbins(freq_range), pow_regions, ROI_pow, ROI_freq, false);
            params(:,:,ii) = mparams;
%             pause;
%             close all;
        end
    end
    disp([num2str(ii) ' complete..']);
end

%% Statistical comparisons of SO%,frequency, and amplitude of Gaussians for each region 
all_SO_modes = nan(length(issz), length(peak_inds));
all_freq_modes = nan(length(issz), length(peak_inds));
all_amp_modes = nan(length(issz), length(peak_inds));
all_vol_modes = nan(length(issz), length(peak_inds));

use_inds = squeeze(~any(isnan(params(:,[4,2,1,7],:)),[1,2]));

for r = 1:length(peak_inds)
    all_SO_modes(:,r) = squeeze(params(r,4,:));
    all_freq_modes(:,r) = squeeze(params(r,2,:));
    all_amp_modes(:,r) = squeeze(params(r,1,:));
    all_vol_modes(:,r) = squeeze(params(r,7,:));
    
    n1_SO = all_SO_modes((nights==1 & use_inds), r);
    n2_SO = all_SO_modes((nights==2 & use_inds), r);

    n1_freq = all_freq_modes((nights==1 & use_inds), r);
    n2_freq = all_freq_modes((nights==2 & use_inds), r);
    
    n1_amp = all_amp_modes((nights==1 & use_inds), r);
    n2_amp = all_amp_modes((nights==2 & use_inds), r);
    
    n1_vol = all_vol_modes((nights==1 & use_inds), r);
    n2_vol = all_vol_modes((nights==2 & use_inds), r);
    
    % form the tables for anova analysis 
    between_tbl_SO = table(issz(nights==1 & use_inds), n1_SO, n2_SO, 'VariableNames',{'issz','n1_SO','n2_SO'});
    between_tbl_freq = table(issz(nights==1 & use_inds), n1_freq, n2_freq, 'VariableNames',{'issz','n1_freq','n2_freq'});
    between_tbl_amp = table(issz(nights==1 & use_inds), n1_amp, n2_amp, 'VariableNames',{'issz','n1_amp','n2_amp'});
    between_tbl_vol = table(issz(nights==1 & use_inds), n1_vol, n2_vol, 'VariableNames',{'issz','n1_vol','n2_vol'});

    within_tbl = table(categorical([1;2]), 'VariableNames', {'night'});

    % do mixed effect ANOVA analysis 
    rm_SO = fitrm(between_tbl_SO, 'n1_SO-n2_SO ~ issz', 'WithinDesign', within_tbl);
    rm_freq = fitrm(between_tbl_freq, 'n1_freq-n2_freq ~ issz', 'WithinDesign', within_tbl);
    rm_amp = fitrm(between_tbl_amp, 'n1_amp-n2_amp ~ issz', 'WithinDesign', within_tbl);
    rm_vol = fitrm(between_tbl_vol, 'n1_vol-n2_vol ~ issz', 'WithinDesign', within_tbl);

    ranovatbl_SO = ranova(rm_SO, 'WithinModel', 'night');
    ranovatbl_freq = ranova(rm_freq, 'WithinModel', 'night');
    ranovatbl_amp = ranova(rm_amp, 'WithinModel', 'night');
    ranovatbl_vol = ranova(rm_vol, 'WithinModel', 'night');
    
    pvalues_issz_SO(r) = ranovatbl_SO{'issz','pValue'};
    pvalues_night_SO(r) = ranovatbl_SO{'(Intercept):night', 'pValue'};

    pvalues_issz_freq(r) = ranovatbl_freq{'issz','pValue'};
    pvalues_night_freq(r) = ranovatbl_freq{'(Intercept):night', 'pValue'};
    
    pvalues_issz_amp(r) = ranovatbl_amp{'issz','pValue'};
    pvalues_night_amp(r) = ranovatbl_amp{'(Intercept):night', 'pValue'};
    
    pvalues_issz_vol(r) = ranovatbl_vol{'issz','pValue'};
    pvalues_night_vol(r) = ranovatbl_vol{'(Intercept):night', 'pValue'};
end


%% PLOT SCATTER 

%The amount to scale the dots
size_fact = 20;

%Get the HC values
HC_pows = reshape(params(peak_inds,4,HC_inds),[],1);
HC_freqs = reshape(params(peak_inds,2,HC_inds),[],1);
HC_amps = reshape(params(peak_inds,1,HC_inds),[],1);
HC_vols = reshape(params(peak_inds,7,HC_inds),[],1);

HC_good_inds = ~isnan(HC_pows) & ~isnan(HC_freqs) & ~isnan(HC_amps) & HC_amps>min_amp;

%Get the SZ values
SZ_pows = reshape(params(peak_inds,4,SZ_inds),[],1);
SZ_freqs = reshape(params(peak_inds,2,SZ_inds),[],1);
SZ_amps = reshape(params(peak_inds,1,SZ_inds),[],1);
SZ_vols = reshape(params(peak_inds,7,SZ_inds),[],1);

SZ_good_inds = ~isnan(SZ_pows) & ~isnan(SZ_freqs) & ~isnan(SZ_amps) & SZ_amps>min_amp;

%Decide what to use for size
HC_size = HC_amps;
SZ_size = SZ_amps;

%Plot the scatter plot
fh1 = figure;
hold on
scatter(HC_pows(HC_good_inds)*100, HC_freqs(HC_good_inds), HC_size(HC_good_inds)*size_fact,'b','filled');
scatter(SZ_pows(SZ_good_inds)*100, SZ_freqs(SZ_good_inds), SZ_size(SZ_good_inds)*size_fact,'r','filled');
alpha(.5);

styles = {'--','-',':','-.','-.'};

for rr = peak_inds
rectangle('Position',ROI_rect(rr,:),'linestyle',styles{rr});
end


xlabel('%SO-power');
ylabel('Frequency(Hz)');

%% PLOT BOXPLOT
fh2 = figure;
ax = figdesign(2,2);

axes(ax(1));
h_box1 = group_boxchart(all_SO_modes(use_inds,:), issz(use_inds,:), pow_ROI_names, {'HC','SZ'}, 1, 0.5, 'o^o^o^o^','brbrbrbrbrb', pvalues_issz_SO(:), 'markerstyle','none');
ylabel('% SO Power');
if any(pvalues_night_SO < 0.05)
   warning(['Significant effect of night on SOpower found for region(s): ', pow_ROI_names{pvalues_night_SO<0.05}]) 
end

axes(ax(2))
h_box2 = group_boxchart(all_freq_modes(use_inds,:), issz(use_inds,:), pow_ROI_names, {'HC','SZ'}, 1, 0.5, 'o^o^o^o^','brbrbrbrbrb', pvalues_issz_freq(:), 'markerstyle','none');
ylabel('Frequency (Hz)')
if any(pvalues_night_freq < 0.05)
   warning(['Significant effect of night on frequency found for region(s): ', pow_ROI_names{pvalues_night_freq<0.05}]) 
end

axes(ax(3));
h_box3 = group_boxchart(all_amp_modes(use_inds,:), issz(use_inds,:), pow_ROI_names, {'HC','SZ'}, 1, 0.5, 'o^o^o^o^','brbrbrbrbrb', pvalues_issz_amp(:), 'markerstyle','none');
ylabel('Gaussian Amplitude');
if any(pvalues_night_amp < 0.05)
   warning(['Significant effect of night on amplitude found for region(s): ', pow_ROI_names{pvalues_night_amp<0.05}]) 
end

axes(ax(4))
h_box4 = group_boxchart(all_vol_modes(use_inds,:), issz(use_inds,:), pow_ROI_names, {'HC','SZ'}, 1, 0.5, 'o^o^o^o^','brbrbrbrbrb', pvalues_issz_vol(:), 'markerstyle','none');
ylabel('Volume');
if any(pvalues_night_vol < 0.05)
   warning(['Significant effect of night on volume found for region(s): ', pow_ROI_names{pvalues_night_vol<0.05}]) 
end

%% Save
if print_png
    print(fh1,'-dpng', '-r300',fullfile( fsave_path, 'PNG','SZ_HC_ROI_PARAM_MODES_SCATTER.png'));
    print(fh2,'-dpng', '-r300',fullfile( fsave_path, 'PNG','SZ_HC_ROI_PARAM_MODES_BOXPLOT.png'));
end

if print_eps
    print(fh1,'-depsc', fullfile(fsave_path, 'EPS', 'SZ_HC_ROI_PARAM_MODES_SCATTER.eps'));
    print(fh2,'-depsc', fullfile(fsave_path, 'EPS', 'SZ_HC_ROI_PARAM_MODES_BOXPLOT.eps'));

end