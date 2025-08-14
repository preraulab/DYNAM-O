function names = get_mode_param_names(fitobj, varargin)
%GET_MODE_PARAM_NAMES Get names of parameters for a given mode
%
%   names = get_mode_param_names(fitobj, varargin)
%
%   This function retrieves the names of coefficients for a specified mode
%
%   Input:
%       fitobj: Fitted model object - The model containing the coefficients
%       params: String specifying the type of parameters to retrieve. 
%               Options are:
%                   'modes' for the parameters common to each mode
%                   'baseline' for the baseline parameter names
%                   'both' for the mode and baseline parameter names
%                   'all' for full list of parameters, equivalent to coeffnames(fitobj)
%               Default is 'modes'.
%
%   Output:
%       names: Cell array of parameter names
%
%   Example:
%       fitobj = ... % create or obtain a fitted model object
%       names = get_mode_param_names(fitobj, 'params', 'all');
%
%   Copyright 2024 Michael J. Prerau Laboratory - http://www.sleepEEG.org
%% ********************************************************************

% Input Parser
parser = inputParser;

% Required inputs
addRequired(parser, 'fitobj', @(x) assert(isa(x, 'sfit'), 'fitobj is not class sfit'));

% Optional inputs
addOptional(parser, 'params', 'modes', @(x) ismember(lower(x), {'both', 'modes', 'baseline', 'all'}));

parse(parser, fitobj, varargin{:});
fitobj = parser.Results.fitobj;
params = parser.Results.params;

all_names = coeffnames(fitobj);
modes_baseline_names = unique(regexprep(all_names, '_.*$', ''));

switch params
    case 'all'
        names = all_names;
    case 'both'
        names = modes_baseline_names;
    case 'modes'
        names = modes_baseline_names(1:num_mode_params(fitobj));
    case 'baseline'
        names = modes_baseline_names(num_mode_params(fitobj)+1:end);
end

% Input Parser
parser = inputParser;

% Required inputs
addRequired(parser, 'fitobj', @(x) assert(isa(x, 'sfit'), 'fitobj is not class sfit'));

% Optional inputs
addOptional(parser, 'params', 'modes', @(x) ismember(lower(x), {'both', 'modes', 'baseline', 'all'}));

parse(parser, fitobj, varargin{:});
fitobj = parser.Results.fitobj;
params = parser.Results.params;

all_names = coeffnames(fitobj);
modes_baseline_names = unique(regexprep(all_names, '_.*$', ''));

switch params
    case 'all'
        names = all_names;
    case 'both'
        names = modes_baseline_names;
    case 'modes'
        names = modes_baseline_names(1:num_mode_params(fitobj));
    case 'baseline'
        names = modes_baseline_names(num_mode_params(fitobj)+1:end);
end

