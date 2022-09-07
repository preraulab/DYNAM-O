function [params, offset, fitresult] = fit_SOPpower_Gaussian_model(pow_hist, pow_bins, freq_bins, pow_ROIs, ROI_pows, ROI_freqs, plot_on)

%Set default plot to true
if nargin<7
    plot_on = true;
end

%Get the number of peaks
N =  size(pow_ROIs,1);

%Create variable names (trick into being in alphabetical order)
var_names = {'amp','fmean','fstd','pmean','pstd','v'};
num_params = length(var_names);

%Initialize
StartPoint = zeros(N,num_params);
Lower = zeros(N,num_params);
Upper = zeros(N,num_params);
eqn_string = [];

%Loop through peaks
for n = 1:N
    %Create the equation string for that peak
    peak_vars = cellfun(@(x)cat(2,x,num2str(n)),var_names,'UniformOutput',false);
    eqn_string = strcat(eqn_string, sprintf('%s * exp(-(((y - %s)/(2 * %s)).^2+((x - %s)/(2 * %s)).^2)) + %s', peak_vars{:}));
    
    %Create the sum of peaks
    if n<N
        eqn_string = strcat(eqn_string, ' + ');
    end
    
    %Compute the peak centroid and density
    freq_inds = pow_ROIs{n,2};
    pow_inds = pow_ROIs{n,1};
    
    ROI_pows_bins = pow_bins(pow_inds);
    ROI_freqs_bins = freq_bins(freq_inds);
    
    ROI_data = pow_hist(freq_inds, pow_inds);
    ROIexp = exp(ROI_data);
    
    sum_data = sum(ROIexp,'all');
    
    pow_centroid = sum(repmat(ROI_pows_bins,length(ROI_freqs_bins),1).*ROIexp,'all')/sum_data;
    freq_centroid = sum(repmat(ROI_freqs_bins,length(ROI_pows_bins),1)'.*ROIexp,'all')/sum_data;
    
    [F,P] = meshgrid(ROI_freqs_bins, ROI_pows_bins);
    centroid_density = interp2(F,P,ROI_data', freq_centroid, pow_centroid);
    
    %Use centroid computation to seed bounds
    StartPoint(n,:) = [centroid_density,freq_centroid, 1,pow_centroid,.5,0];
    Lower(n,:) = [0 ROI_freqs(n,1) 0 ROI_pows(n,1) 0 .01];
    Upper(n,:) = [max(ROI_data(:))*1.5 ROI_freqs(n,2) 10  ROI_pows(n,2) .5 max(ROI_data(:))] ;
    
end

%Set up the fit
ft = fittype([eqn_string ' + zzz'], 'independent', {'x', 'y'}, 'dependent', 'z' );
opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
opts.Display = 'Off';
opts.StartPoint = [reshape(StartPoint,1,numel(StartPoint)), 0];
opts.Lower =  [reshape(Lower,1,numel(Lower)), 0];
opts.Upper =  [reshape(Upper,1,numel(Upper)), Inf];

%Fit
[xData, yData, zData] = prepareSurfaceData( pow_bins, freq_bins, pow_hist );
fitresult= fit( [xData, yData], zData, ft, opts );



%Save the output parameters
params = coeffvalues(fitresult);
offset = params(end);
params = reshape(params(1:end-1),N,num_params);

%Compute the volume
[X,Y] = meshgrid(pow_bins, freq_bins);
vol = zeros(N,1);
for n = 1:N
    amp = params(n,1);
    fmean = params(n,2);
    fstd = params(n,3);
    pmean = params(n,4);
    pstd = params(n,5);
    V = params(n,6);
    Z = amp * exp(-(((Y - fmean)/(2 * fstd)).^2+((X - pmean)/(2 * pstd)).^2)) + V + offset;
    vol(n) = sum(Z(:));
end

params(:,1) = params(:,1) + params(:,6) + offset; % adjust amplitude with global and local offsets

%Add volume to the parameters
params = [params vol];

%% Plot the results
if plot_on
    figure
    ax = figdesign(2,1);
    linkaxes3d(ax);
    axes(ax(1))
    surface(pow_bins, freq_bins, pow_hist,'edgecolor','none')
    axis xy;
    cx = prctile(pow_hist(:),[5,95]);
    caxis(cx);
    zl = zlim;
    
    title('Observed');
    xlabel('%SO-power');
    ylabel('Frequency (Hz)');
    view(-50, 50);
    
    axes(ax(2))
    
    surface(pow_bins, freq_bins,feval(fitresult,X,Y),'edgecolor','none')
    axis xy;
    caxis(cx);
    title('Model Fit');
    xlabel('%SO-power');
    ylabel('Frequency (Hz)');
    zlim(zl);
    
    view(-50, 50);
end

