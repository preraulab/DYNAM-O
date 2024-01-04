function [sigbins_all, p_adj, p_values] = FDR_1D(varargin)
% FDR_1D Perform statistical comparisons between 1D vectors using a False
% Discover Rate (FDR) approach
%
% Usage:
%   FDR_1D(group1, group2, <options>)
%
% Input:
%   - group1: Numeric 1D vector representing the first group of data.
%   - group2: Numeric 1D vector representing the second group of data.
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
%   - sigbins: Vector indicating significant regions between group1 and group2.
%   - p_adj: Vector of adjusted p-values after multiple testing correction.
%   - p_values: Vector of raw p-values.
%
% Example:
%   %Run FDR_1D() for demo data
%
%     %Define dataset
%     N1 = 200;
%     N2 = 200;
%     N = N1+N2;
%
%     %Set time resolution
%     T = 100;
%
%     %Initialize data and null matrices
%     g1 = zeros(T,N1);
%     g2 = zeros(T,N2);
%
%     %Create functions
%     f1 =@(x)normpdf(x)*(rand*5+3);
%     f2 =@(x)normpdf(x)*(rand*5+2);
%
%     x=linspace(-5,5,T)';
%
%     %Generate data
%     for ii = 1:N
%         if ii<=N1
%             data1 = smooth(f1(x)+randn(size(x))*.25)+1;
%             data1(end-10:end) = nan;
%             g1(:,ii) = data1;
%         else
%             data2 = smooth(f2(x)+randn(size(x))*.25)+1;
%             data2(end-3:end) = nan;
%             g2(:,ii-N1) = data2;
%         end
%     end
%
%     %Run nonparametric test
%     FDR_1D(group1,group2,'FDR', .1,'paired', true, 'method', 'dependent','nonparam',false);
%
%     %Run parametric test
%     FDR_1D(group1,group2,'FDR', .1,'paired', false,'method', 'independent','nonparam',true);
%
% See also:
%   FDR_2D, fdr_bh
%
%   Copyright 2023 Michael J. Prerau Laboratory. - http://www.sleepEEG.org

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

input_arguments = struct2cell(p.Results); %#ok<NASGU> %#OK
input_flags = fieldnames(p.Results);
eval(['[', sprintf('%s ', input_flags{:}), '] = deal(input_arguments{:});']);

%Change infs to nans
group1(isinf(group1)) = nan; %#ok<*NODEF> 
group2(isinf(group2)) = nan;
if nonparam
    if paired
        assert(size(group1,2) == size(group2,2),'There must be the same number of observations for a paired test.')
        testfun = @signrank;
    else
        testfun = @ranksum;
    end
else
    if paired
        [~,p_values]=ttest(group1',group2');
    else
        [~,p_values]=ttest2(group1',group2');
    end

end

if nonparam
    p_values = zeros(1,size(group1,1));
    for ii = 1:length(p_values)
        g1 = group1(ii,:);
        g2 = group2(ii,:);

        if all(isnan(g1)) && all(isnan(g2))
            p_values(ii) = nan;
        else
            if any(isnan(g1)) || all(isnan(g2))
                g1(isnan(g1)) = 0;
                g2(isnan(g2)) = 0;
            end

            p_values(ii)=testfun(g1,g2);
        end
    end

end

switch method
    case 'dependent'
        method_string = 'dep';
    case 'independent'
        method_string = 'pdep';
    otherwise
        error('Invalid method string')
end

[~,~,~,p_adj] = fdr_bh(p_values, FDR, method_string);

%Find the significant bins
sigbins_all = p_adj<FDR;

