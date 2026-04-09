function [fitresult, gof] = fit_rotGauss(pow_hist, pow_bins, freq_bins, B0, LB, UB, plot_on)
%FIT_ROTGAUSS - Fit a rotated Gaussian model to data
%
%   [fitresult, gof] = fit_rotGauss(pow_hist, pow_bins, freq_bins, B0, LB, UB, plot_on)
%
%   This function fits a rotated Gaussian model to the given data using nonlinear least squares fitting.
%
%   Input:
%       pow_hist: 2D matrix - Power histogram data
%       pow_bins: 2D matrix - Binning for power values
%       freq_bins: 2D matrix - Binning for frequency values
%       B0: Matrix - Initial parameter guess for the model (optional, default: [])
%           If B0 is provided, it should be a matrix specifying the initial parameter values for the model.
%           Each row of B0 corresponds to a Gaussian peak, and each column represents a parameter of the Gaussian
%           peak in the following order: [amp, fmean, fstd, pmean, pstd, theta].
%           - amp: Amplitude of the Gaussian peak.
%           - fmean: Mean frequency of the peak.
%           - fstd: Standard deviation of the frequency.
%           - pmean: Mean power of the peak.
%           - pstd: Standard deviation of the power.
%           - theta: Angle of rotation (in radians) for the Gaussian.
%           For example, to fit two Gaussian peaks, B0 would be a 2x6 matrix.
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
%       The function fits a model composed of one or more rotated Gaussian peaks to the data. The number
%       of peaks and their parameters are determined by the input B0, LB, and UB. If B0 is empty, a
%       linear model (plane) is fitted to the data.
%
%   Example:
%       % Example usage of the fit_rotGauss function
%       pow_hist = ...; % Your power histogram data
%       pow_bins = ...; % Binning for power values
%       freq_bins = ...; % Binning for frequency values
%       B0 = ...; % Initial parameter guess for the model (optional)
%       LB = ...; % Lower bounds for model parameters (optional)
%       UB = ...; % Upper bounds for model parameters (optional)
%       plot_on = true; % Flag to enable plotting (optional)
%
%       [fitresult, gof] = fit_rotGauss(pow_hist, pow_bins, freq_bins, B0, LB, UB, plot_on);
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

    %Create variable names (trick into being in alphabetical order)
    var_names = {'amp','fmean','fstd','pmean','pstd','theta'};
    num_params = length(var_names);

    %Initialize
    eqn_string = [];

    %Loop through peaks
    for n = 1:N
        %Create the equation string for that peak
        peak_vars = cellfun(@(x)cat(2,x,['_' num2str(n)]),var_names,'UniformOutput',false);
        % rotGauss(X,Y, amp, ymean, ystd, xmean, xstd, theta)
        eqn_string = strcat(eqn_string, sprintf('rotGauss(x, y, %s, %s, %s, %s, %s, %s)', peak_vars{:}));

        %Create the sum of peaks
        if n<N
            eqn_string = strcat(eqn_string, ' + ');
        end
    end

    %Set up the fit
    ft = fittype([eqn_string ' + xxx*x + yyy*y + zzz'], 'independent', {'x', 'y'}, 'dependent', 'z');
    opts = fitoptions('Method', 'NonlinearLeastSquares');
    opts.Display = 'off';
    %     opts.MaxFunEvals = 10000;
    %     opts.MaxIter = 10000;
    %     opts.Robust = "On"
    opts.StartPoint = [reshape(B0,1,numel(B0)), 0, 0, prctile(pow_hist(:),5)];
    opts.Lower = [reshape(LB,1,numel(LB)), -.1, -.1, 0];
    opts.Upper = [reshape(UB,1,numel(UB)), .1, .1, max(pow_hist(:))];
else
    ft = fittype('xxx*x + yyy*y + zzz', 'independent', {'x', 'y'}, 'dependent', 'z');
    opts = fitoptions('Method', 'NonlinearLeastSquares');
    opts.Display = 'notify';
    %     opts.MaxFunEvals = 1000;
    %     opts.MaxIter = 1000;
    opts.StartPoint = [0, 0, prctile(pow_hist(:), 50)];
    opts.Lower = [-.1, -.1, 0];
    opts.Upper = [.1, .1, max(pow_hist(:))];
end

%Fit
[xData, yData, zData] = prepareSurfaceData(pow_bins, freq_bins, pow_hist);
[fitresult, gof] = fit([xData, yData], zData, ft, opts);

%%
if plot_on
    figure
    ax = figdesign(2,1);
    linkaxes3d(ax);
    axes(ax(1))
    surface(pow_bins, freq_bins, pow_hist,'edgecolor','none')
    axis xy;
    cx = prctile(pow_hist(:),[5,95]);
    caxis(cx);
    zl = zlim;

    title('Observed');
    xlabel('%SO-power');
    ylabel('Frequency (Hz)');
    view(-50, 50);

    axes(ax(2))

    surface(pow_bins, freq_bins, feval(fitresult,X,Y),'edgecolor','none')
    axis xy;
    caxis(cx);
    title('Model Fit');
    xlabel('%SO-power');
    ylabel('Frequency (Hz)');
    zlim(zl);

    view(-50, 50);
end

