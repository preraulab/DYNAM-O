function [SO_resized, freqcbins_resize, SO_cbins_resize] = rebin_histogram(hist_data, TIB_data, freq_cbins, SO_cbins, freq_binsizestep, ...
                                                                           SO_binsizestep, SOtype, conv_type, ispartial, isrepeating, TIB_req)
% IN PROGRESS
%
% Inputs:
%       hist_data: MxNxP 3D double - [freq, SO_feature, num_subjs]
%

%% Deal with Inputs
assert(nargin >= 7, '7 arguments required (hist_data, TIB_data, freq_cbins, SO_cbins, freq_binsizestep, SO_binsizestep, SOtype)');

switch lower(SOtype)
    case {'pow', 'power'}
        if nargin < 8 || isempty(conv_type)
            conv_type = 0;
        end
        
        if nargin < 9 || isempty(ispartial)
            ispartial = false;
        end
        
        if nargin < 10 || isempty(isrepeating)
            isrepeating = false;
        end
        
        if nargin < 11 || isempty(TIB_req)
            TIB_req = 1;
        end
        
    case {'phase'}
        if nargin < 8 || isempty(conv_type)
            conv_type = 'circular';
        end
        
        if nargin < 9 || isempty(ispartial)
            ispartial = true;
        end
        
        if nargin < 10 || isempty(isrepeating)
            isrepeating = true;
        end
        
        if nargin < 11 || isempty(TIB_req)
            TIB_req = 0;
        end
        
    otherwise
        error('SOtype not recognized')
end

%% Calc small bin sizes
freq_smallbinsize = freq_cbins(2) - freq_cbins(1);
SO_smallbinsize = SO_cbins(2) - SO_cbins(1);

%% Make sure bin sizes and binsteps are divisible by small bin size
assert( all(round(mod(freq_binsizestep, freq_smallbinsize),6) == 0),  ['frequency bin size and bin step need to be divisible by ', num2str(freq_smallbinsize)] )
assert( all(round(mod(SO_binsizestep, SO_smallbinsize),6) == 0),  ['SO bin size and bin step need to be divisible by ', num2str(SO_smallbinsize)] )

%% Calculate number of bins to combine and number of bins to skip
freq_ncomb = round(freq_binsizestep(1) / freq_smallbinsize, 6);
freq_nskip = round(freq_binsizestep(2) / freq_smallbinsize, 6);

SO_ncomb = round(SO_binsizestep(1) / SO_smallbinsize, 6);
SO_nskip = round(SO_binsizestep(2) / SO_smallbinsize, 6);

%% Resize SOpow and SOphase data
N_subj = size(hist_data,3);

len_freq_resized = length(freq_ncomb:freq_nskip:length(freq_cbins));
switch lower(SOtype)
    case {'pow','power'}
        % Calculate resized dimensions SOpow
        SO_resized = nan(N_subj, len_freq_resized, length(SO_ncomb:SO_nskip:length(SO_cbins)));
        
    case {'phase'}
        % Calculate resized dimensions for SOphase
        col_start = SO_ncomb;
        col_end = length(SO_cbins);
        if mod(SO_ncomb,2)
            col_end = col_end + floor(SO_ncomb/2);
            col_start = col_start - ceil(SO_ncomb/2);
        else
            col_end = col_end + SO_ncomb/2;
            col_start = col_start - SO_ncomb/2;
        end

        if SO_nskip~=1
            col_inds = sort(unique([SO_ncomb:-SO_nskip:col_start, SO_ncomb:SO_nskip:col_end]));
        else
            col_inds = col_start:col_skip:col_end;
        end

        SO_resized = nan(N_subj, len_freq_resized, length(col_inds));
end


% Loop through and resize
for ii = 1:N_subj
    
    % Resize SO hists and get rates 
    [~, hist_rates, ~, freqcbins_resize, SO_cbins_resize] = SOhist_conv(hist_data(:,:,ii), TIB_data(ii,:), freq_cbins, ...
                                                                                   SO_cbins, [freq_ncomb, SO_ncomb], [freq_nskip, SO_nskip],...
                                                                                   conv_type, ispartial, isrepeating, TIB_req, false);
    SO_resized(ii,:,:) = hist_rates;
    
    % Normalize SOphase
    if strcmpi(SOtype, 'phase')
        SO_resized(ii,:,:) = squeeze(SO_resized(ii,:,:)) ./ sum(squeeze(SO_resized(ii,:,:)),2);
    end
end



end

