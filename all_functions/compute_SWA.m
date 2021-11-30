function [SWA, stimes]= compute_SWA( data, Fs, method, spect_data )
%COMPUTE_SWA Computes slow wave amplitude from the multitaper spectrogram
%   SWA = compute_SWA( data, Fs )

if nargin<3
    method='dB';
end

if nargin<4
    spect_data=[];
end

frequency_range = [0.3, 1.5]; 
taper_params = [15, 29];
window_params = [30, 15];
min_NFFT = [];
detrend_opt = 'linear';
weighting = [];
plot_on = false;
verbose = true;
xyflip = true;

if isempty(spect_data)
    [spect,stimes]=multitaper_spectrogram(data, Fs, frequency_range, taper_params, window_params, min_NFFT, detrend_opt, weighting, plot_on, verbose, xyflip);
else
    [~,idx_low]=min(abs(spect_data.sfreqs - frequency_range(1)));
    [~,idx_high]=min(abs(spect_data.sfreqs - frequency_range(2)));
    spect = spect_data.spect(idx_low:idx_high, :);
    stimes = spect_data.stimes;
end

switch lower(method)
    case {'db'}
        SWA=nanpow2db(sum(spect,2));
    case {'sqrt'}
        SWA=sqrt(sum(spect,2));
    otherwise
        error('Invalid method');
end
end

