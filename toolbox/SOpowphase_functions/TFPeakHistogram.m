function [C_mat, freq_cbins, C_cbins, time_in_bin, prop_in_bin, peak_at_freq] = TFPeakHistogram(varargin)
%TFPEAKHISTOGRAM  Compute 2D histogram of TF peak frequency against an arbitrary C metric
%
%   Usage:
%       [C_mat, freq_cbins, C_cbins, time_in_bin, prop_in_bin, peak_at_freq] = TFPeakHistogram(Cmetric, Cmetric_stages, ...)
%
%   Required Inputs:
%       Cmetric:                [1xM] double - C-metric timeseries values -- required
%       Cmetric_stages:         [1xM] double/logical - sleep stage or mask for each C-metric sample -- required
%       Cmetric_times_step:     double - time step between C-metric samples (s) -- required
%       Cmetric_valid:          [1xM] logical - valid (non-artifact) mask for C-metric -- required
%       Cmetric_valid_allstages:[1xM] logical - valid mask across all stages -- required
%       TFpeak_freqs:           [1xP] double - frequency of each TF peak (Hz) -- required
%       peak_Cmetric:           [1xP] double - C-metric value at each TF peak -- required
%
%   Optional Inputs (see SOpowerphasehist_opts() for SOPH parameter defaults):
%       circular_Cmetric:  logical - treat C-metric as circular (default: false)
%       circular_bounds:   [1x2] double - bounds for circular C-metric (default: [-pi, pi])
%       Cmetric_label:     char - label for C-metric axis (default: 'C-metric')
%       xlabel_text:       char - x-axis label string (default: 'C metric')
%       C_range:           [1x2] double - min/max C-metric range (default: [])
%       C_binsizestep:     [1x2] double - [bin size, step] for C-metric axis (default: [])
%       freq_range:        [1x2] double - frequency range in Hz (default: from SOpowerphasehist_opts)
%       freq_binsizestep:  [1x2] double - [size, step] for frequency axis (default: from opts)
%       norm_dim:          integer - normalization dimension (0=none, 1=normalize by row) (default: 0)
%       compute_rate:      logical - compute histogram as rate (peaks/min) (default: true)
%       norm_method:       char - additional normalization method (default: '')
%       min_time_in_bin:   double - minimum time in bin (minutes) to include (default: 0)
%       min_peak_at_freq:  double - minimum peaks at frequency to include (default: 0)
%       plot_on:           logical - plot histogram (default: false)
%       verbose:           logical - verbose output (default: true)
%
%   Outputs:
%       C_mat:          [BxF] double - 2D histogram matrix (C-bins x frequency bins)
%       freq_cbins:     [1xF] double - frequency bin centers (Hz)
%       C_cbins:        [1xB] double - C-metric bin centers
%       time_in_bin:    [1xB] double - time (minutes) in each C-metric bin
%       prop_in_bin:    [1xB] double - proportion of total time in each bin
%       peak_at_freq:   [1xF] double - number of TF peaks in each frequency bin
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
%% Parse input
p = inputParser;

%Cmetric info
addRequired(p, 'Cmetric', @(x) validateattributes(x, {'numeric'}, {'real','vector'}));
addRequired(p, 'Cmetric_stages', @(x) validateattributes(x, {'numeric','logical'}, {'real','finite','nonnegative','vector'}));
addRequired(p, 'Cmetric_times_step', @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addRequired(p, 'Cmetric_valid', @(x) validateattributes(x,{'logical'},{'finite','vector'}));
addRequired(p, 'Cmetric_valid_allstages', @(x) validateattributes(x,{'logical'},{'finite','vector'}));

%TF peak info
addRequired(p, 'TFpeak_freqs', @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector'}));
addRequired(p, 'peak_Cmetric', @(x) validateattributes(x, {'numeric'}, {'real','finite','vector'}));

%CPH settings
SOPH_options = SOpowerphasehist_opts(); % get some default parameters
addOptional(p, 'circular_Cmetric', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'circular_bounds', SOPH_options.SOphase_range, @(x) validateattributes(x, {'numeric'}, {'real','finite','vector','numel',2}));
addOptional(p, 'Cmetric_label', 'C-metric', @(x) validateattributes(x, {'char','string'}, {'scalartext'}));
addOptional(p, 'xlabel_text', 'C metric', @(x) validateattributes(x, {'char','string'}, {'scalartext'}));

addOptional(p, 'C_range', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addOptional(p, 'C_binsizestep', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));

addOptional(p, 'freq_range', SOPH_options.freq_range, @(x) validateattributes(x,{'numeric'},{'real','finite','vector','numel',2}));
addOptional(p, 'freq_binsizestep', SOPH_options.freq_binsizestep, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'norm_dim', 0, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));
addOptional(p, 'compute_rate', SOPH_options.compute_rate, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'norm_method', '', @(x) validateattributes(x, {'char','string'}, {'scalartext'}));
addOptional(p, 'min_time_in_bin', 0, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));
addOptional(p, 'min_peak_at_freq', 0, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));

