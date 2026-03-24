function [splinefit, coefs, spline_obj, knots_x, knots_y, f] = spline_basis(type, SOPH, SOfeature_bins, freq_bins, varargin)
%SPLINE_BASIS  Compute spline approximation for Slow Oscillation Power/Phase Histogram
%
%   Usage:
%       [splinefit, coefs, spline_obj] = spline_basis(type, SOPH, SOfeature_bins, freq_bins, num_knots_x, num_knots_y, plot_on)
%
%   Input:
%       type: String - 'power' or 'phase' to use the appropriate colormap and axis label -- required
%       SOPH: MxN matrix - Slow Oscillation Power Histogram data -- required
%       SOfeature_bins: 1xM vector - Bins for SO-Power or SO-Phase -- required
%       freq_bins: 1xN vector - Bins for frequency -- required
%
%   Optional input:
%       see spline_basis_opts() for optional parameters
%
%   Output:
%       splinefit: MxN matrix of the spline fit to SOPH data
%       coefs: (num_knots_x + 2) x (num_knots_y + 2) matrix of spline
%       coefficients. Additional knots are added at +- 0.1 from the edges
%       to remove an edge effect.
%       spline_obj: Spline structure representing the least-square spline approximation
%       f: figure handle to the final result figure
%
%   Example:
%       % Example SOPH data and usage
%       SOPH_data = rand(10, 20); % Replace with actual SOPH data
%       power_bins = 1:10; % Replace with actual power bins
%       freq_bins = 1:20; % Replace with actual frequency bins
%       num_knots_x = 5;
%       num_knots_y = 7;
%       [splinefit, coefs, spline_obj] = spline_basis('power', SOPH_data, power_bins, freq_bins, num_knots_x, num_knots_y);
%
%   NOTE: This function returns (num_internal_knots_x + 2) x (num_internal_knots_y + 2) coefficients because we
%   need to add external knots to not have edge effects. For dimensionality reduction it may be possible to remove the
%   outer border of coeffcients and retain the main structure of the SOPH, however it would not be possible to reconstruct
%   the SOPH accurately.
%
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
% ********************************************************************

%%
% If a struct is input with settings/params, detect and reformat it to work with the input parser below.
struct_ind = cellfun(@isstruct,varargin); % Get index of the struct

if any(struct_ind)
    locs = find(struct_ind==1);
    struct_arguments = cellfun(@(x) struct2cell(x), varargin(locs), 'UniformOutput', false);
    struct_fieldnames = cellfun(@(x) fieldnames(x), varargin(locs), 'UniformOutput', false);
    opt_struct = cell2struct(vertcat(struct_arguments{:}), vertcat(struct_fieldnames{:}));
    varargin = varargin(~struct_ind); % Remove structs from the varargin

    argcell = namedargs2cell(opt_struct); % Convert the struct to cell array
    varargin = cat(2, varargin, argcell); % Add the new cell array with the params to the end of the varargin

    % Test to make sure that none of the additional parameters are already included
    str_cell = cellstr(varargin(cellfun(@(x)(ischar(x)|isstring(x)),varargin)));
    assert(length(str_cell) == length(unique(str_cell)), 'Cannot include struct and duplicate parameters.')
end

%% Parse inputs
% Validate type input
assert(nargin > 0, 'Type must be specified as ''power'' or ''phase''.');
assert(ismember(type, {'power', 'phase'}), 'Invalid type. Valid types are ''power'' or ''phase''.');

p = inputParser;

addRequired(p, 'SOPH', @(x) isnumeric(x) && isreal(x) && ~any(x(:) < 0) && ~isempty(x) && ismatrix(x) && ~all(isnan(x), 'all'));
addRequired(p, 'SOfeature_bins', @(x) validateattributes(x, {'numeric'}, {'real','finite','increasing','vector'}));
addRequired(p, 'freq_bins', @(x) validateattributes(x, {'numeric'}, {'real','finite','increasing','vector'}));

default_params = spline_basis_opts(type); % get the default parameters
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

