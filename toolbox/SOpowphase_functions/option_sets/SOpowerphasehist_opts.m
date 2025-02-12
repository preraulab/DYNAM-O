function opts = SOpowerphasehist_opts(varargin)
%% Parse inputs
p = inputParser;
p.KeepUnmatched = true;

%General settings
addOptional(p, 'freq_range', [0, 40], @(x) validateattributes(x,{'numeric'},{'real','finite','vector','numel',2}));
addOptional(p, 'freq_binsizestep', [1, 0.2], @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'compute_rate', true, @(x) validateattributes(x,{'logical'},{'scalar'}));
addOptional(p, 'SOPH_stages', 1:3, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','vector'})); % W = 5, REM = 4, N1 = 3, N2 = 2, N3 = 1, Artifact = 6, Undefined = 0

%SOpower computation params
SOpower_options = SOpower_opts(); % get the default parameters
addOptional(p, 'SO_freqrange', SOpower_options.SO_freqrange, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector','numel',2}));
addOptional(p, 'SOpower_tapers', SOpower_options.SOpower_tapers, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'SOpower_window_params', SOpower_options.SOpower_window_params, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'SOpower_outlier_threshold', SOpower_options.SOpower_outlier_threshold, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addOptional(p, 'SOpower_norm_method', SOpower_options.SOpower_norm_method, @(x) validateattributes(x, {'char','string'}, {'nonempty','scalartext'}));
addOptional(p, 'SOpower_retain_Fs', SOpower_options.SOpower_retain_Fs, @(x) validateattributes(x,{'logical'},{'scalar'}));

%SOpower Histogram specific settings
addOptional(p, 'SOpower_min_time_in_bin', 10, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));
%Ranges and bin step sizes determined dynamically with empty input [], set to fixed values when comparing between subjects
addOptional(p, 'SOpower_range', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addOptional(p, 'SOpower_binsizestep', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));

%SOphase computation params
SOphase_options = SOphase_opts(); % get the default parameters
addOptional(p, 'SOphase_filter', SOphase_options.SOphase_filter);

%SOphase Histogram specific settings
addOptional(p, 'SOphase_norm_dim', 1, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));
addOptional(p, 'SOphase_range', [-pi, pi], @(x) validateattributes(x, {'numeric'}, {'real','finite','vector','numel',2}));
addOptional(p, 'SOphase_binsizestep', [(2*pi)/5, (2*pi)/100], @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));

parse(p,varargin{:});
opts = p.Results;
