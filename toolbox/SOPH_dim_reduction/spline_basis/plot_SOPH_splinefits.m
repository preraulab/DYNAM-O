function plot_SOPH_splinefits( ...
    SOpower_mat, SOpower_bins, fit_pow, coefs_pow, knots_x_pow, knots_y_pow, opts_pow, ...
    SOphase_mat, SOphase_bins, fit_phase, coefs_phase, knots_x_phase, knots_y_phase, opts_phase, ...
    freq_bins)
%PLOT_SOPH_SPLINEFITS  Plot SOPH histograms and spline reconstructions in one figure.
%
%   Plots SO-Power (top row) and SO-Phase (bottom row) histograms,
%   their spline reconstructions, and spline coefficients in a 2x3 layout.
%
%   See also: SPLINE_BASIS

f = figure;
ax = figdesign(f, 2, 3, ...
    'type', 'usletter', ...
    'orient', 'landscape', ...
    'margins', [0.05 0.05 0.08 0.1 0.1 0.1], ...
    'position',[0.0404 0.1764 0.4840 0.6576]);

% Helper: plot one set into 3 adjacent axes
    function plot_splinefit(ax_handles, hist_mat, x_bins, fit_mat, coefs, knots_x, knots_y, opts, freq_bins, cmap_hist, cmap_fit, labels)
        % Histogram
        axes(ax_handles(1))
        imagesc(x_bins, freq_bins, hist_mat');
        axis xy
        ylabel('Frequency (Hz)')
        colormap(gca, cmap_hist)
        xlabel(labels.x)
        title(sprintf('%s Histogram: %d Parameters', labels.name, numel(hist_mat)))
        colorbar_noresize;

        % Spline reconstruction
        axes(ax_handles(2))
        imagesc(knots_x, knots_y, fit_mat');
        axis xy
        ylabel('Frequency (Hz)')
        c = colorbar_noresize;
        c.Label.String = labels.fitLabel;
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
        colormap(gca, cmap_fit)
        xlabel(labels.x)
        title(sprintf('Spline Reconstruction: %d Parameters', numel(coefs)))

        % Coefficients
        axes(ax_handles(3))
        imagesc(1:size(coefs,2), 1:size(coefs,1), coefs);
        axis xy;
        clim(max(coefs,[],'all')*[-1 1]);
        c = colorbar_noresize;
        c.Label.String = {'Coefficient'};
        c.Label.Rotation = -90;
        c.Label.VerticalAlignment = "bottom";
        colormap(gca, flipud(redblue_equalized));
        xlabel('x coeff knots')
        ylabel('y coeff knots')
        title('Spline Coefficients')

        % Equalize & limits
        equalize_axes(ax_handles(1:2),'dimension','xyc');
        axes(ax_handles(1))
        axis tight
        ylim(opts.ylimits)
        c_ptiles = prctile(hist_mat(hist_mat(:)~=0), opts.SOPH_clim_prctiles);
        clim(ax_handles(1), [c_ptiles(1) c_ptiles(2)]);
    end

% Top row: SO-Power
plot_splinefit(ax(1:3), SOpower_mat, SOpower_bins, fit_pow, coefs_pow, knots_x_pow, knots_y_pow, ...
    opts_pow, freq_bins, gouldian, gouldian, ...
    struct('x','SO-Power (dB)', 'name','SO-Power', 'fitLabel',{{'Density','(peaks/min in bin)'}}));

% Bottom row: SO-Phase
plot_splinefit(ax(4:6), SOphase_mat, SOphase_bins, fit_phase, coefs_phase, knots_x_phase, knots_y_phase, ...
    opts_phase, freq_bins, magma, magma, ...
    struct('x','SO-Phase (rad)', 'name','SO-Phase', 'fitLabel',{{'Proportion'}}));

set(ax,'fontsize',10);
end
