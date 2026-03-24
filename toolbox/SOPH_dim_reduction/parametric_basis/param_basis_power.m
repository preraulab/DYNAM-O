function [params, fitobj, gof, model_SOPH, power_wshed_img, f] = param_basis_power(SOPH, power_bins, freq_bins, varargin)
%PARAM_BASIS_POWER Perform additive parameterization on SOPH data
%
%   Usage:
%       [params, fitobj, gof, model_SOPH, power_wshed_img] = param_basis_power(SOPH, power_bins, freq_bins, varargin)
%
%   Input:
%       SOPH: Matrix of SOPH data -- required
%       power_bins: Vector of power bins -- required
%       freq_bins: Vector of frequency bins -- required
%
%   Optional inputs:
%       see param_basis_opts() for optional parameters
%
%   Output:
%       params: Matrix of fitted parameters. Columns are: [amp0, fmean0, fstd0, pmean0, pstd0, theta0]
%       fitobj: Fitted object containing detailed fit information
%       gof: Goodness of fit structure
%       model_SOPH: Fitted model SOPH
%       power_wshed_img: Image of watershed power distribution
%       f: figure handle to the final result figure
%
%   Example:
%       [params, fitobj, gof, model_SOPH, power_wshed_img] = param_basis_power(SOPH, power_bins, freq_bins, 'max_peaks', 10, 'min_dr2', 0.01);
%
%   See also fit_rotGauss, extracthistpeaks, num_modes, mode_overlap, get_mode_params
%
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

%%
% If a struct is input with settings/params, detect and reformat it to work with the input parser below.
struct_ind = cellfun(@isstruct,varargin); % Get index of the struct

if any(struct_ind)
    locs = find(struct_ind==1);
    struct_arguments = cellfun(@(x) struct2cell(x), varargin(locs), 'UniformOutput', false);
    struct_fieldnames = cellfun(@(x) fieldnames(x), varargin(locs), 'UniformOutput', false);
    opt_struct = cell2struct(vertcat(struct_arguments{:}), vertcat(struct_fieldnames{:}));
    varargin = varargin(~struct_ind); % Remove structs from the varargin

    argcell = namedargs2cell(opt_struct); % Convert the struct to cell array
    varargin = cat(2, varargin, argcell); % Add the new cell array with the params to the end of the varargin

    % Test to make sure that none of the additional parameters are already included
    str_cell = cellstr(varargin(cellfun(@(x)(ischar(x)|isstring(x)),varargin)));
    assert(length(str_cell) == length(unique(str_cell)), 'Cannot include struct and duplicate parameters.')
end

%% Parse inputs
p = inputParser;

% Required parameters
addRequired(p, 'SOPH', @(x) isnumeric(x) && isreal(x) && ~isempty(x) && ismatrix(x) && ~all(isnan(x), 'all'));
addRequired(p, 'power_bins', @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addRequired(p, 'freq_bins', @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));

