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
%           z = amp .* exp(-(Y-ymean).^2/ystd).* exp(k*cos(X-xmean+(Y-ymean)*sin(theta))-k);
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
%   TUTORIALS  https://harvard.edu
%   GITHUB     https://github.com
%
%   CITATION
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

z = amp .* exp(-(Y-ymean).^2/ystd).* exp(k*cos(X-xmean+(Y-ymean)*sin(theta))-k);
