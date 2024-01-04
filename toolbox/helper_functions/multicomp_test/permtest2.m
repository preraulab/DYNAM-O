function [sigbins, tstat_obs, thresh, perm_tmax] = permtest2(varargin)
%PERMTEST2 Computes permutation test (max t-stat) and regions of significance
%
%   Usage:
%   permtest2() RUNS DEMO
%   [sigbins_all, tstat_obs, thresh, perm_tmax] = permtest2(group1, group2, alpha_level, iterations, ploton)
%
%   Input:
%   group1, group2: in form <dimensions> x <trials> -- required
%   alpha_level: signficance level (Default: 0.05)
%   ploton: (Default: true)
%
%   Output:
%   sigbins: A vector of significant bins
%   tstat_obs: Observed t-statistics
%   thresh: threshold value for the permuted t-stats
%   perm_tmax: Vector of permuted max(t-stats)
%
%   Example:
%       permtest2(); %RUNS DEMO
%
%   Copyright 2021 Michael J. Prerau, Ph.D.
%
%   Last modified 11/01/2021
%********************************************************************

%Call the examples for no input
if nargin == 0
    demo();
    return;
end

%%

%Parse inputs to extract just the xy axis locations
p = inputParser;
addRequired(p,'group1',@(x)validateattributes(x,{'numeric','2d'},{'nonempty'}));
addRequired(p,'group2',@(x)validateattributes(x,{'numeric','2d'},{'nonempty'}));
addOptional(p,'alpha_level',0.05,@(x)validateattributes(x,{'numeric','1d'},{'positive','<=',1}));
addOptional(p,'iterations',1000,@(x)validateattributes(x,{'numeric','1d'},{'positive'}));
addOptional(p,'ploton',true,@islogical);

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
[linear_sigbins, linear_tstat_obs, thresh, perm_tmax] = permtest(g1_redim, g2_redim, alpha_level, iterations, false);

%Reshape output
sigbins = reshape(linear_sigbins, R,C);
tstat_obs = reshape(linear_tstat_obs, R,C);

if ploton
    figure
    hold all
    imagesc(nanmean(reshape(g1_redim, R, C, N1),3)-nanmean(reshape(g2_redim, R, C, N2),3));
    cx = climscale;
    caxis(max(abs(cx))*[-1 1]);
    colormap(redbluemap);
    colorbar
    
    if any(sigbins,'all')
        [~,h_sigregions] = contour(sigbins,1,'color','k', 'LineWidth', 1.5);
        legend(h_sigregions,'Significant Regions');
    end
    
end


function demo
%Define dataset
N1 = 20;
N2 = 33;
N = N1 + N2;

%Set peaks resolution
T = 50;

group1 = zeros(T,T,N1);
group2 = zeros(T,T,N2);

%Create functions
f1 =@(x)peaks(x)*rand*10 + randn(T)*.5;
f2 =@(x)fliplr(peaks(x))*rand*10 + randn(T)*.5;

%Generate data
for ii = 1:N
    if ii<=N1
        group1(:,:,ii) = f1(T);
    else
        group2(:,:,ii-N1) = f2(T);
    end
end

permtest2(group1,group2);


