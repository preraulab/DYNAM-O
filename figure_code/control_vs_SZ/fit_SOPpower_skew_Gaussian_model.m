function [params, offset, fitresult] = fit_SOPpower_skew_Gaussian_model(pow_hist, pow_bins, freq_bins, pow_regions, ROI_freqs, plot_on)
% Perform fitting of skew gaussian to mode in each ROI for a single SOpower histogram
%
%   Inputs:
%       pow_hist: 2D double - power histogram [freq, SOpow] --required
%       pow_bins: 1D double - bin centers for SOpower axis of pow_hist --required
%       freq_bins: 1D double - bin centers for freq axis of pow_hist --required
%       pow_regions: 2D cell array [2 x num_modes] - logical indices determining frequency
%                    and SOpower ranges for each ROI. --required
%       ROI_freq: 2D double - indicates lower and upper freq limits of each ROI where rows 
%                 are ROI and columns are lower and upper bounds  
%       plot_on: logical - plot model fit and observed mode
%
%   Outputs:
%       params: 2D double [num_modes, num_parms] - parameters for each
%               fitted mode: amp, freq_mean, freq_var, pow_alpha, pow_location, pow_scale,
%                            vol, sg_mode, centroid_pow, centroid_freq, centroid_density
%       offset: double - offset for all modes in pow_hist
%       fitresult: sfit object - model fit for modes
%
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - Tom Possidente 2/03/2022
%%%************************************************************************************%%%

%% Deal with Inputs 
assert(nargin >= 5, '5 inputs required: pow_hist, pow_bins, freq_bins, pow_regions, ROI_freqs');

if nargin<6
    plot_on = true; %Set default plot to true
end

%% Get the number of peaks
N =  size(pow_regions,1);

%% Create variable names (trick into being in alphabetical order)
var_names = {'amp','freq_mean','freq_var','pow_alpha','pow_location','pow_scale'};
num_params = length(unique(var_names));

%% Initialize
StartPoint = zeros(N,num_params);
Lower = zeros(N,num_params);
Upper = zeros(N,num_params);
eqn_string = [];

vol = zeros(N,1);

