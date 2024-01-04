function [sigbins, acceptance_bounds, true_stat] = gpermtest2(varargin)
%gpermtest2 Computes global acceptance bounds and regions of significance
%for a given statistic for two sets of multidimensional observations
%
%   Usage:
%   gpermtest2() RUNS DEMO
%   [sig_regions, acceptance_bounds] = gpermtest2(group1, group2, xvals, yvals, alpha_level, statfcn, iterations, ploton)
%
%   Input:
%   group1, group2: in form <dimensions> x <trials> -- required
%   alpha_level:  global acceptance alpha (Default: 0.05)
%   statfcn: handle statistic to compute across trials (Default: @(x)nanmean(x,2) MUST COMPUTE ACROSS DIM 2)
%   ploton: (default: true)
%
%   Output:
%   sig_regions: A cell array of contiguous significant dimensions
%   acceptance_bounds: the 2 x <dimensions> global acceptance bounds at a level defined by alpha_level
%
%   Example:
%      gpermtest2(); %RUNS DEMO
%
%   Copyright 2021 Michael J. Prerau, Ph.D.
%
%   Last modified 11/01/2021
%********************************************************************

%Call the examples for no input
if nargin == 0
    %Set a fixed random seed so both demos have the same data
    seed = 2023;
    rng(seed);
    demo_func;
    return;
end

%%
%Parse inputs 
p = inputParser;
addRequired(p,'group1',@(x)validateattributes(x,{'numeric','2d'},{'nonempty'}));
addRequired(p,'group2',@(x)validateattributes(x,{'numeric','2d'},{'nonempty'}));
addOptional(p,'alpha_level',0.05,@(x)validateattributes(x,{'numeric','1d'},{'nonempty','positive','<=',1}));
addOptional(p,'statfcn', @(x)nanmean(x,2),@(x)isa(x,'function_handle'));
addOptional(p,'iterations',10000,@(x)validateattributes(x,{'numeric','1d'},{'nonempty','positive'}));
addOptional(p,'ploton',true,@(x)validateattributes(x,{'logical','1d'},{'nonempty'}));

parse(p,varargin{:});

input_arguments = struct2cell(p.Results);
input_flags = fieldnames(p.Results);
eval(['[', sprintf('%s ', input_flags{:}), '] = deal(input_arguments{:});']);

%Get group sizes
[R,C,N1] = size(group1);
[R2,C2,N2] = size(group2);

%Check that they are the same size and are valid
assert(R == R2 && C == C2,'Group dims must be the same');
assert(any(isfinite(group1),'all') && any(isfinite(group2),'all'), 'Groups must have valid numeric data')

%Reshape to linear
g1_redim = reshape(group1,size(group1,1)*size(group1,2),size(group1,3));
g2_redim = reshape(group2,size(group2,1)*size(group2,2),size(group2,3));

%Compute linear perm test with global bounds
[linear_sigbins, ~, linear_bounds, linear_true_stat] = gpermtest(g1_redim, g2_redim, alpha_level, statfcn, iterations, false);

%Reshape output
sigbins = reshape(linear_sigbins, R,C);
acceptance_bounds = reshape(linear_bounds, R,C);

true_stat = reshape(linear_true_stat, R,C);

if ploton
    % should mean change to statfnc? But would have to deal with dims
    g1_mean = mean(reshape(g1_redim, R, C, N1),3,'omitnan');
    g2_mean = mean(reshape(g2_redim, R, C, N2),3,'omitnan');
    figure
    ax = figdesign(2,2,'type','usletter','orient','landscape');
    
    axes(ax(1))
    imagesc(g1_mean)
    cx = climscale;
    colormap(ax(1),gouldian);
    title('Group 1')

    axes(ax(2))
    imagesc(g2_mean)
    caxis(cx);
    colormap(ax(2),gouldian);
    title('Group 2')

    axes(ax(3))
    hold all
    imagesc(g1_mean - g2_mean);
    
    cx = climscale;
    caxis(max(abs(cx))*[-1 1]);
    colormap(ax(3),redblue_equalized);
    colorbar
    if any(sigbins,'all')
        [~,h_sigregions] = contour(sigbins,1,'color','k', 'LineWidth', 1.5);
        legend(h_sigregions,'Significant Regions');
    end
    axis tight;
    title('Group 1 - Group 2')
end

function demo_func
%Define dataset
N1 = 30;
N2 = 30;
N = N1 + N2;

%Set peaks resolution
T = 30;

group1 = zeros(T,T,N1);
group2 = zeros(T,T,N2);

%Create functions
f1 = @(x)peaks(x)*rand*10 + randn(T)*5+50;
f2 = @(x)fliplr(peaks(x))*rand*10 + randn(T)*5+50;

%Generate data
for ii = 1:N
    if ii<=N1
        data = f1(T);
        data(:,end-6:end) = nan;
        group1(:,:,ii) = data;
    else
        data = f2(T);
        data(:,end-2:end) = nan;
        group2(:,:,ii-N1) = data;
    end
end
gpermtest2(group1, group2);
