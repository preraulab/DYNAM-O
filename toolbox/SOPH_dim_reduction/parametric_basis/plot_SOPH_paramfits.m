function plot_SOPH_paramfits(power_bins, power_wshed_img, SOPH_pow, model_SOPH_pow, params_pow, SOPH_clim_prctiles_pow, power_limits, freq_limits_pow, ...
    phase_bins, phase_wshed_img, SOPhH_phase, model_SOPhH_phase, params_phase, SOPH_clim_prctiles_phase, phase_limits, freq_limits_phase, ...
    freq_bins, power_fitobj, phase_fitobj)
%PLOT_SOPH_PARAMFITS  Plot SOPH histograms and parametric Gaussian peak reconstructions in one figure.
%
%   Plots SO-Power (top row) and SO-Phase (bottom row) histograms,
%   watershed segmentations, and their parametric reconstructions in a 2x3 layout.
%
%   See also: PARAM_BASIS_POWER and PARAM_BSIS_PHASE
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

% Hover distance threshold (fraction of axis diagonal). Tweak this value as desired.
hover_dist_threshold = 0.05;  % 0.05 = 5% of axis diagonal

% Create invisible; visibility restored at end for interactive callers.
f = figure('Visible','off');
ax = figdesign(f, 2, 3, ...
    'type', 'usletter', ...
    'orient', 'landscape', ...
    'margins', [0.05 0.08 0.1 0.1 0.11 0.12]);
set(f, 'units', 'inches')
set(f, 'position', [0 0 10 6])

% Store all necessary data in the figure's application data
setappdata(f, 'power_fitobj', power_fitobj);
setappdata(f, 'phase_fitobj', phase_fitobj);
setappdata(f, 'power_bins', power_bins);
setappdata(f, 'phase_bins', phase_bins);
setappdata(f, 'freq_bins', freq_bins);
setappdata(f, 'power_ax', ax(3));
setappdata(f, 'phase_ax', ax(6));

