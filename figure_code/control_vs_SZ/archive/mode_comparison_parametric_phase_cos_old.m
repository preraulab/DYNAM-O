%%
% close all;
clc;

%Set to C3
elect_num = 1;


%Change the names
freq_bins = freq_cbins_final;
pow_bins = SOpow_cbins_final;
phase_bins =  SOphase_cbins_final;


% %Remove peaks with amps below this value
% min_amp = 2;
%
% %Slightly adjusted ROIs, decide on one for both figures
% ROI_pow = [.15 1; .7 1; 0.2 0.8; 0 .7; 0 .2];
% ROI_freq = [12 16; 10 12; 7 10; 0 6; 8 12];
%
% num_pow_ROIs = size(ROI_pow,1);
%
% pow_regions = cell(num_pow_ROIs,2);
% for rr = 1:num_pow_ROIs
%     pow_regions{rr,1} = pow_bins> ROI_pow(rr,1) & pow_bins<= ROI_pow(rr,2);
%     pow_regions{rr,2} = freq_bins> ROI_freq(rr,1) & freq_bins<= ROI_freq(rr,2);
%
%     ROI_rect(rr,:) = [ROI_pow(rr,1)*100 ROI_freq(rr,1) diff(ROI_pow(rr,:))*100 diff(ROI_freq(rr,:))];
%
% end
%
% %Set nights to both nights
% night_inds = night_out > 0;
%
% %Get HC and SZ indices
% HC_inds = ~issz_out & night_inds;
% SZ_inds = issz_out & night_inds;
%
% %Create reduced range for analysis
% freq_range = freq_bins>4 & freq_bins< 18;
% params = zeros(num_pow_ROIs, 7, length(sub_inds));
%
% sub_inds = night_out;
% % progressbar
% phists = powhists{elect_num};
%
% %Fit on all subjects
% parfor ii = 1:length(night_out)
%     if sub_inds(ii)
%         pow_hist = squeeze(phists(:,:,ii));
%         pow_hist = pow_hist(freq_range,:);
%
%
%         if ~any(isnan(pow_hist(:)))
%             mparams = fit_SOPpower_Gaussian_model(pow_hist, pow_bins, freq_bins(freq_range), pow_regions, ROI_pow, ROI_freq, false);
%             title(num2str(ii));
%             params(:,:,ii) = mparams;
%         end
%     end
%     disp([num2str(ii) ' complete..']);
% end
% %% PLOT THE OUTPUT
%
% %The amount to scale the dots
% size_fact = 20;
%
% %Select which peaks to show
% peak_inds = 1:(num_pow_ROIs -1); %Don't show the wake peak
%
% %Get the HC values
% HC_pows = reshape(params(peak_inds,4,HC_inds),[],1);
% HC_freqs = reshape(params(peak_inds,2,HC_inds),[],1);
% HC_amps = reshape(params(peak_inds,1,HC_inds),[],1);
% HC_vols = reshape(params(peak_inds,7,HC_inds),[],1);
%
% HC_good_inds = ~isnan(HC_pows) & ~isnan(HC_freqs) & ~isnan(HC_amps) & HC_amps>min_amp;
%
% %Get the SZ values
% SZ_pows = reshape(params(peak_inds,4,SZ_inds),[],1);
% SZ_freqs = reshape(params(peak_inds,2,SZ_inds),[],1);
% SZ_amps = reshape(params(peak_inds,1,SZ_inds),[],1);
% SZ_vols = reshape(params(peak_inds,7,SZ_inds),[],1);
%
% SZ_good_inds = ~isnan(SZ_pows) & ~isnan(SZ_freqs) & ~isnan(SZ_amps) & SZ_amps>min_amp;
%
% %Decide what to use for size
% HC_size = HC_amps;
% SZ_size = SZ_amps;
%
% %Plot the scatter plot
% figure
% hold on
% scatter(HC_pows(HC_good_inds)*100, HC_freqs(HC_good_inds), HC_size(HC_good_inds)*size_fact,'b','filled');
% scatter(SZ_pows(SZ_good_inds)*100, SZ_freqs(SZ_good_inds), SZ_size(SZ_good_inds)*size_fact,'r','filled');
% alpha(.5);
%
% styles = {'--','-',':','-.','-.'};
%
% for rr = peak_inds
% rectangle('Position',ROI_rect(rr,:),'linestyle',styles{rr});
% end
%
%
% xlabel('%SO-power');
% ylabel('Frequency(Hz)');
% %%
%
% %Slightly adjusted ROIs, decide on one for both figures
% ROI_pow = [.15 1; .7 1; 0.2 0.8; 0 .7; 0 .2];
% ROI_freq = [12 16; 10 12; 7 10; 0 6; 8 12];
%
% num_pow_ROIs = size(ROI_pow,1);
%
% pow_regions = cell(num_pow_ROIs,2);
% for rr = 1:num_pow_ROIs
%     pow_regions{rr,1} = pow_bins> ROI_pow(rr,1) & pow_bins<= ROI_pow(rr,2);
%     pow_regions{rr,2} = freq_bins> ROI_freq(rr,1) & freq_bins<= ROI_freq(rr,2);
%
%     ROI_rect(rr,:) = [ROI_pow(rr,1)*100 ROI_freq(rr,1) diff(ROI_pow(rr,:))*100 diff(ROI_freq(rr,:))];
%
% end
%
% %Set nights to both nights
% night_inds = night_out > 0;
%
% %Get HC and SZ indices
% HC_inds = ~issz_out & night_inds;
% SZ_inds = issz_out & night_inds;
%
% %Create reduced range for analysis
% freq_range = freq_bins>4 & freq_bins< 18;
% params = zeros(num_pow_ROIs, 7, length(sub_inds));
%
% sub_inds = night_out;
% % progressbar
% phists = powhists{elect_num};
%
% %Fit on all subjects
% parfor ii = 1:length(night_out)
%     if sub_inds(ii)
%         pow_hist = squeeze(phists(:,:,ii));
%         pow_hist = pow_hist(freq_range,:);
%
%
%         if ~any(isnan(pow_hist(:)))
%             mparams = fit_SOPpower_Gaussian_model(pow_hist, pow_bins, freq_bins(freq_range), pow_regions, ROI_pow, ROI_freq, false);
%             title(num2str(ii));
%             params(:,:,ii) = mparams;
%         end
%     end
%     disp([num2str(ii) ' complete..']);
% end
%% PHASE ANALYSIS

