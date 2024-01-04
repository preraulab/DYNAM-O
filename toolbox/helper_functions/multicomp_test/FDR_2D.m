function [sigbins, p_adj, p_values] =  FDR_2D(varargin)
% FDR_2D Perform statistical comparisons between 2D matrices using a False
% Discover Rate (FDR) approach
%
% Usage:
%   FDR_2D(group1, group2, <options>)
%
% Input:
%   - group1: Numeric 2D array representing the first group of data.
%   - group2: Numeric 2D array representing the second group of data.
%   - FDR: (Optional) False Discovery Rate (FDR) threshold for multiple testing correction. Default is 0.1.
%   - method: (Optional) 'dependent' will use the Benjamini & Yekutieli (2001) procedure,
%     and 'independent' will use the Benjamini & Hochberg (1995) procedure that assumes data are independent or positively
%     dependent. Default is 'dependent'
%   - paired: (Optional) Boolean indicating whether the data in group1 and group2 are paired. Default is false.
%   - nonparam: (Optional) Boolean indicating whether to use nonparametric test.
%               For nonparametric tests, a ranksum test is use for unpaired
%               an a signrank test is used for paired. Paired an unpaired
%               t-tests are used otherwise
%               Default is true.
%   - ploton: (Optional) Boolean indicating whether to plot the results. Default is true.
%
% Output:
%   - sigbins: 2D array indicating significant regions between group1 and group2.
%   - p_adj: 2D array of adjusted p-values after multiple testing correction.
%   - p_values: 2D array of raw p-values.
%
% The FDR procedure is computed using a modified version of fdr_bh() authored by Groppe, D.M.
%   https://www.mathworks.com/matlabcentral/fileexchange/27418-fdr_bh
%
% Example:
%   %Run FDR_2D() for demo data
%
%     %Define dataset
%     N1 = 20;
%     N2 = 30;
%     N = N1 + N2;
%
%     %Set peaks resolution
%     T = 30;
%
%     group1 = zeros(T,T,N1);
%     group2 = zeros(T,T,N2);
%
%     %Create functions
%     f1 = @(x)peaks(x)*rand*10 + randn(T)*5+50;
%     f2 = @(x)fliplr(peaks(x))*rand*10 + randn(T)*5+50;
%
%     %Generate data
%     for ii = 1:N
%         if ii<=N1
%             data = f1(T);
%             data(:,end-6:end) = nan;
%             group1(:,:,ii) = data;
%         else
%             data = f2(T);
%             data(:,end-2:end) = nan;
%             group2(:,:,ii-N1) = data;
%         end
%     end
%
%     %Run nonparametric test
%     FDR_2D(group1,group2,'FDR',.1,'paired', false,'nonparam',false);
%
%     %Run parametric test
%     FDR_2D(group1,group2,'FDR',.1,'paired', false,'nonparam',true);
%
% See also:
%   FDR_1D, fdr_bh
%
%   Copyright 2023 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%%
% DEMO
if nargin == 0
    %Set a fixed random seed so both demos have the same data
    seed = 2023;
    rng(seed);

    demo_func(.1,true,true,'dependent');
    rng(seed);
    demo_func(.1,false,false,'independent');
    return;
end

p = inputParser;
addRequired(p,'group1',@(x)validateattributes(x,{'numeric','2d'},{'nonempty'}));
addRequired(p,'group2',@(x)validateattributes(x,{'numeric','2d'},{'nonempty'}));
addOptional(p,'FDR',0.1,@(x)validateattributes(x,{'numeric','1d'},{'nonempty','positive','<=',1}));
addOptional(p,'method', 'dependent', @(x)ismember(x,{'dependent','independent'}));
addOptional(p,'paired',false,@islogical);
addOptional(p,'nonparam',true,@islogical);
addOptional(p,'ploton',true,@islogical);

parse(p,varargin{:});

input_arguments = struct2cell(p.Results); %#ok<NASGU> 
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

%Set inf values to nan
g1_redim(isinf(g1_redim)) = nan;
g2_redim(isinf(g2_redim)) = nan;

%Compute test
[linear_sigbins, linear_p_adj, linear_p_values] = FDR_1D(g1_redim,g2_redim,  ...
    'FDR',FDR,'method',method,'paired',paired,'nonparam',nonparam,'ploton',false);

%Reshape output
sigbins = reshape(linear_sigbins, R,C);
p_adj = reshape(linear_p_adj, R,C);
p_values = reshape(linear_p_values, R,C);

%Plot results
if ploton
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
    [r,c] = find(isnan(p_adj));
    if ~isempty(r)
        plot(c,r,'x')
    end

    cx = climscale;
    caxis(max(abs(cx))*[-1 1]);
    colormap(ax(3),redblue_equalized);
    colorbar

    %Plot significant regions as a contour
    if(any(sigbins(:)))
        [~,hc] = contour(sigbins,[1 1],'color','k','linewidth',1.5);
        legend(hc,'Regions of Significance')
    end

    axis tight;
    title('Group 1 - Group 2')

    axes(ax(4))
    imagesc(p_adj)
    hold on
    if ~isempty(r)
        plot(c,r,'x')
    end

    caxis([0 FDR*2])
    axis xy
    colormap(ax(4),'parula');
    title('Adjusted p-values')
    colorbar

    if paired
        pstring = 'Paired';
    else
        pstring = 'Unpaired';
    end

    if nonparam
        npstring = 'Nonparametric';
    else
        npstring = 'Parametric';
    end

    mstring = [upper(method(1)) method(2:end)]; %#ok<FNCOLND> 

    suptitle([mstring ' ' pstring ' ' npstring ' Test with FDR of ' num2str(FDR)])
end

function demo_func(FDR,paired,nonparam,method)

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

FDR_2D(group1,group2,'FDR',FDR,'method',method,'paired', paired,'nonparam',nonparam);


