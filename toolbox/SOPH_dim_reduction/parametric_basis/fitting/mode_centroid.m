function centroid = mode_centroid(fitobj, varargin)
%MODE_CENTROID Get the centroid of a given mode
%
%   centroid = mode_centroid(fitobj, mode_num, x_fit, y_fit, weight)
%
%   This function retrieves the indices of coefficients for a specified
%   mode based on mode numer
%
%   Input:
%       fitobj: Fitted model object - The model containing the coefficients
%       mode_num: double - Mode number for which to compute the centroid
%       x_fit: 1 x N vector - Model x-values
%       x_fit: 1 x M vector - Model y-values
%
%     Optional:
%       weight: double - scalar exponent for polynomial weighting
%               or use string input:
%                   'exp' for exponential weighting (Default)
%                   'none' for no weighting
%
%    Example:
%       %Given a fit object for SOpower, powfit, fit the first mode
%       mode_num = 1;
%       
%       % Define high-res spacing for the centroid calculation
%       SOpow_bins_fit = linspace(0,15,500);
%       freq_bins_fit = linspace(4,16,500);
%       
%       %Set the centroid weight
%       weight = 'exp';
%       
%       %Compute the centroid
%       centroid = mode_centroid(fitobj, mode_num, SOpow_bins_fit, freq_bins_fit, weight);
%       
%       %Get true parameters
%       params = get_mode_params(powfit,mode_num(mode_num>0));
%       
%       %Plot the results
%       model_fit = select_modes(fitobj,mode_num,SOpow_bins,freq_bins);
%       imagesc(SOpow_bins,freq_bins,model_fit); axis xy
%       
%       %Plot the model peak parameters and the centroid on the surface
%       hold on
%       plot(params(4),params(2),'^r','markersize',10)
%       plot(centroid(1),centroid(2),'om','markersize',10)
%       legend('Model Peak', 'Centroid')
%           
%   Output:
%       centroid: 1x2 double - Mode centroid
%
%   Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************
% Input Parser
parser = inputParser;

% Required inputs
addRequired(parser, 'fitobj', @(x) assert(isa(x, 'sfit'), 'fitobj is not class sfit'));
addRequired(parser, 'mode_num', @(x) assert(isnumeric(x) && all(mod(x,1)==0) && all(x>=0) && all(x<=num_modes(fitobj)), ['Invalid mode number found, fit object has ' num2str(num_modes(fitobj)) ' modes']));
addRequired(parser, 'x_fit', @(x)validateattributes(x, {'double'},{'increasing'}));
addRequired(parser, 'y_fit', @(x)validateattributes(x, {'double'},{'increasing'}));
% Optional inputs
addOptional(parser, 'weight', 'exp', @(x) isnumeric(x) || ismember(x, {'none', 'exp'}));

parse(parser, fitobj, varargin{:});
fitobj = parser.Results.fitobj;
mode_num = parser.Results.mode_num;
x_fit = parser.Results.x_fit;
y_fit = parser.Results.y_fit;
weight = parser.Results.weight;

%Compute the model with the selected mode
[model_fit, X, Y] = select_modes(fitobj,mode_num,x_fit,y_fit);

%Select weighting for normalization
if isnumeric(weight)
    disp('num')
    expnt = weight;
    model_fit_norm = model_fit^expnt./sum(model_fit^expnt,'all');
else
    switch weight
        case 'none'
            model_fit_norm = model_fit./sum(model_fit,'all');
        case 'exp'
            mod_exp = exp(model_fit-min(model_fit,[],'all'))-1;
            model_fit_norm = mod_exp./sum(mod_exp,'all');
    end
end

%Compute centroid
Xc = sum(model_fit_norm.*X,'all');
Yc = sum(model_fit_norm.*Y,'all');

centroid = [Xc Yc];
end