%% Loop through peaks
for n = 1:N
    %Create the equation string for that peak
    peak_vars = cellfun(@(x)cat(2,x,num2str(n)),var_names,'UniformOutput',false);
    %eqn_string = strcat(eqn_string, sprintf(['%s * exp(-(((y - %s)/(2 * %s)).^2)) .* skew_gaussian_normalized_penalty(%s, %s, %s, x, [', num2str(ROI_pows(n,1)), ' , ' , num2str(ROI_pows(n,2)), '])'], peak_vars{:}));
    eqn_string = strcat(eqn_string, sprintf(['%s * exp(-(((y - %s)/(2 * %s)).^2)) .* create_skew_gaussian_normalized_penalty(%s, %s, %s, x, [0, 1])'], peak_vars{:}));
    
    %Create the sum of peaks
    if n<N && N>1
        eqn_string = strcat(eqn_string, ' + ');
    end
    
    % Get frequency and power indices for ROI
    freq_inds = pow_regions{n,2};
    pow_inds = pow_regions{n,1};
    
    ROI_pows_bins = pow_bins(pow_inds);
    ROI_freqs_bins = freq_bins(freq_inds);
    
    % Get all data in ROI
    ROI_data = pow_hist(freq_inds, pow_inds);
    ROI_enhanced = ROI_data; %exp(ROI_data) - min(exp(ROI_data));
    
    sum_data = sum(ROI_enhanced,'all');
    vol(n) = sum_data;
    
    % Compute peak centroid 
    pow_centroid = sum(repmat(ROI_pows_bins,length(ROI_freqs_bins),1).*ROI_enhanced,'all')/sum_data;
    freq_centroid = sum(repmat(ROI_freqs_bins,length(ROI_pows_bins),1)'.*ROI_enhanced,'all')/sum_data;
    
    % Compute peak density
    [F,P] = meshgrid(ROI_freqs_bins, ROI_pows_bins);
    centroid_density = interp2(F,P,ROI_data', freq_centroid, pow_centroid);
    
    %Use centroid computation to seed bounds of model fit
    StartPoint(n,:) = [centroid_density, freq_centroid, 1, -5, pow_centroid, .5];
    Lower(n,:) = [0 ROI_freqs(n,1) 0.05 -10 0 0];
    Upper(n,:) = [max(ROI_data(:))*1.5 ROI_freqs(n,2) 2.5 10 1 .6];
    
end

%% Set up the fit
ft = fittype([eqn_string ' + zzz'], 'independent', {'x', 'y'}, 'dependent', 'z' );
opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
opts.Display = 'Off';
opts.StartPoint = [reshape(StartPoint,1,numel(StartPoint)), 0];
opts.Lower =  [reshape(Lower,1,numel(Lower)), 0];
opts.Upper =  [reshape(Upper,1,numel(Upper)), 10];

%% Fit
[xData, yData, zData] = prepareSurfaceData( pow_bins, freq_bins, pow_hist );
try
    fitresult= fit( [xData, yData], zData, ft, opts );
catch
    fitresult = nan;
    params = nan(5,11);
    offset = nan;
    disp('Fitting failed')
    return;
end

%% Save the output parameters
params = coeffvalues(fitresult);
offset = params(end);
params = reshape(params(1:end-1),N,num_params);

%% Compute params
df = freq_bins(2) - freq_bins(1);
freq_bins_extended = 0:df:max(freq_bins);

[X,Y] = meshgrid(pow_bins, freq_bins_extended);
sg_mode = zeros(N,1);
centroid_pow = zeros(N,1);
centroid_freq = zeros(N,1);
centroid_density = zeros(N,1);

for n = 1:N
    amp = params(n,1);
    freq_mean = params(n,2);
    freq_var = params(n,3);
    pow_alpha = params(n,4);
    pow_location = params(n,5);
    pow_scale = params(n,6);
    
    %Compute mode
    [peak_out, sg_mode(n)] = create_skew_gaussian_normalized(pow_alpha, pow_location, pow_scale, X);
    
    % Compute volume
    Z = amp * exp(-(((Y - freq_mean)/(2 * freq_var)).^2)) .* peak_out + offset;
    Z_no_offset = Z-offset;

    %freq_inds = freq_bins_extended>ROI_freqs(n,1) & freq_bins_extended<ROI_freqs(n,2);
    %pow_inds = pow_regions{n,1};
    
    %model_ROI_data = Z(freq_inds, pow_inds);
    %vol(n) = sum(model_ROI_data, 'all');
    %vol(n) = sum(Z(Z_no_offset > 0.01), 'all');
    
    % Compute Centroid
    fit_exp = exp(Z_no_offset) - 1;
    sum_data = sum(fit_exp,'all');
    
    centroid_pow(n) = sum(X.*fit_exp,'all')/sum_data;
    centroid_freq(n) = sum(Y.*fit_exp,'all')/sum_data;
    centroid_density(n) = interp2(X,Y,Z, centroid_pow(n), centroid_freq(n));

end

%% Add computed parameters to params variable
params = [params vol sg_mode centroid_pow centroid_freq centroid_density];

%% Plot the results
if plot_on
    figure
    ax = figdesign(2,1);
    linkaxes(ax,'xy');
    axes(ax(1))
    imagesc(pow_bins, freq_bins, pow_hist)
    axis xy;
    cx = climscale(false);
    
    title('Observed');
    xlabel('%SO-power');
    ylabel('Frequency (Hz)');
    
    axes(ax(2))
    imagesc(pow_bins, freq_bins_extended, feval(fitresult,X,Y))
    axis xy;
    caxis(cx);
    hold on; plot(centroid_pow, centroid_freq, 'r.', 'MarkerSize',10);
    plot(sg_mode, params(:,2), 'rx', 'MarkerSize',10);
    title('Model Fit');
    xlabel('%SO-power');
    ylabel('Frequency (Hz)');
end