% Optional parameters with default values
default_params = param_basis_opts('power'); % get the default parameters
addParameter(p, 'power_limits', default_params.power_limits, @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addParameter(p, 'freq_limits', default_params.freq_limits, @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addParameter(p, 'watershed_params', default_params.watershed_params, @(x) isnumeric(x) && numel(x) == 5);
addParameter(p, 'wshed_exp', default_params.wshed_exp, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addParameter(p, 'max_peaks', default_params.max_peaks, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'prefix_modes', default_params.prefix_modes, @(x) isnumeric(x) && (isempty(x) || size(x, 2) == 6));
addParameter(p, 'prefix_modes_order', default_params.prefix_modes_order, @(x) ismember(x, [-1, 0, 1]));
addParameter(p, 'max_overlap', default_params.max_overlap, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'min_amp', default_params.min_amp, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'min_freq_diff', default_params.min_freq_diff, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'criterion', default_params.criterion, @(x) ismember(x, {'max', 'mindr2', 'minpctr2', 'kneedle'}));
addParameter(p, 'min_dr2', default_params.min_dr2, @isnumeric);
addParameter(p, 'min_pctr2', default_params.min_pctr2, @isnumeric);
addParameter(p, 'kneedle_tol', default_params.kneedle_tol, @isscalar);
addParameter(p, 'UB_default', default_params.UB_default, @(x) isnumeric(x) && numel(x) == 6);
addParameter(p, 'LB_default', default_params.LB_default, @(x) isnumeric(x) && numel(x) == 6);
addParameter(p, 'plot_on', default_params.plot_on, @(x) (islogical(x) || isnumeric(x)) && isscalar(x));
addParameter(p, 'SOPH_clim_prctiles', default_params.SOPH_clim_prctiles, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addParameter(p, 'verbose', default_params.verbose, @(x) validateattributes(x, {'logical', 'numeric'}, {'scalar'}));

parse(p, SOPH, power_bins, freq_bins, varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

% Verify the dimensions of SOPH inputs
if size(SOPH, 1) == length(power_bins) && size(SOPH, 2) == length(freq_bins)
    % then SOPH needs to be transposed to work as a 2D image
    SOPH = transpose(SOPH);
else
    assert(size(SOPH, 2) == length(power_bins) && size(SOPH, 1) == length(freq_bins), 'Incompatible dimensions of SOPH inputs.')
end

%% Save models and values for each iteration
good_iter_models = {};
good_iter_rsquared = [];
good_iter_numbers = [];

% Initialize empty parameters for fitting
B0i = [];
UBi = [];
LBi = [];
last_B0i = [];
last_UBi = [];
last_LBi = [];

% Set up empty outputs in case the function fails
params=[];
fitobj=[];
gof=[];
model_SOPH=[];
f = [];

% Locate the valid submatrix of SOPH (non-Nan and non-infinite bins within limits)
valid_mat = isfinite(SOPH);
invalid_freq = all(~valid_mat, 2);
valid_mat(invalid_freq, :) = true;
valid_power_bins = power_bins >= power_limits(1) & power_bins <= power_limits(2) & all(valid_mat, 1);
valid_freq_bins = freq_bins >= freq_limits(1) & freq_bins <= freq_limits(2) & ~invalid_freq';

% Define basis function for fitting
fitfunc = @fit_rotGauss;
[power_grid, freq_grid] = meshgrid(power_bins, freq_bins);

% Define watershed parameters
merge_thresh = watershed_params(1);
dur_min = watershed_params(2);
bw_min = watershed_params(3);
height_min = watershed_params(4);
trim_vol = watershed_params(5);

%% Compute watershed segmentation
if wshed_exp
    [stats_table, power_wshed_img] = extracthistpeaks(exp(SOPH), power_bins, freq_bins, ...
        merge_thresh, dur_min, bw_min, height_min, trim_vol, false, false);
else
    [stats_table, power_wshed_img] = extracthistpeaks(SOPH, power_bins, freq_bins, ...
        merge_thresh, dur_min, bw_min, height_min, trim_vol, false, false);
end

if isempty(stats_table)
    warning('No watershed results')
    mode_params = [];
    tmp_mat = SOPH(valid_freq_bins, valid_power_bins);
    amp0 = tmp_mat(:);
else
    % Exclude peaks with center outside peak frequency limits
    valid_fmean_idx = stats_table.PeakFrequency >= freq_limits(1) & stats_table.PeakFrequency <= freq_limits(2);
    stats_table = stats_table(valid_fmean_idx, :);

    if isempty(stats_table)
        warning('Watershed found some peaks but none is valid')
        mode_params = [];
        tmp_mat = SOPH(valid_freq_bins, valid_power_bins);
        amp0 = tmp_mat(:);
    else
        % Sort peaks by height
        stats_table = sortrows(stats_table, 'Height', 'descend');

        % Extract the parameters from the watershed for initial conditions
        if wshed_exp
            amp0 = log(stats_table.Height);
        else
            amp0 = stats_table.Height;
        end
        fmean0 = stats_table.PeakFrequency;
        fstd0 = stats_table.Bandwidth / 1.96;
        pmean0 = stats_table.SOFeature;
        pstd0 = stats_table.Duration / 1.96;
        theta0 = zeros(size(amp0));

        mode_params = [amp0, fmean0, fstd0, pmean0, pstd0, theta0];

        if verbose > 0
            disp([num2str(size(mode_params, 1)) ' watershed modes found.'])
        end
    end
end

%% Initialize fitting parameters based on watershed results
% Set default amplitude bounds if they are nan
if isnan(UB_default(1))
    UB_default(1) = max(amp0) * 10;
end
if isnan(LB_default(1))
    LB_default(1) = min(amp0) / 10;
end

% Set default frequency bounds if they are nan
if isnan(UB_default(2))
    UB_default(2) = max(freq_bins(valid_freq_bins));
end
if isnan(LB_default(2))
    LB_default(2) = min(freq_bins(valid_freq_bins));
end

% Set default power bounds if they are nan
if isnan(UB_default(4))
    UB_default(4) = max(power_bins(valid_power_bins));
end
if isnan(LB_default(4))
    LB_default(4) = min(power_bins(valid_power_bins));
end

% Add prefix modes to the list of watershed regions
switch prefix_modes_order
    case 1
        mode_params = [prefix_modes; mode_params];
    case -1
        mode_params = [mode_params; prefix_modes];
    case 0
        mode_params = prefix_modes;
end

if verbose > 0
    if size(prefix_modes, 1) > 0
        if prefix_modes_order
            disp(['Adding ' num2str(size(prefix_modes, 1)) ' prefix modes to watershed modes.'])
        else
            disp(['Replacing watershed modes with ' num2str(size(prefix_modes, 1)) ' prefix modes.'])
        end
    end
end

% Update the number of modes with available parameters
N_wshed_modes = size(mode_params, 1);

% Adjust max_peaks if set to -1
if max_peaks == -1 %#ok<*NODEF>
    max_peaks = N_wshed_modes;
end

if N_wshed_modes < 1
    warning('No mode available to fit. Returning empty outputs')
    return
end

%% Plot initial data and watershed regions
if plot_on > 1
    f_iter = fullfig;
    ax = figdesign(1, max_peaks + 3, 'type', 'usletter', 'orient', 'landscape', 'margins', [0.1 0.1 0.03 0.025 0.02]);
    set(f_iter, 'units', 'inches', 'position', [0 8.4583 27.1806 10.0972]);
    linkaxes(ax)
    linkcaxes(ax([1, 3:max_peaks + 3]));
    set(ax, 'fontsize', 18);

    % Plot original SOPH data
    axes(ax(1));
    imagesc(power_bins, freq_bins, SOPH);
    axis xy
    axis tight
    xlabel('SO-Power (dB)', 'fontsize', 18);
    ylabel('Frequency (Hz)', 'fontsize', 18);
    title('Original SOPH', 'fontsize', 20);
    colormap(gouldian);

    % Plot watershed regions
    axes(ax(2));
    imagesc(power_bins, freq_bins, power_wshed_img);
    axis xy
    axis tight
    xlabel('SO-Power (dB)', 'fontsize', 18);
    title('Watershed Regions', 'fontsize', 20);

    axes(ax(max_peaks + 3));
    imagesc(power_bins, freq_bins, SOPH);
    axis xy
    axis tight
    xlabel('SO-Power (dB)', 'fontsize', 18);
    title('Original SOPH', 'fontsize', 20);
end

%% Loop through peaks to fit modes
for ii = 1:max_peaks
    % Set initial fit guess based on watershed results
    if ii <= N_wshed_modes
        %Add a mode to the stack
        B0i = [B0i; mode_params(ii,:)];
    else
        % Add a mode with mean parameters if beyond number of watershed peaks
        B0i = [B0i; mean(B0i, 1)]; %#ok<*AGROW>
    end

    % Define upper and lower bounds for fitting
    UBi = [UBi; UB_default];
    LBi = [LBi; LB_default];

    % Fit the model and obtain goodness-of-fit
    [fitobj, gof] = fitfunc(SOPH(valid_freq_bins, valid_power_bins), power_bins(valid_power_bins), freq_bins(valid_freq_bins), B0i, LBi, UBi, false);

    % Save the fitted model SOPH
    model_SOPH = feval(fitobj, power_grid, freq_grid);
    N_modes = num_modes(fitobj);

    % Compute adjusted R-squared for the current iteration
    adjr2_i = gof.adjrsquare;

    % Compute the difference in R-squared
    if ii > 1
        diffr2 = adjr2_i - good_iter_rsquared(end);
        diffr2_pct = diffr2/abs(good_iter_rsquared(end));
    else
        diffr2 = 0;
        diffr2_pct = 0;
    end

    % Compute mode overlap if there are multiple modes
    if N_modes > 1
        overlap = mode_overlap(fitobj, 1:N_modes, power_bins, freq_bins);
        [ol_max, ol_ind] = max(overlap, [], 'all', 'linear');
    else
        ol_max = 0;
    end

    % Extract fitted parameters
    params = get_mode_params(fitobj);

    % Display iteration information if verbose is true
    if verbose > 0
        disp(['**********Iteration ' num2str(ii) '**********']);
        disp(['   adjr2:    ' num2str(adjr2_i)]);
        disp(['   diff r2:  ' num2str(diffr2)]);
        disp(['   %diff r2: ' num2str(diffr2_pct)]);
        disp(['   maxol:    ' num2str(ol_max * 100, 3) '%']);
        disp(' ')
        disp(' B0i:');
        disp(B0i);
        disp(' LBi:');
        disp(LBi);
        disp(' UBi:');
        disp(UBi);
        disp(' Fit Parameters:');
        disp(params);
    end

    % Update initial parameters using the fitted values
    B0i = params;

    %% Check if need to stop adding peaks
    revert = false;

    % Check if we need to stop early due to hitting minimum criterion
    if ii > 1
        switch criterion
            case 'mindr2'
                if diffr2 < min_dr2
                    if verbose > 0
                        disp(['    R^2 change too small: ', num2str(diffr2)]);
                    end
                    revert = true;
                end
            case 'minpctr2'
                if diffr2_pct < min_pctr2
                    if verbose > 0
                        disp(['    %R^2 change too small: ', num2str(diffr2_pct)]);
                    end
                    revert = true;
                end
        end
    end

    % Check if mode overlap is too high
    if ol_max > max_overlap
        if verbose > 0
            [r, c] = ind2sub(size(overlap), ol_ind);
            disp(['    Overlap between modes ' num2str(r) ' and ' num2str(c) ' exceeds max overlap: ', num2str(ol_max)]);
        end
        revert = true;
    end

    % Check if any peak amplitude is below the minimum
    if any(B0i(:, 1) < min_amp)
        if verbose > 0
            disp(['    Added peak amplitude below min amp: ', num2str(B0i(:, 1)')]);
        end
        revert = true;
    end

    % Check if any peaks are too close in frequency
    if any(pdist(B0i(:,2)) < min_freq_diff)
        if verbose > 0
            disp(['    Peaks too close in frequency: ', num2str(B0i(:,2)')]);
        end
        revert = true;
    end

    %% Plot single plot of all iterations
    if plot_on > 1
        axes(ax(ii + 2)); %#ok<*LAXES>
        imagesc(power_bins, freq_bins, model_SOPH);
        axis xy
        axis tight
        title_str = ['Iteration. ' num2str(ii)];
        if revert
            title_str = [title_str,' X'];
        end
        title(title_str, 'fontsize', 20);
        xlabel('SO-Power (dB)', 'fontsize', 18);
        hold on
        plot(params(:, 4), params(:, 2), 'o', 'markersize', 8, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'r');
    end

    %% Revert to fit from previous iteration if necessary
    if revert
        if ii == 1
            disp('Max mode was insufficient to produce fit. Fitting plane and terminating.');
            fitobj = fitfunc(SOPH(valid_freq_bins, valid_power_bins), power_bins(valid_power_bins), freq_bins(valid_freq_bins), [], LBi, UBi, false);
            model_SOPH = feval(fitobj, power_grid, freq_grid);
            params = [];
            return;
        end

        if verbose > 0
            disp('    REVERTING TO PREVIOUS FIT');
        end

        B0i = last_B0i;
        UBi = last_UBi;
        LBi = last_LBi;

        if verbose > 0
            disp('Reverting to:');
            disp(B0i);
        end

        % Stop adding peaks if already beyond watershed modes
        if ii > N_wshed_modes
            if verbose > 0
                disp("Additional modes will not improve fit. Terminating procedure.");
            end
            break;
        end

    else
        good_iter_models{end+1} = fitobj;
        good_iter_rsquared(end+1) = adjr2_i;
        good_iter_numbers(end+1) = ii;

        % Save the values in case we need to revert
        last_B0i = B0i;
        last_UBi = UBi;
        last_LBi = LBi;
    end

    % Display message if maximum number of peaks is reached
    if ii == max_peaks && verbose > 0
        disp('Hit maximum number of peaks. Terminating.');
    end

end

%% Model selection and extract fitted parameters
switch criterion
    case 'max'
        [~, max_ind] = max(good_iter_rsquared);
        fit_iteration = good_iter_numbers(max_ind);

    case 'mindr2'
        diffr2 = diff([0 good_iter_rsquared]);

        %Find the last time a jump was bigger than the min value
        pick_ind = find(diffr2>=min_dr2,1,'last');
        fit_iteration = good_iter_numbers(pick_ind);

        if plot_on > 1
            figure('color','w')
            plot([0 good_iter_numbers(2:end)], diffr2,'o','MarkerSize',15,'MarkerEdgeColor','k','MarkerFaceColor','r')
            axis tight
            xline(fit_iteration, 'linewidth', 2)
            xlim([1 ii])
            set(gca,'xtick',1:ii)
            yline(min_dr2, '--k', 'linewidth', 2)
            ylim([min([diffr2, min_dr2]), max(diffr2)])
            xlabel('Iteration')
            ylabel('Change in r-squared')
            set(gca,'fontsize',18)
        end

    case 'minpctr2'
        r2s = [0 good_iter_rsquared];
        abs_diff = abs(diff(r2s));

        % Divide the absolute difference by the absolute value of the previous value
        previous_values = r2s(1:end-1);
        diffr2_pct = (abs_diff ./ abs(previous_values));

        %Find the last time a jump was bigger than the min value
        pick_ind = find(diffr2_pct>min_pctr2,1,'last');
        fit_iteration = good_iter_numbers(pick_ind);

        if plot_on > 1
            figure('color','w')
            plot([0 good_iter_numbers(2:end)], diffr2_pct,'o','MarkerSize',15,'MarkerEdgeColor','k','MarkerFaceColor','r')
            axis tight
            xline(fit_iteration, 'linewidth', 2);
            xlim([1 ii])
            set(gca,'xtick',1:ii)
            yline(min_pctr2, '--k', 'linewidth', 2)
            ylim([0, max(diffr2_pct)])
            xlabel('Iteration')
            ylabel('Proportion change in r-squared')
            set(gca,'fontsize',18)
        end

    case 'kneedle'
        if length(good_iter_numbers) > 1
            [knee, ~, x_max] = kneedle(good_iter_numbers', good_iter_rsquared', 'plot_on', plot_on>1);
            if knee(1)<=min(good_iter_numbers)
                fit_iteration = min(good_iter_numbers);
            elseif knee(1)>=max(good_iter_numbers)
                fit_iteration = max(good_iter_numbers);
            else
                fit_iteration = good_iter_numbers(find(good_iter_numbers>= knee(1)+kneedle_tol,1,'first'));
                if fit_iteration > x_max && fit_iteration>1
                    if verbose > 0
                        disp('Kneedle + 1 > max...')
                    end
                    fit_iteration = good_iter_numbers(find(good_iter_numbers< knee(1),1,'last'));
                end
            end
            if verbose > 0
                disp(['Kneedle selects iteration ' num2str(fit_iteration)])
            end
        end
end

fitobj = good_iter_models{good_iter_numbers==fit_iteration};
model_SOPH = feval(fitobj, power_grid, freq_grid);
params = get_mode_params(fitobj);

% Display final parameters if verbose
if verbose > 0
    disp('Final Params:');
    disp(params);
end

%% Plot final result if enabled
if plot_on == 1 || plot_on == 3
    f = fullfig;
    ax = figdesign(1, 3, 'type', 'usletter', 'orient', 'landscape', 'margins', [0.1 0.13 0.08 0.1 0.1 0.08]);
    set(f, 'units', 'inches', 'position', [0 9 14 4]);

    axes(ax(1));
    imagesc(power_bins, freq_bins, power_wshed_img);
    axis xy
    ylabel('Frequency (Hz)');
    title('Watershed Segmentation')

    axes(ax(2));
    imagesc(power_bins, freq_bins, SOPH);
    axis xy
    colorbar_noresize;
    colormap(gouldian);
    xlabel('SO-Power (dB)');
    title('Original Histogram')

    axes(ax(3));
    imagesc(power_bins, freq_bins, model_SOPH);
    axis xy
    hold on
    plot(params(:, 4), params(:, 2), 'o', 'markersize', 8, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'r');
    c = colorbar_noresize;
    c.Label.String = {'Density', '(peaks/min in bin)'};
    c.Label.Rotation = -90;
    c.Label.VerticalAlignment = "bottom";
    colormap(gouldian);
    title('Fitted Modes')

    % additional axes adjustments
    linkcaxes(ax(2:3));
    axes(ax(2))
    c_ptiles = prctile(SOPH(:), SOPH_clim_prctiles);
    clim([c_ptiles(1) c_ptiles(2)]);
    linkaxes(ax)
    axis tight
    xlim(power_limits)
    ylim(freq_limits)
    set(ax, 'fontsize', 10)
end