%Plot the results
if ploton
    figure
    ax = figdesign(2,1,'type','usletter','orient','landscape');
    axes(ax(1))
    hold all;
    h1 = plot(group1,'color',[1 0 0 .1]);
    h2 = plot(group2,'color',[0 0 1 .1]);
    legend([h1(1), h2(1)], 'Group1', ' Group2')

    axes(ax(2))
    [cons_all,sig_regions]=consecutive_runs(sigbins_all);
    [cons_nan,nan_regions]=consecutive_runs(isnan(p_values));
    hold all;
    xvals = 1:length(p_adj);

    %Plot significant regions
    yl=ylim;

    %Plot regions of significance
    for ii = 1:length(cons_all)
        inds = sig_regions{ii};

        if ~isempty(inds)
            h_sigregions = fill([xvals(inds(1))-.5 xvals(inds(1))-.5 xvals(inds(end))+.5 xvals(inds(end))+.5],[yl(1) yl(2) yl(2) yl(1)],'g','edgecolor','none');
        end
    end
    uistack(h_sigregions,'bottom');

    for ii = 1:length(cons_nan)
        inds = nan_regions{ii};

        if ~isempty(inds)
            h_nanregions = fill([xvals(inds(1))-.5 xvals(inds(1))-.5 xvals(inds(end))+.5 xvals(inds(end))+.5],[yl(1) yl(2) yl(2) yl(1)],'r','edgecolor','none');
        end
    end

    if ~isempty(h_nanregions)
        uistack(h_nanregions,'bottom');
    end

    %Plot adjusted pvalues and threshold line
    h_pasj = plot(xvals, p_adj,'linewidth',2,'color','b');
    axis tight;
    h_threshold = hline(FDR,'color','k','linestyle','--');

    if isempty(h_sigregions)
        legend([h_pasj, h_threshold],{'Adjusted p-values','Threshold'});
    else
        if ~isempty(h_nanregions)
            legend([h_pasj, h_threshold, h_sigregions(1), h_nanregions(1)],{'Adjusted p-values','Threshold','Significant Regions','No Data Regions'});
        else
            legend([h_pasj, h_threshold, h_sigregions(1)],{'Adjusted p-values','Threshold','Significant Regions'});
        end
    end

    xlabel('Bin Number');
    ylabel('Adjusted p-value');

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
end


function demo_func(FDR,paired, nonparam, method)
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

FDR_1D(g1,g2, 'FDR',FDR,'method',method,'paired', paired,'nonparam',nonparam);
end


