%Adapted from: https://www.visiondummy.com/wp-content/uploads/2014/04/error_ellipse.m

function error_ellipse(x_vals, y_vals, alpha_level, varargin)
if nargin == 0
    close all
    % Create some random data
    x = randn(500,1);
    x_vals = normrnd(randn*10.*x,1);
    y_vals = normrnd(randn*10.*x,1);
    alpha_level = .05;

    % Plot the original data
    plot(x_vals,y_vals, '.');
    hold on;
    axis tight;

    error_ellipse(x_vals, y_vals, alpha_level, 'linewidth',1,'color','r');
    return;
end

if nargin<3
    alpha_level = .05;
end

data = [x_vals(:) y_vals(:)];

% Calculate the eigenvectors and eigenvalues
covariance = robustcov(data);
[eigenvec, eigenval ] = eig(covariance);

% Get the index of the largest eigenvector
[largest_eigenvec_ind_c, ~] = find(eigenval == max(max(eigenval)));
largest_eigenvec = eigenvec(:, largest_eigenvec_ind_c);

% Get the largest eigenvalue
largest_eigenval = max(max(eigenval));

% Get the smallest eigenvector and eigenvalue
if(largest_eigenvec_ind_c == 1)
    smallest_eigenval = max(eigenval(:,2));
    smallest_eigenvec = eigenvec(:,2);
else
    smallest_eigenval = max(eigenval(:,1));
    smallest_eigenvec = eigenvec(1,:);
end


% Calculate the angle between the x-axis and the largest eigenvector
angle = atan2(largest_eigenvec(2), largest_eigenvec(1));

% Get the coordinates of the data mean
avg = mean(data);

% Get the 1-alpha% confidence interval error ellipse
chisquare_val = sqrt(chi2inv(1-alpha_level,2));
theta_grid = linspace(0,2*pi);
phi = angle;
X0=avg(1);
Y0=avg(2);
a=chisquare_val*sqrt(largest_eigenval);
b=chisquare_val*sqrt(smallest_eigenval);

% the ellipse in x and y coordinates
ellipse_x_r  = a*cos( theta_grid );
ellipse_y_r  = b*sin( theta_grid );

%Define a rotation matrix
R = [ cos(phi) sin(phi); -sin(phi) cos(phi) ];

%let's rotate the ellipse to some angle phi
r_ellipse = [ellipse_x_r;ellipse_y_r]' * R;

% Draw the error ellipse
ellipse_x = r_ellipse(:,1) + X0;
ellipse_y = r_ellipse(:,2) + Y0;
plot(ellipse_x, ellipse_y,varargin{:})

% major_axis = [ largest_eigenvec(1)*sqrt(largest_eigenval), largest_eigenvec(2)*sqrt(largest_eigenval)];
% minor_axis = [smallest_eigenvec(1)*sqrt(smallest_eigenval), smallest_eigenvec(2)*sqrt(smallest_eigenval)];
% 
% quiver(X0, Y0, major_axis(1), major_axis(2),'-m', 'LineWidth',2);
% quiver(X0, Y0, minor_axis(1), minor_axis(2), '-g', 'LineWidth',2);


