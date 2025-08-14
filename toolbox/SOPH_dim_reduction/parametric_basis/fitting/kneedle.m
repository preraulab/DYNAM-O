function [knee, knee_idx, x_max] = kneedle(x, y, varargin)
%KNEEDLE  Detect the knee point in a curve using the kneedle algorithm
%
%   Usage:
%       [knee, knee_idx] = kneedle(x, y, 'sensitivity', sensitivity, 'plot_on', plot_on)
%
%   Input:
%       x: 1xN vector - x-axis values of the curve (required)
%       y: 1xN vector - y-axis values of the curve (required)
%       Optional inputs:
%       - sensitivity: double - sensitivity parameter (0 < sensitivity <= 1) (default: 1.0)
%       - plot_on: logical - whether to plot the knee point on the curve (default: true)
%
%   Output:
%       knee: 1x2 vector - [x, y] coordinates of the knee point in the
%       interpolated space
%       knee_idx: scalar - index of the knee point in the input vectors
%
%   Example:
%       x = linspace(0,10,10);
%       y = exp(x)./(1+exp(x));
%       [knee, knee_idx] = kneedle(x, y, 'sensitivity', 1.0, 'plot_on', true);
%
%   Note: This code implements the algorithm specified in
%       V. Satopää, J. Albrecht, D. Irwin and B. Raghavan, “Finding a “Kneedle” in a Haystack: Detecting Knee Points in System Behavior” (2011),
%       31st International Conference on Distributed Computing Systems Workshops, 2011, pp. 166–171, doi: 10.1109/ICDCSW.2011.20.
%
%    Copyright 2024 Prerau Lab - sleepEEG.org
%% ********************************************************************

% Input parser
p = inputParser;
addParameter(p, 'sensitivity', 1, @(x) isnumeric(x) && x > 0 && x <= 1);
addParameter(p, 'plot_on', true, @(x) islogical(x));
parse(p, varargin{:});
sensitivity = p.Results.sensitivity;
plot_on = p.Results.plot_on;

assert(length(x) == length(y), 'x and y must have the same length')
assert(sensitivity>0 && sensitivity<=1,'Sensitivity must be in the range [0 1)')
assert(iscolumn(x),'x must be a column vector');
assert(iscolumn(y),'y must be a column vector');

x_int = linspace(x(1), x(end), 1000);
f_spline = fit(x,y,'smoothingspline');
y_int = feval(f_spline,x_int)';

%Check if the curve is good for kneedle to run on
valid_curve = check_valid_curve(x_int, y_int, x);

if valid_curve
    % Normalize the x and y values
    x_norm = (x_int - min(x_int)) / (max(x_int) - min(x_int));
    y_norm = (y_int - min(y_int)) / (max(y_int) - min(y_int));

    % Calculate the difference curve
    diff_curve = y_norm - x_norm;

    % Find the maximum point of the difference curve
    max_diff = max(diff_curve);

    % Find the threshold based on sensitivity
    threshold = sensitivity * max_diff;

    % Find the knee point as the point where the difference curve first reaches the threshold
    knee_idx = find(diff_curve >= threshold, 1, 'first');

    % Extract the knee point coordinates
    knee = [x_int(knee_idx), y_int(knee_idx)];

    [~, max_idx] = max(y_int);
    x_max = x_int(max_idx);
else
    warning('Data has does not contain negative curvature, picking max');
    [~,knee_idx] = max(y);
    knee = [x(knee_idx) y(knee_idx)];
    x_max = x(knee_idx);

end

if plot_on
    figure('color','w')
    hold on
    plot(x, y, 'ro', 'markersize', 5, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'r')
    plot(x_int, y_int, 'b')
    vline(knee(1),'color','r','linewidth',2);
    title('Kneedle Procedure')
    legend('Data','Curve','Knee')
    set(gca,'fontsize',18)
end

function valid_curve = check_valid_curve(x_iny, y_int,x)

% Ensure x is sorted for proper finite difference calculation
[x_iny, sortIdx] = sort(x_iny);
y_int = y_int(sortIdx);

% Ensure x and y are column vectors
x_iny = x_iny(:);
y_int = y_int(:);

% Calculate the first derivative
dy = gradient(y_int, x_iny);

% Calculate the second derivative
ddy = gradient(dy, x_iny);

%The curve is good if contains negative curvature
contains_neg_curvature = any(ddy < 0);

valid_length = length(x)>2;

valid_curve = contains_neg_curvature & valid_length;