% fdr_bh() - Executes the Benjamini & Hochberg (1995) and the Benjamini &
%            Yekutieli (2001) procedure for controlling the false discovery
%            rate (FDR) of a family of hypothesis tests. FDR is the expected
%            proportion of rejected hypotheses that are mistakenly rejected
%            (i.e., the null hypothesis is actually true for those tests).
%            FDR is a somewhat less conservative/more powerful method for
%            correcting for multiple comparisons than procedures like Bonferroni
%            correction that provide strong control of the family-wise
%            error rate (i.e., the probability that one or more null
%            hypotheses are mistakenly rejected).
%
%            This function also returns the false coverage-statement rate
%            (FCR)-adjusted selected confidence interval coverage (i.e.,
%            the coverage needed to construct multiple comparison corrected
%            confidence intervals that correspond to the FDR-adjusted p-values).
%
%
% Usage:
%  >> [h, crit_p, adj_ci_cvrg, adj_p]=fdr_bh(pvals,q,method,report);
%
% Required Input:
%   pvals - A vector or matrix (two dimensions or more) containing the
%           p-value of each individual test in a family of tests.
%
% Optional Inputs:
%   q       - The desired false discovery rate. {default: 0.05}
%   method  - ['pdep' or 'dep'] If 'pdep,' the original Bejnamini & Hochberg
%             FDR procedure is used, which is guaranteed to be accurate if
%             the individual tests are independent or positively dependent
%             (e.g., Gaussian variables that are positively correlated or
%             independent).  If 'dep,' the FDR procedure
%             described in Benjamini & Yekutieli (2001) that is guaranteed
%             to be accurate for any test dependency structure (e.g.,
%             Gaussian variables with any covariance matrix) is used. 'dep'
%             is always appropriate to use but is less powerful than 'pdep.'
%             {default: 'pdep'}
%   report  - ['yes' or 'no'] If 'yes', a brief summary of FDR results are
%             output to the MATLAB command line {default: 'no'}
%
%
% Outputs:
%   h       - A binary vector or matrix of the same size as the input "pvals."
%             If the ith element of h is 1, then the test that produced the
%             ith p-value in pvals is significant (i.e., the null hypothesis
%             of the test is rejected).
%   crit_p  - All uncorrected p-values less than or equal to crit_p are
%             significant (i.e., their null hypotheses are rejected).  If
%             no p-values are significant, crit_p=0.
%   adj_ci_cvrg - The FCR-adjusted BH- or BY-selected
%             confidence interval coverage. For any p-values that
%             are significant after FDR adjustment, this gives you the
%             proportion of coverage (e.g., 0.99) you should use when generating
%             confidence intervals for those parameters. In other words,
%             this allows you to correct your confidence intervals for
%             multiple comparisons. You can NOT obtain confidence intervals
%             for non-significant p-values. The adjusted confidence intervals
%             guarantee that the expected FCR is less than or equal to q
%             if using the appropriate FDR control algorithm for the
%             dependency structure of your data (Benjamini & Yekutieli, 2005).
%             FCR (i.e., false coverage-statement rate) is the proportion
%             of confidence intervals you construct
%             that miss the true value of the parameter. adj_ci=NaN if no
%             p-values are significant after adjustment.
%   adj_p   - All adjusted p-values less than or equal to q are significant
%             (i.e., their null hypotheses are rejected). Note, adjusted
%             p-values can be greater than 1.
%
%
% References:
%   Benjamini, Y. & Hochberg, Y. (1995) Controlling the false discovery
%     rate: A practical and powerful approach to multiple testing. Journal
%     of the Royal Statistical Society, Series B (Methodological). 57(1),
%     289-300.
%
%   Benjamini, Y. & Yekutieli, D. (2001) The control of the false discovery
%     rate in multiple testing under dependency. The Annals of Statistics.
%     29(4), 1165-1188.
%
%   Benjamini, Y., & Yekutieli, D. (2005). False discovery rate?adjusted
%     multiple confidence intervals for selected parameters. Journal of the
%     American Statistical Association, 100(469), 71?81. doi:10.1198/016214504000001907
%
%
% Example:
%  nullVars=randn(12,15);
%  [~, p_null]=ttest(nullVars); %15 tests where the null hypothesis
%  %is true
%  effectVars=randn(12,5)+1;
%  [~, p_effect]=ttest(effectVars); %5 tests where the null
%  %hypothesis is false
%  [h, crit_p, adj_ci_cvrg, adj_p]=fdr_bh([p_null p_effect],.05,'pdep','yes');
%  data=[nullVars effectVars];
%  fcr_adj_cis=NaN*zeros(2,20); %initialize confidence interval bounds to NaN
%  if ~isnan(adj_ci_cvrg),
%     sigIds=find(h);
%     fcr_adj_cis(:,sigIds)=tCIs(data(:,sigIds),adj_ci_cvrg); % tCIs.m is available on the
%     %Mathworks File Exchagne
%  end
%
%
% For a review of false discovery rate control and other contemporary
% techniques for correcting for multiple comparisons see:
%
%   Groppe, D.M., Urbach, T.P., & Kutas, M. (2011) Mass univariate analysis
% of event-related brain potentials/fields I: A critical tutorial review.
% Psychophysiology, 48(12) pp. 1711-1725, DOI: 10.1111/j.1469-8986.2011.01273.x
% http://www.cogsci.ucsd.edu/~dgroppe/PUBLICATIONS/mass_uni_preprint1.pdf
%
%
% For a review of FCR-adjusted confidence intervals (CIs) and other techniques
% for adjusting CIs for multiple comparisons see:
%
%   Groppe, D.M. (in press) Combating the scientific decline effect with
% confidence (intervals). Psychophysiology.
% http://biorxiv.org/content/biorxiv/early/2015/12/10/034074.full.pdf
%
%
% Author:
% David M. Groppe
% Kutaslab
% Dept. of Cognitive Science
% University of California, San Diego
% March 24, 2010

