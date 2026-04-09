function [mode_params, mode_inds_all] = get_mode_params(fitobj, varargin)
%GET_MODE_PARAMS Get parameters of a given mode
%
%   [mode_params, mode_inds] = get_param_inds(fitobj, mode_nums, 'valid', true, 'param_type', 'modes')
%
%   This function retrieves the indices of coefficients for a specified
%   mode based on mode numer
%
%   Input:
%       fitobj: Fitted model object - The model containing the coefficients
%
%   Optional Name-Value Pair Inputs:
%       'mode_nums': Vector of mode numbers (Default: all modes)
%       'valid': Logical with a default value of true. If true, select only
%                the rows of mode_params in which the first column is non-zero.
%       'param_type': String that can be 'modes' or 'baseline'. Default is 'modes'.
%
%   Output:
%       mode_params: Matrix of parameter coefficients
%       mode_inds_all: Vector of indices of the parameters within the
%                      coefficients vector
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
addOptional(parser, 'mode_nums',[], @(x) assert(isnumeric(x) && all(mod(x,1)==0) && all(x>0) && all(x<=num_modes(fitobj)), ['Invalid mode number found, fit object has ' num2str(num_modes(fitobj)) ' modes']));
addOptional(parser, 'valid', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addOptional(parser, 'param_type', 'modes', @(x) ismember(x, {'modes', 'baseline'}));

parse(parser, fitobj, varargin{:});
fitobj = parser.Results.fitobj;
mode_nums = parser.Results.mode_nums;
valid = parser.Results.valid;
param_type = parser.Results.param_type;

% Compute once — used in multiple places below
N = num_modes(fitobj);

if isempty(mode_nums)
    mode_nums = 1:N;
end

% Get mode coefficients
mode_params_all = coeffvalues(fitobj);

% Extract baseline or mode parameters
switch param_type
    case 'baseline'
        mode_params = mode_params_all(N*num_mode_params(fitobj)+1:end);

    case 'modes'
        if ~isempty(mode_nums)

            mode_params = zeros(length(mode_nums), num_mode_params(fitobj));
            mode_inds_all = false(length(mode_params_all), 1);

            % Hoist coeffnames — avoids repeated calls inside the loop
            cnames = coeffnames(fitobj);

            for ii = 1:length(mode_nums)
                mode_inds = endsWith(cnames, ['_' num2str(mode_nums(ii))]);
                mode_inds_all = mode_inds_all | mode_inds;
                mode_params(ii,:) = mode_params_all(mode_inds);
            end

            % Pick modes with non-zero amps
            if valid
                mode_params = mode_params(mode_params(:,1)>0,:);
            end
        else
            mode_params = [];
        end
end
