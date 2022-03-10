function [SOfeat_allstages, freqcbins_new, TIB_allstages, PIB_allstages, issz_out, night_out] = ...
                    reconstruct_SOpowphase(SO_data, TIB, PIB, freq_cbins, SO_feat, night, SZ, stages, TIB_limit,...
                    freq_range, issz, count_flag)
% Takes in per-stage SO power/phase peak counts and integrates them into a
% single SO power/phase rate histogram
%
% Inputs:
%       SO_data: 5D double - Slow oscillation feature data (dimensions = freqbins, SObins, subjs, nights, 
%                            stages) --required
%       TIB: 4D double - Time in bin data (SObins, subjs, nights, stages) --required
%       PIB: 4D double - Proportion time in bin data (SObins, subjs, nights, stages) --required
%       freq_cbins: frequency bin centers used for SO_data dim 1 --required
%       SO_feat: char - SO feature being used ('power' or 'phase') --required
%       night: double - which night to extract (1, 2, or [1,2]). Default = [1,2]
%       SZ: logical - extract SZ patients only. Leave blank to extract both SZ and control 
%                      patients (default)
%       stages: double - which stages to combine in reconstruction. Note that 5=WAKE, 4=REM, 
%                        3=NREM1, 2=NREM2, 1=NREM1. Default = [1:5]
%       TIB_limit: double - number of minutes required in SO bin to use the bin, else all values 
%                           in bin will be set to NaN. Default = 1.
%       freq_range: double - [min freq, max freq]. Default = [4, 35];
%       issz: logical vector - indicates the SZ status of each subject in SO_data. 
%                              Default = [false(17,1); true(23,1)]
%       count_flag: logical - return histograms in raw counts per bin instead of rates 
%                             (events/min). Default = false.
%
% Outputs:
%       SOfeat_allstages: 3D double - Peak data (counts or rates). Dim 1 is
%                         frequency, dim 2 is SOfeature, dim 3 is subject
%       freqcbins_new: 1D double - new center bins for frequency axis of
%                      SOfeatallstages. Note: the SOfeat cbins will be
%                      unchanged
%       TIB_allstages: 2D double - Time in each SOfeat bin (minutes) for
%                      each stage 
%       PIB_allstages: 2D double - Proportion of time in each SOfeat bin
%                                  for each stage
%       issz_out: logical vector - SZ status for each subject
%       night_out: double - night status for each subject
%
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - Tom Possidente 11/30/2021
%%%************************************************************************************%%%


%% Deal with inputs
assert(nargin >=5, '5 inputs required: SO_data, TIB, PIB, freq_cbins SO_feat');

if any(strcmpi(SO_feat, {'pow', 'power'}))
    SO_feat = 'power';
end
    
if nargin < 6 || isempty(night)
    night = [1, 2];
end

if nargin < 7 || isempty(SZ)
    SZ = []; % empty gets both SZ and controls
end

if nargin < 8 || isempty(stages)
    stages = [1:5]; % all strages
end

if nargin < 9 || isempty(TIB_limit)
    TIB_limit = 1; % minute
end

if nargin < 10 || isempty(freq_range)
    freq_range = [4, 35];
end

if nargin < 11 || isempty(issz)
    issz = [false(17,1); true(23,1)];
end

if nargin < 12 || isempty(count_flag)
    count_flag = false;
end

%% 

% Get SZ, nonSZ, or all subj inds
if isempty(SZ)
    use_SZ = true(size(SO_data,3),1);
elseif SZ == true
    use_SZ = issz;
elseif SZ == false
    use_SZ = ~issz;
else 
    error('SZ input not recognized. Should be empty, true, or false.');
end

% Get SO data for desired subjects, nights, and stages
night_logical = ismember([1,2], night); % turn indices to logical
stages_logical = ismember([1,2,3,4,5], stages); % turn indices to logical

freqs_use = (freq_cbins <= freq_range(2)) & (freq_cbins >= freq_range(1));
freqcbins_new = freq_cbins(freqs_use);

% Select relevant SO, TIB (time in bin), and PIB (proportion in bin) data
SO_data = SO_data(:,freqs_use,use_SZ,night_logical,stages_logical); %(SOfeat_bins, freq_bins, num_subjs, num_nights, num_stages)
TIB = TIB(:,use_SZ,night_logical,stages_logical);
PIB = PIB(:,use_SZ,night_logical,stages_logical);

% Initialize data storage
n_mats = sum(use_SZ) * length(night);
SOfeat_allstages = zeros(n_mats, size(SO_data,1), size(SO_data,2));
TIB_allstages = zeros(n_mats, size(TIB,1), 5);
PIB_allstages = zeros(n_mats, size(PIB,1), 5);
issz_out = NaN(n_mats,1);
night_out = NaN(n_mats,1);

%% Sum stages
count = 0;
for ii = 1:sum(use_SZ) % for each subj 
    for n = 1:length(night) % for each  night
        count = count + 1;
        
        for s = 1:length(stages) % for each selected stage
            % Sum SO, TIB, and PIB data for relevant stages
            SOfeat_allstages(count,:,:) = nansum(cat(3, squeeze(SOfeat_allstages(count,:,:)), SO_data(:,:,ii,n,s)),3);
            TIB_allstages(count,:, s) = TIB(:,ii,n,s);
            PIB_allstages(count,:, s) = PIB(:,ii,n,s);
        end
        
        if isempty(SZ)
            issz_out(count) = issz(ii);
        elseif SZ == true
            issz_out(count) = true;
        else 
            issz_out(count) = false;
        end
        
        night_out(count) = night(n);
        
    end
end

% If desired, return rates instead of counts
if ~count_flag 
    SOfeat_allstages = SOfeat_allstages ./ sum(TIB_allstages,3);
    
    % If returning rates and using phase, normalize so each frequency row sums to 1
    if strcmp('phase', SO_feat)
        SOfeat_allstages = SOfeat_allstages ./ sum(SOfeat_allstages,2);
    end
end

% Make sure issz_out is logical
issz_out = logical(issz_out);

% Set bins with less than x mins of data to NaN
if strcmp('power', SO_feat) && TIB_limit > 0
    TIB_allstages_summed = nansum(TIB_allstages,3);
    bad_inds = TIB_allstages_summed < TIB_limit;
    SOfeat_allstages_reshape = reshape(SOfeat_allstages, [size(SOfeat_allstages,1)*size(SOfeat_allstages,2), size(SOfeat_allstages,3)] );
    SOfeat_allstages_reshape(bad_inds(:), :) = NaN;
    SOfeat_allstages = reshape(SOfeat_allstages_reshape, [size(SOfeat_allstages,1), size(SOfeat_allstages,2), size(SOfeat_allstages,3)]); 
end

end

