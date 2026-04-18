function plot_SOPH_splinefits(SOpower_mat, SOpower_bins, fit_pow, coefs_pow, knots_x_pow, knots_y_pow, opts_pow, ...
    SOphase_mat, SOphase_bins, fit_phase, coefs_phase, knots_x_phase, knots_y_phase, opts_phase, ...
    freq_bins)
%PLOT_SOPH_SPLINEFITS  Plot SOPH histograms and spline reconstructions in one figure.
%
%   Plots SO-Power (top row) and SO-Phase (bottom row) histograms,
%   their spline reconstructions, and spline coefficients in a 2x3 layout.
%
%   See also: SPLINE_BASIS
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

% Create invisible; visibility restored at end for interactive callers.
f = figure('Visible','off');
ax = figdesign(f, 2, 3, ...
    'type', 'usletter', ...
    'orient', 'landscape', ...
    'margins', [0.05 0.08 0.1 0.1 0.11 0.12]);
set(f, 'units', 'inches')
set(f, 'position', [0 0 10 6])

% Helper: plot one set into 3 adjacent axes
    function plot_splinefit(ax_handles, hist_mat, x_bins, fit_mat, coefs, knots_x, knots_y, opts, freq_bins, cmap_hist, cmap_fit, labels)
        % Histogram
        imagesc(ax_handles(1), x_bins, freq_bins, hist_mat');
        axis(ax_handles(1),'xy')
        ylabel(ax_handles(1),'Frequency (Hz)')
        colormap(ax_handles(1), cmap_hist)
        xlabel(ax_handles(1), labels.x)
        title(ax_handles(1), sprintf('%s Histogram: %d Parameters', labels.name, numel(hist_mat)))
        c = colorbar_noresize(ax_handles(1));
        c.Label.String = labels.fitLabel;
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";

        % Spline reconstruction
        imagesc(ax_handles(2), knots_x, knots_y, fit_mat');
        axis(ax_handles(2),'xy')
        % ylabel('Frequency (Hz)')
        colorbar_noresize(ax_handles(2));
        % c = colorbar_noresize;
        % c.Label.String = labels.fitLabel;
        % c.Label.Rotation = -90;
        % c.Label.VerticalAlignment = "bottom";
        colormap(ax_handles(2), cmap_fit)
        xlabel(ax_handles(2), labels.x)
        title(ax_handles(2), sprintf('Spline Reconstruction: %d Parameters', numel(coefs)))

        % Coefficients
        imagesc(ax_handles(3), 1:size(coefs,2), 1:size(coefs,1), coefs);
        axis(ax_handles(3),'xy');
        clim(ax_handles(3), max(coefs,[],'all')*[-1 1]);
        c = colorbar_noresize(ax_handles(3));
        c.Label.String = {'Coefficient'};
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
        colormap(ax_handles(3), flipud(redblue_equalized));
        xlabel(ax_handles(3), 'x coeff knots')
        ylabel(ax_handles(3), 'y coeff knots')
        title(ax_handles(3), 'Spline Coefficients')

        % Equalize & limits
        equalize_axes(ax_handles(1:2),'dimension','xyc');
        axis(ax_handles(1),'tight')
        if contains(labels.x, 'power', 'IgnoreCase', true)
            xlim(ax_handles(1), opts.power_limits)
        elseif contains(labels.x, 'phase', 'IgnoreCase', true)
            xlim(ax_handles(1), opts.phase_limits)
        end
        ylim(ax_handles(1), opts.freq_limits)
        c_ptiles = prctile(hist_mat(hist_mat(:)~=0), opts.SOPH_clim_prctiles);
        clim(ax_handles(1), [c_ptiles(1) c_ptiles(2)]);
    end

% Top row: SO-Power
plot_splinefit(ax(1:3), SOpower_mat, SOpower_bins, fit_pow, coefs_pow, knots_x_pow, knots_y_pow, ...
    opts_pow, freq_bins, gouldian, gouldian, ...
    struct('x', 'SO-Power (dB)', 'name','SO-Power', 'fitLabel', {{'Density','(peaks/min in bin)'}}));

% Bottom row: SO-Phase
plot_splinefit(ax(4:6), SOphase_mat, SOphase_bins, fit_phase, coefs_phase, knots_x_phase, knots_y_phase, ...
    opts_phase, freq_bins, magma, magma, ...
    struct('x', 'SO-Phase (rad)', 'name','SO-Phase', 'fitLabel', {{'Proportion'}}));

set(ax, 'fontsize', 10);

% Restore visibility for interactive callers (batch runs set root
% DefaultFigureVisible='off' so the figure stays hidden there).
if strcmp(get(groot, 'DefaultFigureVisible'), 'on')
    set(f, 'Visible', 'on');
end
end
