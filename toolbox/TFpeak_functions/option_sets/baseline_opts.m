function opts = baseline_opts(varargin)
%% Parse inputs
p = inputParser;

%*******************************************
% Generate Baseline Options Structure
%*******************************************
addOptional(p, 'baseline_exclude',[],@(x) validateattributes(x,{'logical'},{'real','finite','nonnan'}));
%Sleep stages to include for baseline detection
addOptional(p, 'baseline_stages',[1,2,3,4,5],@(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
%Percentile to use for fixed baseline detection
addOptional(p, 'baseline_ptile',2,@(x) validateattributes(x, {'numeric', 'scalar'}, {'real', 'nonempty'}));
%Start and stop times for baseline trimming OR integer representing buffer time (min) around the first and last sleep period.
addOptional(p, 'baseline_trim',[-inf inf],@(x) validateattributes(x, {'numeric', 'vector'}, {'real'}));

parse(p,varargin{:});
opts = p.Results; 