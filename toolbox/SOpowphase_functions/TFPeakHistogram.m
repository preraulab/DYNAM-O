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
%       time_in_bin:    [B x 5] double - time (minutes) in each C-metric bin per sleep stage
%       prop_in_bin:    [B x 5] double - proportion of total time in each bin per stage
%       peak_at_freq:   [1xF] double - number of TF peaks in each frequency bin
%
%   Notes:
%       - Frequency bins are half-open [lo, hi) on each bin; freq_range(2) is excluded.
%         The same [lo, hi) convention applies to C_range (i.e., the SO_range when this
%         function is called from SOpowerHistogram or SOphaseHistogram). When
%         circular_Cmetric is true, the wrapped bins at the circular boundary use the
%         same half-open convention on each side of the wrap point.
%
%   See Also: SOpowerHistogram, SOphaseHistogram, SOpowerphaseHistogram
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
% Pipeline backend: 'rust' (default) uses tfpeak_histogram_mex when
% available for a ~20x speedup; 'matlab' forces the pure-MATLAB binning
% loop below (bit-identical but slower). Plumbed from runDYNAMO through
% SOpowerphaseHistogram → SOpowerHistogram / SOphaseHistogram.
addOptional(p, 'backend', 'rust', @(x) any(validatestring(lower(char(x)), {'matlab','rust'})));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

if islogical(Cmetric_stages) && Cmetric_stages %#ok<NODEF>
    Cmetric_stages = true(size(Cmetric_valid)); %#ok<*USENS>
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

% MEX fast path: dynamo_rs::tfpeak_histogram covers the whole binning +
% TIB + norm_dim + min_peak_at_freq + min_time_in_bin masking in one
% shot, so we can skip the MATLAB loop entirely when the wrapper is
% built. Inside a ThreadPool worker MATLAB blocks MEX execution — we
% detect that and fall back to the pure-MATLAB path. Outputs are
% bit-identical.
% Set DYNAMO_HIST_MATLAB=1 to force the pure-MATLAB path (bisection aid).
% backend='matlab' also forces the pure-MATLAB path (so the 'matlab'
% backend stays a faithful reference implementation, no Rust behind
% the scenes except the bundled multitaper_spectrogram_mex).
use_mex = strcmpi(char(backend), 'rust') ...
    && exist('tfpeak_histogram_mex', 'file') == 3;
if use_mex
    try
        pool_ = gcp('nocreate');
        if ~isempty(pool_) && isa(pool_, 'parallel.ThreadPool') && ~isempty(getCurrentTask)
            use_mex = false; % ThreadPool worker — MEX disallowed, fall back
        end
    catch
        % getCurrentTask isn't callable outside a worker context; that's fine.
    end
end
if ~isempty(getenv('DYNAMO_HIST_MATLAB'))
    use_mex = false;
end

if use_mex
    mex_opts = struct( ...
        'circular',         logical(circular_Cmetric), ...
        'circular_lo',      circular_bounds(1), ...
        'circular_hi',      circular_bounds(2), ...
        'norm_dim',         int32(norm_dim), ...
        'compute_rate',     logical(compute_rate), ...
        'min_time_in_bin',  double(min_time_in_bin), ...
        'min_peak_at_freq', int32(min_peak_at_freq));
    % Reshape into the row-vector shapes the MEX expects; logical masks
    % must already be logical (we enforced that at addRequired).
    [C_mat, time_in_bin, prop_in_bin, peak_at_freq] = tfpeak_histogram_mex( ...
        double(Cmetric(:)'), double(Cmetric_stages(:)'), double(Cmetric_times_step), ...
        logical(Cmetric_valid(:)'), logical(Cmetric_valid_allstages(:)'), ...
        double(TFpeak_freqs(:)), double(peak_Cmetric(:)), ...
        double(freq_bin_edges), double(C_bin_edges), mex_opts);
    % Rust already applied norm_dim / min_peak_at_freq / min_time_in_bin
    % masking — skip the post-loop fix-ups below.

else % Pure-MATLAB path (bit-identical reference).
    % Intialize Cmetric * freq matrix
    C_mat = nan(num_Cbins, num_freqbins);

    % Initialize time in bin
    if compute_TIB
        time_in_bin = zeros(num_Cbins, 5);
        prop_in_bin = zeros(num_Cbins, 5);
    end

    % Pre-compute the indices of peaks at each freq bin. Logical storage
    % (instead of double) cuts memory 8x and keeps the downstream & ops
    % on the SIMD-fast logical path.
    all_infreqbin_inds = false(length(TFpeak_freqs), num_freqbins);
    for f = 1:num_freqbins
        % Get indices of TFpeaks that occur in this freq bin
        all_infreqbin_inds(:, f) = (TFpeak_freqs >= freq_bin_edges(1,f)) & (TFpeak_freqs < freq_bin_edges(2,f));
    end

    % Pre-compute per-stage validity masks once (used inside the C-bin loop
    % for TIB computation). Builds a [N_times x 5] logical where column k
    % is "Cmetric_stages(i) == k AND Cmetric_valid(i)". Previously these
    % masks were rebuilt from scratch on every outer iteration — 5 masks
    % x num_Cbins outer iterations = hundreds of redundant recomputations.
    if compute_TIB
        stage_valid_masks = false(numel(Cmetric_stages), 5);
        Cmetric_valid_col = Cmetric_valid(:);
        stages_col = Cmetric_stages(:);
        for stg_ = 1:5
            stage_valid_masks(:, stg_) = (stages_col == stg_) & Cmetric_valid_col;
        end
        clear Cmetric_valid_col stages_col
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

        % Get time in bin (min) and proportion of time in bin.
        % Vectorized: a single sum along rows of a [N_times x 5] masked
        % logical matrix replaces the per-stage for-loop. stage_valid_masks
        % was precomputed once above.
        if compute_TIB
            TIB_col = TIB_inds(:);
            time_in_bin(s,:) = (sum(TIB_col & stage_valid_masks, 1) * Cmetric_times_step) / 60;

            time_in_bin_allstages = (sum(TIB_inds & Cmetric_valid_allstages) * Cmetric_times_step) / 60;
            prop_in_bin(s,:) = time_in_bin(s,:) / time_in_bin_allstages;

            % if less than threshold time in C bin, nan the whole column of CPH
            if sum(time_in_bin(s,:)) < min_time_in_bin
                continue
            end
        end

        % Vectorized replacement for the inner freq-bin loop. inCbin_inds is
        % [N_peaks x 1] logical; all_infreqbin_inds is [N_peaks x num_freqbins]
        % logical. Broadcasting &, then sum along rows, produces a
        % [1 x num_freqbins] count in one call — replaces 150 iterations of
        % an N_peaks-length AND+sum. 3-5x faster on typical workloads.
        if any(inCbin_inds)
            % (:) forces inCbin_inds to column so broadcasting with
            % [N_peaks x num_freqbins] always works regardless of whether
            % peak_Cmetric was passed as a row or column vector.
            C_mat(s, :) = sum(inCbin_inds(:) & all_infreqbin_inds, 1);
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

end % end of pure-MATLAB else branch

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