%Edited

%%%%%%%%%%%%%%%% REVISION LOG %%%%%%%%%%%%%%%%%
%
% 5/7/2010-Added FDR adjusted p-values
% 5/14/2013- D.H.J. Poot, Erasmus MC, improved run-time complexity
% 10/2015- Now returns FCR adjusted confidence intervals

function [h, crit_p, adj_ci_cvrg, adj_p]=fdr_bh(pvals,q,method,report)

if nargin<1
    error('You need to provide a vector or matrix of p-values.');
else
    if any(pvals<0)
        error('Some p-values are less than 0.');
    elseif any(pvals>1)
        error('Some p-values are greater than 1.');
    end
end

%Check for nan/inf and remove them
inds = isfinite(pvals);
if any(~inds)
    %     warning('Contains Nan/Inf values. Removing from invalid pvals from the list.')
    %     pvals_all = pvals;
    pvals = pvals(inds);
end

if nargin<2
    q=.05;
end

if nargin<3
    method='pdep';
end

if nargin<4
    report='no';
end

s=size(pvals);
if (length(s)>2) || s(1)>1
    [p_sorted, sort_ids]=sort(reshape(pvals,1,prod(s)));
else
    %p-values are already a row vector
    [p_sorted, sort_ids]=sort(pvals);
end
[~, unsort_ids]=sort(sort_ids); %indexes to return p_sorted to pvals order
m=length(p_sorted); %number of tests

if strcmpi(method,'pdep')
    %BH procedure for independence or positive dependence
    thresh=(1:m)*q/m;
    wtd_p=m*p_sorted./(1:m);

elseif strcmpi(method,'dep')
    %BH procedure for any dependency structure
    denom=m*sum(1./(1:m));
    thresh=(1:m)*q/denom;
    wtd_p=denom*p_sorted./(1:m);
    %Note, it can produce adjusted p-values greater than 1!
    %compute adjusted p-values
else
    error('Argument ''method'' needs to be ''pdep'' or ''dep''.');
end

if nargout>3
    %compute adjusted p-values; This can be a bit computationally intensive
    adj_p_samp=zeros(1,m)*NaN;
    [wtd_p_sorted, wtd_p_sindex] = sort( wtd_p );
    nextfill = 1;
    for k = 1 : m
        if wtd_p_sindex(k)>=nextfill
            adj_p_samp(nextfill:wtd_p_sindex(k)) = wtd_p_sorted(k);
            nextfill = wtd_p_sindex(k)+1;
            if nextfill>m
                break;
            end
        end
    end

    adj_p_samp=reshape(adj_p_samp(unsort_ids),s);
end

rej=p_sorted<=thresh;
max_id=find(rej,1,'last'); %find greatest significant pvalue
if isempty(max_id)
    crit_p_samp=0;
    h_samp=pvals*0;
    adj_ci_cvrg_samp=NaN;
else
    crit_p_samp=p_sorted(max_id);
    h_samp=pvals<=crit_p_samp;
    adj_ci_cvrg_samp=1-thresh(max_id);
end

if strcmpi(report,'yes')
    n_sig=sum(p_sorted<=crit_p_samp);
    if n_sig==1
        fprintf('Out of %d tests, %d is significant using a false discovery rate of %f.\n',m,n_sig,q);
    else
        fprintf('Out of %d tests, %d are significant using a false discovery rate of %f.\n',m,n_sig,q);
    end
    if strcmpi(method,'pdep')
        fprintf('FDR/FCR procedure used is guaranteed valid for independent or positively dependent tests.\n');
    else
        fprintf('FDR/FCR procedure used is guaranteed valid for independent or dependent tests.\n');
    end
end

h = nan(1,length(inds));
crit_p = nan(1,length(inds));
adj_ci_cvrg = nan(1,length(inds));
adj_p = nan(1,length(inds));

h(inds) = h_samp;
crit_p(inds) = crit_p_samp;
adj_ci_cvrg(inds) = adj_ci_cvrg_samp;
adj_p(inds) = adj_p_samp;
end



