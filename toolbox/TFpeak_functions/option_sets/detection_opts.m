function opts = detection_opts(varargin)
%% Parse inputs
p = inputParser;

%************************************************
% Generate TF-Peak Detection Option Structure
%************************************************
%Verbose option
addOptional(p, 'verbose', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));

%Double vs single watershed
addOptional(p, 'double_watershed', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));

%Multitaper method parameters
%Frequency bin resolution of the spectrogram
addOptional(p, 'dsfreqs', 0.1, @(x) validateattributes(x,{'scalar','numeric'},{'real','nonempty', 'nonnan'}));
%Taper parameters [time half-bandwidth product, number of tapers]
addOptional(p, 'mtm_taper_params', [2, 3], @(x) validateattributes(x,{'vector','numeric'},{'real','nonempty', 'nonnan'}));
%Window length in spectrogram computation for the first round of watershed
addOptional(p, 'mtm_window_length_1', 1, @(x) validateattributes(x,{'scalar','numeric'},{'real','nonempty', 'nonnan'}));
%Window length in spectrogram computation for the second round of watershed
addOptional(p, 'mtm_window_length_2', 2, @(x) validateattributes(x,{'scalar','numeric'},{'real','nonempty', 'nonnan'}));
%Window step size in spectrogram computations
addOptional(p, 'mtm_window_stepsize', 0.05, @(x) validateattributes(x,{'scalar','numeric'},{'real','nonempty', 'nonnan'}));

%Watershed parameters
%Decimation steps for the spectrogram prior to watershed: first index along the time axis; second index along frequency
addOptional(p, 'downsample_spect', [], @(x) validateattributes(x,{'vector','numeric'},{})); % set by quality_setting
%Segment size for spectrogram paralleization
addOptional(p, 'seg_time', [], @(x) validateattributes(x,{'scalar','numeric'},{})); % set by quality_setting
%Threshold weight value for when to stop merge rule
addOptional(p, 'merge_thresh', [], @(x) validateattributes(x,{'scalar','numeric'},{})); % set by quality_setting
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
addOptional(p, 'quality_setting', 'default', @(x) validateattributes(x,{'char'},{}));

%Merging and trimming parameters
%Maximum number of merges to perform
addOptional(p, 'max_merges', inf, @(x) validateattributes(x,{'scalar','numeric'},{}));
%Fraction maximum trimmed volume
addOptional(p, 'trim_vol', 0.8, @(x) validateattributes(x,{'scalar','numeric'},{}));
%Max duration allowed
addOptional(p, 'dur_max', 5, @(x) validateattributes(x,{'scalar','numeric'},{}));
%Max bandwidth allowed
addOptional(p, 'bw_max', 15, @(x) validateattributes(x,{'scalar','numeric'},{}));

%Frequency refinement using 1Hz df hann spectrum for final PeakFrequency feature computation
addOptional(p, 'refinement', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));

%Features to compute
all_features = {'all', 'Area', 'Bandwidth', 'Boundaries', 'BoundingBox', 'Duration', 'Height',  'HeightData',...
    'PeakFrequency', 'PeakTime', 'SegmentNum', 'Volume', 'PeakStage'};
addOptional(p,'features','all',@(x)all(ismember(x,all_features)))

parse(p,varargin{:});
opts = p.Results;
