function [C_mat, freq_cbins, C_cbins, time_in_bin, prop_in_bin] = TFPeakHistogram(varargin)
% TFPEAKHISTOGRAM computes 2D histogram values for TFpeaks frequency
% (y-axis) against an arbitrary C metric (x-axis)

%% Parse input

p = inputParser;

%Cmetric info
addRequired(p, 'Cmetric', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'Cmetric_stages', @(x) validateattributes(x, {'numeric', 'vector', 'logical'}, {'real', 'nonempty'}));
addRequired(p, 'Cmetric_times_step', @(x) validateattributes(x,{'numeric'},{'real','finite','nonnan'}));
addRequired(p, 'Cmetric_valid', @(x) validateattributes(x, {'logical'}, {}));
addRequired(p, 'Cmetric_valid_allstages', @(x) validateattributes(x, {'logical'}, {}));

%TF-peak info
addRequired(p, 'TFpeak_freqs', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'peak_Cmetric', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));

%CPH settings
addOptional(p, 'circular_Cmetric', false, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'circular_bounds', [-pi, pi], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan'}));
addOptional(p, 'Cmetric_label', 'C-metric', @(x) validateattributes(x, {'char', 'numeric'},{}));

addOptional(p, 'C_range', [], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'C_binsizestep', [], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'freq_range', [0,40], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'freq_binsizestep', [1, 0.2], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'norm_dim', 0, @(x) validateattributes(x,{'numeric'},{'scalar'}));
addOptional(p, 'compute_rate', false, @(x) validateattributes(x,{'logical'},{}));

addOptional(p, 'norm_method', [], @(x) validateattributes(x, {'char', 'numeric'},{}));
addOptional(p, 'min_time_in_bin', 0, @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','nonnan','nonnegative','integer'}));

%Display settings
addOptional(p, 'plot_on', false, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'xlabel_text', 'C metric', @(x) validateattributes(x,{'char'},{}));
addOptional(p, 'verbose', true, @(x) validateattributes(x,{'char', 'logical'},{}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

if islogical(Cmetric_stages) && Cmetric_stages
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

for s = 1:num_Cbins

    if circular_Cmetric
        % Check for bins that need to be wrapped because Cmetric is circular
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
            infreqbin_inds = (TFpeak_freqs >= freq_bin_edges(1,f)) & (TFpeak_freqs < freq_bin_edges(2,f));

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

% Normalize along a dimension if desired
if norm_dim
    C_mat = C_mat ./ sum(C_mat, norm_dim, 'omitnan');
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

function display_soph_setting(verbose, Cmetric_label, C_range, C_binsizestep, freq_range, freq_binsizestep, norm_method, min_time_in_bin, norm_dim, compute_rate)
% Display CPH settings
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
        display_message = [display_message, '    Normalization Method: ', num2str(norm_method), newline];
    end

    disp(display_message)

end
