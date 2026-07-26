function [fitresult, gof] = fit_vmGauss(phase_hist, phase_bins, freq_bins, B0, LB, UB, plot_on)
%FIT_VMGAUSS - Fit a normalized von Mises 2D Gaussian to 2D data
%
%   [fitresult, gof] = fit_vmGauss(phase_hist, phase_bins, freq_bins, B0, LB, UB, plot_on)
%
%   This function fits a von Mises 2D Gaussian model to the given 2D data using nonlinear least squares fitting.
%
%   Input:
%       phase_hist: 2D matrix - Phase histogram data
%       phase_bins: 2D matrix - Binning for phase values
%       freq_bins: 2D matrix - Binning for frequency values
%       B0: Matrix - Initial parameter guess for the model (optional, default: [])
%           If B0 is provided, it should be a matrix specifying the initial parameter values for the model.
%           Each row of B0 corresponds to a von Mises 2D Gaussian peak, and each column represents a parameter
%           of the peak in the following order: [amp, fmean, fstd, phasepref, recikappa, shift, theta].
%           - amp: Amplitude of the von Mises 2D Gaussian peak.
%           - fmean: Frequency mean of the peak.
%           - fstd: Frequency standard deviation of the peak.
%           - phasepref: Phase preference of the peak (in radians).
%           - recikappa: Reciprocal kappa parameter.
%           - theta: Angle parameter for the von Mises distribution (in radians).
%           For example, to fit two von Mises 2D Gaussian peaks, B0 would be a 2x7 matrix.
%
%       LB: Matrix - Lower bounds for model parameters (optional)
%       UB: Matrix - Upper bounds for model parameters (optional)
%       plot_on: logical - Flag to control whether to plot the fit results (optional, default: true)
%
%   Output:
%       fitresult: Fit object - Contains the result of the nonlinear least squares fitting
%       gof: Goodness of fit object - Provides information about the quality of the fit
%
%   Fit Model:
%       The function fits a model composed of one or more von Mises 2D Gaussian peaks to the data. The number
%       of peaks and their parameters are determined by the input B0, LB, and UB. If B0 is empty, a
%       linear model (plane) is fitted to the data.
%
%   Example:
%       % Example usage of the fit_vmGauss function
%       phase_hist = ...; % Your phase histogram data
%       phase_bins = ...; % Binning for phase values
%       freq_bins = ...; % Binning for frequency values
%       B0 = ...; % Initial parameter guess for the model (optional)
%       LB = ...; % Lower bounds for model parameters (optional)
%       UB = ...; % Upper bounds for model parameters (optional)
%       plot_on = true; % Flag to enable plotting (optional)
%
%       [fitresult, gof] = fit_vmGauss(phase_hist, phase_bins, freq_bins, B0, LB, UB, plot_on);
%
%Set default plot to true
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
if nargin<5
    plot_on = true;
end

if ~isempty(B0)
    %Get the number of peaks
    N =  size(B0,1);
    var_string = [];

    %Create variable names (trick into being in alphabetical order)
    var_names = {'amp','fmean','fstd','phasepref','recikappa','theta'};

    %Loop through peaks
    for n = 1:N
        %Create the equation string for that peak
        peak_vars = cellfun(@(x)cat(2,x,['_' num2str(n)]),var_names,'UniformOutput',false);
        % vmGauss(X,Y, amp, ymean, ystd, xmean, xstd, theta)
        var_string = [var_string, sprintf('%s, %s, %s, %s, %s, %s', peak_vars{:})]; %#ok<*AGROW>

        %Create the sum of peaks
        if n<N
            var_string = [var_string, ', '];
        end
    end

    %Set up the fit
    ft = fittype(['normalized_vmGauss(x, y, unit_row, xxx, yyy, zzz, ', var_string, ')'], 'independent', {'x', 'y'}, 'dependent', 'z', 'problem', 'unit_row');
    opts = fitoptions('Method', 'NonlinearLeastSquares');
    opts.Display = 'Off';
    opts.StartPoint = [reshape(B0,1,numel(B0)), 0, 0, prctile(phase_hist(:),5)];
    opts.Lower = [reshape(LB,1,numel(LB)), -1, -pi, 0];
    opts.Upper = [reshape(UB,1,numel(UB)), 1, pi, max(phase_hist,[],"all")];
else
    ft = fittype('normalized_vmGauss(x, y, unit_row, xxx, yyy, zzz)', 'independent', {'x', 'y'}, 'dependent', 'z', 'problem', 'unit_row');
    opts = fitoptions('Method', 'NonlinearLeastSquares');
    opts.Display = 'Off';
    opts.StartPoint = [0, 0, prctile(phase_hist(:), 50)];
    opts.Lower = [0, 0, 0];
    opts.Upper = [1, 1, max(phase_hist,[],"all")];
end

%Fit
dynamo_pool_trace('fit_vmGauss: before prepareSurfaceData');
[xData, yData, zData] = prepareSurfaceData(phase_bins, freq_bins, phase_hist);
dynamo_pool_trace('fit_vmGauss: after  prepareSurfaceData / before fit()');
[fitresult, gof] = fit([xData, yData], zData, ft, opts, 'problem', true); % row-normalize during fitting (unit-row "Proportion" space)
dynamo_pool_trace('fit_vmGauss: after  fit()');

%%
if plot_on
    figure
    ax = figdesign(2,1);

    axes(ax(1))
    surface(phase_bins, freq_bins, phase_hist, 'edgecolor','none')
    axis xy;
    cx = prctile(phase_hist(:),[5,95]);
    clim(cx);
    zl = zlim;
    title('Observed');
    xlabel('Phase (rad)');
    ylabel('Frequency (Hz)');

    axes(ax(2))
    [phase_grid, freq_grid] = meshgrid(phase_bins, freq_bins);
    surface(phase_bins, freq_bins, feval(fitresult,phase_grid,freq_grid), 'edgecolor','none')
    axis xy;
    clim(cx);
    zlim(zl);
    title('Model Fit');
    xlabel('Phase (rad)');
    ylabel('Frequency (Hz)');

    linkaxes3d(ax);
    view(-50, 50);
end
