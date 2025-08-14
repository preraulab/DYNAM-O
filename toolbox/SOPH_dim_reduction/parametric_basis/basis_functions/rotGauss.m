
function z = rotGauss(X,Y, amp, ymean, ystd, xmean, xstd, theta)
%ROTGAUSS - Compute a 2D Gaussian with rotation
%
%   z = rotGauss(X, Y, amp, ymean, ystd, xmean, xstd, theta)
%
%   This function computes a 3D Gaussian function with rotation based on the given parameters.
%
%   Input:
%       X: 2D matrix - X-coordinates of the data grid
%       Y: 2D matrix - Y-coordinates of the data grid
%       amp: double - Amplitude of the Gaussian
%       ymean: double - Mean of the Gaussian along the Y-axis
%       ystd: double - Standard deviation of the Gaussian along the Y-axis
%       xmean: double - Mean of the Gaussian along the X-axis
%       xstd: double - Standard deviation of the Gaussian along the X-axis
%       theta: double - Angle of rotation (in radians) for the Gaussian
%
%   Output:
%       z: 2D matrix - The computed 3D Gaussian with rotation
%
%   Equation:
%       The 2D Gaussian with rotation is computed using the following equation:
%
%       z = amp .* exp(-(((Y-ymean).*cos(theta)+(X-xmean).*sin(theta))./ystd).^2-((-(Y-ymean).*sin(theta)+(X-xmean).*cos(theta))./xstd).^2);
%
%       where:
%       - amp: Amplitude of the Gaussian
%       - ymean: Mean of the Gaussian along the Y-axis
%       - ystd: Standard deviation of the Gaussian along the Y-axis
%       - xmean: Mean of the Gaussian along the X-axis
%       - xstd: Standard deviation of the Gaussian along the X-axis
%       - theta: Angle of rotation (in radians) for the Gaussian
%
%   Example:
%       % Example usage of the rotGauss function
%       [X, Y] = meshgrid(-5:0.1:5, -5:0.1:5);
%       amp = 1.0;
%       ymean = 0.0;
%       ystd = 3;
%       xmean = 0.0;
%       xstd = 2;
%       theta = pi/8;
%       z = rotGauss(X, Y, amp, ymean, ystd, xmean, xstd, theta);
%
% Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

z = amp .* exp(-(((Y-ymean).*cos(theta)+(X-xmean).*sin(theta))./ystd).^2-((-(Y-ymean).*sin(theta)+(X-xmean)*cos(theta))./xstd).^2);
