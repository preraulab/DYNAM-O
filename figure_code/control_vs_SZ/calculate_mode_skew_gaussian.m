function [params, offset] = calculate_mode_skew_gaussian(powhists, SOpow_cbins, freq_cbins, nights, ROI_pow, ROI_freq, elect_num)
% Fit skew gaussian to modes in regions of interest on SO power histograms and return parameters of the mode fits
%
%   Inputs:
%       powhists: cell array - each cell is a 3D double containing all SOpower histograms 
%                 for a single electrode [freq, SOpower, subject/night] --required
%       SOpow_cbins: 1D double - bin centers for SOpower axis of powhists --required
%       freq_cbins: 1D double - bin centers for freq axis of powhists --required
%       nights: 1D double - indicates night for each histogram in powhists (3rd dim) --required
%       ROI_pow: 2D double - indicates lower and upper SOpow limits of each ROI where rows 
%                are ROI and columns are lower and upper bounds
%       ROI_freq: 2D double - indicates lower and upper freq limits of each ROI where rows 
%                are ROI and columns are lower and upper bounds
%       elect_num: int - index of electrode in powhists to use for analysis
%
%   Ouputs:
%       params: 3D double - params for each mode for each subj [num_modes, num_params, num_subjs]
%       offset: 1D double - global offset parameter for all modes for each subj
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - Tom Possidente 2/03/2022
%%%************************************************************************************%%%

%% Deal with Inputs
assert(nargin >= 4, '4 inputs required: powhists, SOpow_cbins, freq_cbins, nights');

if nargin < 5 || isempty(ROI_pow)
    ROI_pow = [.15 1; .65 1; 0.2 0.85; 0 .8; 0 .2]; % region of interest power boundaries
end

if nargin < 6 || isempty(ROI_freq)
    ROI_freq = [12 16; 10 12; 7 10; 0 6; 8 12]; % region of interest freq boundaries
end

if nargin < 7 || isempty(elect_num)
    elect_num = 1; % C3
end

%% Make 2D mask for selecting SOpow regions of interest on hists
num_pow_ROIs = size(ROI_pow,1);

pow_regions = cell(num_pow_ROIs,2);
for rr = 1:num_pow_ROIs
    pow_regions{rr,1} = SOpow_cbins> ROI_pow(rr,1) & SOpow_cbins<= ROI_pow(rr,2);
    pow_regions{rr,2} = freq_cbins> ROI_freq(rr,1) & freq_cbins<= ROI_freq(rr,2);    
end

%% Make mask for which night of data to use for each subj
night_mask = nights == 2;

%% Select which peaks to show
peak_inds = 1:(num_pow_ROIs -1); %Don't show the wake peak

%% Create reduced frequency range for analysis
freq_range = freq_cbins>4 & freq_cbins< 18;

%% Prealocate outputs
params = nan(num_pow_ROIs, 11, length(night_mask));
offset = zeros(length(night_mask),1);

%% Fit modes with skew gaussian model
phists = powhists{elect_num}; % select hists of specified electrode
parfor ii = 1:length(nights)
    if night_mask(ii) % only fit on desired night
        disp(['Analyzing ' num2str(ii)]);
        pow_hist = squeeze(phists(:,:,ii)); % get singular subj histogram
        pow_hist = pow_hist(freq_range,:); % restrict freq range
        
        if ~all(isnan(pow_hist(:))) % hist must not be all nans
           pow_hist(isnan(pow_hist)) = 0; % convert nans to 0s to avoid fitting errors
           [ mparams, offset(ii)] = fit_SOPpower_skew_Gaussian_model(pow_hist, SOpow_cbins, freq_cbins(freq_range), pow_regions, ROI_freq, false);
            params(:,:,ii) = mparams;

        end
    end
end

