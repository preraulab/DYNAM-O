function opts = SOpower_opts(varargin)
%% Parse inputs
p = inputParser;
p.KeepUnmatched = true;

%****************************************
% Generate SOpower Options Structure
%****************************************
addOptional(p, 'SO_freqrange', [0.3, 1.5], @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector','numel',2}));
addOptional(p, 'SOpower_tapers', [5, 9], @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'SOpower_window_params', [5, .5], @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'SOpower_outlier_threshold', 3, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addOptional(p, 'SOpower_norm_method', 'p2shift1234', @(x) validateattributes(x, {'char','string'}, {'nonempty','scalartext'}));
addOptional(p, 'SOpower_retain_Fs', true, @(x) validateattributes(x,{'logical'},{'scalar'}));

parse(p,varargin{:});
opts = p.Results;
