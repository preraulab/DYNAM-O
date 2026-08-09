function default_params = param_basis_opts(type, varargin)
%PARAM_BASIS_OPTS Create a structure with default parameters for additive parameterization (power or phase)
%
%   Usage:
%       default_params = param_basis_opts(type, varargin)
%
%   Input:
%       type: String - 'power' or 'phase' to select the appropriate parameter set -- required
%
%   Optional inputs:
%       'power_limits' - 1x2 vector of SO power limits over which watershed is ran on spectrogram and 
%                        histograms are parameterized (default: [-2, 20]; only used for power histogram)
%       'phase_limits' - 1x2 vector of SO phase limits over which watershed is ran on spectrogram and 
%                        histograms are parameterized (default: [-pi, pi]; only used for phase histogram)
%       'freq_limits' - 1x2 vector of frequency limits over which watershed is ran on spectrogram and
%                        histograms are parameterized (default: [2, 18])
%       'watershed_params' - Vector [merge_thresh, dur_min, bw_min, height_min, trim_vol]
%           (default for 'power':   [nan,          4,       0.25,   0,          0.7],
%            default for 'phase':   [nan,          pi/6,    2,      1e-4,       0.4])
%       'gauss_filt_std' - Standard deviation ([row, col]) for Gaussian filter to smooth spectrogram before watershed (default: [10, 5]; only used for phase histogram)
%       'wshed_exp' - Flag for watershed expansion (default: false)
%       'max_peaks' - Maximum number of peaks to fit (-1 for unlimited) (default for 'power': 6, 'phase': 3)
%       'prefix_modes' - Prefix modes in the form [amp0, fmean0, fstd0, pmean0, pstd0, theta0],
%                        where fstd0 is a frequency standard deviation in Hz (default for 'power': [],
%                                                                        default for 'phase': [],
%                                                                        consider use for 'phase': [1e-3, 14, sqrt(2), 0,  pi/3, 0;
%                                                                                                   1e-3, 5,  sqrt(5), pi, pi/3, 0])
%       'prefix_modes_order' - Controls whether prefix modes are added before, after, or in place of watershed modes
%                              -1 = append prefix modes after watershed modes
%                              0  = use prefix modes only and ignore watershed modes
%                              1  = append prefix modes before watershed modes
%                              (default: -1)
%       'max_overlap' - Maximum allowed mode overlap (default for 'power': 0.25,
%                                                     default for 'phase': 0.15)
%       'min_amp' - Minimum amplitude for a peak (default: height_min from watershed_params)
%       'min_freq_diff' - Minimum allowed frequency difference (default: 0.5; only used for power histogram)
%       'criterion' - Criterion for model selection ('max', 'mindr2', 'minpctr2', 'kneedle') (default: 'minpctr2')
%       'min_dr2' - Minimum acceptable change in R-squared for adding a mode (default: 0.01)
%       'min_pctr2' - Minimum percentage change in R-squared for 'min%r2' criterion (default for 'power': 0.01,
%                                                                                    default for 'phase': 0.025)
%       'kneedle_tol' - Double, iteration tolerance for the kneedle algorithm (default: 0.01)
%       'UB_default' - Upper bounds for the fitting parameters - [amp0, fmean0, fstd0,       pmean0, pstd0,       theta0]
%                                          (default for 'power': [nan,  nan,    2.5/sqrt(2), nan,    30/sqrt(2),  0.03],
%                                           default for 'phase': [nan,  nan,    sqrt(7.5),   2*pi,   2*pi,        pi/3])
%       'LB_default' - Lower bounds for the fitting parameters - [amp0, fmean0, fstd0,       pmean0, pstd0,       theta0]
%                                          (default for 'power': [nan,  nan,    0.1/sqrt(2), nan,    2.5/sqrt(2), -0.03],
%                                           default for 'phase': [nan,  nan,    1/sqrt(2),   -2*pi,  pi/5,        -pi/3])
%       'constrain_freq_center' - Keep the frequency center within its configured bounds; false uses [-inf, inf] (default: true)
%       'constrain_power_center' - Keep the SO-power center within its configured bounds; false uses [-inf, inf] (default: true; power only)
%       'constrain_phase_center' - Keep the SO-phase center within its configured bounds; false uses [-inf, inf] (default: true; phase only)
%       'plot_on' - Flag to plot: 0 plot nothing, 1: plot the final result, 2: plot iterations, 3: plot iterations and final (default: 1)
%       'SOPH_clim_prctiles' - percentiles used to scale the heatmap color on SO feature histograms (default: [5, 98])
%       'verbose' - Flag to display detailed output (default: true)
%       'peak_assign_prob' - Gaussian probability for the power assignment contour and relative-height contour parameter for phase when computing per-mode Pk* summaries (default: 0.95)
%
%       Migrating custom prefix_modes / LB_default / UB_default values. The
%       Gaussian width slots now accept true standard deviations. Divide a
%       legacy value by sqrt(2) only when the goal is to preserve the exact
%       surface produced by the old no-half kernel. For that surface-preserving
%       conversion, an original variance-form phase value v becomes sqrt(v/2),
%       while an intervening no-half width w becomes w/sqrt(2). The latter
%       conversion applies to fstd0 (slot 3) on both axes and pstd0 (slot 5)
%       for 'power'. If a custom value was intentionally authored as the
%       desired physical standard deviation, reuse it unchanged; dividing it
%       by sqrt(2) would change that intended width. Phase pstd0 (slot 5) is
%       recikappa = 1/sqrt(kappa), a reciprocal-square-root concentration and
%       local small-angle Gaussian scale rather than a circular standard
%       deviation. Its kernel is unchanged, so reuse it unchanged.
%
%   Output:
%       default_params: Structure containing the parameters with either default or user-specified values
%
%   Example:
%       default_params = param_basis_opts('power', 'max_peaks', 10, 'min_dr2', 0.02);
%       default_params = param_basis_opts('phase', 'gauss_filt_std', 3);
%
%
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
%   GITHUB     https://github.com
%
%   ATTRIBUTION
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
default_params_power.freq_limits = [2, 18];
% watershed parameters follow this order: [merge_thresh, dur_min, bw_min, height_min, trim_vol]
default_params_power.watershed_params =   [nan,          4,       0.25,   0,          0.7];
default_params_power.wshed_exp = false;
default_params_power.max_peaks = 6;
default_params_power.prefix_modes = [];
default_params_power.prefix_modes_order = -1;
default_params_power.max_overlap = 0.25;
default_params_power.min_amp = default_params_power.watershed_params(4);
default_params_power.min_freq_diff = 0.5;
default_params_power.criterion = 'minpctr2';
default_params_power.min_dr2 = 0.01;
default_params_power.min_pctr2 = 0.01;
default_params_power.kneedle_tol = 0.01;
% fstd0 and pstd0 are true standard deviations of the rotGauss kernel. The
% sqrt(2) divisors carry the historical bounds (2.5, 30, 0.1, 2.5) into the
% standard-deviation convention, so each bound describes the same physical
% window it always did; only the units of the number moved.
% fitted parameters follow this order: [amp0, fmean0, fstd0,         pmean0, pstd0,       theta0];
default_params_power.UB_default =      [nan,  nan,    2.5/sqrt(2),   nan,    30/sqrt(2),  0.03];
default_params_power.LB_default =      [nan,  nan,    0.1/sqrt(2),   nan,    2.5/sqrt(2), -0.03];
default_params_power.constrain_freq_center = true;
default_params_power.constrain_power_center = true;
default_params_power.plot_on = 1;
default_params_power.SOPH_clim_prctiles = [5, 98];
default_params_power.verbose = true;
% Gaussian probability for the power assignment contour (the Pk* per-mode
% peak-property columns are means over peaks inside this region).
default_params_power.peak_assign_prob = 0.95;

