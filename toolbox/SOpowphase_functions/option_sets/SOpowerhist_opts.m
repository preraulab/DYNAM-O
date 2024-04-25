function opts = SOpowerhist_opts(varargin)
%% Parse inputs
p = inputParser;
p.KeepUnmatched = true;

%General settings
addOptional(p, 'freq_range', [0,40], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'freq_binsizestep', [1, 0.2], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'compute_rate', true, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'SOPH_stages', 1:3, @(x) validateattributes(x, {'numeric', 'vector'}, {'real'})); % W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
addOptional(p, 'SO_freqrange', [0.3, 1.5], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan'}));

%SOpower specific settings
addOptional(p, 'SOpower_outlier_threshold', 3, @(x) validateattributes(x,{'numeric'},{'scalar'}));
addOptional(p, 'SOpower_norm_method', 'p2shift1234', @(x) validateattributes(x, {'char', 'numeric'},{}));
addOptional(p, 'SOpower_retain_Fs', true, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'SOpower_min_time_in_bin', 10, @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','nonnan','nonnegative','integer'}));
addOptional(p, 'SOpower_range', [], @(x) validateattributes(x,{'numeric', 'vector'}, {'real', 'nonempty'}));
addOptional(p, 'SOpower_binsizestep', [], @(x) validateattributes(x,{'numeric', 'vector'}, {'real', 'nonempty'}));

parse(p,varargin{:});
opts = p.Results; 