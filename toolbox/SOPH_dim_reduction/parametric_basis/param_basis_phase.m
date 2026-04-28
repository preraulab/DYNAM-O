function [params, fitobj, gof, model_SOPhH, phase_wshed_img, f] = param_basis_phase(SOPhH, phase_bins, freq_bins, varargin)
%PARAM_BASIS_PHASE Perform additive parameterization on SOPhH data
%
%   Usage:
%       [params, fitobj, gof, model_SOPhH, phase_wshed_img] = param_basis_phase(SOPhH, phase_bins, freq_bins, varargin)
%
%   Input:
%       SOPhH: Matrix of SOPhH data -- required
%       phase_bins: Vector of phase bins -- required
%       freq_bins: Vector of frequency bins -- required
%
%   Optional inputs:
%       see param_basis_opts() for optional parameters
%
%   Output:
%       params: Matrix of fitted parameters. Columns are: [amp0, fmean0, fstd0, pmean0, pstd0, theta0]
%       fitobj: Fitted object containing detailed fit information
%       gof: Goodness of fit structure
%       model_SOPhH: Fitted model SOPhH
%       phase_wshed_img: Image of watershed phase distribution
%       f: figure handle to the final result figure
%
%   Example:
%       [params, fitobj, gof, model_SOPhH, phase_wshed_img] = param_basis_phase(SOPhH, phase_bins, freq_bins, 'max_peaks', 10, 'min_dr2', 0.01);
%
%   See also fit_vmGauss, extracthistpeaks, num_modes, mode_overlap, get_mode_params
%
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

    % Check that no parameter NAME is passed both as an explicit name-value
    % pair and inside a struct. Only inspect odd-indexed string entries
    % (the names in name-value pairs) after the 3 required positional args.
    positional_count = 3; % SOPhH, phase_bins, freq_bins
    name_indices = (positional_count+1):2:length(varargin);
    name_indices = name_indices(name_indices <= length(varargin));
    param_names = varargin(name_indices);
    param_names = param_names(cellfun(@(x) ischar(x) || isstring(x), param_names));
    assert(length(param_names) == length(unique(param_names)), ...
        'Cannot include struct and duplicate parameters.')
end

%% Parse inputs
p = inputParser;

% Required parameters
addRequired(p, 'SOPhH', @(x) isnumeric(x) && isreal(x) && ~isempty(x) && ismatrix(x) && ~all(isnan(x), 'all'));
addRequired(p, 'phase_bins', @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addRequired(p, 'freq_bins', @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));