dp = phase_bins(2)-phase_bins(1);
shift_amount = pi/3;
shift = ceil(shift_amount/dp);

%Slightly adjusted ROIs, decide on one for both figures
ROI_phase = [-pi/2 pi/4; pi/4 pi];
ROI_freq = [12 17; 6 11];

num_phase_ROIs = size(ROI_phase,1);

phase_regions = cell(num_phase_ROIs,2);
for rr = 1:num_phase_ROIs
    phase_regions{rr,1} = phase_bins> ROI_phase(rr,1) & phase_bins<= ROI_phase(rr,2);
    phase_regions{rr,2} = freq_bins> ROI_freq(rr,1) & freq_bins<= ROI_freq(rr,2);

    ROI_rect(rr,:) = [ROI_phase(rr,1) ROI_freq(rr,1) diff(ROI_phase(rr,:)) diff(ROI_freq(rr,:))];

end


%Set nights to both nights
night_inds = night_out > 0;

%Get HC and SZ indices
HC_inds = ~issz_out & night_inds;
SZ_inds = issz_out & night_inds;

%Create reduced range for analysis
freq_range = freq_bins>4 & freq_bins< 18;
params = nan(num_phase_ROIs, 6, length(night_inds));

% progressbar
phists = phasehists{elect_num};

freqs_trunc = freq_bins(freq_range);
phase_bins_shift = circshift(phase_bins,[0, -shift]);

%Fit on all subjects
parfor ii = 1:length(night_out)
    if night_inds(ii)
        phase_hist = squeeze(phists(:,:,ii));
        phase_hist = phase_hist(freq_range,:);
        phase_hist = circshift(phase_hist,[0, -shift]);
        
        if ~any(isnan(phase_hist(:)))
            mparams = fit_SOPphase_Gaussian_cos_model(phase_hist, phase_bins, freqs_trunc, phase_regions, ROI_phase, ROI_freq, false);
%             title(num2str(ii));
            params(:,:,ii) = mparams;
            %pause
%             close all
        end
    end
    disp([num2str(ii) ' complete..']);
end

%% SCATTERPLOT
min_amp = 0.001;

%The amount to scale the dots
size_fact = 2.75e4;

%Select which peaks to show
peak_inds = 1:2; %

%Get the HC values
HC_amps = reshape(params(peak_inds,1,HC_inds),[],1);
HC_freqs = reshape(params(peak_inds,2,HC_inds),[],1);
HC_fstd = reshape(params(peak_inds,3,HC_inds),[],1);
HC_phases = reshape(params(peak_inds,4,HC_inds),[],1);
HC_vols = reshape(params(peak_inds,6,HC_inds),[],1);

HC_good_inds = ~isnan(HC_phases) & ~isnan(HC_freqs) & ~isnan(HC_amps) & HC_amps>min_amp;
 
%Get the SZ values
SZ_amps = reshape(params(peak_inds,1,SZ_inds),[],1);
SZ_freqs = reshape(params(peak_inds,2,SZ_inds),[],1);
SZ_fstd = reshape(params(peak_inds,3,SZ_inds),[],1);
SZ_phases = reshape(params(peak_inds,4,SZ_inds),[],1);
SZ_vols = reshape(params(peak_inds,6,SZ_inds),[],1);


SZ_good_inds = ~isnan(SZ_phases) & ~isnan(SZ_freqs) & ~isnan(SZ_amps) & SZ_amps>min_amp;

%Decide what to use for size
HC_size = HC_amps;
SZ_size = SZ_amps;

%Plot the scatter plot
figure
hold on
shc = scatter(HC_phases(HC_good_inds), HC_freqs(HC_good_inds), HC_size(HC_good_inds)*size_fact,'b','filled');
ssz = scatter(SZ_phases(SZ_good_inds), SZ_freqs(SZ_good_inds), SZ_size(SZ_good_inds)*size_fact,'r','filled');
alpha(.5);

styles = {'--','-',':','-.','-.'};

for rr = peak_inds
    rpos = ROI_rect(rr,:);
    rpos(2) = rpos(2)+shift;
    rectangle('Position',ROI_rect(rr,:),'linestyle',styles{rr});
end


xlabel('SO-phase');
ylabel('Frequency(Hz)');

legend([shc(1) ssz(1)], 'HC','SZ');

%% BOXPLOT

[pvals_issz, pvals_night] = mode_parameter_boxplot(params, [1,2], [1,2,4], issz_out, night_out, {'Sigma Wide','Low'}, {'Amplitude','Frequency (Hz)', 'Phase (rad)'},...
                                                            min_amp, 1, '', false, false);



