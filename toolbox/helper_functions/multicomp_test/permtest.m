function [sigbins_all, tstat_obs, thresh, perm_tmax] = permtest(varargin)
%PERMTEST Computes permutation test (max t-stat) and regions of significance
%
%   Usage:
%   permtest() RUNS DEMO
%   [sigbins_all, tstat_obs, thresh, perm_tmax] = permtest(group1, group2, alpha_level, iterations, ploton)
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
%       permtest(); %RUNS DEMO
%
%   Copyright 2021 Michael J. Prerau, Ph.D.
%
%   Last modified 11/01/2021
%********************************************************************

%Call the examples for no input
if nargin==0
    demo;
    return;
end

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

assert(any(isfinite(group1),'all') && any(isfinite(group2),'all'), 'Groups must have valid numeric data')

%Remove nan dimensions
p1 = group1(:,any(~isnan(group1)));
p2 = group2(:,any(~isnan(group2)));


%Combine both groups
all=[p1 p2];
Np1=size(p1,2);

%Allocat max tstat array
perm_tmax = zeros(1,iterations);

disp(['Computing test with ' num2str(iterations) ' iterations at alpha level ' num2str(alpha_level) '...']);

%Generate null distribution
disp('Generating null distribution...');
parfor ii=1:iterations
    %Get a random permutation of the labels
    inds=randperm(size(all,2));
    
    %Indices for new pseudo-groups
    inds1=inds(1:Np1);
    inds2=inds((Np1 + 1):end);
    
    %Compute the ttest
    [~,~,~,STATS] = ttest2(all(:,inds1)',all(:,inds2)');
    perm_tmax(ii) = max(abs(STATS.tstat));
end

%Sort the trials for ease of computing the pointwise N-tile
[~,~,~,STATS_obs] = ttest2(p1',p2');
tstat_obs = STATS_obs.tstat;

thresh = prctile(perm_tmax,(1-alpha_level)*100);

%Find the significant bins
sigbins_all= abs(tstat_obs)>thresh;
[cons_all,sig_regions]=consecutive(sigbins_all);

%Plot the results
if ploton
    figure('units','normalized','position',[0 0 1 1],'color','w');
    
    subplot(211)
    histogram(perm_tmax)
    h_thresh = vline(thresh,'color','k','linestyle','--');
    legend(h_thresh,'Threshold');
    xlabel('t-stat');
    ylabel('Count');
    
    xvals = 1:length(sigbins_all);
    
    subplot(212)
    hold on;
    
    %Plot significant regions
    yl=[min(tstat_obs) max(tstat_obs)];
    h_sigregions = [];
    
    for ii=1:length(cons_all)
        inds=sig_regions{ii};
        h_sigregions(ii) = fill(xvals([inds(1) inds(1) inds(end) inds(end)]),[yl(1) yl(2) yl(2) yl(1)],'g','edgecolor','none');
    end
    
    h_stat = plot(xvals, tstat_obs,'b','linewidth',2);
    h_threshold = hline(thresh,'color','k','linestyle','--');
    xlabel('Bin Number');
    ylabel('Stat Value');
    
    axis tight;
    
    %Generate legend
    if isempty(h_sigregions)
        legend([h_threshold, h_stat],{'Threshold','Observed Statistic'});
    else
        legend([h_threshold, h_stat, h_sigregions(1)],{'Threshold','Observed Statistic','Significant Regions'});
    end
    
end
end


function demo

%Define dataset
N1 = 200;
N2 = 303;
N = N1+N2;

%Set time resolution
T = 100;

%Initialize data and null matrices
g1 = zeros(T,N1);
g2 = zeros(T,N2);

%Create functions
f1 =@(x)normpdf(x)*(rand*5+3);
f2 =@(x)normpdf(x)*(rand*5+2);

x=linspace(-5,5,T)';

%Generate data
for ii = 1:N
    if ii<=N1
        g1(:,ii) = smooth(f1(x)+randn(size(x))*.125);
    else
        g2(:,ii-N1) = smooth(f2(x)+randn(size(x))*.125);
    end
end

permtest(g1, g2);
end