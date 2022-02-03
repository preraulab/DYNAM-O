function [SOdata_counts, SOdata_rates, SO_TIB_out, freq_cbins, SO_cbins] = SOhist_conv(SO_data, SO_TIB, x_cbins, y_cbins, num_combine, num_skip, conv_type, ispartial, ...
                                                                                       isrepeating, TIB_req, ploton)
%
%
% Inputs:
%       SO_data: MxN double - SO data (counts not rates) with frequency as 1st dim and SO
%                feature as 2nd dim --required
%       SO_TIB: 1xN double - Time in bin (seconds) for each SO bin --required
%       x_cbins: Bin center values for x axis of SO_data --required
%       y_cbins: Bin center values for y axis of SO_data --required
%       num_combine: 1x2 integers - number of bins to combine in x and y
%                    direction [nbins_x nbins_y] --required
%       num_skip: 1x2 integers - number of bins to skip (bin step) when
%                 selecting from imfiltered data --required
%       conv_type: integer or char - indicates the convolution padding
%                  options. Integer indicates number of 0s to pad with. 'circular' 
%                  indicates bins wrap around. Default = 0
%       ispartial: logical - indicates whether combined bins in columns of
%                  SO_data can be partial. Default = false
%       isrepeating: logical - indicates whether the first and last columns
%                    of SOdata_counts and SOdata_rates should be the same/repeated to
%                    show circularity of bins. Default = false
%       TIB_req: double - minutes required in each y bin. Y bins with <
%                TIB_req minutes will be tured to NaNs. Defauly = 0.
%       ploton: logical - plot new 2D heatmap of rates. Default = false
%       
%
% Outputs:
%       SOdata_counts: resized peak counts (frequency as 1st dim and SO
%                      feature as 2nd dim)
%       SOdata_rates: resized peak rates (frequency as 1st dim and SO
%                      feature as 2nd dim) in peakas/min
%       SO_TIB_out: Time in each SO feature bin (minutes)
%       freq_cbins: Bin centers for x axis (1st dim) of SOdata_counts and
%                   SOdata_rates
%       SO_cbins: Bin centers for y axis (2nd dim) of SOdata_counts and
%                 SOdata_rates
%
%
% Last Modified:
%       - created: Tom P and Mike P - 12/29/2021
%
%
%%%************************************************************************************%%%


%% Deal with inputs
assert(nargin >= 6, '6 inputs required');
assert(size(SO_TIB,1)==1, 'SO_TIB must be 1xN');

if nargin < 7 || isempty(conv_type)
    conv_type = 0; % 0 for pow, 'circular' for phase
end

if nargin < 8 || isempty(ispartial)
    ispartial = false; % false for pow, true for phase
end

if nargin < 9 || isempty(isrepeating)
    isrepeating = false; % false for pow, true for phase
end

if nargin < 10 || isempty(TIB_req)
    TIB_req = 0;
end

if nargin < 11 || isempty(ploton)
    ploton = false;
end


% Establish row and column combination factors and skip factors
row_fact = num_combine(1);
col_fact = num_combine(2);
row_skip = num_skip(1);
col_skip = num_skip(2);

%First full conv
%disp(['First full conv = ' num2str(sum(SO_data(1:row_fact,1:col_fact),'all'))]);

%Define convolution filter
conv_filt = ones(row_fact, col_fact);

%Run the convolution
matfilt = imfilter(SO_data,conv_filt,'full',conv_type,'conv');
timesfilt = imfilter(SO_TIB,conv_filt(1,:),'full',conv_type,'conv');
%timesfilt = [timesfilt];

%Set up selection from full matrix
row_start = row_fact;
col_start = col_fact;

%Compute the range for full bins
row_end = size(SO_data,1);
col_end = size(SO_data,2);

%Handle partial columns
if ispartial
    if mod(col_fact,2)
        col_end = col_end + floor(col_fact/2);
        col_start = col_start - ceil(col_fact/2);
    else
        col_end = col_end + col_fact/2;
        col_start = col_start - col_fact/2;
    end
    
    if ~isrepeating
        col_end = col_end - 1;
    end
end

%Create new matrix
if ispartial && col_skip~=1
    col_inds = sort(unique([col_fact:-col_skip:col_start, col_fact:col_skip:col_end]));
else
    col_inds = col_start:col_skip:col_end;
end

row_inds = row_start:row_skip:row_end;

SOdata_counts = matfilt(row_inds, col_inds);

SO_TIB_out = timesfilt(col_inds);

%Compute rate
SOdata_rates = SOdata_counts./SO_TIB_out;

%Make new bins 
freq_cbins = x_cbins(row_fact/2:row_skip:end-(row_fact/2));
if isrepeating && max(col_inds>length(y_cbins))
    col_inds_alt = col_inds(1:end-1);
    SO_cbins = [y_cbins(col_inds_alt-(col_start-1)), y_cbins(end)+(y_cbins(2)-y_cbins(1))];
else
    SO_cbins = y_cbins(col_fact/2:col_skip:end-(col_fact/2));
end

% If column doesn't have enough time, mark as nan
if TIB_req ~= 0 
    bad_inds = SO_TIB_out < TIB_req;
    SOdata_counts(:, bad_inds(:)) = NaN;
    SOdata_rates(:, bad_inds(:)) = NaN;
end

% Plot new mat
if ploton
    figure; imagesc(SO_cbins, freq_cbins, SOdata_rates); axis xy; colormap parula; climscale; colorbar;
end

end

