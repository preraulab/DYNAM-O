function opts = watershed_opts(varargin)
%% Parse inputs
p = inputParser;

%Watershed struct
addOptional(p, 'double_watershed', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
addOptional(p, 'dsfreqs', 0.1, @(x) validateattributes(x,{'scalar','numeric'},{'real','nonempty', 'nonnan'}));
addOptional(p, 'downsample_spect', [2 2], @(x) validateattributes(x,{'vector','numeric'},{}));
addOptional(p, 'seg_time', 3, @(x) validateattributes(x,{'scalar','numeric'},{}));
addOptional(p, 'merge_thresh', 11, @(x) validateattributes(x,{'scalar','numeric'},{}));
addOptional(p, 'quality_setting', '', @(x) validateattributes(x,{'char','numeric'},{}));
addOptional(p, 'refinement', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
addOptional(p, 'remove_edge_peaks', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
addOptional(p, 'refine_method', 'spline_interp', @(x) validatestring(x,{'spline_interp','spline_opt','spect_max'}));
addOptional(p, 'verbose', true, @(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));

parse(p,varargin{:});
opts = p.Results; 
