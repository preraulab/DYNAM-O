function [SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin, peak_at_freq, peak_SOphase, peak_selection_inds, SOphase, SOphase_times] = SOphaseHistogram(v1,v2,varargin)
% SOPHASEHISTOGRAM computes slow-oscillation phase histogram matrix
% Usage:
%   [SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin, peak_at_freq, peak_SOphase, peak_selection_inds, SOphase, SOphase_times] = ...
%                                 SOphaseHistogram(EEG, Fs, TFpeak_freqs, TFpeak_times, <options>)
%
%  Inputs:
%   REQUIRED:
%       EEG: 1xN double - timeseries EEG data --required
%       Fs: numerical - sampling frequency of EEG (Hz) --required
%                   OR
%       SOphase: 1xN double - SO phase timeseries data --required
%       SOphase_times: 1xN double - SO phase timeseries times --required
%
%       TFpeak_freqs: Px1 - frequency each TF peak occurs (Hz) --required
%       TFpeak_times: Px1 - times each TF peak occurs (s) --required
%
%   OPTIONAL:
%       TFpeak_stages: Px1 - sleep stage each TF peak occurs 5=W,4=R,3=N1,2=N2,1=N3
%       stage_times: 1xS double - stage times
%       stage_vals: 1xS double - numeric stage values 5=W,4=R,3=N1,2=N2,1=N3
%       EEG_times: 1xN double - times for each EEG sample. Default = (0:length(EEG)-1)/Fs
%       time_range: 1x2 double - min and max times for which to include TFpeaks.
%                                Default = [EEG_times(1), EEG_times(end)]
%       isexcluded: 1xN logical - marks each time point of data to be excluded or not, e.g., due to artifacts. Default = all false.
%
%    HISTOGRAM OPTIONAL:
%       see SOpowerphasehist_opts() for optional parameters
%
%  Outputs:
%       SO_mat: SO phase histogram (SOphase x frequency)
%       freq_cbins: 1xF double - centers of the frequency bins
%       SO_cbins: 1xPH - centers of the SO phase bins
%       time_in_bin: 1xTx5 - minutes spent in each phase bin for each stage
%       prop_in_bin: 1xT - proportion of total time (all stages) in each bin spent in
%                          the selected stages
%       peak_at_freq: 1xF - number of peaks in each frequency bin
%       peak_SOphase: 1xP double - slow oscillation phase at each TFpeak
%       peak_selection_inds: 1xP logical - which TFpeaks are counted in the histogram
%       SOphase: 1xN double - SO phase timeseries data
%       SOphase_times: 1xN double - SO phase timeseries times
%
%  Notes:
%       - Frequency bins are half-open [lo, hi) on each bin; freq_range(2) is excluded.
%         The same [lo, hi) convention applies to SO_range.
%
%  See Also: SOpowerHistogram, SOpowerphaseHistogram, computeSOphase, TFPeakHistogram
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
%Check for first two inputs being EEG/FS or SOphase/SOphase_times
assert(nargin >= 2, 'First inputs must either be EEG/Fs or SOphase/SOphase_times')
if isscalar(v2)
    EEG = v1;
    Fs = v2;
    SOphase = [];
    SOphase_times = [];
    assert(isvector(EEG) & length(EEG)>1,'EEG must be a vector')
    assert(Fs>0,'Must have positive Fs');
else
    EEG = [];
    Fs = [];
    SOphase = v1;
    SOphase_times = v2;
end

%% Parse input
p = inputParser;

