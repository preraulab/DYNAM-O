%% Skew gaussian distributions 

% distribution parameters
alpha = -5;
scale = 2;
location = 5;
x = linspace(-10, 10, 1000);
y = @(x,location,scale)2 * normpdf((x-location)/scale) .* normcdf(alpha * (x-location)/scale);

% statistics
delta = alpha / sqrt(1 + alpha^2);
mu_z = delta * sqrt(2/pi);
sigma_z = sqrt(1 - mu_z^2);

sg_mean = location + scale * mu_z;
sg_variance = scale^2 * (1 - 2*delta^2/pi);
sg_skew = (4 - pi)/2 * (delta * sqrt(2/pi))^3 / (1 - 2*delta^2/pi)^(3/2);
sg_mode = location + scale * (mu_z - sg_skew * sigma_z/2 - sign(alpha)/2 * exp(-2*pi / abs(alpha)));

figure
plot(x, y(x,location,scale)/y(sg_mode,location,scale))
hold on
l1 = plot([sg_mean, sg_mean], ylim, 'k');
l2 = plot([sg_mode, sg_mode], ylim, 'm');
legend([l1, l2], {'mean', 'mode'})
set(gca, 'FontSize', 14)
