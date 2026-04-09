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
% Input Parser
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://harvard.edu
%   GITHUB     https://github.com
%
%   CITATION
%   If you use this toolbox, please cite:
%
%   He, M., Prerau, M. J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%    in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%    for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
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