%TFpeak info
addRequired(p, 'TFpeak_freqs', @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector'}));
addRequired(p, 'TFpeak_times', @(x) validateattributes(x, {'numeric'}, {'real','finite','vector'}));
addOptional(p, 'TFpeak_stages', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','2d'}));

%Stage info
addOptional(p, 'stage_times', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nondecreasing','2d'}));
addOptional(p, 'stage_vals', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nonnegative','2d'}));

%EEG time settings
addOptional(p, 'EEG_times', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addOptional(p, 'time_range', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addOptional(p, 'isexcluded', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));

%SOPH settings
SOPH_options = SOpowerphasehist_opts(); % get the default parameters
addOptional(p, 'freq_range', SOPH_options.freq_range, @(x) validateattributes(x,{'numeric'},{'real','finite','vector','numel',2}));
addOptional(p, 'freq_binsizestep', SOPH_options.freq_binsizestep, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'SO_range', SOPH_options.SOphase_range, @(x) validateattributes(x, {'numeric'}, {'real','finite','vector','numel',2}));
addOptional(p, 'SO_binsizestep', SOPH_options.SOphase_binsizestep, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'SO_freqrange', SOPH_options.SO_freqrange, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector','numel',2}));
addOptional(p, 'SOPH_stages', SOPH_options.SOPH_stages, @(x) validateattributes(x,{'numeric'},{'real','nonnegative','vector'})); % W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
addOptional(p, 'norm_dim', SOPH_options.SOphase_norm_dim, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));
addOptional(p, 'compute_rate', SOPH_options.compute_rate, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));

%SOphase specific settings
addOptional(p, 'min_peak_at_freq', SOPH_options.SOphase_min_peak_at_freq, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));
addOptional(p, 'SOphase_filter', SOPH_options.SOphase_filter);

%Display settings
addOptional(p, 'plot_on', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(p, 'verbose', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

if ~isempty(EEG) %Handle EEG/Fs input
    %Force EEG to be a column vector
    if isrow(EEG)
        EEG = EEG(:);
    end

    if isempty(EEG_times) %#ok<*NODEF>
        EEG_times = (0:length(EEG)-1)/Fs;
    else
        %Force EEG_times to be a row vector
        if iscolumn(EEG_times)
            EEG_times = transpose(EEG_times);
        end
        assert(length(EEG_times) == length(EEG), 'EEG_times must be the same length as EEG');
    end

    if isempty(time_range)
        time_range = [min(EEG_times), max(EEG_times)];
    else
        assert( (time_range(1) >= min(EEG_times)) & (time_range(2) <= max(EEG_times)), 'time_range cannot be outside of the time range described by "EEG_times"');
    end

    if isempty(isexcluded)
        isexcluded = false(length(EEG), 1);
    else
        assert(length(isexcluded) == length(EEG),'isexcluded must be the same length as EEG');
    end

else %Handle SOphase/SOphase_times input
    SOphase_times_step = SOphase_times(2) - SOphase_times(1);
    if isempty(time_range)
        time_range = [min(SOphase_times)-SOphase_times_step, max(SOphase_times)+SOphase_times_step];
    else
        assert( (time_range(1) >= min(SOphase_times)-SOphase_times_step) & (time_range(2) <= max(SOphase_times)+SOphase_times_step), 'time_range cannot be outside of the time range described by "SOphase_times"');
    end

    % Compute SOphase stage
    if ~isempty(stage_times) && ~isempty(stage_vals)
        SOphase_stages = interp1(stage_times, stage_vals, SOphase_times, 'previous');
        SOphase_stages(isnan(SOphase_stages)) = 0; % a conservative choice to mark samples outside scored stages as Unknown
    else
        SOphase_stages = true;
    end
end

assert((SO_range(1) >= -pi) & (SO_range(2) <= pi), 'SO-phase range must be values between -pi and pi')
assert(SO_binsizestep(1) < 2*pi, 'SO-phase bin size must be less than 2*pi')

%% Compute SO phase
if ~isempty(SOphase) % SOphase is directly provided
    assert(~isempty(SOphase_times), 'SOphase input only but no SOphase_times received.')
    %Force SOphase to be a row vector for the interp1
    if iscolumn(SOphase)
        SOphase = transpose(SOphase);
    end
    %Force SOphase_times to be a row vector for the interp1
    if iscolumn(SOphase_times)
        SOphase_times = transpose(SOphase_times);
    end

else % Compute the SOphase
    [SOphase, SOphase_times, SOphase_stages] = computeSOphase(EEG, Fs, 'stage_times', stage_times, 'stage_vals', stage_vals,...
        'EEG_times', EEG_times, 'isexcluded', isexcluded, 'SO_freqrange', SO_freqrange, 'SOphase_filter', SOphase_filter);
end

% Get SOphase_times step size
SOphase_times_step = SOphase_times(2) - SOphase_times(1);

% Interpolate SOphase to peak time points
peak_SOphase = interp1([SOphase_times(1)-SOphase_times_step, SOphase_times, SOphase_times(end)+SOphase_times_step],...
    [SOphase(1), SOphase, SOphase(end)], TFpeak_times); % peaks at isexcluded time points have NaN values here

% Re-wrap phases to be between -pi and pi
peak_SOphase = wrapToPi(peak_SOphase);
SOphase = wrapToPi(SOphase);

%% Get valid peak indices
% Compute TF peak stages if not included
if isempty(TFpeak_stages) && ~isempty(stage_times) && ~isempty(stage_vals)
    TFpeak_stages = interp1(stage_times, stage_vals, TFpeak_times, 'previous');
    TFpeak_stages(isnan(TFpeak_stages)) = 0; % a conservative choice to mark peaks outside scored stages as unknown
end

% Remove TF peaks outside of stage to reduce computational load during loop
if ~isempty(TFpeak_stages)
    stage_inds_peaks = ismember(TFpeak_stages, SOPH_stages);
else
    stage_inds_peaks = true(size(TFpeak_times));
end

nanSOphase_inds_peaks = ~isnan(peak_SOphase); % isexcluded time points have NaN values here
timerange_inds_peaks = TFpeak_times>=time_range(1) & TFpeak_times<=time_range(2);
peak_selection_inds = stage_inds_peaks & nanSOphase_inds_peaks & timerange_inds_peaks;

clear stage_inds_peaks nanSOphase_inds_peaks timerange_inds_peaks

%% Get valid SOphase indices
% Exclude unwanted stages, isexcluded, and outside time range
if islogical(SOphase_stages) && SOphase_stages
    SOphase_stages_valid = true(size(SOphase_stages));
else
    SOphase_stages_valid = ismember(SOphase_stages, SOPH_stages);
end

SOphase_excluded_valid = ~isnan(SOphase); % isexcluded time points have NaN values here
SOphase_times_valid = SOphase_times>=time_range(1) & SOphase_times<=time_range(2);

SOphase_valid = SOphase_stages_valid & SOphase_excluded_valid & SOphase_times_valid;
SOphase_valid_allstages = SOphase_excluded_valid & SOphase_times_valid;

clear SOphase_stages_valid SOphase_excluded_valid SOphase_times_valid

%% Compute the SO phase histogram
[SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin, peak_at_freq] = TFPeakHistogram(SOphase,...
    SOphase_stages, SOphase_times_step, SOphase_valid, SOphase_valid_allstages,...
    TFpeak_freqs(peak_selection_inds), peak_SOphase(peak_selection_inds),...
    'circular_Cmetric', true, 'circular_bounds', SO_range,... # specific to SOphase histogram
    'Cmetric_label', 'SO-Phase', 'xlabel_text', 'SO Phase (radians)',...
    'C_range', SO_range, 'C_binsizestep', SO_binsizestep,...
    'freq_range', freq_range, 'freq_binsizestep', freq_binsizestep,...
    'norm_dim', norm_dim, 'compute_rate', compute_rate,...
    'min_peak_at_freq', min_peak_at_freq,... # specific to SOphase histogram
    'plot_on', plot_on, 'verbose', verbose);

end
