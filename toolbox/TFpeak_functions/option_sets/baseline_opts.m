function opts = baseline_opts(varargin)
%% Parse inputs
p = inputParser;

%****************************************
% Generate Baseline Options Structure
%****************************************
%Sleep stages to include for baseline computation
addOptional(p, 'baseline_stages',[1,2,3,4,5], @(x) validateattributes(x,{'numeric'},{'real','vector'}));
%Logical indices for time points to exclude for baseline computation
addOptional(p, 'baseline_exclude',logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));
%Percentile to use for fixed baseline computation
addOptional(p, 'baseline_ptile',2, @(x) validateattributes(x,{'numeric'},{'real','scalar'}));
%Start and stop times for baseline trimming OR integer representing buffer time (min) around the first and last sleep period.
addOptional(p, 'baseline_trim',[-inf inf], @(x) isa(x,'numeric') && length(x) <= 2);

parse(p,varargin{:});
opts = p.Results;
