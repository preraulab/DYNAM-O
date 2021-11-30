function global_bounds = global_perm_test_2d(data_matrix, group, iterations, statfcn, plot_on)
%GLOBALPERMTEST Computes global regions of significance for a set of
%matrices for a given statistic for two sets of multidimensional observations
%
%   Usage:
%   global_bounds = global_perm_test_2d(data_matrix, group, iterations, statfcn)
%
%   Input:
%   data_matrix: data in form <R,C> x <trials> -- required
%   groups: logical vector defining two groups
%   iterations: bootstrap iterations (default: 1000)
%   statfcn: handle statistic to compute across trials (Default: @(x)nanmean(x,3) MUST COMPUTE ACROSS DIM 3)
%   plot_on: logical - plot output (default: true)
%
%   Output:
%   global_bounds: an R x C matrix with values equal to the global significance alpha at that point
%
%
%   Copyright 2018 Michael J. Prerau, Ph.D.
%
%   Last modified 08/03/2018
%********************************************************************
if nargin == 0
    N = 50;
    D = 100;
    data_matrix = zeros(D,D,2*N);
    
    group = false(1,2*N);
    
    for ii = 1:2*N
        if ii<=N
            data_matrix(:,:,ii) = peaks(D) + randn(D);
            group(ii) = true;
        else
            data_matrix(:,:,ii) = -peaks(D) + randn(D);
        end
    end
end


%Set default iterations
if nargin < 3 || isempty(iterations)
    iterations=1000;
end

%Set default boostrap statistica function
if nargin<4 || isempty(statfcn)
    statfcn=@(x)nanmean(x,3);
end

%Set default plot to be on
if nargin<5
    plot_on = true;
end

%Find any empty data
bad_inds=false(size(group));

for ii=1:length(group)
    slice=data_matrix(:,:,ii);
    bad_inds(ii)=sum(isnan(slice(:)))==numel(slice);
end

%Remove bad data from matrix
group=logical(group(~bad_inds));
data=data_matrix(:,:,~bad_inds);

%Get group 0 size
N0=sum(~group);

%Compute data dimensions (rows, columns, number of data points)
[R,C,N]=size(data);

if N~=length(group)
    error('Mismatch in size between group and data');
end

%Compute the actual stat for the existing groups
data_stat=reshape((statfcn(data(:,:,~group))-statfcn(data(:,:,group))),1,R*C);

disp('   Doing bootstrap iterations...');
%Generate two groups boostrap samples from the shuffled distribution and compute the
%difference in means between them
diff_all=zeros(R*C,iterations);

progressbar();

parfor ii=1:iterations
    %Create random permutation
    inds=randperm(N);
    
    %Assign to two groups of the original data group size
    inds0=inds(1:N0);
    inds1=inds((N0 + 1):end);
    
    %Compute the bootstrap statistic
    diff_all(:,ii)=reshape((statfcn(data(:,:,inds0))-statfcn(data(:,:,inds1))),1,R*C);
    progressbar(ii/iterations);
end

progressbar(1);

%Sort the trials for ease of computing the pointwise percentile
sdiff_all=sort(diff_all,2);

%Set initial bounds at highest %ile
pbounds=[1 iterations];

signifiance_matrix=zeros(size(data_stat'));

% Number of individual trials falling outside the global bounds
numout=0;
if ~(any(sdiff_all(:)))
    error('Bad data...');
else
    disp('   Computing significance levels...');
    
    %Shrink the bounds until the number of outside trials is %5
    while numout<iterations*.1 && min(pbounds>=1) && max(pbounds)<=iterations
        %Calculate the global bounds
        gbounds=sdiff_all(:,pbounds);
        
        %Calculate the low and high bounds
        lo=repmat(gbounds(:,1),1,iterations);
        hi=repmat(gbounds(:,2),1,iterations);
        
        %Check the number out of bounds
        numout=sum(any(~(sdiff_all>=lo) & (diff_all<=hi)));
        
        %Compute the significance level for all points below the threshold
        sig_inds_lo=data_stat'<=gbounds(:,1) & ~signifiance_matrix;
        signifiance_matrix(sig_inds_lo)=-(1-numout/iterations);
        
        %Compute the significance level for all points above the threshold
        sig_inds_hi=data_stat'>=gbounds(:,2) & ~signifiance_matrix;
        signifiance_matrix(sig_inds_hi)=1-numout/iterations;
        
        %Shrink the bounds
        pbounds(1)= pbounds(1)+1;
        pbounds(2)= pbounds(2)-1;
    end
end

%Return to matrix form
global_bounds=reshape(signifiance_matrix,R,C);

if plot_on
    data_stat_mat = statfcn(data(:,:,~group))-statfcn(data(:,:,group));
    imagesc(data_stat_mat);
    hold on
    contour(abs(global_bounds),[.95 .95],'color','k', 'LineWidth', 1.5);
    colormap(gca,colormap(gca,flipud(redbluemap(1024,0))))
    axis xy;
    axis tight
    
    diff_val=prctile(abs(data_stat_mat(:)),95);
    caxis([-diff_val diff_val]);
end


