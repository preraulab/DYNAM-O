function opts = SOphasehist_opts(varargin)
%% Parse inputs
p = inputParser;
p.KeepUnmatched = true;

%General settings
addOptional(p, 'freq_range', [0,40], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'freq_binsizestep', [0.5, 0.05], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'compute_rate', false, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'SOPH_stages', 1:3, @(x) validateattributes(x, {'numeric', 'vector'}, {'real'})); % W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0
addOptional(p, 'SO_freqrange', [0.3, 1.5], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan'}));

%SOphase specific settings
addOptional(p, 'SOphase_filter', []);
addOptional(p, 'SOphase_norm_dim', 0, @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','nonnan','nonnegative','integer'}));
addOptional(p, 'SOpower_tapers', [15 29], @(x) validateattributes(x,{'numeric', 'vector'}, {'numel',2}));
addOptional(p, 'SOpower_window_params', [30 15], @(x) validateattributes(x,{'numeric', 'vector'}, {'numel',2}));
addOptional(p, 'SOphase_range', [-pi,pi], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'SOphase_binsizestep', [(2*pi)/5, (2*pi)/100], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));

parse(p,varargin{:});
opts = p.Results; 