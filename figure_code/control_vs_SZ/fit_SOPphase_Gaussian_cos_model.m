function [params, offset, fitresult] = fit_SOPphase_Gaussian_cos_model(phase_hist, phase_bins, freq_bins, phase_ROIs, ROI_phases, ROI_freqs, plot_on)

%Set default plot to true
if nargin<7
    plot_on = true;
end

%Get the number of peaks
N =  size(phase_ROIs,1);

%Create variable names (trick into being in alphabetical order)
var_names = {'amp','fmean','fstd','phasepref','v'};
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
    eqn_string = strcat(eqn_string, sprintf('%s*exp(-(((y - %s)/(2 * %s)).^2)) * (cos(x-%s)/2 +0.5) + %s', peak_vars{:}));
    
    %Create the sum of peaks
    if n<N
        eqn_string = strcat(eqn_string, ' + ');
    end
    
    %Compute the peak centroid and density
    freq_inds = phase_ROIs{n,2};
    pow_inds = phase_ROIs{n,1};
    
    ROI_pows_bins = phase_bins(pow_inds);
    ROI_freqs_bins = freq_bins(freq_inds);
    
    ROI_data = phase_hist(freq_inds, pow_inds);
    ROIexp = exp(ROI_data);
    
    sum_data = sum(ROIexp,'all');
    
    pow_centroid = sum(repmat(ROI_pows_bins,length(ROI_freqs_bins),1).*ROIexp,'all')/sum_data;
    freq_centroid = sum(repmat(ROI_freqs_bins,length(ROI_pows_bins),1)'.*ROIexp,'all')/sum_data;
    
    [F,P] = meshgrid(ROI_freqs_bins, ROI_pows_bins);
    centroid_density = interp2(F,P,ROI_data', freq_centroid, pow_centroid);
    
    %Use centroid computation to seed bounds
    StartPoint(n,:) = [centroid_density, freq_centroid, 1,mean(ROI_phases(n,2)),0];
    Lower(n,:) = [0 ROI_freqs(n,1) 0 ROI_phases(n,1) 0];
    Upper(n,:) = [max(ROI_data(:))*1.5 ROI_freqs(n,2) 5  ROI_phases(n,2) max(ROI_data(:))] ;
    
end

%Set up the fit
ft = fittype([eqn_string ' + zzz'], 'independent', {'x', 'y'}, 'dependent', 'z' );
opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
opts.Display = 'Off';
opts.StartPoint = [reshape(StartPoint,1,numel(StartPoint)), 0];
opts.Lower =  [reshape(Lower,1,numel(Lower)), 0];
opts.Upper =  [reshape(Upper,1,numel(Upper)), Inf];

%Fit
[xData, yData, zData] = prepareSurfaceData( phase_bins, freq_bins, phase_hist );
fitresult= fit( [xData, yData], zData, ft, opts );

%Save the output parameters
params = coeffvalues(fitresult);
offset = params(end);
params = reshape(params(1:end-1),N,num_params);

%Compute the volume
[X,Y] = meshgrid(phase_bins, freq_bins);
vol = zeros(N,1);
for n = 1:N
    amp = params(n,1);
    fmean = params(n,2);
    fstd = params(n,3);
    phase_pref = params(n,4);
    offset = params(n,5);
    Z = amp * exp(-(((Y - fmean)/(2 * fstd)).^2)).*(cos(X - phase_pref)/2 + 0.5) + offset;
    vol(n) = sum(Z(:));
end

%Add volume to the parameters
params = [params vol];

%%
if plot_on
    figure
    ax = figdesign(2,1);
    linkaxes3d(ax);
    axes(ax(1))
    imagesc(phase_bins, freq_bins, phase_hist)
    axis xy;
    cx = climscale;
    %cx = prctile(phase_hist(:),[5,95]);
    %caxis(cx);
    %zl = zlim;
    
    title('Observed');
    xlabel('%SO-power');
    ylabel('Frequency (Hz)');
    %view(-50, 50);
    
    axes(ax(2))
    
    imagesc(phase_bins, freq_bins,feval(fitresult,X,Y))
    axis xy;
    caxis(cx);
    title('Model Fit');
    xlabel('%SO-power');
    ylabel('Frequency (Hz)');
%     zlim(zl);
    
%     view(-50, 50);
end

