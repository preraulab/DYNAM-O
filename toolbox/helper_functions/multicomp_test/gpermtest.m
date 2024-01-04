function [sigbins_all, sig_regions, acceptance_bounds, true_stat] = gpermtest(varargin)
%GPERMTEST Computes global acceptance bounds and regions of significance
%for a given statistic for two sets of multidimensional observations
%
%   Usage:
%   gpermtest() RUNS DEMO
%   [sigbins_all, sig_regions, acceptance_bounds, true_stat] = gpermtest(group1, group2, 'alpha_level', alpha_level, 'statfcn', ...
%                                                                        statfcn, 'iterations', iterations, 'ploton', ploton);
%
%   Input:
%   group1, group2: in form <dimensions> x <trials> -- required
%   alpha_level:  global acceptance alpha (Default: 0.05)x a
%   statfcn: handle statistic to compute across trials (Default: @(x)mean(x,2) MUST COMPUTE ACROSS DIM 2)
%   ploton: 0 no plot, 1 plot traces (default), 2 plot mean and 2*standard errors     % Previously boolean for plot output (Default: true)
%
%   Output:
%   sig_regions: A cell array of contiguous significant dimensions
%   acceptance_bounds: the 2 x <dimensions> global acceptance bounds at a level defined by alpha_level
%
%   Example:
%      gpermtest(); %RUNS DEMO
%
%   Copyright 2021 Michael J. Prerau, Ph.D.
%
%   Last modified 11/01/2021
%********************************************************************

%Call the examples for no input
if nargin==0
    %Set a fixed random seed so both demos have the same data
    seed = 2023;
    rng(seed);
    demo_func;
    return;
end


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

%Remove nan dimensions
p1 = group1(:,any(~isnan(group1)));
p2 = group2(:,any(~isnan(group2)));

[R, C] = size(p1);

%Combine both groups
all=[p1 p2];

Np1=size(p1,2);

%The difference in mean activity between the two scenarios
true_stat=statfcn(p1)-statfcn(p2);

%Generate null distribution
null_mat=zeros(R,iterations);

disp(['Computing test with ' num2str(iterations) ' iterations at alpha level ' num2str(alpha_level) '...']);

%Generate null distribution
statfcn = statfcn;
disp('Generating null distribution...');
parfor ii=1:iterations
    %Get a random permutation of the labels
    inds=randperm(size(all,2));
    
    %Indices for new pseudo-groups
    inds1=inds(1:Np1);
    inds2=inds((Np1 + 1):end);
    
    %Compute the stat and take absolute value
    null_mat(:,ii)=abs((statfcn(all(:,inds1))-statfcn(all(:,inds2))));
end

%Sort the trials for ease of computing the pointwise N-tile
sorted_null=sort(null_mat,2);

%Set initial bounds at highest %ile
cutoff_ind = iterations;

% Number of individual trials falling outside the global bounds
numout=0;

%Compute the citerion for the number out
out_crit = ceil(alpha_level*iterations);

gbounds=sorted_null(:,end);

h_sigregions = waitbar(0,'Computing bounds...');

disp(['Out crit: ' num2str(out_crit) ' out of ' num2str(iterations) ' = ' num2str(out_crit/iterations)]);

%Shrink the bounds until the number of outside trials is %alpha
if out_crit<iterations && out_crit>0
    while numout<out_crit && cutoff_ind>0
        %Calculate the global bounds
        gbounds=sorted_null(:,cutoff_ind)+1e-5;
        
        %Check the number out of bounds
        numout=sum(any(null_mat>=gbounds & ~isnan(null_mat)));
        
        %Shrink the bounds
        cutoff_ind = cutoff_ind - 1;
        
        waitbar(numout/out_crit,h_sigregions);
    end
    
    close(h_sigregions);
elseif out_crit>=iterations
    warning('Global bounds includes all iterations. Increase iterations or reduce p-value');
    gbounds = zeros(size(sorted_null(:,1)));
elseif out_crit == 0
    warning('Global bounds is below precision for number of iterations. Increase iterations or increase p-value');
    gbounds = sorted_null(:,end);
end

disp(['Found bounds to exclude ' num2str(numout) ' = ' num2str(numout/iterations)]);

alpha_diff = alpha_level - (numout/iterations);
if abs(alpha_diff)>0.01
    warning(['Difference between alpha-level and p-value is large: ' num2str(alpha_diff) '. Results likely inaccurate. Increase iterations or de-noise data.']);
end

%Create symmetrical bounds
hi = gbounds;
% lo = -gbounds;

%Find the significant bins
sigbins_all=(abs(true_stat)>=hi);% | true_stat<=lo);
acceptance_bounds=hi;%[hi,lo];
[cons_all,sig_regions]=consecutive(sigbins_all);

%Plot the results
if ploton
    figure
    ax = figdesign(2,1,'type','usletter','orient','landscape');
    axes(ax(1))
    hold all;
    h1 = plot(group1,'color',[1 0 0 .1]);
    h2 = plot(group2,'color',[0 0 1 .1]);
    legend([h1(1), h2(1)], 'Group1', ' Group2')

    xvals = 1:length(sigbins_all);

%     figure('units','normalized','position',[0 0 1 1],'color','w');
%     %Plot raw data if not too big
%     if iterations<500
%         plot(xvals, null_mat','color',[.8 .8 .8]);
%     end
    axes(ax(2))
    %Plot bounds and stat
    hold on;
    h_bounds = plot(xvals,hi,'r','linewidth',2);
    h_stat = plot(xvals, abs(true_stat),'k','linewidth',2);
    
    %Plot significant regions
    yl=ylim;
    h_sigregions = [];
    
    for ii=1:length(cons_all)
        inds = sig_regions{ii};
        h_sigregions(ii) = fill(xvals([inds(1) inds(1) inds(end) inds(end)]),[yl(1) yl(2) yl(2) yl(1)],'g','edgecolor','none');
        uistack(h_sigregions,'bottom');
    end
    
    %Generate legend
    if isempty(h_sigregions)
        legend([h_bounds, h_stat],{'Global Bounds','Observed Statistic'});
    else
        legend([h_bounds, h_stat, h_sigregions(1)],{'Global Bounds','Observed Statistic','Significant Regions'});
    end
    
    xlabel('Bin Number');
    ylabel('Stat Value');
    
    axis tight;
end
end


function demo_func
%Define dataset
N1 = 200;
N2 = 200;
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
        data1 = smooth(f1(x)+randn(size(x))*.25)+1;
        data1(end-10:end) = nan;
        g1(:,ii) = data1;
    else
        data2 = smooth(f2(x)+randn(size(x))*.25)+1;
        data2(end-3:end) = nan;
        g2(:,ii-N1) = data2;
    end
end
gpermtest(g1, g2);
end