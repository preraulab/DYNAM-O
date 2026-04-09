function opts = detection_opts(varargin)
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
%% Parse inputs
p = inputParser;

%% Multitaper method parameters
%Frequency bin resolution of the spectrogram
addOptional(p, 'mtm_dsfreqs', 0.1, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
%Frequency range to compute spectrogram over (Hz)
addOptional(p, 'mtm_freq_range', [0, 30], @(x) validateattributes(x,{'numeric'},{'real','finite','vector','numel',2}));
%Taper parameters [time half-bandwidth product, number of tapers]
addOptional(p, 'mtm_taper_params', [2, 3], @(x) validateattributes(x,{'numeric'},{'real','finite','vector','numel',2}));
%Window length in spectrogram computation for the first round of watershed
addOptional(p, 'mtm_window_length_1', 1, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
%Window length in spectrogram computation for the second round of watershed
addOptional(p, 'mtm_window_length_2', 2, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
%Window step size in spectrogram computations
addOptional(p, 'mtm_window_stepsize', 0.05, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));

%% Watershed parameters
%Double vs single watershed
addOptional(p, 'double_watershed', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
%Decimation steps for the spectrogram prior to watershed: first index along the time axis; second index along frequency
addOptional(p, 'downsample_spect', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2)); % set by quality_setting
%Segment size for spectrogram parallelization
addOptional(p, 'seg_time', [], @(x) isa(x,'numeric') && (isempty(x) || isscalar(x))); % set by quality_setting
%Threshold weight value for when to stop merge rule
addOptional(p, 'merge_thresh', [], @(x) isa(x,'numeric') && (isempty(x) || isscalar(x))); % set by quality_setting
%Fixed quality setting by string options: 'stokes_2023', 'precision', or 'default'
% 'stokes_2023':
%   downsample_spect = [];
%   seg_time = 60; (seconds)
%   merge_thresh = 8; (merge weight unit)
% 'precision':
%   downsample_spect = [];
%   seg_time = 30; (seconds)
%   merge_thresh = 8; (merge weight unit)
% 'default':
%   downsample_spect = [2, 2]; (steps, steps)
%   seg_time = 30; (seconds)
%   merge_thresh = 11; (merge weight unit)
addOptional(p, 'quality_setting', 'default', @(x) any(validatestring(x, {'stokes_2023', 'precision', 'default'})));

%% Merging and trimming parameters
%Maximum number of merges to perform
addOptional(p, 'max_merges', inf, @(x) validateattributes(x,{'numeric'},{'real','positive','scalar'}));
%Fraction maximum trimmed volume
addOptional(p, 'trim_vol', 0.8, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
%Max duration allowed
addOptional(p, 'dur_max', 5, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
%Max bandwidth allowed
addOptional(p, 'bw_max', 15, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));

%% Frequency refinement using 1Hz df hann spectrum for final PeakFrequency feature computation
addOptional(p, 'refinement', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));

%% Features to compute
all_features = {'all', 'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height',  'HeightData',...
    'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume', 'PeakStage'};
addOptional(p, 'features', 'all', @(x) all(ismember(x, all_features)))

%% Display progress bar during runSegmentedData()
addOptional(p, 'show_pbar', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));

%% Add debug mode to execute runSegmentedData() in serial instead of parfor
addOptional(p, 'debug_mode', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));

%%
parse(p,varargin{:});
opts = p.Results;
