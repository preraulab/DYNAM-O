function default_params = spline_basis_opts(type, varargin)
%SPLINE_BASIS_OPTS Create a structure with default parameters for spline basis approximation (power or phase)
%
%   Usage:
%       default_params = spline_basis_opts(type, varargin)
%
%   Input:
%       type: String - 'power' or 'phase' to select the appropriate parameter set -- required
%
%   Optional inputs:
%       'power_limits' - 1x2 vector of SO power limits over which histograms are fitted with splines (default: [-2, 20]; only used for power histogram)
%       'phase_limits' - 1x2 vector of SO phase limits over which histograms are fitted with splines (default: [-pi, pi]; only used for phase histogram)
%       'freq_limits' - 1x2 vector of frequency limits over which histograms are fitted with splines (default: [2, 16])
%       'num_knots_x' - Integer number of internal knots in the x-direction (default for 'power': 5, default for 'phase': 5)
%       'num_knots_y' - Integer number of internal knots in the frequency y-direction (default for 'power': 18, default for 'phase': 9)
%       'plot_on' - Flag to control whether to plot results (default: true)
%       'SOPH_clim_prctiles' - percentiles used to scale the heatmap color on SO feature histograms (default: [5, 98])
%
%   Output:
%       default_params: Structure containing the parameters with either default or user-specified values
%
%   Example:
%       default_params = spline_basis_opts('power', 'num_knots_x', 7, 'num_knots_y', 20);
%       default_params = spline_basis_opts('phase', 'freq_limits', [1, 30], 'plot_on', false);
%
%
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
%   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
%%
% Validate type input
assert(nargin > 0, 'Type must be specified as ''power'' or ''phase''.');
assert(ismember(type, {'power', 'phase'}), 'Invalid type. Valid types are ''power'' or ''phase''.');

% Default parameter values for 'power'
default_params_power.power_limits = [-2, 20];
default_params_power.freq_limits = [2, 16];
default_params_power.num_knots_x = 5;
default_params_power.num_knots_y = 18;
default_params_power.plot_on = true;
default_params_power.SOPH_clim_prctiles = [5, 98];

% Default parameter values for 'phase'
default_params_phase.phase_limits = [-pi, pi];
default_params_phase.freq_limits = [2, 16];
default_params_phase.num_knots_x = 5;
default_params_phase.num_knots_y = 9;
default_params_phase.plot_on = true;
default_params_phase.SOPH_clim_prctiles = [5, 98];

% Select appropriate default parameters based on type
switch type
    case 'power'
        default_params = default_params_power;
    case 'phase'
        default_params = default_params_phase;
end

% Create input parser
p = inputParser;

% Add each field in default_params to the parser with validation
switch type
    case 'power'
        addParameter(p, 'power_limits', default_params.power_limits, @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
    case 'phase'
        addParameter(p, 'phase_limits', default_params.phase_limits, @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
end
addParameter(p, 'freq_limits', default_params.freq_limits, @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addParameter(p, 'num_knots_x', default_params.num_knots_x, @(x) validateattributes(x, {'numeric'}, {'positive', 'integer', 'scalar'}));
addParameter(p, 'num_knots_y', default_params.num_knots_y, @(x) validateattributes(x, {'numeric'}, {'positive', 'integer', 'scalar'}));
addParameter(p, 'plot_on', default_params.plot_on, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addParameter(p, 'SOPH_clim_prctiles', default_params.SOPH_clim_prctiles, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));

% Parse input arguments
parse(p, varargin{:});

% Convert the parsed parameters into a structure
default_params = p.Results;
