function [out, sg_mode, sg_mean, sg_variance, sg_skew] = create_skew_gaussian_normalized(alpha, location, scale, x)
% Make a skew gaussian distribution from specified distribution parameters
%
%   Inputs:
%       alpha:
%       location:
%       scale:
%       x:
%     
%   Outputs:
%       out:
%       sg_mode:
%       sg_mean:
%       sg_variance:
%       sg_skew:
%
%
%%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - Tom Possidente 2/03/2022
%%%************************************************************************************%%%


if nargin == 0
    % distribution parameters
    alpha = -5;
    scale = 2;
    location = 5;
    x = linspace(-10, 10, 1000);
end

% Set skew gaussian formula
y = @(x,location,scale)2 * normpdf((x-location)/scale) .* normcdf(alpha * (x-location)/scale);

% Compute skew gaussian
delta = alpha / sqrt(1 + alpha^2);
mu_z = delta * sqrt(2/pi);
sigma_z = sqrt(1 - mu_z^2);

sg_mean = location + scale * mu_z;
sg_variance = scale^2 * (1 - 2*delta^2/pi);
sg_skew = (4 - pi)/2 * (delta * sqrt(2/pi))^3 / (1 - 2*delta^2/pi)^(3/2);
sg_mode = location + scale * (mu_z - sg_skew * sigma_z/2 - sign(alpha)/2 * exp(-2*pi / abs(alpha)));

out = y(x,location,scale)/y(sg_mode,location,scale);

if nargin == 0
    figure
    plot(x, out)
    hold on
    axis tight
    l2 = plot([sg_mode, sg_mode], ylim, 'm');
    legend(l2, {'mean', 'mode'})
    set(gca, 'FontSize', 14)
end