% Default parameter values for 'phase'
default_params_phase.phase_limits = [-pi, pi];
default_params_phase.freq_limits = [2, 18];
% watershed parameters follow this order: [merge_thresh, dur_min, bw_min, height_min, trim_vol]
default_params_phase.watershed_params =   [nan,          pi/6,    2,      1e-4,       0.4];
default_params_phase.gauss_filt_std = [10, 5];
default_params_phase.wshed_exp = false;
default_params_phase.max_peaks = 3;
default_params_phase.prefix_modes =  [];
default_params_phase.prefix_modes_order = -1;
default_params_phase.max_overlap = 0.15;
default_params_phase.min_amp = default_params_phase.watershed_params(4);
default_params_phase.criterion = 'minpctr2';
default_params_phase.min_dr2 = 0.01;
default_params_phase.min_pctr2 = 0.025;
default_params_phase.kneedle_tol = 0.01;
% Two periods retain every circular phase class while allowing fits to cross
% the +/-pi seam without leaving the phase center completely unbounded.
% fstd0 is a true standard deviation (Hz): the historical bounds were sqrt(15)
% and 1 in the pre-half convention, so the equivalents are sqrt(15)/sqrt(2) =
% sqrt(7.5) and 1/sqrt(2). pstd0 is recikappa = 1/sqrt(kappa) (rad), a
% reciprocal-square-root concentration and local small-angle Gaussian scale;
% its von Mises kernel is unchanged, so 2*pi and pi/5 are left alone.
% fitted parameters follow this order: [amp0, fmean0, fstd0,     pmean0, pstd0, theta0];
default_params_phase.UB_default =      [nan,  nan,    sqrt(7.5), 2*pi,   2*pi,  pi/3];
default_params_phase.LB_default =      [nan,  nan,    1/sqrt(2), -2*pi,  pi/5,  -pi/3];
default_params_phase.constrain_freq_center = true;
default_params_phase.constrain_phase_center = true;
default_params_phase.plot_on = 1;
default_params_phase.SOPH_clim_prctiles = [5, 98];
default_params_phase.verbose = true;
% Relative-height contour parameter for phase assignment (the Pk* per-mode
% peak-property columns are means over peaks inside this region).
default_params_phase.peak_assign_prob = 0.95;

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
addParameter(p, 'watershed_params', default_params.watershed_params, @(x) isnumeric(x) && numel(x) == 5);
addParameter(p, 'max_overlap', default_params.max_overlap, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'min_amp', default_params.min_amp, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'max_peaks', default_params.max_peaks, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'wshed_exp', default_params.wshed_exp, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addParameter(p, 'prefix_modes', default_params.prefix_modes, @(x) isnumeric(x) && (isempty(x) || size(x, 2) == 6));
addParameter(p, 'prefix_modes_order', default_params.prefix_modes_order, @(x) ismember(x, [-1, 0, 1]));
switch type
    case 'power'
        addParameter(p, 'min_freq_diff', default_params.min_freq_diff, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    case 'phase'
        addParameter(p, 'gauss_filt_std', default_params.gauss_filt_std, @(x) isnumeric(x) && all(x > 0));
end
addParameter(p, 'criterion', default_params.criterion, @(x) ismember(x, {'max', 'mindr2', 'minpctr2', 'kneedle'}));
addParameter(p, 'min_dr2', default_params.min_dr2, @isnumeric);
addParameter(p, 'min_pctr2', default_params.min_pctr2, @isnumeric);
addParameter(p, 'kneedle_tol', default_params.kneedle_tol, @isscalar);
addParameter(p, 'UB_default', default_params.UB_default, @(x) isnumeric(x) && numel(x) == 6);
addParameter(p, 'LB_default', default_params.LB_default, @(x) isnumeric(x) && numel(x) == 6);
addParameter(p, 'constrain_freq_center', default_params.constrain_freq_center, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
switch type
    case 'power'
        addParameter(p, 'constrain_power_center', default_params.constrain_power_center, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    case 'phase'
        addParameter(p, 'constrain_phase_center', default_params.constrain_phase_center, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
end
addParameter(p, 'plot_on', default_params.plot_on, @(x) validateattributes(x, {'logical', 'numeric'}, {'scalar'}));
addParameter(p, 'SOPH_clim_prctiles', default_params.SOPH_clim_prctiles, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addParameter(p, 'verbose', default_params.verbose, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary'}));
addParameter(p, 'peak_assign_prob', default_params.peak_assign_prob, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);

% Parse input arguments
parse(p, varargin{:});

% Convert the parsed parameters into a structure
default_params = p.Results;
