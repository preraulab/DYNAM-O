function opts = baseline_opts(varargin)
%% Parse inputs
p = inputParser;

%Baseline struct
addOptional(p, 'baseline_stages',[1,2,3,4,5],@(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addOptional(p, 'baseline_ptile',2,@(x) validateattributes(x, {'numeric', 'scalar'}, {'real', 'nonempty'}));
addOptional(p, 'baseline_trim',[],@(x) validateattributes(x, {'numeric', 'vector'}, {'real'}));

parse(p,varargin{:});
opts = p.Results; 