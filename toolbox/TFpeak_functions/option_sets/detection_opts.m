function opts = detection_opts(varargin)
%% Parse inputs
p = inputParser;

%*******************************************
% Generate TF-Peak detection Structure
%*******************************************
%Verbose option
addOptional(p, 'verbose', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));

%Double vs single watershed
addOptional(p, 'double_watershed', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
%Frequency refinment using 1Hz df hann spectrum
addOptional(p, 'refinement', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
%Remove descritization by interpolating to a much higher df during the refinement stage
addOptional(p, 'refine_method', 'spline_interp', @(x) validatestring(x,{'spline_interp','spline_opt','spect_max'}));

%Frequency bin resolution of the spectrogram
addOptional(p, 'dsfreqs', 0.1, @(x) validateattributes(x,{'scalar','numeric'},{'real','nonempty', 'nonnan'}));
%Decimation steps for the spectrogram prior to watershed
addOptional(p, 'downsample_spect', [2 2], @(x) validateattributes(x,{'vector','numeric'},{}));
%Segment size for spectrogram paralleization
addOptional(p, 'seg_time', 30, @(x) validateattributes(x,{'scalar','numeric'},{}));
%Fixed quality setting by name 'fast', 'precision', 'paper'
addOptional(p, 'quality_setting', '', @(x) validateattributes(x,{'char','numeric'},{}));
%Remove peaks at the edge of the bounds in masking step
addOptional(p, 'remove_edge_peaks', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));

%Watershed parameters
%Threshold weight value for when to stop merge rule
addOptional(p, 'merge_thresh', 11, @(x) validateattributes(x,{'scalar','numeric'},{}));
%Maximum number of merges to perform
addOptional(p, 'max_merges', inf, @(x) validateattributes(x,{'scalar','numeric'},{}));
%Fraction maximum trimmed volume
addOptional(p, 'trim_vol', 0.8, @(x) validateattributes(x,{'scalar','numeric'},{}));
%Pixel connection used in trimming
addOptional(p, 'conn_trim', 8, @(x) validateattributes(x,{'scalar','numeric'},{}));
%Pixel connection used by watershed
addOptional(p, 'conn_wshed', 8, @(x) validateattributes(x,{'scalar','numeric'},{}));
%Min duration allowed
addOptional(p, 'dur_min', 0, @(x) validateattributes(x,{'scalar','numeric'},{}));
%Min bandwidth allowed
addOptional(p, 'bw_min', 0, @(x) validateattributes(x,{'scalar','numeric'},{}));

parse(p,varargin{:});
opts = p.Results; 
