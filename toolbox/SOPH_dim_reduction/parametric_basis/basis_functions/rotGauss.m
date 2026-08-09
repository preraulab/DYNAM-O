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
%       z = amp .* exp(-0.5*(((Y-ymean).*cos(theta)+(X-xmean).*sin(theta))./ystd).^2-0.5*((-(Y-ymean).*sin(theta)+(X-xmean).*cos(theta))./xstd).^2);
%
%       where:
%       - amp: Amplitude of the Gaussian
%       - ymean: Mean of the Gaussian along the Y-axis
%       - ystd: Standard deviation of the Gaussian along the Y-axis
%       - xmean: Mean of the Gaussian along the X-axis
%       - xstd: Standard deviation of the Gaussian along the X-axis
%       - theta: Angle of rotation (in radians) for the Gaussian
%
%       The factor of one half is what makes ystd and xstd genuine standard
%       deviations: at one ystd from the center along the rotated Y-axis the
%       kernel falls to exp(-0.5) of its peak. Squaring the denominator alone
%       is not enough -- without the half the widths are sqrt(2) times the
%       standard deviation they are named after.
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
z = amp .* exp(-0.5*(((Y-ymean).*cos(theta)+(X-xmean).*sin(theta))./ystd).^2-0.5*((-(Y-ymean).*sin(theta)+(X-xmean)*cos(theta))./xstd).^2);
