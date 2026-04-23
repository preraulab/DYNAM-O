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
addOptional(p, 'downsample_spect', [2, 2], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
%Segment size for spectrogram parallelization
addOptional(p, 'seg_time', 30, @(x) isa(x,'numeric') && isscalar(x));
%Threshold weight value for when to stop merge rule
addOptional(p, 'merge_thresh', 11, @(x) isa(x,'numeric') && isscalar(x));
%Quality setting preset: 'stokes_2023', 'precision', 'default', or '' (use individual params above).
% Overrides downsample_spect, seg_time, and merge_thresh when non-empty.
% 'stokes_2023':  downsample_spect=[],    seg_time=60, merge_thresh=8
% 'precision':    downsample_spect=[],    seg_time=30, merge_thresh=8
% 'default':      downsample_spect=[2,2], seg_time=30, merge_thresh=11
addOptional(p, 'quality_setting', '', @(x) (ischar(x) || isstring(x)) && (isempty(x) || any(validatestring(x, {'stokes_2023', 'precision', 'default'}))));

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

%% Parallel pool type: 'Processes' (default), 'Threads', or '' (same as 'Processes').
% ProcessPool is used on every host. ThreadPool is supported as an explicit
% override but disables trim_region_mex (MEX cannot run inside a ThreadPool
% worker; the MATLAB fallback is bit-identical but slower).
addOptional(p, 'parallel_mode', 'Processes', @(x) (ischar(x) || isstring(x)) && any(strcmp(x, {'', 'Processes', 'Threads'})));

%% Trim-region MEX toggle: set false to force the pure-MATLAB trim path
% even on ProcessPool / serial runs where the MEX is available. Useful for
% reproducing a master-branch run without deleting the binary, bisecting
% a suspected MEX-vs-MATLAB disagreement, or benchmarking MEX impact on a
% given host. When false, output is bit-identical to the MEX path but
% runs slower. Always effectively false inside a ThreadPool worker
% regardless of this setting (MATLAB hard-blocks MEX there).
addOptional(p, 'use_trim_mex', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));

%%
parse(p,varargin{:});
opts = p.Results;

% A non-empty quality_setting overrides downsample_spect, seg_time, and merge_thresh
if ~isempty(opts.quality_setting)
    switch lower(opts.quality_setting)
        case 'stokes_2023'
            opts.downsample_spect = [];
            opts.seg_time = 60;
            opts.merge_thresh = 8;
        case 'precision'
            opts.downsample_spect = [];
            opts.seg_time = 30;
            opts.merge_thresh = 8;
        case 'default'
            opts.downsample_spect = [2, 2];
            opts.seg_time = 30;
            opts.merge_thresh = 11;
    end
end
