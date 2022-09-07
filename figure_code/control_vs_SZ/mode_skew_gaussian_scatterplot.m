function [fh1] = mode_skew_gaussian_scatterplot(params, issz, min_amp, fsave_path, print_png, print_eps)
%
%
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - Tom Possidente 1/03/2022
%%%************************************************************************************%%%


%% Deal with Inputs

if nargin < 2 || isempty(min_amp)
    min_amp = 2; %Remove peaks with amps below this value
end

%Get HC and SZ indices
HC_inds = ~issz;
SZ_inds = issz;

%Set ROIs
ROI_pow = [.15 1; .4 1; 0.2 0.8; 0 .7; 0 .2];
ROI_freq = [12 16; 10 12; 7 10; 0 6; 8 12];

num_pow_ROIs = size(ROI_pow,1);

ROI_rect = zeros(num_pow_ROIs,4);
for rr = 1:num_pow_ROIs
    ROI_rect(rr,:) = [ROI_pow(rr,1)*100 ROI_freq(rr,1) diff(ROI_pow(rr,:))*100 diff(ROI_freq(rr,:))];
end

%% PLOT SCATTER
peak_inds = 1:4;

%The amount to scale the dots
size_fact = 10;

%Get the HC values
HC_pows = reshape(params(peak_inds,9,HC_inds),[],1);
HC_freqs = reshape(params(peak_inds,10,HC_inds),[],1);
HC_amps = reshape(params(peak_inds,11,HC_inds),[],1);

HC_good_inds = ~isnan(HC_pows) & ~isnan(HC_freqs) & ~isnan(HC_amps) & HC_amps>min_amp;
disp([num2str(sum(HC_amps<=min_amp)), ' out of ', num2str(length(HC_good_inds)) , ' HC peaks been eliminated due to being below the threshold']);

%Get the SZ values
SZ_pows = reshape(params(peak_inds,9,SZ_inds),[],1);
SZ_freqs = reshape(params(peak_inds,10,SZ_inds),[],1);
SZ_amps = reshape(params(peak_inds,11,SZ_inds),[],1);

SZ_good_inds = ~isnan(SZ_pows) & ~isnan(SZ_freqs) & ~isnan(SZ_amps) & SZ_amps>min_amp;
disp([num2str(sum(SZ_amps<=min_amp)), ' out of ', num2str(length(SZ_good_inds)) , ' SZ peaks been eliminated due to being below the threshold']);

%Decide what to use for size
HC_size = HC_amps;
SZ_size = SZ_amps;

%Plot the scatter plot
fh1 = figure;
hold on
%     plot3(HC_pows(HC_good_inds)*100, HC_freqs(HC_good_inds), HC_size(HC_good_inds)*size_fact,'.b');
%     plot3(SZ_pows(SZ_good_inds)*100, SZ_freqs(SZ_good_inds), SZ_size(SZ_good_inds)*size_fact,'r');
scatter(HC_pows(HC_good_inds)*100, HC_freqs(HC_good_inds), HC_size(HC_good_inds)*size_fact,'b','filled');
scatter(SZ_pows(SZ_good_inds)*100, SZ_freqs(SZ_good_inds), SZ_size(SZ_good_inds)*size_fact,'r','filled');
alpha(.5);

styles = {'--','-',':','-.','-.'};

for rr = peak_inds
    %% Plot ROI bounds
    rectangle('Position',ROI_rect(rr,:),'linestyle',styles{rr});

%         %Plot 95% confidence bound elipses
%         HC_pow_currpeak = HC_pows(rr:length(peak_inds):end);
%         HC_freqs_currpeak = HC_freqs(rr:length(peak_inds):end);
%         HC_good_inds_curr = HC_good_inds(rr:length(peak_inds):end);
%         
%         SZ_pow_currpeak = SZ_pows(rr:length(peak_inds):end);
%         SZ_freqs_currpeak = SZ_freqs(rr:length(peak_inds):end);
%         SZ_good_inds_curr = SZ_good_inds(rr:length(peak_inds):end);

%         error_ellipse(HC_pow_currpeak(HC_good_inds_curr)*100, HC_freqs_currpeak(HC_good_inds_curr), 0.1, 'b', 'linewidth', 1.5)
%         error_ellipse(SZ_pow_currpeak(SZ_good_inds_curr)*100, SZ_freqs_currpeak(SZ_good_inds_curr), 0.1, 'r', 'linewidth', 1.5)
end



xlabel('%SO-power');
ylabel('Frequency(Hz)');

%% Save
if print_png
    print(fh1,'-dpng', '-r300',fullfile( fsave_path, 'PNG','SZ_HC_ROI_PARAM_MODES_SCATTER.png'));
    %     print(fh2,'-dpng', '-r300',fullfile( fsave_path, 'PNG','SZ_HC_ROI_PARAM_MODES_BOXPLOT.png'));
end

if print_eps
    print(fh1,'-depsc', fullfile(fsave_path, 'EPS', 'SZ_HC_ROI_PARAM_MODES_SCATTER.eps'));
    %     print(fh2,'-depsc', fullfile(fsave_path, 'EPS', 'SZ_HC_ROI_PARAM_MODES_BOXPLOT.eps'));
    
end