% Parse inputs
parse(p, SOPH, SOfeature_bins, freq_bins, varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

% Verify the dimensions of SOPH inputs
if size(SOPH, 1) == length(SOfeature_bins) && size(SOPH, 2) == length(freq_bins)
    % then SOPH needs to be transposed to work as a 2D image
    SOPH = transpose(SOPH);
else
    assert(size(SOPH, 2) == length(SOfeature_bins) && size(SOPH, 1) == length(freq_bins), 'Incompatible dimensions of SOPH inputs.')
end

% Locate the valid submatrix of SOPH (non-Nan and non-infinite bins within limits)
valid_mat = isfinite(SOPH);
invalid_freq = all(~valid_mat, 2);
valid_mat(invalid_freq, :) = true;
switch type
    case 'power'
        SOfeature_limits = power_limits;
    case 'phase'
        SOfeature_limits = phase_limits;
end
valid_SOfeature_bins = SOfeature_bins >= SOfeature_limits(1) & SOfeature_bins <= SOfeature_limits(2) & all(valid_mat, 1);
valid_freq_bins = freq_bins >= freq_limits(1) & freq_bins <= freq_limits(2) & ~invalid_freq';

SOPH_original = SOPH;
SOfeature_bins_original = SOfeature_bins;
freq_bins_original = freq_bins;

SOPH = SOPH(valid_freq_bins, valid_SOfeature_bins);
SOfeature_bins = SOfeature_bins(valid_SOfeature_bins);
freq_bins = freq_bins(valid_freq_bins);

%%
%Create interpolation grid
[X,Y] = ndgrid(SOfeature_bins, freq_bins);

% Create equally spaced knots in the x and y directions: addding external +- .1 to remove edge effect
knots_x = [min(SOfeature_bins)-.1 linspace(min(SOfeature_bins), max(SOfeature_bins), num_knots_x) max(SOfeature_bins)+.1];
knots_y = [min(freq_bins)-.1 linspace(min(freq_bins), max(freq_bins), num_knots_y) max(freq_bins)+.1];

% Compute the least-square spline approximation of SOPH/SOPhH
spline_obj = spap2({augknt(knots_x, 3), augknt(knots_y, 3)}, [4 4], {SOfeature_bins, freq_bins}, SOPH');
coefs = squeeze(spline_obj.coefs)';

%Create image matrix
splinefit = reshape(fnval(spline_obj, [X(:)'; Y(:)']), size(SOPH'));

%Plot results
if plot_on
    f = fullfig;
    ax = figdesign(1, 3, 'type', 'usletter', 'orient', 'landscape', 'margins', [0.1 0.13 0.08 0.1 0.1 0.08]);
    switch type
        case 'power'
            set(f, 'units', 'inches', 'position', [0 3 14 4]);
        case 'phase'
            set(f, 'units', 'inches', 'position', [0 0 14 4]);
    end

    axes(ax(1))
    imagesc(SOfeature_bins_original, freq_bins_original, SOPH_original);
    axis xy
    ylabel('Frequency (Hz)')
    switch type
        case 'power'
            colormap(gca, gouldian)
            xlabel('SO-Power (dB)')
            title(['SO-Power Histogram: ' num2str(numel(SOPH)) ' Parameters'])
        case 'phase'
            colormap(gca, magma);
            xlabel('SO-Phase (rad)');
            title(['SO-Phase Histogram: ' num2str(numel(SOPH)) ' Parameters'])
    end
    colorbar_noresize;

    axes(ax(2))
    imagesc(knots_x, knots_y, splinefit');
    axis xy
    ylabel('Frequency (Hz)')
    switch type
        case 'power'
            c = colorbar_noresize;
            c.Label.String = {'Density', '(peaks/min in bin)'};
            c.Label.Rotation = -90;
            c.Label.VerticalAlignment = "bottom";
            colormap(gca, gouldian)
            xlabel('SO-Power (dB)')
            title(['SO-Power Histogram: ' num2str(numel(SOPH)) ' Parameters'])
        case 'phase'
            c = colorbar_noresize;
            c.Label.String = {'Proportion'};
            c.Label.Rotation = -90;
            c.Label.VerticalAlignment = "bottom";
            colormap(gca, magma);
            xlabel('SO-Phase (rad)');
            title(['SO-Phase Histogram: ' num2str(numel(SOPH)) ' Parameters'])
    end
    title(['Spline Reconstruction: ' num2str(numel(coefs)) ' Parameters'])

    axes(ax(3))
    imagesc(1:size(coefs,2), 1:size(coefs,1), coefs);
    axis xy;
    clim(max(coefs,[],'all')*[-1 1]);
    c = colorbar_noresize;
    c.Label.String = {'Coefficient'};
    c.Label.Rotation = -90;
    c.Label.VerticalAlignment = "bottom";
    colormap(gca, flipud(redblue_equalized)); % make positive red and negative blue
    xlabel('x coeff knots')
    ylabel('y coeff knots')
    title('Spline Coefficients')

    equalize_axes(ax(1:2),'dimension','xyc');
    axes(ax(1))
    axis tight
    xlim(SOfeature_limits)
    ylim(freq_limits)

    c_ptiles = prctile(SOPH_original(SOPH_original(:)~=0), SOPH_clim_prctiles);
    clim(ax(1), [c_ptiles(1) c_ptiles(2)]);

    set(ax,'fontsize',10);
else
    f = [];
end
