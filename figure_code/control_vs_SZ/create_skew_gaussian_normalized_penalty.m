function [out, sg_mode, sg_mean, sg_variance, sg_skew] = create_skew_gaussian_normalized_penalty(alpha, location, scale, x, penalty_bounds, ...
                                                                                          plot_on)

if nargin == 0
    % distribution parameters
    alpha = -3;
    scale = 2;
    location = 5;
    x = linspace(-10, 10, 1000);
    penalty_bounds = [0,1];
    create_skew_gaussian_normalized_penalty(alpha, location, scale, x, penalty_bounds)
    return
end

if nargin<5 || isempty(penalty_bounds)
    penalty_bounds = [0, 1];
end

if nargin<6
    plot_on = false;
end

y = @(x,location,scale)2 * normpdf((x-location)/scale) .* normcdf(alpha * (x-location)/scale);

% statistics
delta = alpha / sqrt(1 + alpha^2);
mu_z = delta * sqrt(2/pi);
sigma_z = sqrt(1 - mu_z^2);

sg_mean = location + scale * mu_z;
sg_variance = scale^2 * (1 - 2*delta^2/pi);
sg_skew = (4 - pi)/2 * (delta * sqrt(2/pi))^3 / (1 - 2*delta^2/pi)^(3/2);
sg_mode = location + scale * (mu_z - sg_skew * sigma_z/2 - sign(alpha)/2 * exp(-2*pi / abs(alpha)));

out = y(x,location,scale)/y(sg_mode,location,scale);

%Compute centroid
w = exp(out) - min(exp(out));
w = w/sum(w);
wcentroid = sum(w.*x);

if  ~(wcentroid>=penalty_bounds(1) & wcentroid<=penalty_bounds(2))
    if sg_mode>1
        mode_dist = 1 - wcentroid;
    else
        mode_dist = wcentroid;
    end
    
    out = ones(size(x))*1000-(100*mode_dist);
end

if plot_on
    figure
    plot(x, out)
    hold on
    axis tight
    l2 = plot([sg_mode, sg_mode], ylim, 'm');
    legend(l2, 'mode')
    set(gca, 'FontSize', 14)
    title(num2str(sg_mode))
end