function oof_slopes = oof_slope_calc(spect, stimes, sfreqs)
% Compute 1/f slope for each timepoint in spectrogram by fitting a linear
% regression model to the spectrum at each time
%
% Inputs:
%       spect: 2D double - spectrogram (in dB) [stimes, sfreqs]
%       stimes: 1D double - bin center times for dimension 1 of spect
%       sfreqs: 1D double = frequencies for dimension 2 of spect
%
% Outputs:
%       oof_slopes: slope of 1/f at each stime. 
%


oof_slopes = nan(length(stimes),1);
spect(spect==0) = 0.000001; % change 0s to avoid error of infs in fooof

settings = struct;

for ii = 1:length(stimes)
    tic;
    disp(ii);
    fooof_res = fooof(sfreqs', spect(ii,:)', [15, 45], settings, true);
    oof_slopes(ii) = fooof_res.aperiodic_params(2);
    toc;
%     oof_mdl_tbl = table(spect(ii,:)', log(sfreqs'), 'VariableNames', {'oof_pow', 'log_sfreqs'});
%     oof_mdl_fit = fitlm(oof_mdl_tbl, 'oof_pow~1+log_sfreqs');
%     oof_slopes(ii) = oof_mdl_fit.Coefficients.Estimate(2);
end

end


