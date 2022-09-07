function wcentroid = weighted_centroid(data, row_vals, col_vals, trans_func, plot_on)

%% Simulate data
if nargin == 0
    N = 100;
    pow_bins = linspace(0,1,N);
    freq_bins = linspace(4,20,N);

    %Get generate the peak
    data = peaks(100);

    trans_func = @exp;

    weighted_centroid(data,freq_bins,pow_bins,trans_func, true);
    return;
end

%Set default transformation function to identity
if nargin<4
    trans_func = @(x)x;
end

if nargin<5
    plot_on = false;
end

%Compute the region properties
mask = true(size(data));
%Do the transformation
data_trans = trans_func(data);

%Make sure nothing is less than zero
data_trans = data_trans-min(data_trans(:));

%Compute region props
props = regionprops(mask, data_trans,'WeightedCentroid');

%Interpolate to get the centroid in the row/col space
wcentroid(1) = interp1(1:length(col_vals),col_vals, props.WeightedCentroid(1));
wcentroid(2) = interp1(1:length(row_vals),row_vals, props.WeightedCentroid(2));

if plot_on
    %Plot the results
    close all;
    hold on
    imagesc(col_vals, row_vals, data)
    axis xy; 
    plot(wcentroid(1),wcentroid(2),'o','markersize',10,'MarkerFaceColor','m','MarkerEdgeColor','k')
    axis tight
end