%Display settings
addOptional(p, 'plot_on', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'verbose', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

if islogical(Cmetric_stages) && Cmetric_stages %#ok<NODEF>
    Cmetric_stages = true(size(Cmetric_valid));
end

if circular_Cmetric
    circular_low = circular_bounds(1);
    circular_high = circular_bounds(2);
    circular_range = diff(circular_bounds);
end

%Compute TIB if any of these conditions are true
compute_TIB = compute_rate || nargout >= 3 || min_time_in_bin > 0;

%% Settings for the histogram
% Get frequency bins
[freq_bin_edges, freq_cbins] = create_bins(freq_range, freq_binsizestep(1), freq_binsizestep(2), 'partial');
num_freqbins = length(freq_cbins);

if circular_Cmetric
    [C_bin_edges, C_cbins] = create_bins(C_range, C_binsizestep(1), C_binsizestep(2), 'extend');
else
    [C_bin_edges, C_cbins] = create_bins(C_range, C_binsizestep(1), C_binsizestep(2), 'partial');
end
num_Cbins = length(C_cbins);

% Display the CPH settings
display_soph_setting(verbose, Cmetric_label, C_range, C_binsizestep, freq_range, freq_binsizestep, norm_method, min_time_in_bin, norm_dim, compute_rate)

%% Create the histogram
% Intialize Cmetric * freq matrix
C_mat = nan(num_Cbins, num_freqbins);

% Initialize time in bin
if compute_TIB
    time_in_bin = zeros(num_Cbins, 5);
    prop_in_bin = zeros(num_Cbins, 5);
end

% Pre-compute the indices of peaks at each freq bin
all_infreqbin_inds = zeros(length(TFpeak_freqs), num_freqbins);
for f = 1:num_freqbins
    % Get indices of TFpeaks that occur in this freq bin
    all_infreqbin_inds(:, f) = (TFpeak_freqs >= freq_bin_edges(1,f)) & (TFpeak_freqs < freq_bin_edges(2,f));
end

for s = 1:num_Cbins

    if circular_Cmetric
        % Check for bins that need to be wrapped when Cmetric is circular
        if (C_bin_edges(1,s) <= circular_low) % Lower limit should be wrapped
            wrapped_edge_lowlim = C_bin_edges(1,s) + circular_range;

            if compute_TIB
                TIB_inds = (Cmetric >= wrapped_edge_lowlim) | (Cmetric < C_bin_edges(2,s));
            end
            inCbin_inds = (peak_Cmetric >= wrapped_edge_lowlim) | (peak_Cmetric < C_bin_edges(2,s));

        elseif (C_bin_edges(2,s) >= circular_high) % Upper limit should be wrapped
            wrapped_edge_highlim = C_bin_edges(2,s) - circular_range;

            if compute_TIB
                TIB_inds = (Cmetric < wrapped_edge_highlim) | (Cmetric >= C_bin_edges(1,s));
            end
            inCbin_inds = (peak_Cmetric < wrapped_edge_highlim) | (peak_Cmetric >= C_bin_edges(1,s));

        else % Both limits are within circular_bounds, no wrapping necessary
            if compute_TIB
                TIB_inds = (Cmetric >= C_bin_edges(1,s)) & (Cmetric < C_bin_edges(2,s));
            end
            inCbin_inds = (peak_Cmetric >= C_bin_edges(1,s)) & (peak_Cmetric < C_bin_edges(2,s));
        end

    else
        if compute_TIB
            % Get indices of Cmetric that occur in this Cmetric bin
            TIB_inds = (Cmetric >= C_bin_edges(1,s)) & (Cmetric < C_bin_edges(2,s));
        end

        % Get indices of valid TFpeaks that occur in this Cmetric bin
        inCbin_inds = (peak_Cmetric >= C_bin_edges(1,s)) & (peak_Cmetric < C_bin_edges(2,s));
    end

    % Get time in bin (min) and proportion of time in bin
    if compute_TIB
        for stage = 1:5
            Cmetric_stages_ind = Cmetric_stages == stage;
            time_in_bin(s,stage) = (sum(TIB_inds & Cmetric_valid & Cmetric_stages_ind) * Cmetric_times_step) / 60;
        end

        time_in_bin_allstages = (sum(TIB_inds & Cmetric_valid_allstages) * Cmetric_times_step) / 60;
        prop_in_bin(s,:) = time_in_bin(s,:) / time_in_bin_allstages;

        % if less than threshold time in C bin, nan the whole column of CPH
        if sum(time_in_bin(s,:)) < min_time_in_bin
            continue
        end
    end

    if sum(inCbin_inds) >= 1
        for f = 1:num_freqbins
            % Get indices of TFpeaks that occur in this freq bin
            infreqbin_inds = all_infreqbin_inds(:, f);

            % Fill histogram with count of peaks in this freq/Cmetric bin
            C_mat(s, f) = sum(inCbin_inds & infreqbin_inds);
        end
    else
        C_mat(s,:) = 0;
    end

    if compute_rate
        C_mat(s,:) = C_mat(s,:) / sum(time_in_bin(s,:));
    end

end

% Mask out freq bins with too few peaks
peak_at_freq = sum(all_infreqbin_inds, 1);
C_mat(:, peak_at_freq < min_peak_at_freq) = nan;

% Normalize along a dimension if desired
if norm_dim
    dim_sum = sum(C_mat, norm_dim, 'omitnan');
    dim_sum(dim_sum == 0) = 1; % avoid 0/0 = nan
    C_mat = C_mat ./ dim_sum;
end

%% Plot
if plot_on
    figure;
    imagesc(C_cbins, freq_cbins, C_mat')
    axis xy
    if circular_Cmetric
        colormap magma
    else
        colormap(gouldian)
    end
    climscale([],[],false);
    colorbar;
    xlabel(xlabel_text);
    ylabel('Frequency (Hz)');
end

end


%% % Display CPH settings
function display_soph_setting(verbose, Cmetric_label, C_range, C_binsizestep, freq_range, freq_binsizestep, norm_method, min_time_in_bin, norm_dim, compute_rate)
if ischar(verbose)
    disp(verbose)

elseif verbose
    display_message = ['  ', Cmetric_label,  ' Histogram Settings', newline, ...
        '    Frequency Window Size: ' num2str(freq_binsizestep(1)) ' Hz, Window Step: ' num2str(freq_binsizestep(2)) ' Hz', newline,...
        '    Frequency Range: ', num2str(freq_range(1)) '-' num2str(freq_range(2)) ' Hz', newline,...
        '    ', Cmetric_label, ' Window Size: ' num2str(C_binsizestep(1)) ', Window Step: ' num2str(C_binsizestep(2)), newline,...
        '    ', Cmetric_label, ' Range: ', num2str(C_range(1)), '-', num2str(C_range(2)),  newline...
        '    Normalized Histogram Dimension: ', num2str(norm_dim), newline,...
        '    Compute Rate: ', char(string(compute_rate)), newline,...
        '    Minimum time required in each ', Cmetric_label, ' bin: ', num2str(min_time_in_bin), ' min', newline];

    if ~isempty(norm_method)
        display_message = [display_message, '    Normalization Method: ', norm_method, newline];
    end

    disp(display_message)

end
end
