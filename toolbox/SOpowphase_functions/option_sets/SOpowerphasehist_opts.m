function opts = SOpowerphasehist_opts(varargin)
%% Parse inputs
p = inputParser;
p.KeepUnmatched = true;

%General settings
addOptional(p, 'freq_range', [0,40], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'freq_binsizestep', [1, 0.2], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'compute_rate', true, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'SOPH_stages', 1:3, @(x) validateattributes(x, {'numeric', 'vector'}, {'real'})); % W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0

%SOpower params
addOptional(p, 'SO_freqrange', [0.3, 1.5], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan'}));
addOptional(p, 'SOpower_tapers', [5 9], @(x) validateattributes(x,{'numeric', 'vector'}, {'numel',2}));
addOptional(p, 'SOpower_window_params', [5 .5], @(x) validateattributes(x,{'numeric', 'vector'}, {'numel',2}));
addOptional(p, 'SOpower_outlier_threshold', 3, @(x) validateattributes(x,{'numeric'},{'scalar'}));

%SOpower specific settings
addOptional(p, 'SOpower_norm_method', 'p2shift1234', @(x) validateattributes(x, {'char', 'numeric'},{}));
addOptional(p, 'SOpower_retain_Fs', true, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'SOpower_min_time_in_bin', 10, @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','nonnan','nonnegative','integer'}));
%Ranges and bin step sizes determined dynamically with empty input [], set to fixed values when comparing between subjects
addOptional(p, 'SOpower_range', [], @(x) validateattributes(x,{'numeric', 'vector'}, {'real', 'nonempty'}));
addOptional(p, 'SOpower_binsizestep', [], @(x) validateattributes(x,{'numeric', 'vector'}, {'real', 'nonempty'}));

%SOphase specific settings
addOptional(p, 'SOphase_filter', []);
addOptional(p, 'SOphase_norm_dim', 1, @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','nonnan','nonnegative','integer'}));
addOptional(p, 'SOphase_range', [-pi,pi], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'SOphase_binsizestep', [(2*pi)/5, (2*pi)/100], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));

parse(p,varargin{:});
opts = p.Results;
