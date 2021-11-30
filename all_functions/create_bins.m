function [bin_edges, bin_centers] = create_bins(bin_range, bin_width, bin_step, bin_method)
%CREATE_BINS Create bins with potential for overlap
%   [bin_edges, bin_centers] = create_bins(bin_range, bin_width, bin_step, full_bins)
%
% Inputs:
%   bin_range: 1x2 numeric vector - [min max] --required
%   bin_width: numeric - how large each bin is --required
%   bin_step: numeric - step size --required
%   bin_method: char - 'full' starts the first bin at bin_range(1). 'partial' starts the 
%               first bin with its bin center at bin_range(1) but ignores all values below 
%               bin_range(1). 'full_extend' starts the first bin at bin_range(1) - bin_width/2. 
%               Note that it is possible to get values outside of bin_range with this setting. 
%               Default = 'full'.
%
% Outputs:
%   bin_edges: 2xN vector - where the first row is the lefthand bin edges and the 2nd row is 
%              righthand bin edges
%   bin_centers: 1xN - centers of each bin
%
%%%************************************************************************************%%%

if nargin<4
    bin_method = 'full';
end

switch lower(bin_method)
    
    case 'full'
        bin_range_new(1) = bin_range(1) + bin_width/2;
        bin_range_new(2) = bin_range(2) - bin_width/2;

        bin_centers = (bin_range_new(1):bin_step:bin_range_new(2));
        bin_edges = bin_centers + [-bin_width/2; bin_width/2];
        %bin_edges = max(min(bin_centers + [-bin_width/2 ; bin_width/2], bin_range(2)), bin_range(1));
        
    case 'partial'
        bin_centers = (bin_range(1):bin_step:bin_range(2));
        bin_edges = max(min(bin_centers + [-bin_width/2 ; bin_width/2], bin_range(2)),bin_range(1));
        
    case {'full_extend', 'full extend', 'extend'}
        bin_centers = (bin_range(1):bin_step:bin_range(2));
        bin_edges = bin_centers + [-bin_width/2; bin_width/2];
end


end

