function [SOPHs] = fitSplineBasis(SOPHs, power_opts, phase_opts, valid_powerhist, valid_phasehist, verbose, plot_each, plot_both)
%FITSPLINEBASIS  Fit the spline basis to SOpower and SOphase histograms.
%
%   SOPHs = fitSplineBasis(SOPHs, power_opts, phase_opts, ...
%                          valid_powerhist, valid_phasehist, ...
%                          verbose, plot_each, plot_both)
%
%   Same isolation pattern as fitParamBasis: power and phase fits run
%   independently, and a failure in one leaves the corresponding
%   *_splinefit field empty rather than aborting the other.
if verbose && (valid_powerhist || valid_phasehist)
    disp('  Fitting spline basis...');
end

pow_ok = false; phase_ok = false;
SOPHs.SOpower_splinefit = [];
SOPHs.SOphase_splinefit = [];
splinefit_power = []; coefs_power = []; knots_x_power = []; knots_y_power = [];
splinefit_phase = []; coefs_phase = []; knots_x_phase = []; knots_y_phase = [];

if valid_powerhist
    power_opts.plot_on = plot_each;
    try
        [splinefit_power, coefs_power, spline_obj_power, knots_x_power, knots_y_power, fit_so_power, fit_freq_power] = spline_basis('power', SOPHs.SOpower_mat, SOPHs.SOpower_bins, SOPHs.freq_bins, power_opts);
        SOPHs.SOpower_splinefit = createSOPHsplinefitStruct(splinefit_power, coefs_power, spline_obj_power, knots_x_power, knots_y_power, fit_so_power, fit_freq_power);
        pow_ok = true;
    catch ME_pow
        fprintf(2, '  [ERROR] spline_basis (power) failed: %s\n', ME_pow.message);
        warning('runDYNAMO:fitSplineBasis:power', 'spline_basis (power) failed: %s', ME_pow.message);
    end
end

if valid_phasehist
    phase_opts.plot_on = plot_each;
    try
        [splinefit_phase, coefs_phase, spline_obj_phase, knots_x_phase, knots_y_phase, fit_so_phase, fit_freq_phase] = spline_basis('phase', SOPHs.SOphase_mat, SOPHs.SOphase_bins, SOPHs.freq_bins, phase_opts);
        SOPHs.SOphase_splinefit = createSOPHsplinefitStruct(splinefit_phase, coefs_phase, spline_obj_phase, knots_x_phase, knots_y_phase, fit_so_phase, fit_freq_phase);
        phase_ok = true;
    catch ME_phase
        fprintf(2, '  [ERROR] spline_basis (phase) failed: %s\n', ME_phase.message);
        warning('runDYNAMO:fitSplineBasis:phase', 'spline_basis (phase) failed: %s', ME_phase.message);
    end
end

if plot_both && (pow_ok || phase_ok)
    plot_SOPH_splinefits( ...
        SOPHs.SOpower_mat, SOPHs.SOpower_bins, splinefit_power, coefs_power, knots_x_power, knots_y_power, power_opts, ...
        SOPHs.SOphase_mat, SOPHs.SOphase_bins, splinefit_phase, coefs_phase, knots_x_phase, knots_y_phase, phase_opts, ...
        SOPHs.freq_bins);
end
end
