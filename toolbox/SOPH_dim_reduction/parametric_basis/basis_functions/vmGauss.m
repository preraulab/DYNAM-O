function z = vmGauss(X,Y, amp, ymean, ystd, xmean, xstd, theta)
%VMGAUSS - Fit a hybrid von Mises Gaussian to data
%
%   z = vmGauss(X, Y, amp, ymean, ystd, xmean, xstd, theta)
%
%   This function fits a flexible von Mises Gaussian shape to the given data.
%
%   Input:
%       X: 2D matrix - X-coordinates of the data grid
%       Y: 2D matrix - Y-coordinates of the data grid
%       amp: double - Amplitude of the von Mises Gaussian
%       ymean: double - Mean of the Gaussian along the Y-axis
%       ystd: double - Standard deviation of the Gaussian along the Y-axis
%       xmean: double - Mean of the Gaussian along the X-axis
%       xstd: double - Standard deviation of the Gaussian along the X-axis
%       theta: double - Angle parameter for the von Mises distribution
%
%   Output:
%       z: 2D matrix - The computed von Mises Gaussian shape
%
%   Equation:
%       The von Mises Gaussian shape is computed using the following equation:
%           z = amp .* exp(-0.5*(Y-ymean).^2/ystd^2).* exp(k*cos(X-xmean+(Y-ymean)*sin(theta))-k);
%
%       where:
%       - amp: Amplitude of the von Mises Gaussian
%       - ymean: Mean of the Gaussian along the Y-axis
%       - ystd: Standard deviation of the Gaussian along the Y-axis
%       - xmean: Mean of the Gaussian along the X-axis
%       - xstd: Standard deviation of the Gaussian along the X-axis
%       - theta: Angle parameter for the von Mises distribution
%       - k: kappa = concentration parameter that measures dispersion (computed as 1 / xstd^2)
%
%       Both widths are genuine standard deviations, but they get there by
%       different routes and are NOT symmetric under rescaling:
%       - ystd is a standard deviation because of the explicit factor of one
%         half above. Squaring the denominator alone is not enough -- without
%         the half the frequency width is sqrt(2) times the standard deviation.
%       - xstd is ALREADY a standard deviation with no half needed, because the
%         von Mises factor is its own small-angle Gaussian:
%         exp(k*(cos(d)-1)) -> exp(-d^2/(2*xstd^2)). It carries the half
%         intrinsically, so k = 1/xstd^2 and the von Mises factor are written
%         here exactly as before. Never rescale xstd alongside ystd.
%
%   Example:
%       % Example usage of the vmGauss function
%       X = meshgrid(-2:0.1:2, -2:0.1:2);
%       Y = meshgrid(-2:0.1:2, -2:0.1:2);
%       amp = 1.0;
%       ymean = 0.0;
%       ystd = 0.5;
%       xmean = 0.0;
%       xstd = 0.5;
%       theta = pi/4;
%       z = vmGauss(X, Y, amp, ymean, ystd, xmean, xstd, theta);
%
%Fit a von Mises Gaussian to data
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
%   GITHUB     https://github.com
%
%   ATTRIBUTION
%   If you use this toolbox, please cite:
%
%   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
k = 1/xstd^2; % kappa = concentration parameter that measures dispersion

z = amp .* exp(-0.5*(Y-ymean).^2/ystd^2).* exp(k*cos(X-xmean+(Y-ymean)*sin(theta))-k);
