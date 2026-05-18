function [SOPHs] = fitParamBasis(SOPHs, power_opts, phase_opts, valid_powerhist, valid_phasehist, verbose, plot_each, plot_both)
%FITPARAMBASIS  Fit the parametric basis to SOpower and SOphase histograms.
%
%   SOPHs = fitParamBasis(SOPHs, power_opts, phase_opts, ...
%                         valid_powerhist, valid_phasehist, ...
%                         verbose, plot_each, plot_both)
%
%   Power and phase fits run independently — a failure in one is reported
%   but does not abort the other. The corresponding *_paramfit field is
%   left empty to signal failure.
if nargin < 2 || isempty(power_opts); power_opts = param_basis_opts('power'); end
if nargin < 3 || isempty(phase_opts); phase_opts = param_basis_opts('phase'); end
if nargin < 4 || isempty(valid_powerhist); valid_powerhist = true; end
if nargin < 5 || isempty(valid_phasehist); valid_phasehist = true; end
if nargin < 6 || isempty(verbose); verbose = true; end
if nargin < 7 || isempty(plot_each); plot_each = false; end
if nargin < 8 || isempty(plot_both); plot_both = true; end

if verbose && (valid_powerhist || valid_phasehist)
    disp('  Fitting parametric basis...');
end

pow_ok = false; phase_ok = false;
SOPHs.SOpower_paramfit = [];
SOPHs.SOphase_paramfit = [];
params_power = []; model_SOPH_power = [];
params_phase = []; model_SOPH_phase = [];

% Phase fit runs first so its model surface (model_SOPH_phase) is
% available when the power table is annotated below with model-based
% preferred-phase columns.
if valid_phasehist
    phase_opts.plot_on = plot_each;
    phase_opts.verbose = verbose-1;
    try
        [params_phase, fitobj_phase, gof_phase, model_SOPH_phase, wshed_img_phase] = param_basis_phase(SOPHs.SOphase_mat, SOPHs.SOphase_bins, SOPHs.freq_bins, phase_opts);
        if isempty(fitobj_phase)
            fprintf(2, '  [WARN] param_basis_phase returned no fit (see warning above).\n');
        else
            SOPHs.SOphase_paramfit = createSOPHparamfitStruct('phase', params_phase, fitobj_phase, gof_phase, model_SOPH_phase, wshed_img_phase);
            phase_ok = true;
        end
    catch ME_phase
        fprintf(2, '  [ERROR] param_basis_phase failed: %s\n', ME_phase.message);
        warning('runDYNAMO:fitParamBasis:phase', 'param_basis_phase failed: %s', ME_phase.message);
    end
end

if valid_powerhist
    power_opts.plot_on = plot_each;
    power_opts.verbose = verbose-1;
    try
        [params_power, fitobj_power, gof_power, model_SOPH_power, wshed_img_power] = param_basis_power(SOPHs.SOpower_mat, SOPHs.SOpower_bins, SOPHs.freq_bins, power_opts);
        if isempty(fitobj_power)
            fprintf(2, '  [WARN] param_basis_power returned no fit (see warning above).\n');
        else
            SOPHs.SOpower_paramfit = createSOPHparamfitStruct('power', params_power, fitobj_power, gof_power, model_SOPH_power, wshed_img_power);
            pow_ok = true;

            % Annotate the power table with three preferred-phase
            % estimators per mode (argmax / circular mean / model max).
            % Skipped when the power fit produced zero modes (empty
            % table already carries placeholder column names).
            if ~isempty(SOPHs.SOpower_paramfit.params)
                SOPHs.SOpower_paramfit.params = annotatePowerWithPreferredPhase( ...
                    SOPHs.SOpower_paramfit.params, SOPHs.SOphase_mat, ...
                    SOPHs.freq_bins, SOPHs.SOphase_bins, model_SOPH_phase);
            end
        end
    catch ME_pow
        fprintf(2, '  [ERROR] param_basis_power failed: %s\n', ME_pow.message);
        warning('runDYNAMO:fitParamBasis:power', 'param_basis_power failed: %s', ME_pow.message);
    end
end

if plot_both && (pow_ok || phase_ok)
    if pow_ok,   pow_fitobj   = SOPHs.SOpower_paramfit.fitobj;   pow_wshed   = SOPHs.SOpower_paramfit.wshed_img;   else, pow_fitobj   = []; pow_wshed   = []; end
    if phase_ok, phase_fitobj = SOPHs.SOphase_paramfit.fitobj;   phase_wshed = SOPHs.SOphase_paramfit.wshed_img;   else, phase_fitobj = []; phase_wshed = []; end
    plot_SOPH_paramfits( ...
        SOPHs.SOpower_bins, pow_wshed, SOPHs.SOpower_mat, model_SOPH_power, params_power, power_opts.SOPH_clim_prctiles, power_opts.power_limits, power_opts.freq_limits, ...
        SOPHs.SOphase_bins, phase_wshed, SOPHs.SOphase_mat, model_SOPH_phase, params_phase, phase_opts.SOPH_clim_prctiles, phase_opts.phase_limits, phase_opts.freq_limits, ...
        SOPHs.freq_bins, pow_fitobj, phase_fitobj);
end
end