% Helper function for one row
    function plot_paramfit(ax_handles, x_bins, freq_bins, wshed_img, hist_mat, model_mat, params, cmap, type_str, xlabel_str, fitLabel, clim_prctiles, x_limits, freq_limits, plot_type)
        % --- Watershed segmentation
        hImg1 = imagesc(ax_handles(1), x_bins, freq_bins, wshed_img);
        set(hImg1, 'HitTest', 'off', 'PickableParts', 'none'); % images shouldn't capture datatips
        axis(ax_handles(1),'xy')
        ylabel(ax_handles(1), 'Frequency (Hz)');
        title(ax_handles(1), 'Watershed Segmentation')

        % --- Original histogram
        hImg2 = imagesc(ax_handles(2), x_bins, freq_bins, hist_mat');
        set(hImg2, 'HitTest', 'off', 'PickableParts', 'none');
        axis(ax_handles(2),'xy')
        colorbar_noresize(ax_handles(2));
        colormap(ax_handles(2), cmap);
        xlabel(ax_handles(2), xlabel_str);
        title(ax_handles(2), ['Original ' type_str ' Histogram'])

        % --- Fitted modes
        hImg3 = imagesc(ax_handles(3), x_bins, freq_bins, model_mat);
        set(hImg3, 'HitTest', 'off', 'PickableParts', 'none'); % disable datatips for image
        axis(ax_handles(3),'xy')
        hold(ax_handles(3),'on')

        if ~isempty(params)
            % --- Plot the mode points (single line object with multiple markers)
            hPts = plot(ax_handles(3), params(:, 4), params(:, 2), 'o', ...
                'markersize', 8, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'r', 'LineStyle', 'none');

            % Clear default data tip rows - most compatible method (old-style approach)
            try
                hPts.DataTipTemplate.DataTipRows = dataTipTextRow.empty();
            catch
                try
                    delete(hPts.DataTipTemplate.DataTipRows);
                catch
                    % fallback - overwrite later
                end
            end

            % Choose parameter names depending on type (using the latex-like names you provided)
            if strcmpi(type_str,'Power')
                colNames = {'amp','freq_{mean}','freq_{std}','power_{mean}','power_{std}','\theta'};
            else
                colNames = {'amp','freq_{mean}','freq_{std}','phase_{mean}','phase_{std}','\theta'};
            end

            % Add custom data tip rows for each parameter (vector values per marker)
            try
                for k = 1:length(colNames)
                    hPts.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow(colNames{k}, params(:,k), '%.3f');
                end
            catch
                % ignore if DataTipTemplate not supported exactly
            end

            % Make the marker object pickable (so datatips work) but do not let images steal hits
            set(hPts, 'HitTest', 'on', 'PickableParts', 'all');

            % Store mode data and point handle in axes appdata
            setappdata(ax_handles(3), [plot_type '_mode_pts'], hPts);
            setappdata(ax_handles(3), [plot_type '_params'], params);
            setappdata(ax_handles(3), [plot_type '_x_bins'], x_bins);
            setappdata(ax_handles(3), [plot_type '_mode_x'], params(:, 4));
            setappdata(ax_handles(3), [plot_type '_mode_y'], params(:, 2));

            % --- Plot contours for each mode (initially invisible)
            fitobj = getappdata(f, [plot_type '_fitobj']);
            x_fine = linspace(x_bins(1), x_bins(end), 200);
            freq_fine = linspace(freq_bins(1), freq_bins(end), 100);
            contours = gobjects(size(params,1),1);
            for k = 1:size(params,1)
                try
                    cdata = select_modes(fitobj, k, x_fine, freq_fine);
                catch
                    cdata = nan(length(freq_fine), length(x_fine));
                end
                try
                    % Capture the graphics object handle returned by contour
                    [~, contours(k)] = contour(ax_handles(3), x_fine, freq_fine, cdata, 'w-', 'LineWidth', 2);
                    if isgraphics(contours(k))
                        % make contours non-pickable so they don't steal picks from markers
                        set(contours(k), 'Visible','off', 'Tag','mode_contour', 'HitTest','off', 'PickableParts','none');
                    end
                catch
                    contours(k) = gobjects(1);
                end
            end
            setappdata(ax_handles(3), [plot_type '_contours'], contours);

            % Now ensure points are visually on top of contours
            try
                uistack(hPts, 'top');
            catch
                % ignore if uistack unavailable
            end

            % Colorbar, colormap and titles
            c = colorbar_noresize(ax_handles(3));
            c.Label.String = fitLabel;
            c.Label.Rotation = -90;
            c.Label.VerticalAlignment = "bottom";
            colormap(ax_handles(3), cmap);
            title(ax_handles(3), ['Model ' type_str ' Histogram and Modes'])

            % Additional layout / scaling adjustments
            linkcaxes(ax_handles(2:3));
            if any(hist_mat(:) ~= 0)
                c_ptiles = prctile(hist_mat(hist_mat(:)~=0), clim_prctiles);
            else
                c_ptiles = prctile(hist_mat(:), clim_prctiles);
            end
            clim(ax_handles(2), [c_ptiles(1) c_ptiles(2)]);
            linkaxes(ax_handles)
            axis(ax_handles(2),'tight')
            xlim(ax_handles(2), x_limits)
            ylim(ax_handles(2), freq_limits)
            set(ax_handles, 'fontsize', 10)
        end
    end

% --- SO-Power row ---
plot_paramfit(ax(1:3), power_bins, freq_bins, power_wshed_img, SOPH_pow, model_SOPH_pow, params_pow, ...
    gouldian, 'Power', 'SO-Power (dB)', {'Density','(peaks/min in bin)'}, SOPH_clim_prctiles_pow, power_limits, freq_limits_pow, 'power');

% --- SO-Phase row ---
plot_paramfit(ax(4:6), phase_bins, freq_bins, phase_wshed_img(:,length(phase_bins)+1:end-length(phase_bins),:), SOPhH_phase, model_SOPhH_phase, params_phase, ...
    magma, 'Phase', 'SO-Phase (rad)', {'Proportion'}, SOPH_clim_prctiles_phase, phase_limits, freq_limits_phase, 'phase');

% --- Enable datacursor mode (so clicking markers produces the enhanced datatip) ---
dcm = datacursormode(f);
set(dcm, 'Enable','on');

% --- Hover function to toggle contours (with axis-aware threshold) ---
set(f, 'WindowButtonMotionFcn', @(src,evt) hoverModeContour(src));

    function hoverModeContour(fig_handle)
        % Only act if there's a current axes under the pointer
        curr_ax = get(fig_handle, 'CurrentAxes');
        if isempty(curr_ax) || ~isgraphics(curr_ax)
            return
        end

        % For each plot type (power/phase) check if this axes contains its data
        for plot_type = {'power','phase'}
            plot_type_str = plot_type{1};
            if ~isappdata(curr_ax, [plot_type_str '_mode_pts'])
                continue
            end

            hPts = getappdata(curr_ax, [plot_type_str '_mode_pts']);
            if isempty(hPts) || ~isvalid(hPts)
                continue
            end

            % If cursor is over any mode point, do not update contours (let datatips work)
            curr_obj = hittest(fig_handle);
            if ~isempty(curr_obj) && any(curr_obj == hPts)
                return
            end

            % Mouse in axis coordinates
            pt = get(curr_ax,'CurrentPoint');
            x_mouse = pt(1,1);
            y_mouse = pt(1,2);

            % Mode points and contours
            mode_x = getappdata(curr_ax, [plot_type_str '_mode_x']);
            mode_y = getappdata(curr_ax, [plot_type_str '_mode_y']);
            contours = getappdata(curr_ax, [plot_type_str '_contours']);
            if isempty(contours), continue; end

            % Compute normalized distances so threshold is axis-aware:
            xlim_curr = get(curr_ax, 'XLim');
            ylim_curr = get(curr_ax, 'YLim');
            xrange = diff(xlim_curr);
            yrange = diff(ylim_curr);
            if xrange == 0, xrange = eps; end
            if yrange == 0, yrange = eps; end

            norm_dx = (mode_x - x_mouse) ./ xrange;
            norm_dy = (mode_y - y_mouse) ./ yrange;
            norm_dist = sqrt(norm_dx.^2 + norm_dy.^2);  % axis-normalized Euclidean distance

            % Find closest mode
            [min_dist, idx] = min(norm_dist);

            % If not within threshold, hide all contours
            if min_dist > hover_dist_threshold
                for k = 1:length(contours)
                    try
                        if isgraphics(contours(k))
                            set(contours(k),'Visible','off');
                        end
                    catch
                        % ignore individual errors
                    end
                end
                return
            end

            % Otherwise show only the selected contour
            for k = 1:length(contours)
                try
                    if isgraphics(contours(k))
                        if k == idx
                            set(contours(k),'Visible','on');
                        else
                            set(contours(k),'Visible','off');
                        end
                    end
                catch
                    % ignore individual errors
                end
            end
        end
    end

% Clean up on figure close
set(f, 'DeleteFcn', @(src,evt) delete(findobj(f, 'Tag', 'mode_contour')));

% Restore visibility for interactive callers (batch runs set root
% DefaultFigureVisible='off' so the figure stays hidden there).
if strcmp(get(groot, 'DefaultFigureVisible'), 'on')
    set(f, 'Visible', 'on');
end
end
