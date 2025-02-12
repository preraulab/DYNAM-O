function opts = SOphase_opts(varargin)
%% Parse inputs
p = inputParser;
p.KeepUnmatched = true;

%****************************************
% Generate SOphase Options Structure
%****************************************
SOpower_options = SOpower_opts(); % only define once the default frequency range for slow oscillation
addOptional(p, 'SO_freqrange', SOpower_options.SO_freqrange, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector','numel',2}));
addOptional(p, 'SOphase_filter', []);

parse(p,varargin{:});
opts = p.Results;