% Optional parameters with default values
default_params = param_basis_opts('phase'); % get the default parameters
addParameter(p, 'phase_limits', default_params.phase_limits, @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addParameter(p, 'freq_limits', default_params.freq_limits, @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addParameter(p, 'watershed_params', default_params.watershed_params, @(x) isnumeric(x) && numel(x) == 5);
addParameter(p, 'gauss_filt_std', default_params.gauss_filt_std, @(x) isnumeric(x) && all(x > 0));
addParameter(p, 'wshed_exp', default_params.wshed_exp, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addParameter(p, 'max_peaks', default_params.max_peaks, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'prefix_modes', default_params.prefix_modes, @(x) isnumeric(x) && (isempty(x) || size(x, 2) == 6));
addParameter(p, 'prefix_modes_order', default_params.prefix_modes_order, @(x) ismember(x, [-1, 0, 1]));
addParameter(p, 'max_overlap', default_params.max_overlap, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'min_amp', default_params.min_amp, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'criterion', default_params.criterion, @(x) ismember(x, {'max', 'mindr2', 'minpctr2', 'kneedle'}));
addParameter(p, 'min_dr2', default_params.min_dr2, @isnumeric);
addParameter(p, 'min_pctr2', default_params.min_pctr2, @isnumeric);
addParameter(p, 'kneedle_tol', default_params.kneedle_tol, @isscalar);
addParameter(p, 'UB_default', default_params.UB_default, @(x) isnumeric(x) && numel(x) == 6);
addParameter(p, 'LB_default', default_params.LB_default, @(x) isnumeric(x) && numel(x) == 6);
addParameter(p, 'plot_on', default_params.plot_on, @(x) (islogical(x) || isnumeric(x)) && isscalar(x));
addParameter(p, 'SOPH_clim_prctiles', default_params.SOPH_clim_prctiles, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addParameter(p, 'verbose', default_params.verbose, @(x) validateattributes(x, {'logical', 'numeric'}, {'scalar'}));

parse(p, SOPhH, phase_bins, freq_bins, varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

% Verify the dimensions of SOPhH inputs
if size(SOPhH, 1) == length(phase_bins) && size(SOPhH, 2) == length(freq_bins)
    % then SOPhH needs to be transposed to work as a 2D image
    SOPhH = transpose(SOPhH);
else
    assert(size(SOPhH, 2) == length(phase_bins) && size(SOPhH, 1) == length(freq_bins), 'Incompatible dimensions of SOPhH inputs.')
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

% Set up empty outputs in case the function fails (soft-fail returns
% leave all outputs at these empties so callers can detect failure with
% a simple isempty(params) check).
params = [];
fitobj = [];
gof = [];
model_SOPhH = [];
phase_wshed_img = [];
f = [];

% Locate the valid submatrix of SOPhH (non-Nan and non-infinite bins within limits)
valid_mat = isfinite(SOPhH);
invalid_freq = all(~valid_mat, 2);
valid_mat(invalid_freq, :) = true;
valid_phase_bins = phase_bins >= phase_limits(1) & phase_bins <= phase_limits(2) & all(valid_mat, 1);
valid_freq_bins = freq_bins >= freq_limits(1) & freq_bins <= freq_limits(2) & ~invalid_freq';

% Define basis function for fitting
fitfunc = @fit_vmGauss;
[phase_grid, freq_grid] = meshgrid(phase_bins, freq_bins);

% Define watershed parameters
merge_thresh = watershed_params(1);
dur_min = watershed_params(2);
bw_min = watershed_params(3);
height_min = watershed_params(4);
trim_vol = watershed_params(5);

% -------- SOPhase Specific --------
%Duplicate the SOPhH so that periodic regions can be detected
SOPhH_wshed = [SOPhH SOPhH(:,2:end-1) SOPhH];
if gauss_filt_std>0
    SOPhH_wshed = imgaussfilt(SOPhH_wshed, gauss_filt_std);
end
phase_wshed = [(phase_bins-2*pi) phase_bins(2:end-1) (phase_bins+2*pi)];
% ----------------------------------

%% Compute watershed segmentation
if wshed_exp
    [stats_table, phase_wshed_img] = extracthistpeaks(exp(SOPhH_wshed), phase_wshed, freq_bins, ...
        merge_thresh, dur_min, bw_min, height_min, trim_vol, false, false);
else
    [stats_table, phase_wshed_img] = extracthistpeaks(SOPhH_wshed, phase_wshed, freq_bins, ...
        merge_thresh, dur_min, bw_min, height_min, trim_vol, false, false);
end

if isempty(stats_table)
    warning('No watershed results')
    mode_params = [];
    tmp_mat = SOPhH(valid_freq_bins, valid_phase_bins);
    amp0 = tmp_mat(:);
else
    % -------- SOPhase Specific --------
    % Merge modes that become close when you wrap back to pi
    coords = [stats_table.PeakFrequency wrapToPi(stats_table.SOFeature)];
    [~, coords_idx] = uniquetol(coords, 0.1, 'ByRows', true, 'OutputAllIndices', true);
    unique_regions_idx = [];
    for ii = 1:length(coords_idx)
        current_idx = coords_idx{ii};

        if length(current_idx) > 1
            raw_angles = stats_table.SOFeature(current_idx);
            is_in_range = raw_angles >= -pi & raw_angles <= pi;
            valid_idx = current_idx(is_in_range);

            if isempty(valid_idx)
                % Soft-fail: the watershed-on-tripled-phase image returned
                % a duplicate cluster with no member inside [-pi, pi]. Bail
                % cleanly with empty outputs so the rest of the pipeline
                % (e.g. the surviving SO-power parametric fit) keeps going.
                warning('param_basis_phase:noValidDuplicate', ...
                    'Duplicate regions found but none within the -pi to pi range. Returning empty outputs.');
                params      = [];
                fitobj      = [];
                gof         = [];
                model_SOPhH = [];
                phase_wshed_img = [];
                return
            elseif isscalar(valid_idx)
                % exactly one valid peak
                unique_regions_idx(end+1) = valid_idx;
            else
                % more than one valid regions, potentially due to multiple regions clustered together
                sub_coords = coords(current_idx, :);
                [~, subIdxList] = uniquetol(sub_coords, 0.01, 'ByRows', true, 'OutputAllIndices', true);
                for sj = 1:length(subIdxList)
                    cluster = current_idx(subIdxList{sj});
                    sub_angles = stats_table.SOFeature(cluster);
                    sub_valid = cluster(sub_angles >= -pi & sub_angles <= pi);
                    assert(~isempty(sub_valid), 'After finer clustering, no valid region in subgroup %d.', sj)
                    assert(isscalar(sub_valid), 'More than one valid regions found. Not possible with deterministic watershed.')
                    unique_regions_idx(end+1) = sub_valid;
                end
            end
        end
    end
    assert(numel(unique_regions_idx) == numel(unique(unique_regions_idx)), 'Duplicate entries found in unique_regions_idx.');

    % Reduce to unique regions within -pi to pi
    stats_table = stats_table(unique_regions_idx, :);
    assert(all(stats_table.SOFeature >= -pi & stats_table.SOFeature <= pi), 'SO-Phase for watershed regions out of [-pi, pi] bound. An error occured when selecting unique regions.')
    % ----------------------------------

    % Exclude peaks with center outside peak frequency limits
    valid_fmean_idx = stats_table.PeakFrequency >= freq_limits(1) & stats_table.PeakFrequency <= freq_limits(2);
    stats_table = stats_table(valid_fmean_idx, :);

    if isempty(stats_table)
        warning('Watershed found some peaks but none is valid')
        mode_params = [];
        tmp_mat = SOPhH(valid_freq_bins, valid_phase_bins);
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

% Set default phase bounds if they are nan
if isnan(UB_default(4))
    UB_default(4) = max(phase_bins(valid_phase_bins));
end
if isnan(LB_default(4))
    LB_default(4) = min(phase_bins(valid_phase_bins));
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

    % Plot original SOPhH data
    axes(ax(1));
    imagesc(phase_bins, freq_bins, SOPhH);
    axis xy
    axis tight
    xlim(phase_limits)
    ylim(freq_limits)
    xlabel('SO-Phase (rad)', 'fontsize', 18);
    ylabel('Frequency (Hz)', 'fontsize', 18);
    title('Original SOPhH', 'fontsize', 20);
    colormap(magma);

    % Plot watershed regions
    axes(ax(2));
    imagesc(phase_wshed, freq_bins, phase_wshed_img);
    axis xy
    axis tight
    xlim(phase_limits)
    ylim(freq_limits)
    xlabel('SO-Phase (rad)', 'fontsize', 18);
    title('Watershed Regions', 'fontsize', 20);

    axes(ax(max_peaks + 3));
    imagesc(phase_bins, freq_bins, SOPhH);
    axis xy
    axis tight
    xlim(phase_limits)
    ylim(freq_limits)
    xlabel('SO-Phase (rad)', 'fontsize', 18);
    title('Original SOPhH', 'fontsize', 20);
end

%% Loop through peaks to fit modes

% -------- SOPhase Specific --------
% indices used to skip initializing modes when revert gets triggered
valid_peaks = 1:N_wshed_modes;
% ----------------------------------

for ii = 1:max_peaks
    % Set initial fit guess based on watershed results
    if ii <= N_wshed_modes
        % -------- SOPhase Specific --------
        %Always start with initial parameters
        tmp_idx = 1:ii;
        select_idx = tmp_idx(ismember(tmp_idx, valid_peaks));
        B0i = mode_params(select_idx,:);
        % ----------------------------------
    else
        % Add a mode with mean parameters if beyond number of watershed peaks
        B0i = [B0i; mean(B0i, 1)]; %#ok<*AGROW>
    end

    % Define upper and lower bounds for fitting
    UBi = [UBi; UB_default];
    LBi = [LBi; LB_default];

    % Fit the model and obtain goodness-of-fit
    [fitobj, gof] = fitfunc(SOPhH(valid_freq_bins, valid_phase_bins), phase_bins(valid_phase_bins), freq_bins(valid_freq_bins), B0i, LBi, UBi, false);

    % Save the fitted model SOPhH
    model_SOPhH = feval(fitobj, phase_grid, freq_grid);
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
        overlap = mode_overlap(fitobj, 1:N_modes, phase_bins, freq_bins);
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

    % -------- SOPhase Specific --------
    % Compute empirical amplitude from normalized SOPhH
    %Get rid of any background sinusoid
    fitobj_nosin = fitobj;
    coeff_names = coeffnames(fitobj_nosin);
    if any(strcmpi(coeff_names, 'xxx'))
        fitobj_nosin.xxx = 0;
    end

    model_SOPhH_nosin = feval(fitobj_nosin, phase_grid, freq_grid);
    e_amp = B0i(:, 1);
    for jj = 1:size(B0i, 1)
        [~, freq_idx] = min(abs(freq_bins - B0i(jj, 2)));
        [~, phase_idx] = min(abs(phase_bins - B0i(jj, 4)));
        e_amp(jj) = model_SOPhH_nosin(freq_idx, phase_idx);
    end
    % ----------------------------------

    if any(e_amp < min_amp)
        if verbose > 0
            disp(['    Added peak empirical amplitude below min amp: ', num2str(e_amp')]);
        end
        revert = true;
    end

    %% Plot single plot of all iterations
    if plot_on > 1
        axes(ax(ii + 2)); %#ok<*LAXES>
        imagesc(phase_bins, freq_bins, model_SOPhH);
        axis xy
        axis tight
        xlim(phase_limits)
        ylim(freq_limits)
        title_str = ['Iteration. ' num2str(ii)];
        if revert
            title_str = [title_str,' X'];
        end
        title(title_str, 'fontsize', 20);
        xlabel('SO-Phase (rad)', 'fontsize', 18);
        hold on
        plot(params(:, 4), params(:, 2), 'o', 'markersize', 8, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'r');
    end

    %% Revert to fit from previous iteration if necessary
    if revert
        if ii == 1
            disp('Max mode was insufficient to produce fit. Fitting plane and terminating.');
            fitobj = fitfunc(SOPhH(valid_freq_bins, valid_phase_bins), phase_bins(valid_phase_bins), freq_bins(valid_freq_bins), [], LBi, UBi, false);
            model_SOPhH = feval(fitobj, phase_grid, freq_grid);
            params = [];
            return;
        end

        if verbose > 0
            disp('    REVERTING TO PREVIOUS FIT');
        end

        B0i = last_B0i;
        UBi = last_UBi;
        LBi = last_LBi;
        % -------- SOPhase Specific --------
        valid_peaks(ii) = 0;
        % ----------------------------------

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
model_SOPhH = feval(fitobj, phase_grid, freq_grid);
params = get_mode_params(fitobj);

% -------- SOPhase Specific --------
% Update the amplitude to empirical values from normalized SOPhH
%Get rid of any background sinusoid
fitobj_nosin = fitobj;
coeff_names = coeffnames(fitobj_nosin);
if any(strcmpi(coeff_names, 'xxx'))
    fitobj_nosin.xxx = 0;
end

model_SOPhH_nosin = feval(fitobj_nosin, phase_grid, freq_grid);

for ii = 1:size(params, 1)
    [~, freq_idx] = min(abs(freq_bins - params(ii, 2)));
    [~, phase_idx] = min(abs(phase_bins - params(ii, 4)));
    params(ii, 1) = model_SOPhH_nosin(freq_idx, phase_idx);
end

% Wrap the phase estimates to [-pi, pi] for interpretability
params(:, 4) = wrapToPi(params(:, 4));
% ----------------------------------

% Display final parameters if verbose
if verbose > 0
    disp('Final Params:');
    disp(params);
end

%% Plot final result if enabled
if plot_on == 1 || plot_on == 3
    f = fullfig;
    ax = figdesign(1, 3, 'type', 'usletter', 'orient', 'landscape', 'margins', [0.1 0.13 0.08 0.1 0.1 0.08]);
    set(f, 'units', 'inches', 'position', [0 6 14 4]);

    axes(ax(1));
    imagesc(phase_wshed, freq_bins, phase_wshed_img);
    axis xy
    ylabel('Frequency (Hz)');
    title('Watershed Segmentation')

    axes(ax(2));
    imagesc(phase_bins, freq_bins, SOPhH);
    axis xy
    colorbar_noresize;
    colormap(magma);
    xlabel('SO-Phase (rad)');
    title('Original Histogram')

    axes(ax(3));
    imagesc(phase_bins, freq_bins, model_SOPhH);
    axis xy
    hold on
    plot(params(:, 4), params(:, 2), 'o', 'markersize', 8, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'r');
    c = colorbar_noresize;
    c.Label.String = {'Proportion'};
    c.Label.Rotation = -90;
    c.Label.VerticalAlignment = "bottom";
    colormap(magma);
    title('Fitted Modes')

    % additional axes adjustments
    linkcaxes(ax(2:3));
    axes(ax(2))
    c_ptiles = prctile(SOPhH(SOPhH(:)~=0), SOPH_clim_prctiles);
    clim([c_ptiles(1) c_ptiles(2)]);
    linkaxes(ax)
    axis tight
    xlim(phase_limits)
    ylim(freq_limits)
    set(ax, 'fontsize', 10)
end
